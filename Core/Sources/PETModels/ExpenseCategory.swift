import Foundation
import SwiftData

@Model
public final class ExpenseCategory {
    @Attribute(.unique) public var id: UUID
    public var name: String
    public var colorHex: String
    public var symbolName: String
    public var sortOrder: Int
    public var isTransferCategory: Bool
    public var isSystemDefault: Bool
    public var createdAt: Date

    @Relationship(deleteRule: .nullify, inverse: \Transaction.category)
    public var transactions: [Transaction]? = []

    @Relationship(deleteRule: .nullify, inverse: \MerchantRule.category)
    public var merchantRules: [MerchantRule]? = []

    public init(
        id: UUID = UUID(),
        name: String,
        colorHex: String,
        symbolName: String,
        sortOrder: Int = 0,
        isTransferCategory: Bool = false,
        isSystemDefault: Bool = false,
        createdAt: Date = .now
    ) {
        self.id = id
        self.name = name
        self.colorHex = colorHex
        self.symbolName = symbolName
        self.sortOrder = sortOrder
        self.isTransferCategory = isTransferCategory
        self.isSystemDefault = isSystemDefault
        self.createdAt = createdAt
    }
}
