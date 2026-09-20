import Foundation
import SwiftData
import Testing
import PETModels
@testable import PETRepositories

@Suite("DemoDataRepository")
struct DemoDataRepositoryTests {
    @MainActor
    private func makeContainer() -> ModelContainer {
        ModelContainerFactory.makeInMemoryContainer()
    }

    @Test("seeding creates transactions resolved against real categories")
    @MainActor
    func seedingCreatesTransactions() throws {
        let container = makeContainer()
        try CategoryRepository(context: container.mainContext).seedDefaultCategoriesIfNeeded()

        let created = try DemoDataRepository(context: container.mainContext).seedDemoData()
        #expect(!created.isEmpty)
        #expect(created.allSatisfy { $0.source == .manual })
        #expect(created.allSatisfy { $0.category != nil })

        let stored = try TransactionRepository(context: container.mainContext).fetchAll()
        #expect(stored.count == created.count)
    }

    @Test("seeding creates no merchant rules for fictional demo merchants")
    @MainActor
    func seedingCreatesNoMerchantRules() throws {
        let container = makeContainer()
        try CategoryRepository(context: container.mainContext).seedDefaultCategoriesIfNeeded()
        try DemoDataRepository(context: container.mainContext).seedDemoData()

        #expect(try MerchantRuleRepository(context: container.mainContext).fetchAll().isEmpty)
    }

    @Test("seeding flags the repeated monthly merchants as recurring")
    @MainActor
    func seedingDetectsRecurringMerchants() throws {
        let container = makeContainer()
        try CategoryRepository(context: container.mainContext).seedDefaultCategoriesIfNeeded()
        try DemoDataRepository(context: container.mainContext).seedDemoData()

        let stored = try TransactionRepository(context: container.mainContext).fetchAll()
        let streaming = stored.filter { $0.merchant == "Sample Streaming Service" }
        #expect(streaming.allSatisfy { $0.isRecurring })
    }

    @Test("seeding without categories present still creates transactions, just Uncategorized")
    @MainActor
    func seedingWithoutCategoriesStillCreatesTransactions() throws {
        let container = makeContainer()
        let created = try DemoDataRepository(context: container.mainContext).seedDemoData()
        #expect(!created.isEmpty)
        #expect(created.allSatisfy { $0.category == nil })
    }
}
