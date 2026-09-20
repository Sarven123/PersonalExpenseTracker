import Foundation
import SwiftData
import Testing
import PETModels
@testable import PETRepositories

@Suite("DataResetRepository")
struct DataResetRepositoryTests {
    @MainActor
    private func makeContainer() -> ModelContainer {
        ModelContainerFactory.makeInMemoryContainer()
    }

    @Test("deleteAllData removes every transaction, category, and rule")
    @MainActor
    func deleteAllDataWipesEverything() throws {
        let container = makeContainer()
        let context = container.mainContext

        try CategoryRepository(context: context).seedDefaultCategoriesIfNeeded()
        try MerchantRuleRepository(context: context).seedBuiltInRulesIfNeeded()
        try DemoDataRepository(context: context).seedDemoData()

        #expect(!(try TransactionRepository(context: context).fetchAll()).isEmpty)
        #expect(!(try MerchantRuleRepository(context: context).fetchAll()).isEmpty)

        try DataResetRepository(context: context).deleteAllData()

        #expect(try TransactionRepository(context: context).fetchAll().isEmpty)

        // Re-seeded automatically, so the app stays usable without a relaunch.
        let categories = try CategoryRepository(context: context).fetchAll()
        #expect(categories.count == 14)
        #expect(!(try MerchantRuleRepository(context: context).fetchAll()).isEmpty)
    }

    @Test("deleteAllData on an already-empty store just re-seeds defaults")
    @MainActor
    func deleteAllDataOnEmptyStore() throws {
        let container = makeContainer()
        let context = container.mainContext

        try DataResetRepository(context: context).deleteAllData()

        #expect(try CategoryRepository(context: context).fetchAll().count == 14)
        #expect(try TransactionRepository(context: context).fetchAll().isEmpty)
    }
}
