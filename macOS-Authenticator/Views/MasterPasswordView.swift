import SwiftUI

struct MasterPasswordView: View {
    @EnvironmentObject var appState: AppState

    @State private var password        = ""
    @State private var confirmPassword = ""
    @State private var errorMessage    = ""
    @State private var isLoading       = false

    private var isFirstLaunch: Bool { appState.isFirstLaunch }

    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "lock.shield.fill")
                .font(.system(size: 64))
                .foregroundColor(.accentColor)

            Text(isFirstLaunch ? "Set Master Password" : "Unlock Authenticator")
                .font(.title2).bold()

            VStack(spacing: 12) {
                SecureField("Master Password", text: $password)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 280)

                if isFirstLaunch {
                    SecureField("Confirm Password", text: $confirmPassword)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 280)
                }
            }

            if !errorMessage.isEmpty {
                Text(errorMessage)
                    .foregroundColor(.red)
                    .font(.caption)
                    .multilineTextAlignment(.center)
                    .frame(width: 280)
            }

            Button(action: submit) {
                if isLoading {
                    ProgressView().controlSize(.small)
                } else {
                    Text(isFirstLaunch ? "Create" : "Unlock")
                        .frame(width: 120)
                }
            }
            .buttonStyle(.borderedProminent)
            .disabled(password.isEmpty || isLoading)
            .keyboardShortcut(.return)
        }
        .padding(40)
        .frame(width: 400, height: 360)
    }

    private func submit() {
        errorMessage = ""
        isLoading    = true

        Task { @MainActor in
            defer { isLoading = false }
            do {
                if isFirstLaunch {
                    guard password.count >= 8 else {
                        errorMessage = "Password must be at least 8 characters"
                        return
                    }
                    guard password == confirmPassword else {
                        errorMessage = "Passwords do not match"
                        return
                    }
                    try appState.setupMasterPassword(password)
                } else {
                    try appState.unlock(password: password)
                }
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }
}
