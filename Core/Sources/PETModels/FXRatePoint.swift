import Foundation
import SwiftData

/// Cache/backfill store for FX rates. `quoteCurrency` is always "EUR" in
/// practice (the app's fixed reporting currency); `source` is never silently
/// mixed between providers for the same date — see the market-data layer's
/// "prefer Frankfurter, only fall back to Alpha Vantage FX if Frankfurter's
/// request itself fails" ordering.
@Model
public final class FXRatePoint {
    @Attribute(.unique) public var id: UUID
    public var baseCurrency: String
    public var quoteCurrency: String
    public var rateDate: Date
    public var rate: Decimal
    public var fetchedAt: Date
    public var source: String

    public init(
        id: UUID = UUID(),
        baseCurrency: String,
        quoteCurrency: String = "EUR",
        rateDate: Date,
        rate: Decimal,
        fetchedAt: Date = .now,
        source: String
    ) {
        self.id = id
        self.baseCurrency = baseCurrency
        self.quoteCurrency = quoteCurrency
        self.rateDate = rateDate
        self.rate = rate
        self.fetchedAt = fetchedAt
        self.source = source
    }
}
