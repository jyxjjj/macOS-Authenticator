import SwiftUI
import UniformTypeIdentifiers

struct ExportImportView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) private var dismiss

    @State private var message    = ""
    @State private var isSuccess  = false
    @State private var showExport = false
    @State private var showImport = false

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Export / Import").font(.headline)
                Spacer()
                Button("Done") { dismiss() }
            }.padding()

            Divider()

            VStack(spacing: 20) {
                VStack(alignment: .leading, spacing: 8) {
                    Label("Backup is encrypted with your master key",
                          systemImage: "lock.fill").font(.caption).foregroundColor(.secondary)
                    Label("Only accounts not already present are imported",
                          systemImage: "info.circle").font(.caption).foregroundColor(.secondary)
                }
                .padding()
                .background(Color.secondary.opacity(0.08))
                .cornerRadius(8)
                .padding(.horizontal)

                HStack(spacing: 16) {
                    Button { showExport = true } label: {
                        Label("Export", systemImage: "square.and.arrow.up")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered).controlSize(.large)

                    Button { showImport = true } label: {
                        Label("Import", systemImage: "square.and.arrow.down")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered).controlSize(.large)
                }
                .padding()

                if !message.isEmpty {
                    Text(message)
                        .foregroundColor(isSuccess ? .green : .red)
                        .font(.caption).multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
            }
            .padding(.top)
        }
        .frame(width: 400, height: 300)
        .fileExporter(isPresented: $showExport,
                      document: ExportDocument(appState: appState),
                      contentType: .data,
                      defaultFilename: "authenticator-backup.nacosauth") { result in
            switch result {
            case .success:         message = "Export successful";         isSuccess = true
            case .failure(let e):  message = e.localizedDescription;      isSuccess = false
            }
        }
        .fileImporter(isPresented: $showImport,
                      allowedContentTypes: [.data],
                      allowsMultipleSelection: false) { result in
            doImport(result)
        }
    }

    private func doImport(_ result: Result<[URL], Error>) {
        do {
            let urls = try result.get()
            guard let url = urls.first else { return }
            _ = url.startAccessingSecurityScopedResource()
            defer { url.stopAccessingSecurityScopedResource() }
            let data = try Data(contentsOf: url)
            try appState.importData(data)
            message = "Import successful — \(appState.entries.count) accounts loaded"
            isSuccess = true
        } catch {
            message   = error.localizedDescription
            isSuccess = false
        }
    }
}

// MARK: - FileDocument

struct ExportDocument: FileDocument {
    static var readableContentTypes: [UTType] = [.data]

    private var exportData: Data?

    init(appState: AppState) {
        exportData = try? appState.exportData()
    }

    init(configuration: ReadConfiguration) throws {
        exportData = configuration.file.regularFileContents
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        guard let d = exportData else { throw CocoaError(.fileWriteUnknown) }
        return FileWrapper(regularFileWithContents: d)
    }
}
