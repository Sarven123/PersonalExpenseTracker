import Foundation
import SwiftData

/// Cache and historical-backfill store for equity/ETF prices, one row per
/// `(ticker, priceDate)`. Uniqueness on that pair is enforced in repository code
/// before insert, not via a schema constraint — SwiftData doesn't cleanly support
/// compound unique attributes, mirroring how `ExpenseTransaction.dedupeHash`
/// already handles logical dedup in code rather than at the schema layer.
@Model
public final class SecurityPricePoint {
    @Attribute(.unique) public var id: UUID
    public var ticker: String
    public var priceDate: Date
    public var closePrice: Decimal
    /// Always USD for US-listed equities/ETFs.
    public var currencyCode: String
    public var fetchedAt: Date
    public var source: String
    public var isBackfilled: Bool

    public init(
        id: UUID = UUID(),
        ticker: String,
        priceDate: Date,
        closePrice: Decimal,
        currencyCode: String = "USD",
        fetchedAt: Date = .now,
        source: String,
        isBackfilled: Bool = false
    ) {
        self.id = id
        self.ticker = ticker
        self.priceDate = priceDate
        self.closePrice = closePrice
        self.currencyCode = currencyCode
        self.fetchedAt = fetchedAt
        self.source = source
        self.isBackfilled = isBackfilled
    }
}
