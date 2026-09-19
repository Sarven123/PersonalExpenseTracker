import Foundation
import SwiftData
import Testing
@testable import PETModels

@Suite("ModelContainerFactory")
struct ModelContainerFactoryTests {
    @Test("In-memory container persists and fetches a Category")
    @MainActor
    func inMemoryContainerRoundTrips() throws {
        let container = ModelContainerFactory.makeInMemoryContainer()
        let context = container.mainContext

        let category = ExpenseCategory(name: "Food", colorHex: "#FF6B6B", symbolName: "fork.knife")
        context.insert(category)
        try context.save()

        let descriptor = FetchDescriptor<ExpenseCategory>()
        let results = try context.fetch(descriptor)
        #expect(results.count == 1)
        #expect(results.first?.name == "Food")
    }

    @Test("Transaction links to its category")
    @MainActor
    func transactionCategoryRelationship() throws {
        let container = ModelContainerFactory.makeInMemoryContainer()
        let context = container.mainContext

        let category = ExpenseCategory(name: "Groceries", colorHex: "#4ECDC4", symbolName: "cart")
        let transaction = ExpenseTransaction(
            bookingDate: .now,
            amount: Decimal(-42.50),
            type: .expense,
            merchant: "REWE",
            rawDescription: "REWE SAGT DANKE",
            source: .manual,
            category: category
        )
        context.insert(category)
        context.insert(transaction)
        try context.save()

        let descriptor = FetchDescriptor<ExpenseTransaction>()
        let results = try context.fetch(descriptor)
        #expect(results.first?.category?.name == "Groceries")
    }
}
