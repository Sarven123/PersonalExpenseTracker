import Foundation
import SwiftData
import Testing
import PETModels
@testable import PETRepositories

@Suite("MerchantRuleRepository")
struct MerchantRuleRepositoryTests {
    @MainActor
    private func makeContainer() -> ModelContainer {
        ModelContainerFactory.makeInMemoryContainer()
    }

    @Test("seeding creates builtin rules resolved against real categories, and is idempotent")
    @MainActor
    func seedingIsIdempotent() throws {
        let container = makeContainer()
        try CategoryRepository(context: container.mainContext).seedDefaultCategoriesIfNeeded()
        let repository = MerchantRuleRepository(context: container.mainContext)

        let firstPass = try repository.seedBuiltInRulesIfNeeded()
        #expect(!firstPass.isEmpty)
        #expect(firstPass.allSatisfy { $0.category != nil })

        let secondPass = try repository.seedBuiltInRulesIfNeeded()
        #expect(secondPass.count == firstPass.count)
        #expect(try repository.fetchAll().filter { $0.origin == .builtIn }.count == firstPass.count)
    }

    @Test("seeding without categories present creates no rules")
    @MainActor
    func seedingWithoutCategoriesCreatesNothing() throws {
        let container = makeContainer()
        let repository = MerchantRuleRepository(context: container.mainContext)
        let created = try repository.seedBuiltInRulesIfNeeded()
        #expect(created.isEmpty)
    }

    @Test("suggestCategory resolves a builtin rule for a known merchant")
    @MainActor
    func suggestCategoryUsesBuiltInRules() throws {
        let container = makeContainer()
        try CategoryRepository(context: container.mainContext).seedDefaultCategoriesIfNeeded()
        let repository = MerchantRuleRepository(context: container.mainContext)
        try repository.seedBuiltInRulesIfNeeded()

        let match = try repository.suggestCategory(merchant: "REWE Markt GmbH", purpose: nil)
        #expect(match?.category?.name == "Food")
    }

    @Test("recordUserCorrection creates a new exact-match rule")
    @MainActor
    func recordUserCorrectionCreatesRule() throws {
        let container = makeContainer()
        let categoryRepository = CategoryRepository(context: container.mainContext)
        try categoryRepository.seedDefaultCategoriesIfNeeded()
        let travel = try categoryRepository.fetchAll().first { $0.name == "Travel" }!

        let repository = MerchantRuleRepository(context: container.mainContext)
        let rule = try repository.recordUserCorrection(merchant: "Corner Coffee Shop", category: travel)

        #expect(rule?.origin == .userCorrection)
        #expect(rule?.matchType == .exact)
        #expect(rule?.category?.name == "Travel")
        #expect(rule?.pattern == "corner coffee shop")
    }

    @Test("recordUserCorrection updates an existing rule instead of duplicating it")
    @MainActor
    func recordUserCorrectionUpdatesExisting() throws {
        let container = makeContainer()
        let categoryRepository = CategoryRepository(context: container.mainContext)
        try categoryRepository.seedDefaultCategoriesIfNeeded()
        let categories = try categoryRepository.fetchAll()
        let travel = categories.first { $0.name == "Travel" }!
        let food = categories.first { $0.name == "Food" }!

        let repository = MerchantRuleRepository(context: container.mainContext)
        try repository.recordUserCorrection(merchant: "Corner Coffee Shop", category: travel)
        try repository.recordUserCorrection(merchant: "Corner Coffee Shop", category: food)

        let userRules = try repository.fetchAll().filter { $0.origin == .userCorrection }
        #expect(userRules.count == 1)
        #expect(userRules.first?.category?.name == "Food")
        #expect(userRules.first?.matchCount == 2)
    }

    @Test("recordUserCorrection no-ops for a merchant that normalizes to empty")
    @MainActor
    func recordUserCorrectionSkipsEmptyPattern() throws {
        let container = makeContainer()
        let categoryRepository = CategoryRepository(context: container.mainContext)
        try categoryRepository.seedDefaultCategoriesIfNeeded()
        let food = try categoryRepository.fetchAll().first { $0.name == "Food" }!

        let repository = MerchantRuleRepository(context: container.mainContext)
        let rule = try repository.recordUserCorrection(merchant: "GmbH", category: food)

        #expect(rule == nil)
        #expect(try repository.fetchAll().isEmpty)
    }

    @Test("delete removes a rule")
    @MainActor
    func deleteRemovesRule() throws {
        let container = makeContainer()
        let categoryRepository = CategoryRepository(context: container.mainContext)
        try categoryRepository.seedDefaultCategoriesIfNeeded()
        let food = try categoryRepository.fetchAll().first { $0.name == "Food" }!

        let repository = MerchantRuleRepository(context: container.mainContext)
        let rule = try repository.recordUserCorrection(merchant: "Corner Coffee Shop", category: food)!
        try repository.delete(rule)

        #expect(try repository.fetchAll().isEmpty)
    }
}
