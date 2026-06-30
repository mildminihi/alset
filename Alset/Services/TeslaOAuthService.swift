import AuthenticationServices
import Foundation
import UIKit

// MARK: - Configuration

struct TeslaOAuthConfiguration: Sendable {
    let clientID: String
    let clientSecret: String
    let redirectURI: String
    let authorizeURL: URL
    let tokenURL: URL
    let audience: URL
    let scopes: String

    static let defaultRedirectURI = "alset://auth/callback"

    static func `default`(clientSecret: String) -> TeslaOAuthConfiguration {
        TeslaOAuthConfiguration(
            clientID: TeslaNetworkConfiguration.defaultClientID,
            clientSecret: clientSecret,
            redirectURI: defaultRedirectURI,
            authorizeURL: URL(string: "https://auth.tesla.com/oauth2/v3/authorize")!,
            tokenURL: URL(string: "https://fleet-auth.prd.vn.cloud.tesla.com/oauth2/v3/token")!,
            audience: TeslaNetworkConfiguration.defaultFleetAPIBaseURL,
            scopes: "openid offline_access vehicle_device_data"
        )
    }
}

// MARK: - Errors

enum TeslaOAuthError: Error, LocalizedError, Sendable {
    case missingClientSecret
    case invalidCallbackURL
    case stateMismatch
    case missingAuthorizationCode
    case userCancelled
    case tokenExchangeFailed(reason: String)
    case decodingFailed(String)

    var errorDescription: String? {
        switch self {
        case .missingClientSecret:
            return "Tesla client secret is required for the authorization code exchange."
        case .invalidCallbackURL:
            return "Tesla returned an unexpected callback URL."
        case .stateMismatch:
            return "OAuth state did not match. Try signing in again."
        case .missingAuthorizationCode:
            return "Tesla did not return an authorization code."
        case .userCancelled:
            return "Tesla sign-in was cancelled."
        case .tokenExchangeFailed(let reason):
            return "Token exchange failed: \(reason)"
        case .decodingFailed(let message):
            return "Failed to decode token response: \(message)"
        }
    }
}

// MARK: - OAuth service

/// Opens Tesla sign-in in a secure web session and exchanges the auth code for tokens (PKCE).
@MainActor
final class TeslaOAuthService: NSObject {
    private let configuration: TeslaOAuthConfiguration
    private let session: URLSession
    private var presentationContextProvider: WebAuthPresentationContextProvider?

    init(
        configuration: TeslaOAuthConfiguration,
        session: URLSession = .shared
    ) {
        self.configuration = configuration
        self.session = session
        super.init()
    }

    /// Presents Tesla login and returns fresh OAuth tokens.
    func signIn() async throws -> TeslaTokenResponse {
        guard !configuration.clientSecret.isEmpty else {
            throw TeslaOAuthError.missingClientSecret
        }

        let verifier = PKCE.generateVerifier()
        let challenge = PKCE.challenge(for: verifier)
        let state = PKCE.generateVerifier()

        let authorizeURL = try buildAuthorizeURL(challenge: challenge, state: state)
        let callbackURL = try await presentWebAuthenticationSession(
            url: authorizeURL,
            callbackScheme: URL(string: configuration.redirectURI)?.scheme ?? "alset"
        )

        let code = try parseAuthorizationCode(from: callbackURL, expectedState: state)
        return try await exchangeCodeForTokens(code: code, verifier: verifier)
    }

    // MARK: - Authorize URL

    private func buildAuthorizeURL(challenge: String, state: String) throws -> URL {
        var components = URLComponents(url: configuration.authorizeURL, resolvingAgainstBaseURL: false)!
        components.queryItems = [
            URLQueryItem(name: "client_id", value: configuration.clientID),
            URLQueryItem(name: "redirect_uri", value: configuration.redirectURI),
            URLQueryItem(name: "response_type", value: "code"),
            URLQueryItem(name: "scope", value: configuration.scopes),
            URLQueryItem(name: "state", value: state),
            URLQueryItem(name: "code_challenge", value: challenge),
            URLQueryItem(name: "code_challenge_method", value: "S256")
        ]

        guard let url = components.url else {
            throw TeslaOAuthError.invalidCallbackURL
        }
        return url
    }

    // MARK: - Web authentication session

    private func presentWebAuthenticationSession(
        url: URL,
        callbackScheme: String
    ) async throws -> URL {
        try await withCheckedThrowingContinuation { continuation in
            let provider = WebAuthPresentationContextProvider()
            self.presentationContextProvider = provider

            let session = ASWebAuthenticationSession(
                url: url,
                callbackURLScheme: callbackScheme
            ) { callbackURL, error in
                self.presentationContextProvider = nil

                if let error = error as? ASWebAuthenticationSessionError,
                   error.code == .canceledLogin {
                    continuation.resume(throwing: TeslaOAuthError.userCancelled)
                    return
                }

                if let error {
                    continuation.resume(throwing: error)
                    return
                }

                guard let callbackURL else {
                    continuation.resume(throwing: TeslaOAuthError.invalidCallbackURL)
                    return
                }

                continuation.resume(returning: callbackURL)
            }

            session.presentationContextProvider = provider
            session.prefersEphemeralWebBrowserSession = false

            if !session.start() {
                continuation.resume(throwing: TeslaOAuthError.invalidCallbackURL)
            }
        }
    }

    private func parseAuthorizationCode(from url: URL, expectedState: String) throws -> String {
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            throw TeslaOAuthError.invalidCallbackURL
        }

        let items = Dictionary(
            uniqueKeysWithValues: (components.queryItems ?? []).compactMap { item in
                item.value.map { (item.name, $0) }
            }
        )

        if let returnedState = items["state"], returnedState != expectedState {
            throw TeslaOAuthError.stateMismatch
        }

        if let code = items["code"], !code.isEmpty {
            return code
        }

        throw TeslaOAuthError.missingAuthorizationCode
    }

    // MARK: - Token exchange

    private func exchangeCodeForTokens(code: String, verifier: String) async throws -> TeslaTokenResponse {
        var request = URLRequest(url: configuration.tokenURL)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")

        let body = formURLEncoded([
            "grant_type": "authorization_code",
            "client_id": configuration.clientID,
            "client_secret": configuration.clientSecret,
            "code": code,
            "redirect_uri": configuration.redirectURI,
            "audience": configuration.audience.absoluteString,
            "code_verifier": verifier
        ])
        request.httpBody = body.data(using: .utf8)

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw TeslaOAuthError.tokenExchangeFailed(reason: "Invalid response type")
        }

        let bodyText = String(data: data, encoding: .utf8) ?? ""

        guard (200 ... 299).contains(httpResponse.statusCode) else {
            throw TeslaOAuthError.tokenExchangeFailed(
                reason: "HTTP \(httpResponse.statusCode): \(bodyText)"
            )
        }

        do {
            return try JSONDecoder().decode(TeslaTokenResponse.self, from: data)
        } catch {
            throw TeslaOAuthError.decodingFailed(error.localizedDescription)
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
}

// MARK: - Presentation anchor

private final class WebAuthPresentationContextProvider: NSObject, ASWebAuthenticationPresentationContextProviding {
    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        let window = scenes.flatMap(\.windows).first { $0.isKeyWindow } ?? scenes.first?.windows.first
        return window ?? ASPresentationAnchor()
    }
}
