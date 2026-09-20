import Foundation
import PETModels

/// Matches a transaction's merchant/purpose text against a set of
/// `MerchantRule`s to suggest a category. Rules are tried in descending
/// `priority` order; the first rule whose pattern matches wins.
public enum CategoryRuleEngine {
    public static func bestMatch(merchant: String, purpose: String?, rules: [MerchantRule]) -> MerchantRule? {
        let normalizedMerchant = MerchantNormalizer.normalize(merchant)
        let normalizedPurpose = purpose.map(MerchantNormalizer.normalize) ?? ""
        let normalizedHaystack = [normalizedMerchant, normalizedPurpose]
            .filter { !$0.isEmpty }
            .joined(separator: " ")
        let rawHaystack = [merchant, purpose ?? ""].joined(separator: " ")

        return rules
            .sorted { $0.priority > $1.priority }
            .first {
                matches(
                    rule: $0,
                    normalizedHaystack: normalizedHaystack,
                    normalizedMerchant: normalizedMerchant,
                    rawHaystack: rawHaystack
                )
            }
    }

    public static func suggestCategory(merchant: String, purpose: String?, rules: [MerchantRule]) -> ExpenseCategory? {
        bestMatch(merchant: merchant, purpose: purpose, rules: rules)?.category
    }

    private static func matches(
        rule: MerchantRule,
        normalizedHaystack: String,
        normalizedMerchant: String,
        rawHaystack: String
    ) -> Bool {
        switch rule.matchType {
        case .contains:
            let pattern = MerchantNormalizer.normalize(rule.pattern)
            return !pattern.isEmpty && normalizedHaystack.contains(pattern)
        case .exact:
            let pattern = MerchantNormalizer.normalize(rule.pattern)
            return !pattern.isEmpty && normalizedMerchant == pattern
        case .startsWith:
            let pattern = MerchantNormalizer.normalize(rule.pattern)
            return !pattern.isEmpty && normalizedHaystack.hasPrefix(pattern)
        case .regex:
            // Regex patterns are matched against the raw (non-normalized) text,
            // since normalization would mangle regex metacharacters.
            guard let regex = try? NSRegularExpression(pattern: rule.pattern, options: [.caseInsensitive]) else {
                return false
            }
            let range = NSRange(rawHaystack.startIndex..., in: rawHaystack)
            return regex.firstMatch(in: rawHaystack, options: [], range: range) != nil
        }
    }
}
