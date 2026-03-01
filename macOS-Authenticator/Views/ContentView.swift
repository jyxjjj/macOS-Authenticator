import SwiftUI

struct ContentView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        Group {
            if appState.isLocked {
                MasterPasswordView()
            } else {
                TOTPListView()
            }
        }
        .animation(.easeInOut(duration: 0.2), value: appState.isLocked)
    }
}
