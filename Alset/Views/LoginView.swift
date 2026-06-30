import SwiftUI

struct LoginView: View {
    @Bindable var viewModel: AppViewModel
    @State private var email = ""
    @State private var password = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("Supabase") {
                    TextField("Email", text: $email)
                        .textContentType(.emailAddress)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()

                    SecureField("Password", text: $password)
                }

                if let errorMessage = viewModel.errorMessage {
                    Section {
                        Text(errorMessage)
                            .foregroundStyle(.red)
                            .font(.footnote)
                    }
                }

                Section {
                    Button(viewModel.isLoading ? "Signing in…" : "Sign In") {
                        Task { await viewModel.signIn(email: email, password: password) }
                    }
                    .disabled(viewModel.isLoading || email.isEmpty || password.isEmpty)
                }
            }
            .navigationTitle("Alset")
        }
    }
}
