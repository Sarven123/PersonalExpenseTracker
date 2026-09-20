import SwiftUI
import SwiftData
import UniformTypeIdentifiers
import PETModels
import PETRepositories
import PETExport

public struct SettingsView: View {
    @Environment(\.modelContext) private var modelContext

    @State private var isPresentingDeleteConfirmation = false
    @State private var isPresentingExporter = false
    @State private var exportDocument: CSVDocument?
    @State private var errorMessage: String?
    @State private var successMessage: String?

    public init() {}

    public var body: some View {
        Form {
            Section("Backup") {
                Button("Export All Transactions as CSV…") { exportBackup() }
            }
            Section("Danger Zone") {
                Button("Delete All Local Data…", role: .destructive) {
                    isPresentingDeleteConfirmation = true
                }
            }
            if let errorMessage {
                Text(errorMessage)
                    .foregroundStyle(.red)
                    .font(.caption)
            }
            if let successMessage {
                Text(successMessage)
                    .foregroundStyle(.secondary)
                    .font(.caption)
            }
        }
        .formStyle(.grouped)
        .navigationTitle("Settings")
        .confirmationDialog(
            "Delete All Local Data?",
            isPresented: $isPresentingDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("Delete Everything", role: .destructive) { deleteAllData() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This permanently deletes every transaction, category, and rule stored on this Mac. This cannot be undone.")
        }
        .fileExporter(
            isPresented: $isPresentingExporter,
            document: exportDocument,
            contentType: .commaSeparatedText,
            defaultFilename: "PersonalExpenseTracker-Backup"
        ) { result in
            if case let .failure(error) = result {
                errorMessage = error.localizedDescription
            }
        }
    }

    private func exportBackup() {
        do {
            let transactions = try TransactionRepository(context: modelContext).fetchAll()
            exportDocument = CSVDocument(data: TransactionCSVExporter.exportData(transactions))
            isPresentingExporter = true
            errorMessage = nil
            successMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func deleteAllData() {
        do {
            try DataResetRepository(context: modelContext).deleteAllData()
            successMessage = "All local data deleted."
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
            successMessage = nil
        }
    }
}
