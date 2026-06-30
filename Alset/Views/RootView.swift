import SwiftUI

struct RootView: View {
    @Bindable var viewModel: AppViewModel

    var body: some View {
        Group {
            if !viewModel.isSignedIn {
                LoginView(viewModel: viewModel)
            } else if !viewModel.isTeslaConnected {
                NavigationStack {
                    TeslaConnectView(viewModel: viewModel)
                }
            } else {
                VehicleDashboardView(viewModel: viewModel)
            }
        }
        .task {
            if viewModel.isSignedIn {
                await viewModel.refreshTeslaConnectionStatus()
            }
        }
    }
}
