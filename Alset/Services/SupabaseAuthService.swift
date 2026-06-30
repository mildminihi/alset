import Foundation

enum SupabaseAuthError: Error, LocalizedError, Sendable {
    case missingCredentials
    case invalidResponse
    case httpError(status: Int, body: String)
    case decodingFailed(String)

    var errorDescription: String? {
        switch self {
        case .missingCredentials:
            return "Email and password are required."
        case .invalidResponse:
            return "Supabase returned an invalid response."
        case .httpError(let status, let body):
            return "Supabase auth error \(status): \(body)"
        case .decodingFailed(let message):
            return "Failed to decode Supabase response: \(message)"
        }
    }
}

/// Minimal Supabase Auth client using REST (no SDK dependency).
final class SupabaseAuthService: Sendable {
    private let supabaseURL: URL
    private let anonKey: String
    private let session: URLSession

    init(
        supabaseURL: URL = TeslaNetworkConfiguration.defaultSupabaseURL,
        anonKey: String,
        session: URLSession = .shared
    ) {
        self.supabaseURL = supabaseURL
        self.anonKey = anonKey
        self.session = session
    }

    func signIn(email: String, password: String) async throws -> String {
        guard !email.isEmpty, !password.isEmpty else {
            throw SupabaseAuthError.missingCredentials
        }

        let url = supabaseURL.appendingPathComponent("auth/v1/token")
        var components = URLComponents(url: url, resolvingAgainstBaseURL: false)!
        components.queryItems = [URLQueryItem(name: "grant_type", value: "password")]

        guard let requestURL = components.url else {
            throw SupabaseAuthError.invalidResponse
        }

        var request = URLRequest(url: requestURL)
        request.httpMethod = "POST"
        request.setValue(anonKey, forHTTPHeaderField: "apikey")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let payload = ["email": email, "password": password]
        request.httpBody = try JSONEncoder().encode(payload)

        let (data, response) = try await session.data(for: request)
        try validate(response: response, data: data)

        do {
            let tokenResponse = try JSONDecoder().decode(SupabaseTokenResponse.self, from: data)
            return tokenResponse.accessToken
        } catch {
            throw SupabaseAuthError.decodingFailed(error.localizedDescription)
        }
    }

    private func validate(response: URLResponse, data: Data) throws {
        guard let httpResponse = response as? HTTPURLResponse else {
            throw SupabaseAuthError.invalidResponse
        }

        guard (200 ... 299).contains(httpResponse.statusCode) else {
            let body = String(data: data, encoding: .utf8) ?? ""
            throw SupabaseAuthError.httpError(status: httpResponse.statusCode, body: body)
        }
    }
}

private struct SupabaseTokenResponse: Decodable, Sendable {
    let accessToken: String

    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
    }
}
