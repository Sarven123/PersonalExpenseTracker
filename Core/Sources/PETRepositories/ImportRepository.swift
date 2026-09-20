import Foundation
import SwiftData
import PETModels
import PETImport
import PETCategorization

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

    /// Commits a batch of accepted drafts, auto-suggesting a category for each
    /// via `CategoryRuleEngine` against every stored `MerchantRule` (builtin +
    /// user-correction). A draft with no matching rule stays Uncategorized —
    /// see the "Uncategorized" review filter. Also refreshes recurring-transaction
    /// detection across the whole dataset once the batch is committed.
    @discardableResult
    public func commitImport(
        sourceFileName: String,
        columnMapping: ColumnMapping,
        detectedEncoding: DetectedEncoding,
        totalRowCount: Int,
        acceptedDrafts: [DraftTransaction],
        skippedDuplicateCount: Int
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

        let rules = try MerchantRuleRepository(context: context).fetchAll()

        for draft in acceptedDrafts {
            let matchedRule = CategoryRuleEngine.bestMatch(merchant: draft.merchant, purpose: draft.purpose, rules: rules)
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
                categorySuggestionSource: matchedRule.map { "rule:\($0.origin.rawValue)" },
                category: matchedRule?.category,
                importBatch: batch
            )
            context.insert(transaction)
            if let matchedRule {
                matchedRule.matchCount += 1
            }
        }

        try context.save()
        try RecurringScheduleRepository(context: context).refreshDetectedRecurrence()
        return batch
    }
}
