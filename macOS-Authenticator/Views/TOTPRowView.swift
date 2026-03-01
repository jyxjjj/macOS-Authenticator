import SwiftUI

struct TOTPRowView: View {
    @EnvironmentObject var appState: AppState
    let entry: TOTPEntry

    @State private var code          = "------"
    @State private var timeRemaining = 30.0
    @State private var fraction      = 0.0
    @State private var copied        = false
    @State private var refreshTimer: Timer?

    var body: some View {
        HStack(spacing: 12) {
            serviceIcon
            info
            Spacer()
            codeAndTimer
            copyButton
        }
        .padding(.vertical, 6)
        .onAppear  { startTimer() }
        .onDisappear { stopTimer() }
    }

    // MARK: - Sub-views

    private var serviceIcon: some View {
        ZStack {
            Circle()
                .fill(Color.accentColor.opacity(0.15))
                .frame(width: 40, height: 40)
            Text(entry.serviceName.prefix(1).uppercased())
                .font(.headline)
                .foregroundColor(.accentColor)
        }
    }

    private var info: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(entry.serviceName).font(.headline)
            if !entry.username.isEmpty {
                Text(entry.username).font(.caption).foregroundColor(.secondary)
            }
        }
    }

    private var codeAndTimer: some View {
        HStack(spacing: 8) {
            Text(formattedCode)
                .font(.system(.title2, design: .monospaced).bold())
                .foregroundColor(timeRemaining <= 5 ? .red : .primary)
                .animation(.none, value: code)

            ZStack {
                Circle().stroke(Color.secondary.opacity(0.2), lineWidth: 3)
                Circle()
                    .trim(from: 0, to: 1.0 - fraction)
                    .stroke(
                        timeRemaining <= 5 ? Color.red : Color.accentColor,
                        style: StrokeStyle(lineWidth: 3, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .animation(.linear(duration: 1), value: fraction)
                Text("\(Int(timeRemaining))")
                    .font(.system(size: 9, weight: .medium))
                    .foregroundColor(.secondary)
            }
            .frame(width: 28, height: 28)
        }
    }

    private var copyButton: some View {
        Button(action: copyCode) {
            Image(systemName: copied ? "checkmark" : "doc.on.doc")
                .foregroundColor(copied ? .green : .secondary)
                .frame(width: 20)
        }
        .buttonStyle(.plain)
        .help("Copy code")
    }

    // MARK: - Helpers

    private var formattedCode: String {
        guard code.count == 6 else { return code }
        let mid = code.index(code.startIndex, offsetBy: 3)
        return "\(code[..<mid]) \(code[mid...])"
    }

    private func refreshCode() {
        guard let secretData = try? appState.decryptSecret(for: entry) else { return }
        code          = TOTPEngine.generateCode(secret: secretData,
                                               algorithm: entry.algorithm,
                                               digits: entry.digits,
                                               period: entry.period)
        timeRemaining = TOTPEngine.timeRemaining(period: entry.period)
        fraction      = TOTPEngine.timeFraction(period: entry.period)
    }

    private func copyCode() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(code, forType: .string)
        withAnimation { copied = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            withAnimation { self.copied = false }
        }
    }

    private func startTimer() {
        refreshCode()
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            Task { @MainActor in self.refreshCode() }
        }
    }

    private func stopTimer() {
        refreshTimer?.invalidate()
        refreshTimer = nil
    }
}
