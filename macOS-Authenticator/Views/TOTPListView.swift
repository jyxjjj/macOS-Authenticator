import SwiftUI

struct TOTPListView: View {
    @EnvironmentObject var appState: AppState

    @State private var searchText       = ""
    @State private var showAddEntry     = false
    @State private var showSettings     = false
    @State private var showExportImport = false
    @State private var entryToEdit: TOTPEntry?
    @State private var errorMessage     = ""
    @State private var showError        = false

    private var filtered: [TOTPEntry] {
        guard !searchText.isEmpty else { return appState.entries }
        return appState.entries.filter {
            $0.serviceName.localizedCaseInsensitiveContains(searchText)
            || $0.username.localizedCaseInsensitiveContains(searchText)
        }
    }

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                searchBar

                Divider()

                if appState.entries.isEmpty {
                    emptyState
                } else {
                    List {
                        ForEach(filtered) { entry in
                            TOTPRowView(entry: entry)
                                .contextMenu {
                                    Button("Edit") { entryToEdit = entry }
                                    Divider()
                                    Button("Delete", role: .destructive) { delete(entry) }
                                }
                        }
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle("Authenticator")
            .toolbar {
                ToolbarItemGroup(placement: .primaryAction) {
                    Button { showExportImport = true } label: {
                        Image(systemName: "square.and.arrow.up.on.square")
                    }.help("Export / Import")

                    Button { showSettings = true } label: {
                        Image(systemName: "gearshape")
                    }.help("Settings")

                    Button { showAddEntry = true } label: {
                        Image(systemName: "plus")
                    }.help("Add Account")
                }

                ToolbarItem(placement: .navigation) {
                    Button { appState.lock() } label: {
                        Image(systemName: "lock")
                    }.help("Lock")
                }
            }
        }
        .sheet(isPresented: $showAddEntry) {
            AddEntryView().environmentObject(appState)
        }
        .sheet(item: $entryToEdit) { entry in
            EditEntryView(entry: entry).environmentObject(appState)
        }
        .sheet(isPresented: $showSettings) {
            SettingsView().environmentObject(appState)
        }
        .sheet(isPresented: $showExportImport) {
            ExportImportView().environmentObject(appState)
        }
        .alert("Error", isPresented: $showError) {
            Button("OK") {}
        } message: { Text(errorMessage) }
    }

    private var searchBar: some View {
        HStack {
            Image(systemName: "magnifyingglass").foregroundColor(.secondary)
            TextField("Search", text: $searchText).textFieldStyle(.plain)
            if !searchText.isEmpty {
                Button { searchText = "" } label: {
                    Image(systemName: "xmark.circle.fill").foregroundColor(.secondary)
                }.buttonStyle(.plain)
            }
        }
        .padding(8)
        .background(Color(nsColor: .controlBackgroundColor))
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "key.slash").font(.system(size: 48)).foregroundColor(.secondary)
            Text("No accounts yet").font(.headline).foregroundColor(.secondary)
            Text("Tap + to add your first TOTP account").font(.caption).foregroundColor(.secondary)
            Button("Add Account") { showAddEntry = true }.buttonStyle(.borderedProminent)
            Spacer()
        }
    }

    private func delete(_ entry: TOTPEntry) {
        do {
            try appState.deleteEntry(id: entry.id)
        } catch {
            errorMessage = error.localizedDescription
            showError    = true
        }
    }
}
