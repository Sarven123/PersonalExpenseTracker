import Foundation
import SwiftData

/// Append-only audit ledger for buy/sell/fee events against a `Holding`. This is
/// the only path allowed to change a holding's `quantity`/`averageCostPerUnit` —
/// `resultingQuantity`/`resultingAverageCost` are snapshots after applying this
/// activity, so the ledger is self-auditing without needing to replay history.
@Model
public final class HoldingActivity {
    @Attribute(.unique) public var id: UUID
    public var activityType: HoldingActivityType
    public var date: Date
    public var quantity: Decimal?
    public var pricePerUnit: Decimal?
    public var currencyCode: String?
    public var feeAmount: Decimal?
    public var resultingQuantity: Decimal
    public var resultingAverageCost: Decimal
    /// Populated only on `.sell`; approximate, since this app uses average-cost accounting, not per-lot.
    public var realizedGainEUR: Decimal?
    public var notes: String?
    public var createdAt: Date

    public var holding: Holding?

    public init(
        id: UUID = UUID(),
        activityType: HoldingActivityType,
        date: Date = .now,
        quantity: Decimal? = nil,
        pricePerUnit: Decimal? = nil,
        currencyCode: String? = nil,
        feeAmount: Decimal? = nil,
        resultingQuantity: Decimal,
        resultingAverageCost: Decimal,
        realizedGainEUR: Decimal? = nil,
        notes: String? = nil,
        createdAt: Date = .now,
        holding: Holding? = nil
    ) {
        self.id = id
        self.activityType = activityType
        self.date = date
        self.quantity = quantity
        self.pricePerUnit = pricePerUnit
        self.currencyCode = currencyCode
        self.feeAmount = feeAmount
        self.resultingQuantity = resultingQuantity
        self.resultingAverageCost = resultingAverageCost
        self.realizedGainEUR = realizedGainEUR
        self.notes = notes
        self.createdAt = createdAt
        self.holding = holding
    }
}
