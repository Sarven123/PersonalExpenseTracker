import Foundation
import SwiftData
import PETModels
import PETImport

@MainActor
public final class ImportRepository {
    private let context: ModelContext

    public init(context: ModelContext) {
        self.context = context
    }

    /// Dedupe hashes of every transaction already stored, for partitioning
    /// a freshly-parsed batch into unique vs. duplicate rows before commit.
    public func existingDedupeHashes() throws -> Set<String> {
        let descriptor = FetchDescriptor<ExpenseTransaction>()
        return Set(try context.fetch(descriptor).map(\.dedupeHash))
    }

    @discardableResult
    public func commitImport(
        sourceFileName: String,
        columnMapping: ColumnMapping,
        detectedEncoding: DetectedEncoding,
        totalRowCount: Int,
        acceptedDrafts: [DraftTransaction],
        skippedDuplicateCount: Int,
        category: ExpenseCategory? = nil
    ) throws -> ImportBatch {
        let batch = ImportBatch(
            sourceFileName: sourceFileName,
            sourceFormat: columnMapping.sourceFormat,
            detectedEncoding: detectedEncoding.rawValue,
            columnMapping: (try? JSONEncoder().encode(columnMapping)) ?? Data(),
            rowCount: totalRowCount,
            importedCount: acceptedDrafts.count,
            skippedDuplicateCount: skippedDuplicateCount
        )
        context.insert(batch)

        for draft in acceptedDrafts {
            let transaction = ExpenseTransaction(
                bookingDate: draft.bookingDate,
                valueDate: draft.valueDate,
                amount: draft.amount,
                currencyCode: draft.currencyCode,
                type: draft.type,
                merchant: draft.merchant,
                rawDescription: draft.rawDescription,
                purpose: draft.purpose,
                bookingText: draft.bookingText,
                iban: draft.ownIBAN,
                counterpartyIBAN: draft.counterpartyIBAN,
                isRecurring: false,
                source: .imported,
                dedupeHash: draft.dedupeHash,
                category: category,
                importBatch: batch
            )
            context.insert(transaction)
        }

        try context.save()
        return batch
    }
}
