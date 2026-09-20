import Foundation
import SwiftData
import PETModels

@MainActor
public final class AssetRepository {
    private let context: ModelContext

    public init(context: ModelContext) {
        self.context = context
    }

    public func fetchAll() throws -> [Asset] {
        var descriptor = FetchDescriptor<Asset>()
        descriptor.sortBy = [SortDescriptor(\.name)]
        return try context.fetch(descriptor)
    }

    @discardableResult
    public func create(
        name: String,
        ticker: String?,
        assetType: AssetType,
        accountOrLocation: String?,
        quantity: Decimal,
        unit: String,
        purityPerMille: Int?,
        acquisitionDate: Date?,
        notes: String?
    ) throws -> Asset {
        let asset = Asset(
            name: name.trimmingCharacters(in: .whitespacesAndNewlines),
            ticker: ticker?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty,
            assetType: assetType,
            accountOrLocation: accountOrLocation?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty,
            quantity: quantity,
            unit: unit.trimmingCharacters(in: .whitespacesAndNewlines),
            purityPerMille: purityPerMille,
            acquisitionDate: acquisitionDate,
            notes: notes?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
        )
        context.insert(asset)
        try context.save()
        return asset
    }

    public func update(
        _ asset: Asset,
        name: String,
        ticker: String?,
        assetType: AssetType,
        accountOrLocation: String?,
        quantity: Decimal,
        unit: String,
        purityPerMille: Int?,
        acquisitionDate: Date?,
        notes: String?
    ) throws {
        asset.name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        asset.ticker = ticker?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
        asset.assetType = assetType
        asset.accountOrLocation = accountOrLocation?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
        asset.quantity = quantity
        asset.unit = unit.trimmingCharacters(in: .whitespacesAndNewlines)
        asset.purityPerMille = purityPerMille
        asset.acquisitionDate = acquisitionDate
        asset.notes = notes?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
        asset.modifiedAt = .now
        try context.save()
    }

    public func delete(_ asset: Asset) throws {
        context.delete(asset)
        try context.save()
    }

    /// One-time, idempotent carry-forward of pre-existing `Holding` rows (from the cancelled Net
    /// Worth prototype) into the new `Asset` model, so real data already entered through that
    /// now-deleted UI doesn't just vanish. Lives here as ordinary application code, mirroring
    /// `CategoryRepository.seedDefaultCategoriesIfNeeded()`, rather than inside
    /// `PETMigrationPlan` itself — this codebase has no precedent for a custom migration stage,
    /// and this idempotent-seed pattern is already proven and simpler to test. Only carries
    /// forward the fields the new model actually has (name/type/quantity/unit/purity/acquisition
    /// date) — cost-basis/currency/fee fields on the old `Holding` are dropped, per the explicit
    /// product decision that valuation data is out of scope now.
    @discardableResult
    public func migrateLegacyHoldingsIfNeeded() throws -> [Asset] {
        guard try fetchAll().isEmpty else { return [] }

        let legacyHoldings = try context.fetch(FetchDescriptor<Holding>())
        guard !legacyHoldings.isEmpty else { return [] }

        let migrated = legacyHoldings.map { holding -> Asset in
            Asset(
                name: holding.displayName ?? holding.ticker
                    ?? (holding.assetType == .physicalGold ? "Physical Gold" : "Untitled Asset"),
                ticker: holding.ticker,
                assetType: holding.assetType == .physicalGold ? .physicalGold : .usStock,
                accountOrLocation: holding.account?.name,
                quantity: holding.quantity,
                unit: holding.assetType == .physicalGold ? "grams" : "shares",
                purityPerMille: holding.purityPerMille,
                acquisitionDate: holding.firstPurchaseDate,
                notes: holding.notes
            )
        }
        migrated.forEach { context.insert($0) }
        try context.save()
        return migrated
    }
}

private extension String {
    var nilIfEmpty: String? { isEmpty ? nil : self }
}
