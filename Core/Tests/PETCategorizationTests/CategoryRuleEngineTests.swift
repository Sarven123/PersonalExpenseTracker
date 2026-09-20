import Testing
import PETModels
@testable import PETCategorization

private func makeCategory(_ name: String) -> ExpenseCategory {
    ExpenseCategory(name: name, colorHex: "#000000", symbolName: "tag", sortOrder: 0)
}

@Suite("CategoryRuleEngine")
struct CategoryRuleEngineTests {

    @Test("a contains rule matches a merchant that contains its pattern")
    func containsRuleMatches() {
        let food = makeCategory("Food")
        let rule = MerchantRule(matchType: .contains, pattern: "rewe", category: food)
        let match = CategoryRuleEngine.suggestCategory(merchant: "REWE Markt GmbH", purpose: nil, rules: [rule])
        #expect(match?.name == "Food")
    }

    @Test("a contains rule also matches against the purpose text")
    func containsRuleMatchesPurpose() {
        let subscriptions = makeCategory("Subscriptions")
        let rule = MerchantRule(matchType: .contains, pattern: "netflix", category: subscriptions)
        let match = CategoryRuleEngine.suggestCategory(
            merchant: "Netflix International BV",
            purpose: "Netflix.com Streaming Abo",
            rules: [rule]
        )
        #expect(match?.name == "Subscriptions")
    }

    @Test("an exact rule requires the whole normalized merchant to match")
    func exactRuleRequiresFullMatch() {
        let shopping = makeCategory("Shopping")
        let rule = MerchantRule(matchType: .exact, pattern: "zalando", category: shopping)

        #expect(CategoryRuleEngine.suggestCategory(merchant: "Zalando SE", purpose: nil, rules: [rule])?.name == "Shopping")
        #expect(CategoryRuleEngine.suggestCategory(merchant: "Zalando Outlet SE", purpose: nil, rules: [rule]) == nil)
    }

    @Test("a startsWith rule only matches a prefix")
    func startsWithRule() {
        let transport = makeCategory("Transport")
        let rule = MerchantRule(matchType: .startsWith, pattern: "db vertrieb", category: transport)

        #expect(CategoryRuleEngine.suggestCategory(merchant: "DB Vertrieb GmbH", purpose: nil, rules: [rule])?.name == "Transport")
        #expect(CategoryRuleEngine.suggestCategory(merchant: "Not DB Vertrieb GmbH", purpose: nil, rules: [rule]) == nil)
    }

    @Test("a regex rule matches against the raw, non-normalized text")
    func regexRule() {
        let fees = makeCategory("Fees")
        let rule = MerchantRule(matchType: .regex, pattern: "geb(ü|ue)hr", category: fees)
        #expect(CategoryRuleEngine.suggestCategory(merchant: "Kontogebühr", purpose: nil, rules: [rule])?.name == "Fees")
    }

    @Test("higher-priority rules win over lower-priority matches")
    func priorityBreaksTies() {
        let shopping = makeCategory("Shopping")
        let food = makeCategory("Food")
        let low = MerchantRule(matchType: .contains, pattern: "amazon", priority: 0, category: shopping)
        let high = MerchantRule(matchType: .contains, pattern: "amazon fresh", priority: 100, category: food)

        let match = CategoryRuleEngine.suggestCategory(merchant: "Amazon Fresh GmbH", purpose: nil, rules: [low, high])
        #expect(match?.name == "Food")
    }

    @Test("no match returns nil, leaving the transaction Uncategorized")
    func noMatchReturnsNil() {
        let rule = MerchantRule(matchType: .contains, pattern: "rewe", category: makeCategory("Food"))
        let match = CategoryRuleEngine.suggestCategory(merchant: "Totally Unrelated Merchant", purpose: nil, rules: [rule])
        #expect(match == nil)
    }

    @Test("an empty rule set returns nil")
    func emptyRuleSet() {
        #expect(CategoryRuleEngine.suggestCategory(merchant: "REWE", purpose: nil, rules: []) == nil)
    }
}
