import SwiftUI

@main
struct AlsetApp: App {
    @State private var viewModel = AppViewModel(
        supabaseAnonKey: AppSecrets.supabaseAnonKey,
        teslaClientSecret: AppSecrets.teslaClientSecret
    )

    var body: some Scene {
        WindowGroup {
            RootView(viewModel: viewModel)
        }
    }
}
