import Foundation

// MARK: - Configuration

/// Injected credentials and endpoints — keep secrets out of source control.
struct TeslaNetworkConfiguration: Sendable {
    let fleetAPIBaseURL: URL
    let authBaseURL: URL
    let teslaClientID: String
    let supabaseURL: URL
    let supabaseAnonKey: String
    let supabaseAccessToken: String
    let authRecordID: UUID?
    /// Fallback when `tesla_auth.vin` is not set yet.
    let vin: String?

    static let defaultFleetAPIBaseURL = URL(string: "https://fleet-api.prd.api.tesla.com")!
    static let defaultAuthBaseURL = URL(string: "https://fleet-auth.prd.vn.cloud.tesla.com")!
    static let defaultSupabaseURL = URL(string: "https://eqgxfdbaxptmokniggar.supabase.co")!
    static let defaultVIN = "LRW3F7EJ6TC864153"
}

// MARK: - Errors

enum TeslaNetworkError: Error, LocalizedError, Sendable {
    case missingVIN
    case noAuthRecord
    case tokenRefreshFailed(reason: String)
    case vehicleUnavailable
    case httpError(status: Int, body: String)
    case decodingFailed(underlying: String)

    var errorDescription: String? {
        switch self {
        case .missingVIN:
            return "No VIN is stored in tesla_auth. Add your vehicle VIN before fetching data."
        case .noAuthRecord:
            return "No Tesla auth record found in Supabase."
        case .tokenRefreshFailed(let reason):
            return "Failed to refresh Tesla access token: \(reason)"
        case .vehicleUnavailable:
            return "Vehicle is asleep or unavailable (HTTP 408)."
        case .httpError(let status, let body):
            return "HTTP \(status): \(body)"
        case .decodingFailed(let underlying):
            return "Failed to decode response: \(underlying)"
        }
    }
}

// MARK: - Token coordinator

/// Serializes token load/refresh so concurrent callers never double-spend a single-use refresh token.
private actor TokenCoordinator {
    private var cachedRecord: TeslaAuthRecord?
    private var refreshTask: Task<String, Error>?

    func validAccessToken(
        using manager: TeslaNetworkManager
    ) async throws -> String {
        if let refreshTask {
            return try await refreshTask.value
        }

        let record = try await manager.fetchAuthRecord()
        cachedRecord = record

        // Refresh 60 seconds before expiry to avoid edge-case 401s.
        if record.expiresAt > Date().addingTimeInterval(60) {
            return record.accessToken
        }

        let task = Task<String, Error> {
            try await manager.refreshAndPersistTokens(for: record)
        }
        refreshTask = task

        defer { refreshTask = nil }

        return try await task.value
    }

    func invalidateCache() {
        cachedRecord = nil
    }
}

// MARK: - Network manager

/// Handles Tesla Fleet API communication and Supabase-backed OAuth token lifecycle.
final class TeslaNetworkManager: Sendable {
    private let configuration: TeslaNetworkConfiguration
    private let session: URLSession
    private let jsonDecoder: JSONDecoder
    private let jsonEncoder: JSONEncoder
    private let tokenCoordinator = TokenCoordinator()

    init(
        configuration: TeslaNetworkConfiguration,
        session: URLSession = .shared
    ) {
        self.configuration = configuration
        self.session = session

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let value = try container.decode(String.self)

            let withFractional = ISO8601DateFormatter()
            withFractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            if let date = withFractional.date(from: value) { return date }

            let withoutFractional = ISO8601DateFormatter()
            withoutFractional.formatOptions = [.withInternetDateTime]
            if let date = withoutFractional.date(from: value) { return date }

            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Unrecognized date format: \(value)"
            )
        }
        self.jsonDecoder = decoder

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        self.jsonEncoder = encoder
    }

    // MARK: - Public API

    /// Returns a valid Tesla access token, refreshing via OAuth and updating Supabase when expired.
    func validAccessToken() async throws -> String {
        try await tokenCoordinator.validAccessToken(using: self)
    }

    /// Fetches live vehicle data for the VIN stored in Supabase.
    func fetchVehicleData() async throws -> TeslaVehicleData {
        try await fetchVehicleData(forceTokenRefresh: false)
    }

    // MARK: - Supabase

  fileprivate func fetchAuthRecord() async throws -> TeslaAuthRecord {
        var components = URLComponents(
            url: configuration.supabaseURL
                .appendingPathComponent("rest/v1/tesla_auth"),
            resolvingAgainstBaseURL: false
        )!

        var queryItems = [URLQueryItem(name: "select", value: "*")]

        if let authRecordID = configuration.authRecordID {
            queryItems.append(URLQueryItem(name: "id", value: "eq.\(authRecordID.uuidString)"))
        } else {
            queryItems.append(URLQueryItem(name: "limit", value: "1"))
        }

        components.queryItems = queryItems

        guard let url = components.url else {
            throw TeslaNetworkError.noAuthRecord
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        applySupabaseHeaders(to: &request)

        let (data, response) = try await session.data(for: request)
        try validateHTTP(response: response, data: data)

        do {
            let records = try jsonDecoder.decode([TeslaAuthRecord].self, from: data)
            guard let record = records.first else {
                throw TeslaNetworkError.noAuthRecord
            }
            return record
        } catch let error as TeslaNetworkError {
            throw error
        } catch {
            throw TeslaNetworkError.decodingFailed(underlying: error.localizedDescription)
        }
    }

    fileprivate func refreshAndPersistTokens(for record: TeslaAuthRecord) async throws -> String {
        let tokenURL = configuration.authBaseURL
            .appendingPathComponent("oauth2/v3/token")

        var request = URLRequest(url: tokenURL)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")

        let body = formURLEncoded([
            "grant_type": "refresh_token",
            "client_id": configuration.teslaClientID,
            "refresh_token": record.refreshToken
        ])
        request.httpBody = body.data(using: .utf8)

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw TeslaNetworkError.tokenRefreshFailed(reason: "Invalid response type")
        }

        guard (200 ... 299).contains(httpResponse.statusCode) else {
            let bodyText = String(data: data, encoding: .utf8) ?? ""
            throw TeslaNetworkError.tokenRefreshFailed(reason: "HTTP \(httpResponse.statusCode): \(bodyText)")
        }

        let tokenResponse: TeslaTokenResponse
        do {
            tokenResponse = try jsonDecoder.decode(TeslaTokenResponse.self, from: data)
        } catch {
            throw TeslaNetworkError.decodingFailed(underlying: error.localizedDescription)
        }

        let expiresAt = Date().addingTimeInterval(TimeInterval(tokenResponse.expiresIn))
        try await updateAuthRecord(
            id: record.id,
            accessToken: tokenResponse.accessToken,
            refreshToken: tokenResponse.refreshToken,
            expiresAt: expiresAt
        )

        return tokenResponse.accessToken
    }

    private func updateAuthRecord(
        id: UUID,
        accessToken: String,
        refreshToken: String,
        expiresAt: Date
    ) async throws {
        let url = configuration.supabaseURL
            .appendingPathComponent("rest/v1/tesla_auth")
            .appending(queryItems: [URLQueryItem(name: "id", value: "eq.\(id.uuidString)")])

        var request = URLRequest(url: url)
        request.httpMethod = "PATCH"
        applySupabaseHeaders(to: &request)
        request.setValue("return=minimal", forHTTPHeaderField: "Prefer")

        let payload: [String: String] = [
            "access_token": accessToken,
            "refresh_token": refreshToken,
            "expires_at": iso8601String(from: expiresAt)
        ]
        request.httpBody = try jsonEncoder.encode(payload)

        let (data, response) = try await session.data(for: request)
        try validateHTTP(response: response, data: data)
    }

    // MARK: - Tesla Fleet API

    private func fetchVehicleData(forceTokenRefresh: Bool) async throws -> TeslaVehicleData {
        let record = try await fetchAuthRecord()

        guard let vin = resolvedVIN(from: record) else {
            throw TeslaNetworkError.missingVIN
        }

        let accessToken: String
        if forceTokenRefresh {
            await tokenCoordinator.invalidateCache()
            accessToken = try await refreshAndPersistTokens(for: record)
        } else {
            accessToken = try await validAccessToken()
        }

        do {
            return try await requestVehicleData(vin: vin, accessToken: accessToken)
        } catch TeslaNetworkError.httpError(let status, _) where status == 401 && !forceTokenRefresh {
            return try await fetchVehicleData(forceTokenRefresh: true)
        }
    }

    private func requestVehicleData(vin: String, accessToken: String) async throws -> TeslaVehicleData {
        var components = URLComponents(
            url: configuration.fleetAPIBaseURL
                .appendingPathComponent("api/1/vehicles/\(vin)/vehicle_data"),
            resolvingAgainstBaseURL: false
        )!
        components.queryItems = [
            URLQueryItem(name: "endpoints", value: "charge_state;climate_state;vehicle_state")
        ]

        guard let url = components.url else {
            throw TeslaNetworkError.httpError(status: 0, body: "Invalid vehicle_data URL")
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw TeslaNetworkError.httpError(status: 0, body: "Invalid response type")
        }

        let bodyText = String(data: data, encoding: .utf8) ?? ""

        if httpResponse.statusCode == 408 {
            throw TeslaNetworkError.vehicleUnavailable
        }

        guard (200 ... 299).contains(httpResponse.statusCode) else {
            throw TeslaNetworkError.httpError(status: httpResponse.statusCode, body: bodyText)
        }

        do {
            let apiResponse = try jsonDecoder.decode(TeslaAPIResponse<TeslaVehicleData>.self, from: data)
            return apiResponse.response
        } catch {
            throw TeslaNetworkError.decodingFailed(underlying: error.localizedDescription)
        }
    }

    // MARK: - Helpers

    private func resolvedVIN(from record: TeslaAuthRecord) -> String? {
        if let vin = record.vin, !vin.isEmpty { return vin }
        if let vin = configuration.vin, !vin.isEmpty { return vin }
        if !Self.defaultVIN.isEmpty { return Self.defaultVIN }
        return nil
    }

    private func applySupabaseHeaders(to request: inout URLRequest) {
        request.setValue(configuration.supabaseAnonKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(configuration.supabaseAccessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
    }

    private func validateHTTP(response: URLResponse, data: Data) throws {
        guard let httpResponse = response as? HTTPURLResponse else {
            throw TeslaNetworkError.httpError(status: 0, body: "Invalid response type")
        }

        guard (200 ... 299).contains(httpResponse.statusCode) else {
            let bodyText = String(data: data, encoding: .utf8) ?? ""
            throw TeslaNetworkError.httpError(status: httpResponse.statusCode, body: bodyText)
        }
    }

    private func formURLEncoded(_ parameters: [String: String]) -> String {
        parameters
            .map { key, value in
                let encodedKey = key.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? key
                let encodedValue = value.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? value
                return "\(encodedKey)=\(encodedValue)"
            }
            .joined(separator: "&")
    }

    private func iso8601String(from date: Date) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter.string(from: date)
    }
}
