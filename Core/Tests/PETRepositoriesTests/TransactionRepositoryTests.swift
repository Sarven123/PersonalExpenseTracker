import Foundation
import SwiftData
import Testing
import PETModels
@testable import PETRepositories

@Suite("TransactionRepository")
struct TransactionRepositoryTests {
    // Returning just `.mainContext` would let the backing ModelContainer be
    // deallocated (nothing else retains it), leaving the context dangling.
    // Keep the container alive for the lifetime of each test.
    @MainActor
    private func makeContainer() -> ModelContainer {
        ModelContainerFactory.makeInMemoryContainer()
    }

    @Test("Expense amounts are stored as negative")
    @MainActor
    func expenseIsNegative() throws {
        let container = makeContainer()
        let repository = TransactionRepository(context: container.mainContext)
        let transaction = try repository.createManualTransaction(
            date: .now, magnitude: 42.5, type: .expense, merchant: "REWE",
            notes: nil, category: nil, isRecurring: false
        )
        #expect(transaction.amount == Decimal(-42.5))
    }

    @Test("Income amounts are stored as positive")
    @MainActor
    func incomeIsPositive() throws {
        let container = makeContainer()
        let repository = TransactionRepository(context: container.mainContext)
        let transaction = try repository.createManualTransaction(
            date: .now, magnitude: 2500, type: .income, merchant: "Employer",
            notes: nil, category: nil, isRecurring: false
        )
        #expect(transaction.amount == Decimal(2500))
    }

    @Test("Transfer amounts are stored as negative")
    @MainActor
    func transferIsNegative() throws {
        let container = makeContainer()
        let repository = TransactionRepository(context: container.mainContext)
        let transaction = try repository.createManualTransaction(
            date: .now, magnitude: 300, type: .transfer, merchant: "Own Savings",
            notes: nil, category: nil, isRecurring: false
        )
        #expect(transaction.amount == Decimal(-300))
    }

    @Test("Update changes fields and re-signs the amount")
    @MainActor
    func updateChangesFields() throws {
        let container = makeContainer()
        let repository = TransactionRepository(context: container.mainContext)
        let transaction = try repository.createManualTransaction(
            date: .now, magnitude: 10, type: .expense, merchant: "Test",
            notes: nil, category: nil, isRecurring: false
        )
        try repository.update(
            transaction, date: .now, magnitude: 10, type: .income, merchant: "Test",
            notes: "Refund", category: nil, isRecurring: false
        )
        #expect(transaction.amount == Decimal(10))
        #expect(transaction.notes == "Refund")
    }

    @Test("Delete removes the transaction")
    @MainActor
    func deleteRemoves() throws {
        let container = makeContainer()
        let repository = TransactionRepository(context: container.mainContext)
        let transaction = try repository.createManualTransaction(
            date: .now, magnitude: 5, type: .expense, merchant: "Test",
            notes: nil, category: nil, isRecurring: false
        )
        try repository.delete(transaction)
        #expect(try repository.fetchAll().isEmpty)
    }
}
