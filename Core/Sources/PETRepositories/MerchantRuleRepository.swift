import Foundation
import SwiftData
import PETModels
import PETCategorization

@MainActor
public final class MerchantRuleRepository {
    private let context: ModelContext

    public init(context: ModelContext) {
        self.context = context
    }

    public func fetchAll() throws -> [MerchantRule] {
        var descriptor = FetchDescriptor<MerchantRule>()
        descriptor.sortBy = [SortDescriptor(\.priority, order: .reverse)]
        return try context.fetch(descriptor)
    }

    @discardableResult
    public func seedBuiltInRulesIfNeeded() throws -> [MerchantRule] {
        let existing = try fetchAll()
        guard !existing.contains(where: { $0.origin == .builtIn }) else { return existing }

        let categoriesByName = Dictionary(
            uniqueKeysWithValues: try CategoryRepository(context: context).fetchAll().map { ($0.name, $0) }
        )

        var created: [MerchantRule] = []
        for definition in BuiltInMerchantRuleSeed.all {
            guard let category = categoriesByName[definition.categoryName] else { continue }
            let rule = MerchantRule(
                matchType: definition.matchType,
                pattern: definition.pattern,
                priority: definition.priority,
                origin: .builtIn,
                isRecurringHint: definition.isRecurringHint,
                category: category
            )
            context.insert(rule)
            created.append(rule)
        }
        try context.save()
        return created
    }

    public func suggestCategory(merchant: String, purpose: String?) throws -> MerchantRule? {
        CategoryRuleEngine.bestMatch(merchant: merchant, purpose: purpose, rules: try fetchAll())
    }

    /// Called whenever a user manually assigns a category to a transaction —
    /// creates or strengthens a local rule so future imports auto-suggest the
    /// same category for this merchant. No-ops for a merchant that normalizes
    /// to an empty pattern (would otherwise match everything).
    @discardableResult
    public func recordUserCorrection(merchant: String, category: ExpenseCategory) throws -> MerchantRule? {
        let normalizedPattern = MerchantNormalizer.normalize(merchant)
        guard !normalizedPattern.isEmpty else { return nil }

        if let existing = try fetchAll().first(where: {
            $0.origin == .userCorrection && $0.matchType == .exact && $0.pattern == normalizedPattern
        }) {
            existing.category = category
            existing.matchCount += 1
            try context.save()
            return existing
        }

        let rule = MerchantRule(
            matchType: .exact,
            pattern: normalizedPattern,
            priority: 100,
            origin: .userCorrection,
            matchCount: 1,
            category: category
        )
        context.insert(rule)
        try context.save()
        return rule
    }

    public func delete(_ rule: MerchantRule) throws {
        context.delete(rule)
        try context.save()
    }
}
