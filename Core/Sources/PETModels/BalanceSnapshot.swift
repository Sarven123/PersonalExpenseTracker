import Foundation
import SwiftData

/// A timestamped, user-typed balance for a `BalanceAccount` (cash or liability).
/// There is no API for these — the user types the number and it holds until the
/// next snapshot, which is also how historical reconstruction treats it (forward-fill
/// from the most recent snapshot on or before a given date).
@Model
public final class BalanceSnapshot {
    @Attribute(.unique) public var id: UUID
    public var amount: Decimal
    public var asOfDate: Date
    public var notes: String?
    public var createdAt: Date

    public var account: BalanceAccount?

    public init(
        id: UUID = UUID(),
        amount: Decimal,
        asOfDate: Date = .now,
        notes: String? = nil,
        createdAt: Date = .now,
        account: BalanceAccount? = nil
    ) {
        self.id = id
        self.amount = amount
        self.asOfDate = asOfDate
        self.notes = notes
        self.createdAt = createdAt
        self.account = account
    }
}
