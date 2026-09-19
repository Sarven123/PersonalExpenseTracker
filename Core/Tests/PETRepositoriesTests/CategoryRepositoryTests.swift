import Foundation
import SwiftData
import Testing
import PETModels
import PETCategorization
@testable import PETRepositories

@Suite("CategoryRepository")
struct CategoryRepositoryTests {
    // Returning just `.mainContext` would let the backing ModelContainer be
    // deallocated (nothing else retains it), leaving the context dangling.
    // Keep the container alive for the lifetime of each test.
    @MainActor
    private func makeContainer() -> ModelContainer {
        ModelContainerFactory.makeInMemoryContainer()
    }

    @Test("Seeding creates all default categories, and is idempotent")
    @MainActor
    func seedsDefaultCategoriesOnce() throws {
        let container = makeContainer()
        let repository = CategoryRepository(context: container.mainContext)
        let first = try repository.seedDefaultCategoriesIfNeeded()
        #expect(first.count == DefaultCategorySeed.all.count)
        let second = try repository.seedDefaultCategoriesIfNeeded()
        #expect(second.count == DefaultCategorySeed.all.count)
        #expect(try repository.fetchAll().count == DefaultCategorySeed.all.count)
    }

    @Test("Create rejects duplicate category names")
    @MainActor
    func rejectsDuplicateNames() throws {
        let container = makeContainer()
        let repository = CategoryRepository(context: container.mainContext)
        _ = try repository.create(name: "Gadgets", colorHex: "#4D96FF", symbolName: "tag.fill")
        #expect(throws: CategoryRepositoryError.self) {
            try repository.create(name: "gadgets", colorHex: "#000000", symbolName: "tag.fill")
        }
    }

    @Test("Deleting a system default category is rejected")
    @MainActor
    func rejectsDeletingSystemDefault() throws {
        let container = makeContainer()
        let repository = CategoryRepository(context: container.mainContext)
        try repository.seedDefaultCategoriesIfNeeded()
        let food = try #require(try repository.fetchAll().first { $0.name == "Food" })
        #expect(throws: CategoryRepositoryError.self) {
            try repository.delete(food, reassigningTransactionsTo: nil)
        }
    }

    @Test("Deleting a custom category reassigns its transactions")
    @MainActor
    func deletingReassignsTransactions() throws {
        let container = makeContainer()
        let categoryRepository = CategoryRepository(context: container.mainContext)
        let transactionRepository = TransactionRepository(context: container.mainContext)
        let custom = try categoryRepository.create(name: "Hobbies", colorHex: "#A78BFA", symbolName: "paintpalette.fill")
        let fallback = try categoryRepository.create(name: "Misc", colorHex: "#9CA3AF", symbolName: "ellipsis.circle.fill")
        let transaction = try transactionRepository.createManualTransaction(
            date: .now,
            magnitude: 10,
            type: .expense,
            merchant: "Hobby Shop",
            notes: nil,
            category: custom,
            isRecurring: false
        )
        try categoryRepository.delete(custom, reassigningTransactionsTo: fallback)
        #expect(transaction.category?.name == "Misc")
    }
}
