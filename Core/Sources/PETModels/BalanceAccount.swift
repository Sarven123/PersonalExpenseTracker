import Foundation
import SwiftData

/// Collapses cash and liability accounts into one model (distinguished by `kind`),
/// matching this codebase's "wide optional fields on one model" convention rather
/// than a class hierarchy for variants.
@Model
public final class BalanceAccount {
    @Attribute(.unique) public var id: UUID
    public var name: String
    public var kind: BalanceAccountKind
    public var currencyCode: String
    public var isArchived: Bool
    public var createdAt: Date

    @Relationship(deleteRule: .nullify, inverse: \BalanceSnapshot.account)
    public var snapshots: [BalanceSnapshot]? = []

    public init(
        id: UUID = UUID(),
        name: String,
        kind: BalanceAccountKind,
        currencyCode: String = "EUR",
        isArchived: Bool = false,
        createdAt: Date = .now
    ) {
        self.id = id
        self.name = name
        self.kind = kind
        self.currencyCode = currencyCode
        self.isArchived = isArchived
        self.createdAt = createdAt
    }
}
