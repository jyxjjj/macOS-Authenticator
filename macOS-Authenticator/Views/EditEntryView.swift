import SwiftUI

struct EditEntryView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) private var dismiss

    let entry: TOTPEntry

    @State private var serviceName: String
    @State private var username: String
    @State private var algorithm: TOTPAlgorithm
    @State private var digits: Int
    @State private var period: Int
    @State private var errorMessage = ""

    init(entry: TOTPEntry) {
        self.entry  = entry
        _serviceName = State(initialValue: entry.serviceName)
        _username    = State(initialValue: entry.username)
        _algorithm   = State(initialValue: entry.algorithm)
        _digits      = State(initialValue: entry.digits)
        _period      = State(initialValue: entry.period)
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Edit Account").font(.headline)
                Spacer()
                Button("Cancel") { dismiss() }.keyboardShortcut(.escape)
            }.padding()

            Divider()

            Form {
                Section("Account Info") {
                    TextField("Service Name", text: $serviceName)
                    TextField("Username / Remark", text: $username)
                }
                Section("Options") {
                    Picker("Algorithm", selection: $algorithm) {
                        ForEach(TOTPAlgorithm.allCases, id: \.self) { a in
                            Text(a.rawValue).tag(a)
                        }
                    }
                    Stepper("Digits: \(digits)",  value: $digits, in: 6...8)
                    Stepper("Period: \(period)s", value: $period, in: 15...60, step: 15)
                }
            }
            .formStyle(.grouped)

            if !errorMessage.isEmpty {
                Text(errorMessage).foregroundColor(.red).font(.caption).padding(.horizontal)
            }

            Divider()

            HStack {
                Spacer()
                Button("Save Changes", action: save)
                    .buttonStyle(.borderedProminent)
                    .disabled(serviceName.isEmpty)
                    .keyboardShortcut(.return)
            }.padding()
        }
        .frame(width: 380, height: 380)
    }

    private func save() {
        var updated      = entry
        updated.serviceName = serviceName
        updated.username    = username
        updated.algorithm   = algorithm
        updated.digits      = digits
        updated.period      = period
        updated.updatedAt   = Date()
        do {
            try appState.updateEntry(updated)
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
