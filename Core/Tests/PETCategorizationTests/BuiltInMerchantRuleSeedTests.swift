import Testing
@testable import PETCategorization

@Suite("BuiltInMerchantRuleSeed")
struct BuiltInMerchantRuleSeedTests {
    @Test("every rule targets a real DefaultCategorySeed category name")
    func targetsKnownCategories() {
        let knownNames = Set(DefaultCategorySeed.all.map(\.name))
        for definition in BuiltInMerchantRuleSeed.all {
            #expect(knownNames.contains(definition.categoryName), "Unknown category: \(definition.categoryName)")
        }
    }

    @Test("no two rules share the exact same pattern")
    func patternsAreUnique() {
        let patterns = BuiltInMerchantRuleSeed.all.map(\.pattern)
        #expect(Set(patterns).count == patterns.count)
    }

    @Test("no rule has an empty pattern")
    func noEmptyPatterns() {
        #expect(BuiltInMerchantRuleSeed.all.allSatisfy { !$0.pattern.isEmpty })
    }

    @Test("is non-empty")
    func isNonEmpty() {
        #expect(!BuiltInMerchantRuleSeed.all.isEmpty)
    }
}
