import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) private var dismiss

    @State private var oldPassword = ""
    @State private var newPassword = ""
    @State private var confirmNew  = ""
    @State private var message     = ""
    @State private var isSuccess   = false

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Settings").font(.headline)
                Spacer()
                Button("Done") { dismiss() }
            }.padding()

            Divider()

            Form {
                Section("Change Master Password") {
                    SecureField("Current Password", text: $oldPassword)
                    SecureField("New Password (min 8 chars)", text: $newPassword)
                    SecureField("Confirm New Password", text: $confirmNew)

                    Button("Change Password", action: changePassword)
                        .disabled(oldPassword.isEmpty || newPassword.isEmpty || confirmNew.isEmpty)
                }

                Section("About") {
                    LabeledContent("App",       value: "macOS Authenticator")
                    LabeledContent("Version",   value: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0")
                    LabeledContent("License",   value: "AGPL-3.0")
                    LabeledContent("Bundle ID", value: "com.desmg.nacos.authenticator")
                }
            }
            .formStyle(.grouped)

            if !message.isEmpty {
                Text(message)
                    .foregroundColor(isSuccess ? .green : .red)
                    .font(.caption)
                    .padding()
            }
        }
        .frame(width: 400, height: 450)
    }

    private func changePassword() {
        guard newPassword.count >= 8 else {
            message = "New password must be at least 8 characters"; isSuccess = false; return
        }
        guard newPassword == confirmNew else {
            message = "New passwords do not match"; isSuccess = false; return
        }
        do {
            try appState.changeMasterPassword(oldPassword: oldPassword, newPassword: newPassword)
            message = "Password changed successfully"
            isSuccess = true
            oldPassword = ""; newPassword = ""; confirmNew = ""
        } catch {
            message = error.localizedDescription; isSuccess = false
        }
    }
}
