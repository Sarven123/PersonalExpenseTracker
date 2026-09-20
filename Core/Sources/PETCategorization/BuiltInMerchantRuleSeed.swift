import Foundation
import PETModels

public struct MerchantRuleSeedDefinition: Sendable {
    public let pattern: String
    public let matchType: RuleMatchType
    public let categoryName: String
    public let priority: Int
    public let isRecurringHint: Bool

    public init(
        pattern: String,
        matchType: RuleMatchType = .contains,
        categoryName: String,
        priority: Int = 0,
        isRecurringHint: Bool = false
    ) {
        self.pattern = pattern
        self.matchType = matchType
        self.categoryName = categoryName
        self.priority = priority
        self.isRecurringHint = isRecurringHint
    }
}

/// A starter set of transparent, local rules for common German merchants,
/// mapped to `DefaultCategorySeed`'s category names. Seeded once (idempotent)
/// alongside the default categories; users can see, correct, or delete these
/// via the merchant rule manager.
public enum BuiltInMerchantRuleSeed {
    public static let all: [MerchantRuleSeedDefinition] = [
        // Food
        .init(pattern: "rewe", categoryName: "Food"),
        .init(pattern: "edeka", categoryName: "Food"),
        .init(pattern: "aldi", categoryName: "Food"),
        .init(pattern: "lidl", categoryName: "Food"),
        .init(pattern: "penny", categoryName: "Food"),
        .init(pattern: "kaufland", categoryName: "Food"),
        .init(pattern: "netto", categoryName: "Food"),
        .init(pattern: "restaurant", categoryName: "Food"),

        // Transport
        .init(pattern: "db vertrieb", categoryName: "Transport"),
        .init(pattern: "deutsche bahn", categoryName: "Transport"),
        .init(pattern: "bvg", categoryName: "Transport"),
        .init(pattern: "tankstelle", categoryName: "Transport"),
        .init(pattern: "shell", categoryName: "Transport"),
        .init(pattern: "aral", categoryName: "Transport"),

        // Entertainment
        .init(pattern: "kino", categoryName: "Entertainment"),
        .init(pattern: "cinema", categoryName: "Entertainment"),

        // Subscriptions
        .init(pattern: "netflix", categoryName: "Subscriptions", isRecurringHint: true),
        .init(pattern: "spotify", categoryName: "Subscriptions", isRecurringHint: true),
        .init(pattern: "disney", categoryName: "Subscriptions", isRecurringHint: true),
        .init(pattern: "amazon prime", categoryName: "Subscriptions", isRecurringHint: true),

        // Housing
        .init(pattern: "hausverwaltung", categoryName: "Housing", isRecurringHint: true),
        .init(pattern: "miete", categoryName: "Housing", isRecurringHint: true),

        // Utilities
        .init(pattern: "stadtwerke", categoryName: "Utilities", isRecurringHint: true),
        .init(pattern: "stromabschlag", categoryName: "Utilities", isRecurringHint: true),
        .init(pattern: "telekom", categoryName: "Utilities", isRecurringHint: true),
        .init(pattern: "vodafone", categoryName: "Utilities", isRecurringHint: true),

        // Health
        .init(pattern: "apotheke", categoryName: "Health"),
        .init(pattern: "aok", categoryName: "Health"),
        .init(pattern: "krankenkasse", categoryName: "Health"),

        // Shopping
        .init(pattern: "zalando", categoryName: "Shopping"),
        .init(pattern: "amazon", categoryName: "Shopping"),
        .init(pattern: "dm-drogerie", categoryName: "Shopping"),
        .init(pattern: "rossmann", categoryName: "Shopping"),

        // Travel
        .init(pattern: "lufthansa", categoryName: "Travel"),
        .init(pattern: "booking.com", categoryName: "Travel"),
        .init(pattern: "airbnb", categoryName: "Travel"),

        // Fees
        .init(pattern: "kontofuehrung", categoryName: "Fees"),
        .init(pattern: "kontoführung", categoryName: "Fees"),

        // Income
        .init(pattern: "gehalt", categoryName: "Income"),
        .init(pattern: "lohn", categoryName: "Income"),

        // Transfers
        .init(pattern: "eigenes sparkonto", categoryName: "Transfers"),
        .init(pattern: "umbuchung", categoryName: "Transfers"),
    ]
}
