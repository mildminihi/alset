import Foundation

enum TeslaAuthRepositoryError: Error, LocalizedError, Sendable {
    case httpError(status: Int, body: String)
    case decodingFailed(String)

    var errorDescription: String? {
        switch self {
        case .httpError(let status, let body):
            return "Failed to save Tesla tokens (\(status)): \(body)"
        case .decodingFailed(let message):
            return "Failed to decode Supabase response: \(message)"
        }
    }
}

/// Persists Tesla OAuth tokens to `public.tesla_auth` via Supabase REST.
final class TeslaAuthRepository: Sendable {
    private let supabaseURL: URL
    private let anonKey: String
    private let accessToken: String
    private let session: URLSession
    private let jsonDecoder: JSONDecoder
    private let jsonEncoder: JSONEncoder

    init(
        supabaseURL: URL = TeslaNetworkConfiguration.defaultSupabaseURL,
        anonKey: String,
        accessToken: String,
        session: URLSession = .shared
    ) {
        self.supabaseURL = supabaseURL
        self.anonKey = anonKey
        self.accessToken = accessToken
        self.session = session

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom(Self.decodeSupabaseDate)
        self.jsonDecoder = decoder

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .custom(Self.encodeSupabaseDate)
        self.jsonEncoder = encoder
    }

    /// Inserts or updates the single auth row with fresh Tesla tokens.
    @discardableResult
    func saveTokens(
        _ tokens: TeslaTokenResponse,
        vin: String? = TeslaNetworkConfiguration.defaultVIN
    ) async throws -> TeslaAuthRecord {
        let expiresAt = Date().addingTimeInterval(TimeInterval(tokens.expiresIn))

        if let existing = try await fetchExistingRecord() {
            return try await updateRecord(
                id: existing.id,
                accessToken: tokens.accessToken,
                refreshToken: tokens.refreshToken,
                expiresAt: expiresAt,
                vin: vin ?? existing.vin
            )
        }

        return try await insertRecord(
            accessToken: tokens.accessToken,
            refreshToken: tokens.refreshToken,
            expiresAt: expiresAt,
            vin: vin
        )
    }

    // MARK: - Private

    private func fetchExistingRecord() async throws -> TeslaAuthRecord? {
        var components = URLComponents(
            url: supabaseURL.appendingPathComponent("rest/v1/tesla_auth"),
            resolvingAgainstBaseURL: false
        )!
        components.queryItems = [
            URLQueryItem(name: "select", value: "*"),
            URLQueryItem(name: "limit", value: "1")
        ]

        guard let url = components.url else { return nil }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        applyHeaders(to: &request)

        let (data, response) = try await session.data(for: request)
        try validate(response: response, data: data)

        let records = try jsonDecoder.decode([TeslaAuthRecord].self, from: data)
        return records.first
    }

    private func insertRecord(
        accessToken: String,
        refreshToken: String,
        expiresAt: Date,
        vin: String?
    ) async throws -> TeslaAuthRecord {
        let url = supabaseURL.appendingPathComponent("rest/v1/tesla_auth")

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        applyHeaders(to: &request)
        request.setValue("return=representation", forHTTPHeaderField: "Prefer")

        let payload = TeslaAuthInsertPayload(
            accessToken: accessToken,
            refreshToken: refreshToken,
            expiresAt: expiresAt,
            vin: vin
        )
        request.httpBody = try jsonEncoder.encode(payload)

        let (data, response) = try await session.data(for: request)
        try validate(response: response, data: data)

        do {
            let records = try jsonDecoder.decode([TeslaAuthRecord].self, from: data)
            guard let record = records.first else {
                throw TeslaAuthRepositoryError.decodingFailed("Empty insert response")
            }
            return record
        } catch let error as TeslaAuthRepositoryError {
            throw error
        } catch {
            throw TeslaAuthRepositoryError.decodingFailed(error.localizedDescription)
        }
    }

    private func updateRecord(
        id: UUID,
        accessToken: String,
        refreshToken: String,
        expiresAt: Date,
        vin: String?
    ) async throws -> TeslaAuthRecord {
        let url = supabaseURL
            .appendingPathComponent("rest/v1/tesla_auth")
            .appending(queryItems: [URLQueryItem(name: "id", value: "eq.\(id.uuidString)")])

        var request = URLRequest(url: url)
        request.httpMethod = "PATCH"
        applyHeaders(to: &request)
        request.setValue("return=representation", forHTTPHeaderField: "Prefer")

        let payload = TeslaAuthUpdatePayload(
            accessToken: accessToken,
            refreshToken: refreshToken,
            expiresAt: expiresAt,
            vin: vin
        )
        request.httpBody = try jsonEncoder.encode(payload)

        let (data, response) = try await session.data(for: request)
        try validate(response: response, data: data)

        do {
            let records = try jsonDecoder.decode([TeslaAuthRecord].self, from: data)
            guard let record = records.first else {
                throw TeslaAuthRepositoryError.decodingFailed("Empty update response")
            }
            return record
        } catch let error as TeslaAuthRepositoryError {
            throw error
        } catch {
            throw TeslaAuthRepositoryError.decodingFailed(error.localizedDescription)
        }
    }

    private func applyHeaders(to request: inout URLRequest) {
        request.setValue(anonKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
    }

    private func validate(response: URLResponse, data: Data) throws {
        guard let httpResponse = response as? HTTPURLResponse else {
            throw TeslaAuthRepositoryError.httpError(status: 0, body: "Invalid response")
        }

        guard (200 ... 299).contains(httpResponse.statusCode) else {
            let body = String(data: data, encoding: .utf8) ?? ""
            throw TeslaAuthRepositoryError.httpError(status: httpResponse.statusCode, body: body)
        }
    }

    private static func decodeSupabaseDate(_ decoder: Decoder) throws -> Date {
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
            debugDescription: "Unrecognized date: \(value)"
        )
    }

    private static func encodeSupabaseDate(_ date: Date, encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        try container.encode(formatter.string(from: date))
    }
}

private struct TeslaAuthInsertPayload: Encodable {
    let accessToken: String
    let refreshToken: String
    let expiresAt: Date
    let vin: String?

    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case refreshToken = "refresh_token"
        case expiresAt = "expires_at"
        case vin
    }
}

private struct TeslaAuthUpdatePayload: Encodable {
    let accessToken: String
    let refreshToken: String
    let expiresAt: Date
    let vin: String?

    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case refreshToken = "refresh_token"
        case expiresAt = "expires_at"
        case vin
    }
}
