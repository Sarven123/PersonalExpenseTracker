import Foundation
import SwiftData
import Testing
import PETModels
@testable import PETRepositories

@Suite("FilterCriteria")
struct FilterCriteriaTests {
    @MainActor
    private func makeContainer() -> ModelContainer {
        ModelContainerFactory.makeInMemoryContainer()
    }

    private static func date(_ daysFromReference: Int, reference: Date = Date(timeIntervalSince1970: 1_756_684_800)) -> Date {
        reference.addingTimeInterval(Double(daysFromReference) * 86400)
    }

    @Test("a default FilterCriteria is not active and matches everything")
    func defaultIsInactiveAndMatchesEverything() {
        let filter = FilterCriteria()
        #expect(!filter.isActive)

        let transaction = ExpenseTransaction(bookingDate: .now, amount: -10, type: .expense, merchant: "Anything", rawDescription: "Anything")
        #expect(filter.matches(transaction))
    }

    @Test("merchantSearchText filters case-insensitively")
    @MainActor
    func merchantSearchIsCaseInsensitive() throws {
        var filter = FilterCriteria()
        filter.merchantSearchText = "rewe"

        let match = ExpenseTransaction(bookingDate: .now, amount: -10, type: .expense, merchant: "REWE Markt GmbH", rawDescription: "")
        let noMatch = ExpenseTransaction(bookingDate: .now, amount: -10, type: .expense, merchant: "Aldi", rawDescription: "")

        #expect(filter.matches(match))
        #expect(!filter.matches(noMatch))
        #expect(filter.isActive)
    }

    @Test("types restricts to the selected transaction types")
    func typesRestrictsSelection() {
        var filter = FilterCriteria()
        filter.types = [.income]

        let expense = ExpenseTransaction(bookingDate: .now, amount: -10, type: .expense, merchant: "A", rawDescription: "")
        let income = ExpenseTransaction(bookingDate: .now, amount: 10, type: .income, merchant: "B", rawDescription: "")

        #expect(!filter.matches(expense))
        #expect(filter.matches(income))
    }

    @Test("sources restricts to the selected transaction sources")
    func sourcesRestrictsSelection() {
        var filter = FilterCriteria()
        filter.sources = [.imported]

        let manual = ExpenseTransaction(bookingDate: .now, amount: -10, type: .expense, merchant: "A", rawDescription: "", source: .manual)
        let imported = ExpenseTransaction(bookingDate: .now, amount: -10, type: .expense, merchant: "B", rawDescription: "", source: .imported)

        #expect(!filter.matches(manual))
        #expect(filter.matches(imported))
    }

    @Test("excludeTransfers filters out Transfers-category transactions")
    func excludeTransfersFiltersTransferCategory() {
        var filter = FilterCriteria()
        filter.excludeTransfers = true

        let transfers = ExpenseCategory(name: "Transfers", colorHex: "#000", symbolName: "tag", isTransferCategory: true)
        let transfer = ExpenseTransaction(bookingDate: .now, amount: -10, type: .expense, merchant: "A", rawDescription: "", category: transfers)
        let regular = ExpenseTransaction(bookingDate: .now, amount: -10, type: .expense, merchant: "B", rawDescription: "")

        #expect(!filter.matches(transfer))
        #expect(filter.matches(regular))
    }

    @Test("uncategorizedOnly matches only transactions with no category")
    func uncategorizedOnlyMatchesNilCategory() {
        var filter = FilterCriteria()
        filter.uncategorizedOnly = true

        let food = ExpenseCategory(name: "Food", colorHex: "#000", symbolName: "tag")
        let categorized = ExpenseTransaction(bookingDate: .now, amount: -10, type: .expense, merchant: "A", rawDescription: "", category: food)
        let uncategorized = ExpenseTransaction(bookingDate: .now, amount: -10, type: .expense, merchant: "B", rawDescription: "")

        #expect(!filter.matches(categorized))
        #expect(filter.matches(uncategorized))
    }

    @Test("categoryIDs matches only transactions in the selected categories")
    func categoryIDsRestrictsSelection() throws {
        let food = ExpenseCategory(name: "Food", colorHex: "#000", symbolName: "tag")
        let shopping = ExpenseCategory(name: "Shopping", colorHex: "#000", symbolName: "tag")

        var filter = FilterCriteria()
        filter.categoryIDs = [food.id]

        let foodTx = ExpenseTransaction(bookingDate: .now, amount: -10, type: .expense, merchant: "A", rawDescription: "", category: food)
        let shoppingTx = ExpenseTransaction(bookingDate: .now, amount: -10, type: .expense, merchant: "B", rawDescription: "", category: shopping)

        #expect(filter.matches(foodTx))
        #expect(!filter.matches(shoppingTx))
    }

    @Test("dateRange .custom restricts to the given range")
    func customDateRangeRestrictsSelection() {
        var filter = FilterCriteria()
        filter.dateRange = .custom(start: Self.date(-5), end: Self.date(5))

        let inside = ExpenseTransaction(bookingDate: Self.date(0), amount: -10, type: .expense, merchant: "A", rawDescription: "")
        let outside = ExpenseTransaction(bookingDate: Self.date(100), amount: -10, type: .expense, merchant: "B", rawDescription: "")

        #expect(filter.matches(inside))
        #expect(!filter.matches(outside))
    }

    @Test("matchesAttributes ignores the date range")
    func matchesAttributesIgnoresDateRange() {
        var filter = FilterCriteria()
        filter.dateRange = .custom(start: Self.date(-5), end: Self.date(5))

        let outsideRange = ExpenseTransaction(bookingDate: Self.date(1000), amount: -10, type: .expense, merchant: "A", rawDescription: "")
        #expect(filter.matchesAttributes(outsideRange))
        #expect(!filter.matches(outsideRange))
    }

    @Test("reset() restores default values")
    func resetRestoresDefaults() {
        var filter = FilterCriteria()
        filter.merchantSearchText = "rewe"
        filter.excludeTransfers = true
        filter.reset()
        #expect(!filter.isActive)
        #expect(filter.merchantSearchText.isEmpty)
    }
}
