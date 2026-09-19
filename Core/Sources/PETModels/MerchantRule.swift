import Foundation
import SwiftData

@Model
public final class MerchantRule {
    @Attribute(.unique) public var id: UUID
    public var matchType: RuleMatchType
    public var pattern: String
    public var priority: Int
    public var origin: RuleOrigin
    public var isRecurringHint: Bool
    public var matchCount: Int
    public var createdAt: Date

    public var category: ExpenseCategory?

    public init(
        id: UUID = UUID(),
        matchType: RuleMatchType,
        pattern: String,
        priority: Int = 0,
        origin: RuleOrigin = .userCorrection,
        isRecurringHint: Bool = false,
        matchCount: Int = 0,
        createdAt: Date = .now,
        category: ExpenseCategory? = nil
    ) {
        self.id = id
        self.matchType = matchType
        self.pattern = pattern
        self.priority = priority
        self.origin = origin
        self.isRecurringHint = isRecurringHint
        self.matchCount = matchCount
        self.createdAt = createdAt
        self.category = category
    }
}
