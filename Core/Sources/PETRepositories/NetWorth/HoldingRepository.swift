import Foundation
import SwiftData
import PETModels

public enum HoldingRepositoryError: Error, LocalizedError, Equatable {
    case invalidQuantity
    case insufficientQuantity

    public var errorDescription: String? {
        switch self {
        case .invalidQuantity:
            "Quantity must be greater than zero."
        case .insufficientQuantity:
            "Cannot sell more than the currently held quantity."
        }
    }
}

/// `quantity`/`averageCostPerUnit` must only ever be mutated through `recordBuy`/`recordSell`
/// below — never by a plain field edit — so every change stays paired with an audited
/// `HoldingActivity` row. This mirrors `TransactionRepository` being the only path that
/// mutates `ExpenseTransaction.amount`.
@MainActor
public final class HoldingRepository {
    private let context: ModelContext

    public init(context: ModelContext) {
        self.context = context
    }

    public func fetchAll() throws -> [Holding] {
        var descriptor = FetchDescriptor<Holding>()
        descriptor.sortBy = [SortDescriptor(\.createdAt, order: .reverse)]
        return try context.fetch(descriptor)
    }

    /// Creates a new holding from its first buy — every holding starts with a `HoldingActivity`
    /// audit row, there is no "just a holding with no history" state.
    @discardableResult
    public func createHolding(
        assetType: HoldingAssetType,
        ticker: String?,
        displayName: String?,
        initialQuantity: Decimal,
        purityPerMille: Int?,
        pricePerUnit: Decimal,
        purchaseCurrencyCode: String,
        purchaseDate: Date?,
        fee: Decimal = 0,
        account: InvestmentAccount?,
        notes: String?
    ) throws -> Holding {
        guard initialQuantity > 0 else { throw HoldingRepositoryError.invalidQuantity }

        let holding = Holding(
            assetType: assetType,
            ticker: ticker?.trimmingCharacters(in: .whitespacesAndNewlines).uppercased().nilIfEmpty,
            displayName: displayName?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty,
            quantity: initialQuantity,
            purityPerMille: purityPerMille,
            averageCostPerUnit: pricePerUnit,
            purchaseCurrencyCode: purchaseCurrencyCode,
            firstPurchaseDate: purchaseDate,
            notes: notes?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty,
            account: account
        )
        context.insert(holding)

        let activity = HoldingActivity(
            activityType: .buy,
            date: purchaseDate ?? .now,
            quantity: initialQuantity,
            pricePerUnit: pricePerUnit,
            currencyCode: purchaseCurrencyCode,
            feeAmount: fee,
            resultingQuantity: initialQuantity,
            resultingAverageCost: pricePerUnit,
            holding: holding
        )
        context.insert(activity)
        try context.save()
        return holding
    }

    /// A buy always recomputes the weighted average cost; it never changes anything else about
    /// prior activity rows, which stay a true append-only audit trail.
    @discardableResult
    public func recordBuy(
        _ holding: Holding,
        quantity: Decimal,
        pricePerUnit: Decimal,
        currencyCode: String,
        fee: Decimal = 0,
        date: Date = .now
    ) throws -> HoldingActivity {
        guard quantity > 0 else { throw HoldingRepositoryError.invalidQuantity }

        let existingQuantity = holding.quantity
        let newQuantity = existingQuantity + quantity
        let newAverageCost = ((holding.averageCostPerUnit * existingQuantity) + (pricePerUnit * quantity)) / newQuantity

        holding.quantity = newQuantity
        holding.averageCostPerUnit = newAverageCost
        holding.modifiedAt = .now
        if holding.firstPurchaseDate == nil {
            holding.firstPurchaseDate = date
        }

        let activity = HoldingActivity(
            activityType: .buy,
            date: date,
            quantity: quantity,
            pricePerUnit: pricePerUnit,
            currencyCode: currencyCode,
            feeAmount: fee,
            resultingQuantity: newQuantity,
            resultingAverageCost: newAverageCost,
            holding: holding
        )
        context.insert(activity)
        try context.save()
        return activity
    }

    /// A sell never changes `averageCostPerUnit` — only a buy does, per standard average-cost
    /// accounting. Realized gain here is computed against the current average cost in the
    /// holding's own purchase currency, **not yet converted to EUR** (there is no FX pipeline
    /// until Phase 12) — this is a deliberate, documented approximation for this phase; see
    /// Known Issues in CLAUDE.md. Auto-archives the holding once its quantity reaches zero.
    @discardableResult
    public func recordSell(
        _ holding: Holding,
        quantity: Decimal,
        pricePerUnit: Decimal,
        currencyCode: String,
        fee: Decimal = 0,
        date: Date = .now
    ) throws -> HoldingActivity {
        guard quantity > 0 else { throw HoldingRepositoryError.invalidQuantity }
        guard quantity <= holding.quantity else { throw HoldingRepositoryError.insufficientQuantity }

        let averageCost = holding.averageCostPerUnit
        let realizedGain = (pricePerUnit - averageCost) * quantity
        let newQuantity = holding.quantity - quantity

        holding.quantity = newQuantity
        holding.soldQuantity += quantity
        holding.realizedGainEUR += realizedGain
        holding.modifiedAt = .now
        if newQuantity == 0 {
            holding.isArchived = true
        }

        let activity = HoldingActivity(
            activityType: .sell,
            date: date,
            quantity: quantity,
            pricePerUnit: pricePerUnit,
            currencyCode: currencyCode,
            feeAmount: fee,
            resultingQuantity: newQuantity,
            resultingAverageCost: averageCost,
            realizedGainEUR: realizedGain,
            holding: holding
        )
        context.insert(activity)
        try context.save()
        return activity
    }

    public func recordFee(
        _ holding: Holding,
        amount: Decimal,
        currencyCode: String,
        date: Date = .now,
        notes: String? = nil
    ) throws {
        holding.totalFeesPaidEUR += amount
        holding.modifiedAt = .now

        let activity = HoldingActivity(
            activityType: .feeOnly,
            date: date,
            currencyCode: currencyCode,
            feeAmount: amount,
            resultingQuantity: holding.quantity,
            resultingAverageCost: holding.averageCostPerUnit,
            notes: notes,
            holding: holding
        )
        context.insert(activity)
        try context.save()
    }

    /// Metadata-only edit — deliberately cannot touch `quantity`/`averageCostPerUnit`.
    public func editMetadata(
        _ holding: Holding,
        displayName: String?,
        notes: String?,
        account: InvestmentAccount?
    ) throws {
        holding.displayName = displayName?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
        holding.notes = notes?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
        holding.account = account
        holding.modifiedAt = .now
        try context.save()
    }

    /// The always-available, zero-network fallback price (usable even after live quotes exist,
    /// e.g. for a ticker a market-data provider doesn't cover).
    public func setManualPrice(_ holding: Holding, pricePerUnit: Decimal, asOf: Date = .now) throws {
        holding.manualCurrentPricePerUnit = pricePerUnit
        holding.manualCurrentPriceAsOf = asOf
        holding.modifiedAt = .now
        try context.save()
    }

    public func archive(_ holding: Holding) throws {
        holding.isArchived = true
        holding.modifiedAt = .now
        try context.save()
    }

    public func delete(_ holding: Holding) throws {
        context.delete(holding)
        try context.save()
    }
}

private extension String {
    var nilIfEmpty: String? { isEmpty ? nil : self }
}
