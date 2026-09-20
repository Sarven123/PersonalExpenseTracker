import SwiftUI
import SwiftData
import UniformTypeIdentifiers
import PETModels
import PETRepositories
import PETImport

/// A multi-step Sparkasse CSV import wizard: pick a file, review what was
/// parsed (format/encoding detected, plus any per-row warnings), review
/// duplicates against transactions already stored, then commit.
public struct ImportCSVView: View {
    private enum Step {
        case pickFile
        case reviewParse(fileName: String, result: ImportParseResult)
        case reviewDuplicates(fileName: String, result: ImportParseResult, unique: [DraftTransaction], duplicates: [DraftTransaction])
        case finished(ImportBatch)
    }

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var step: Step = .pickFile
    @State private var isPresentingFileImporter = false
    @State private var errorMessage: String?
    @State private var includedDuplicateRows: Set<Int> = []

    public init() {}

    public var body: some View {
        NavigationStack {
            content
                .navigationTitle("Import CSV")
        }
        .frame(minWidth: 560, minHeight: 520)
        .fileImporter(
            isPresented: $isPresentingFileImporter,
            allowedContentTypes: [.commaSeparatedText, .plainText, .text],
            onCompletion: handleFileSelection
        )
        .onAppear {
            isPresentingFileImporter = true
        }
    }

    @ViewBuilder
    private var content: some View {
        switch step {
        case .pickFile:
            pickFileStep
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") { dismiss() }
                    }
                }
        case let .reviewParse(fileName, result):
            reviewParseStep(fileName: fileName, result: result)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") { dismiss() }
                    }
                    ToolbarItem(placement: .automatic) {
                        Button("Choose Different File") {
                            errorMessage = nil
                            step = .pickFile
                            isPresentingFileImporter = true
                        }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Continue") { proceedToDuplicateReview(fileName: fileName, result: result) }
                            .disabled(result.drafts.isEmpty)
                    }
                }
        case let .reviewDuplicates(fileName, result, unique, duplicates):
            reviewDuplicatesStep(fileName: fileName, result: result, unique: unique, duplicates: duplicates)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") { dismiss() }
                    }
                    ToolbarItem(placement: .automatic) {
                        Button("Back") { step = .reviewParse(fileName: fileName, result: result) }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        let acceptedCount = unique.count + includedDuplicateRows.count
                        Button("Import \(acceptedCount) Transaction\(acceptedCount == 1 ? "" : "s")") {
                            commit(fileName: fileName, result: result, unique: unique, duplicates: duplicates)
                        }
                        .disabled(acceptedCount == 0)
                    }
                }
        case let .finished(batch):
            finishedStep(batch: batch)
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Done") { dismiss() }
                    }
                }
        }
    }

    // MARK: - Step 1: pick file

    private var pickFileStep: some View {
        VStack(spacing: 16) {
            Image(systemName: "arrow.down.doc")
                .font(.system(size: 40))
                .foregroundStyle(.secondary)
            Text("Choose a Sparkasse CSV export to import.")
                .font(.headline)
            Text("CAMT and MT940-style exports are supported, in UTF-8 or Windows-1252 encoding.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Button("Choose File…") { isPresentingFileImporter = true }
                .buttonStyle(.borderedProminent)
            if let errorMessage {
                Text(errorMessage)
                    .foregroundStyle(.red)
                    .font(.caption)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(40)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func handleFileSelection(_ result: Result<URL, Error>) {
        switch result {
        case let .failure(error):
            errorMessage = error.localizedDescription
        case let .success(url):
            parseFile(at: url)
        }
    }

    private func parseFile(at url: URL) {
        let didAccess = url.startAccessingSecurityScopedResource()
        defer { if didAccess { url.stopAccessingSecurityScopedResource() } }

        do {
            let data = try Data(contentsOf: url)
            let result = try CSVImportPipeline.parse(fileData: data)
            errorMessage = nil
            step = .reviewParse(fileName: url.lastPathComponent, result: result)
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }
    }

    // MARK: - Step 2: review parse

    private func reviewParseStep(fileName: String, result: ImportParseResult) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            summaryHeader(fileName: fileName, result: result)
            Divider()
            if !result.warnings.isEmpty {
                warningsSection(result.warnings)
                Divider()
            }
            List {
                Section("Transactions Found (\(result.drafts.count))") {
                    ForEach(result.drafts, id: \.sourceRowNumber) { draft in
                        DraftRow(draft: draft)
                    }
                }
            }
        }
    }

    private func summaryHeader(fileName: String, result: ImportParseResult) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(fileName).font(.headline)
            HStack(spacing: 12) {
                Label(formatLabel(result.sourceFormat), systemImage: "doc.text")
                Label(encodingLabel(result.detectedEncoding), systemImage: "textformat")
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .padding()
    }

    private func warningsSection(_ warnings: [ImportError]) -> some View {
        DisclosureGroup("\(warnings.count) row(s) skipped due to parsing issues") {
            ForEach(Array(warnings.enumerated()), id: \.offset) { _, warning in
                Text(warning.errorDescription ?? "Unknown error")
                    .font(.caption)
                    .foregroundStyle(.orange)
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
    }

    private func proceedToDuplicateReview(fileName: String, result: ImportParseResult) {
        do {
            let existingHashes = try ImportRepository(context: modelContext).existingDedupeHashes()
            let partitioned = DuplicateDetector.partition(drafts: result.drafts, existingHashes: existingHashes)
            includedDuplicateRows = []
            step = .reviewDuplicates(
                fileName: fileName,
                result: result,
                unique: partitioned.unique,
                duplicates: partitioned.duplicates
            )
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Step 3: review duplicates

    private func reviewDuplicatesStep(
        fileName: String,
        result: ImportParseResult,
        unique: [DraftTransaction],
        duplicates: [DraftTransaction]
    ) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 4) {
                Text(fileName).font(.headline)
                Text("\(unique.count) new transaction\(unique.count == 1 ? "" : "s") ready to import.")
                    .font(.subheadline)
                if !duplicates.isEmpty {
                    Text("\(duplicates.count) look like duplicates of transactions you already have. They're skipped by default — select any you'd still like to import.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .padding()
            Divider()
            if duplicates.isEmpty {
                ContentUnavailableView(
                    "No Duplicates Found",
                    systemImage: "checkmark.circle",
                    description: Text("Every parsed row is new.")
                )
            } else {
                List {
                    ForEach(duplicates, id: \.sourceRowNumber) { draft in
                        Toggle(isOn: includeDuplicateBinding(for: draft)) {
                            DraftRow(draft: draft)
                        }
                    }
                }
            }
        }
    }

    private func includeDuplicateBinding(for draft: DraftTransaction) -> Binding<Bool> {
        Binding(
            get: { includedDuplicateRows.contains(draft.sourceRowNumber) },
            set: { isOn in
                if isOn {
                    includedDuplicateRows.insert(draft.sourceRowNumber)
                } else {
                    includedDuplicateRows.remove(draft.sourceRowNumber)
                }
            }
        )
    }

    private func commit(
        fileName: String,
        result: ImportParseResult,
        unique: [DraftTransaction],
        duplicates: [DraftTransaction]
    ) {
        let includedDuplicates = duplicates.filter { includedDuplicateRows.contains($0.sourceRowNumber) }
        let accepted = unique + includedDuplicates
        let skippedCount = duplicates.count - includedDuplicates.count

        do {
            let batch = try ImportRepository(context: modelContext).commitImport(
                sourceFileName: fileName,
                columnMapping: result.columnMapping,
                detectedEncoding: result.detectedEncoding,
                totalRowCount: result.drafts.count + result.warnings.count,
                acceptedDrafts: accepted,
                skippedDuplicateCount: skippedCount
            )
            step = .finished(batch)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Step 4: finished

    private func finishedStep(batch: ImportBatch) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 48))
                .foregroundStyle(.green)
            Text("Import Complete")
                .font(.headline)
            VStack(spacing: 4) {
                Text("\(batch.importedCount) transaction\(batch.importedCount == 1 ? "" : "s") imported.")
                if batch.skippedDuplicateCount > 0 {
                    Text("\(batch.skippedDuplicateCount) duplicate\(batch.skippedDuplicateCount == 1 ? "" : "s") skipped.")
                        .foregroundStyle(.secondary)
                }
            }
            .font(.subheadline)
        }
        .padding(40)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Shared helpers

    private func formatLabel(_ format: ImportSourceFormat) -> String {
        switch format {
        case .camtCSV: "CAMT export"
        case .mt940CSV: "MT940-style export"
        }
    }

    private func encodingLabel(_ encoding: DetectedEncoding) -> String {
        switch encoding {
        case .utf8: "UTF-8"
        case .utf8BOM: "UTF-8 (BOM)"
        case .windows1252: "Windows-1252"
        }
    }
}

private struct DraftRow: View {
    let draft: DraftTransaction

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(draft.merchant)
                    .font(.body.weight(.medium))
                Text(draft.bookingDate, format: .dateTime.day().month().year())
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Text(draft.amount, format: .currency(code: draft.currencyCode))
                .monospacedDigit()
                .foregroundStyle(draft.amount < 0 ? Color.red : Color.green)
        }
        .padding(.vertical, 2)
    }
}
