import Foundation
import SwiftData

/// Cache/backfill store for gold spot price. Always priced in USD — gold price
/// fetches are deliberately never converted to EUR by the provider, so gold and
/// equities share exactly one FX pipeline (via `FXRatePoint`) instead of two
/// independent, unaudited conversion paths.
@Model
public final class GoldPricePoint {
    @Attribute(.unique) public var id: UUID
    public var priceDate: Date
    public var pricePerTroyOunce: Decimal
    public var currencyCode: String
    public var fetchedAt: Date
    public var source: String
    public var isBackfilled: Bool

    public init(
        id: UUID = UUID(),
        priceDate: Date,
        pricePerTroyOunce: Decimal,
        currencyCode: String = "USD",
        fetchedAt: Date = .now,
        source: String,
        isBackfilled: Bool = false
    ) {
        self.id = id
        self.priceDate = priceDate
        self.pricePerTroyOunce = pricePerTroyOunce
        self.currencyCode = currencyCode
        self.fetchedAt = fetchedAt
        self.source = source
        self.isBackfilled = isBackfilled
    }
}
