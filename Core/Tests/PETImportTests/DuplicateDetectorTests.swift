import Foundation
import Testing
import PETModels
@testable import PETImport

@Suite("DuplicateDetector")
struct DuplicateDetectorTests {
    private static func draft(
        rowNumber: Int = 1,
        bookingDate: Date = Date(timeIntervalSince1970: 1_756_684_800),
        amount: Decimal = Decimal(string: "-42.17")!,
        merchant: String = "REWE Markt GmbH",
        counterpartyIBAN: String? = "DE02120300000000202051",
        purpose: String? = "REWE SAGT DANKE"
    ) -> DraftTransaction {
        DraftTransaction(
            sourceRowNumber: rowNumber,
            bookingDate: bookingDate,
            valueDate: nil,
            amount: amount,
            currencyCode: "EUR",
            type: amount < 0 ? .expense : .income,
            merchant: merchant,
            rawDescription: purpose ?? "",
            purpose: purpose,
            bookingText: nil,
            ownIBAN: nil,
            counterpartyIBAN: counterpartyIBAN,
            bic: nil,
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

    @Test("produces identical hashes for identical transactions")
    func stableHash() {
        let a = Self.draft()
        let b = Self.draft()
        #expect(a.dedupeHash == b.dedupeHash)
    }

    @Test("produces different hashes when the amount differs")
    func differentAmount() {
        let a = Self.draft(amount: Decimal(string: "-42.17")!)
        let b = Self.draft(amount: Decimal(string: "-42.18")!)
        #expect(a.dedupeHash != b.dedupeHash)
    }

    @Test("produces different hashes when the booking date differs")
    func differentDate() {
        let a = Self.draft(bookingDate: Date(timeIntervalSince1970: 1_756_684_800))
        let b = Self.draft(bookingDate: Date(timeIntervalSince1970: 1_756_771_200))
        #expect(a.dedupeHash != b.dedupeHash)
    }

    @Test("flags an incoming row as a duplicate of an existing stored hash")
    func flagsExistingDuplicate() {
        let draft = Self.draft()
        let result = DuplicateDetector.partition(drafts: [draft], existingHashes: [draft.dedupeHash])
        #expect(result.unique.isEmpty)
        #expect(result.duplicates.count == 1)
    }

    @Test("flags a repeated row within the same batch as a duplicate")
    func flagsIntraBatchDuplicate() {
        let draft = Self.draft()
        let result = DuplicateDetector.partition(drafts: [draft, draft], existingHashes: [])
        #expect(result.unique.count == 1)
        #expect(result.duplicates.count == 1)
    }

    @Test("keeps distinct rows unique")
    func keepsDistinctRowsUnique() {
        let a = Self.draft(merchant: "REWE Markt GmbH", counterpartyIBAN: "DE02120300000000202051")
        let b = Self.draft(merchant: "dm-drogerie markt", counterpartyIBAN: "DE33500105170123456789")
        let result = DuplicateDetector.partition(drafts: [a, b], existingHashes: [])
        #expect(result.unique.count == 2)
        #expect(result.duplicates.isEmpty)
    }
}
