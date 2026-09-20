import Foundation
import SwiftData
import Testing
import PETModels
import PETImport
@testable import PETRepositories

@Suite("ImportRepository")
struct ImportRepositoryTests {
    // Returning just `.mainContext` would let the backing ModelContainer be
    // deallocated (nothing else retains it), leaving the context dangling.
    // Keep the container alive for the lifetime of each test.
    @MainActor
    private func makeContainer() -> ModelContainer {
        ModelContainerFactory.makeInMemoryContainer()
    }

    private static let mapping = try! ColumnMapping.detect(headerRow: [
        "Buchungsdatum", "Wertstellung", "Umsatzart", "Buchungstext",
        "Empfänger/Zahlungspflichtiger", "IBAN", "BIC", "Betrag", "Waehrung",
    ])

    private static func draft(
        rowNumber: Int = 2,
        merchant: String = "REWE Markt GmbH",
        counterpartyIBAN: String = "DE02120300000000202051",
        amount: Decimal = Decimal(string: "-42.17")!
    ) -> DraftTransaction {
        let bookingDate = Date(timeIntervalSince1970: 1_756_684_800)
        let purpose = "REWE SAGT DANKE"
        return DraftTransaction(
            sourceRowNumber: rowNumber,
            bookingDate: bookingDate,
            valueDate: nil,
            amount: amount,
            currencyCode: "EUR",
            type: amount < 0 ? .expense : .income,
            merchant: merchant,
            rawDescription: purpose,
            purpose: purpose,
            bookingText: "Kartenzahlung",
            ownIBAN: nil,
            counterpartyIBAN: counterpartyIBAN,
            bic: "NOLADE21",
            dedupeHash: DuplicateDetector.computeHash(
                bookingDate: bookingDate,
                amount: amount,
                currencyCode: "EUR",
                counterpartyIBAN: counterpartyIBAN,
                merchant: merchant,
                purpose: purpose
            )
        )
    }

    @Test("Commit creates an ImportBatch and one imported transaction per accepted draft")
    @MainActor
    func commitCreatesBatchAndTransactions() throws {
        let container = makeContainer()
        let repository = ImportRepository(context: container.mainContext)
        let draft = Self.draft()

        let batch = try repository.commitImport(
            sourceFileName: "export.csv",
            columnMapping: Self.mapping,
            detectedEncoding: .utf8,
            totalRowCount: 1,
            acceptedDrafts: [draft],
            skippedDuplicateCount: 0
        )

        #expect(batch.importedCount == 1)
        #expect(batch.skippedDuplicateCount == 0)
        #expect(batch.sourceFormat == .mt940CSV)

        let transactions = try TransactionRepository(context: container.mainContext).fetchAll()
        #expect(transactions.count == 1)
        let transaction = try #require(transactions.first)
        #expect(transaction.source == .imported)
        #expect(transaction.merchant == "REWE Markt GmbH")
        #expect(transaction.amount == Decimal(string: "-42.17"))
        #expect(transaction.dedupeHash == draft.dedupeHash)
        #expect(transaction.importBatch?.id == batch.id)
    }

    @Test("Commit round-trips the column mapping as decodable JSON")
    @MainActor
    func commitPersistsColumnMapping() throws {
        let container = makeContainer()
        let repository = ImportRepository(context: container.mainContext)

        let batch = try repository.commitImport(
            sourceFileName: "export.csv",
            columnMapping: Self.mapping,
            detectedEncoding: .utf8,
            totalRowCount: 1,
            acceptedDrafts: [Self.draft()],
            skippedDuplicateCount: 0
        )

        let decoded = try JSONDecoder().decode(ColumnMapping.self, from: batch.columnMapping)
        #expect(decoded == Self.mapping)
    }

    @Test("existingDedupeHashes reflects previously committed transactions")
    @MainActor
    func existingDedupeHashesReflectsCommittedData() throws {
        let container = makeContainer()
        let repository = ImportRepository(context: container.mainContext)
        let draft = Self.draft()

        #expect(try repository.existingDedupeHashes().isEmpty)

        try repository.commitImport(
            sourceFileName: "export.csv",
            columnMapping: Self.mapping,
            detectedEncoding: .utf8,
            totalRowCount: 1,
            acceptedDrafts: [draft],
            skippedDuplicateCount: 0
        )

        #expect(try repository.existingDedupeHashes() == [draft.dedupeHash])
    }

    @Test("Re-importing the same file end-to-end skips duplicates via DuplicateDetector")
    @MainActor
    func reimportSkipsDuplicatesEndToEnd() throws {
        let container = makeContainer()
        let repository = ImportRepository(context: container.mainContext)
        let firstBatchDrafts = [Self.draft(rowNumber: 2), Self.draft(rowNumber: 3, merchant: "dm-drogerie markt", counterpartyIBAN: "DE33500105170123456789", amount: Decimal(string: "-23.45")!)]

        try repository.commitImport(
            sourceFileName: "export.csv",
            columnMapping: Self.mapping,
            detectedEncoding: .utf8,
            totalRowCount: 2,
            acceptedDrafts: firstBatchDrafts,
            skippedDuplicateCount: 0
        )

        let existingHashes = try repository.existingDedupeHashes()
        let partitioned = DuplicateDetector.partition(drafts: firstBatchDrafts, existingHashes: existingHashes)
        #expect(partitioned.unique.isEmpty)
        #expect(partitioned.duplicates.count == 2)

        try repository.commitImport(
            sourceFileName: "export.csv",
            columnMapping: Self.mapping,
            detectedEncoding: .utf8,
            totalRowCount: 2,
            acceptedDrafts: partitioned.unique,
            skippedDuplicateCount: partitioned.duplicates.count
        )

        let allTransactions = try TransactionRepository(context: container.mainContext).fetchAll()
        #expect(allTransactions.count == 2) // second commit added nothing new
    }
}
