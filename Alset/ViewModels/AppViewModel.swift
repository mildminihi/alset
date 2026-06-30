import Foundation
import Observation

/// Shared app state for Supabase session and Tesla connection status.
@MainActor
@Observable
final class AppViewModel {
    var supabaseAccessToken: String?
    var isTeslaConnected = false
    var isLoading = false
    var errorMessage: String?
    var vehicleSnapshot: TeslaVehicleSnapshot?

    let supabaseAnonKey: String
    let teslaClientSecret: String

    init(supabaseAnonKey: String, teslaClientSecret: String) {
        self.supabaseAnonKey = supabaseAnonKey
        self.teslaClientSecret = teslaClientSecret
    }

    var isSignedIn: Bool {
        supabaseAccessToken != nil
    }

    func signIn(email: String, password: String) async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            let authService = SupabaseAuthService(anonKey: supabaseAnonKey)
            supabaseAccessToken = try await authService.signIn(email: email, password: password)
            await refreshTeslaConnectionStatus()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func connectTesla() async {
        guard let supabaseAccessToken else {
            errorMessage = "Sign in to Supabase first."
            return
        }

        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            let oauth = TeslaOAuthService(
                configuration: .default(clientSecret: teslaClientSecret)
            )
            let tokens = try await oauth.signIn()

            let repository = TeslaAuthRepository(
                anonKey: supabaseAnonKey,
                accessToken: supabaseAccessToken
            )
            _ = try await repository.saveTokens(tokens)
            isTeslaConnected = true
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func fetchVehicleData() async {
        guard let supabaseAccessToken else {
            errorMessage = "Sign in to Supabase first."
            return
        }

        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            let manager = TeslaNetworkManager(
                configuration: TeslaNetworkConfiguration(
                    fleetAPIBaseURL: .defaultFleetAPIBaseURL,
                    authBaseURL: .defaultAuthBaseURL,
                    teslaClientID: .defaultClientID,
                    teslaClientSecret: teslaClientSecret,
                    supabaseURL: .defaultSupabaseURL,
                    supabaseAnonKey: supabaseAnonKey,
                    supabaseAccessToken: supabaseAccessToken,
                    authRecordID: nil,
                    vin: .defaultVIN
                )
            )

            let data = try await manager.fetchVehicleData()
            vehicleSnapshot = TeslaVehicleSnapshot(from: data)
            isTeslaConnected = true
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func refreshTeslaConnectionStatus() async {
        guard let supabaseAccessToken else {
            isTeslaConnected = false
            return
        }

        do {
            let manager = TeslaNetworkManager(
                configuration: TeslaNetworkConfiguration(
                    fleetAPIBaseURL: .defaultFleetAPIBaseURL,
                    authBaseURL: .defaultAuthBaseURL,
                    teslaClientID: .defaultClientID,
                    teslaClientSecret: teslaClientSecret,
                    supabaseURL: .defaultSupabaseURL,
                    supabaseAnonKey: supabaseAnonKey,
                    supabaseAccessToken: supabaseAccessToken,
                    authRecordID: nil,
                    vin: .defaultVIN
                )
            )
            _ = try await manager.validAccessToken()
            isTeslaConnected = true
        } catch {
            isTeslaConnected = false
        }
    }
}
