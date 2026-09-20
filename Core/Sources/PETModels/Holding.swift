import Foundation
import SwiftData

/// One row per ticker (or the single physical-gold instance) under average-cost
/// accounting. `quantity`/`averageCostPerUnit` must only ever be mutated via
/// `HoldingActivity`-recording repository methods (record a buy/sell), never
/// edited directly — mirrors how `TransactionRepository` is the only path that
/// mutates `ExpenseTransaction.amount`.
@Model
public final class Holding {
    @Attribute(.unique) public var id: UUID
    public var assetType: HoldingAssetType
    public var ticker: String?
    public var displayName: String?
    public var quantity: Decimal
    /// Purity in per-mille (995 for the tracked physical gold instance). Always nil for equities.
    public var purityPerMille: Int?
    public var averageCostPerUnit: Decimal
    public var purchaseCurrencyCode: String
    public var firstPurchaseDate: Date?
    public var totalFeesPaidEUR: Decimal
    /// Always-available zero-network fallback price, usable even after live quotes exist.
    public var manualCurrentPricePerUnit: Decimal?
    public var manualCurrentPriceAsOf: Date?
    public var soldQuantity: Decimal
    public var realizedGainEUR: Decimal
    public var isArchived: Bool
    public var notes: String?
    public var createdAt: Date
    public var modifiedAt: Date

    public var account: InvestmentAccount?

    @Relationship(deleteRule: .nullify, inverse: \HoldingActivity.holding)
    public var activities: [HoldingActivity]? = []

    public init(
        id: UUID = UUID(),
        assetType: HoldingAssetType,
        ticker: String? = nil,
        displayName: String? = nil,
        quantity: Decimal,
        purityPerMille: Int? = nil,
        averageCostPerUnit: Decimal,
        purchaseCurrencyCode: String,
        firstPurchaseDate: Date? = nil,
        totalFeesPaidEUR: Decimal = 0,
        manualCurrentPricePerUnit: Decimal? = nil,
        manualCurrentPriceAsOf: Date? = nil,
        soldQuantity: Decimal = 0,
        realizedGainEUR: Decimal = 0,
        isArchived: Bool = false,
        notes: String? = nil,
        createdAt: Date = .now,
        modifiedAt: Date = .now,
        account: InvestmentAccount? = nil
    ) {
        self.id = id
        self.assetType = assetType
        self.ticker = ticker
        self.displayName = displayName
        self.quantity = quantity
        self.purityPerMille = purityPerMille
        self.averageCostPerUnit = averageCostPerUnit
        self.purchaseCurrencyCode = purchaseCurrencyCode
        self.firstPurchaseDate = firstPurchaseDate
        self.totalFeesPaidEUR = totalFeesPaidEUR
        self.manualCurrentPricePerUnit = manualCurrentPricePerUnit
        self.manualCurrentPriceAsOf = manualCurrentPriceAsOf
        self.soldQuantity = soldQuantity
        self.realizedGainEUR = realizedGainEUR
        self.isArchived = isArchived
        self.notes = notes
        self.createdAt = createdAt
        self.modifiedAt = modifiedAt
        self.account = account
    }
}
