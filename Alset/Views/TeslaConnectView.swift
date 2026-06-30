import SwiftUI

struct TeslaConnectView: View {
    @Bindable var viewModel: AppViewModel

    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "car.fill")
                .font(.system(size: 56))
                .foregroundStyle(.secondary)

            Text("Connect your Tesla")
                .font(.title2.bold())

            Text("Sign in with your Tesla account to store OAuth tokens securely in Supabase.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .padding(.horizontal)

            if let errorMessage = viewModel.errorMessage {
                Text(errorMessage)
                    .font(.footnote)
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }

            Button {
                Task { await viewModel.connectTesla() }
            } label: {
                Label(
                    viewModel.isLoading ? "Connecting…" : "Connect with Tesla",
                    systemImage: "link"
                )
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .disabled(viewModel.isLoading)
            .padding(.horizontal)
        }
        .padding()
        .navigationTitle("Tesla")
    }
}
