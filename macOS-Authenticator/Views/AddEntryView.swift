import SwiftUI

struct AddEntryView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) private var dismiss

    @State private var serviceName   = ""
    @State private var username      = ""
    @State private var secret        = ""
    @State private var algorithm     = TOTPAlgorithm.sha1
    @State private var digits        = 6
    @State private var period        = 30
    @State private var uriString     = ""
    @State private var showURIInput  = false
    @State private var errorMessage  = ""

    var body: some View {
        VStack(spacing: 0) {
            header

            Divider()

            Form {
                Section("Account Info") {
                    TextField("Service Name (e.g. GitHub)", text: $serviceName)
                    TextField("Username / Remark", text: $username)
                }
                Section("Secret") {
                    Toggle("Paste otpauth:// URI instead", isOn: $showURIInput)

                    if showURIInput {
                        HStack {
                            TextField("otpauth:// URI", text: $uriString)
                            Button("Parse") { parseURI() }.buttonStyle(.bordered)
                        }
                    }
                    TextField("Base32 Secret", text: $secret)
                        .font(.system(.body, design: .monospaced))
                }
                Section("Options") {
                    Picker("Algorithm", selection: $algorithm) {
                        ForEach(TOTPAlgorithm.allCases, id: \.self) { a in
                            Text(a.rawValue).tag(a)
                        }
                    }
                    Stepper("Digits: \(digits)",  value: $digits,  in: 6...8)
                    Stepper("Period: \(period)s", value: $period,  in: 15...60, step: 15)
                }
            }
            .formStyle(.grouped)

            if !errorMessage.isEmpty {
                Text(errorMessage)
                    .foregroundColor(.red).font(.caption)
                    .padding(.horizontal)
            }

            Divider()

            footer
        }
        .frame(width: 420, height: 520)
    }

    private var header: some View {
        HStack {
            Text("Add Account").font(.headline)
            Spacer()
            Button("Cancel") { dismiss() }.keyboardShortcut(.escape)
        }.padding()
    }

    private var footer: some View {
        HStack {
            Spacer()
            Button("Add Account", action: addEntry)
                .buttonStyle(.borderedProminent)
                .disabled(serviceName.isEmpty || secret.isEmpty)
                .keyboardShortcut(.return)
        }.padding()
    }

    private func parseURI() {
        do {
            let r = try TOTPEngine.parseOTPAuthURI(uriString)
            secret      = r.secret
            serviceName = r.issuer.isEmpty ? serviceName : r.issuer
            username    = r.account
            algorithm   = r.algorithm
            digits      = r.digits
            period      = r.period
            errorMessage = ""
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func addEntry() {
        do {
            try appState.addEntry(serviceName: serviceName, username: username,
                                  secret: secret, algorithm: algorithm,
                                  digits: digits, period: period)
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
