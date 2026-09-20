import SwiftData

/// SchemaV2's thirteen models plus one new one, `Asset` — the entire schema footprint of the
/// simplified Assets-inventory feature that replaced the cancelled Net Worth/valuation roadmap.
/// The eight Net Worth models from SchemaV2 (`InvestmentAccount`, `Holding`, `HoldingActivity`,
/// `BalanceAccount`, `BalanceSnapshot`, `SecurityPricePoint`, `FXRatePoint`, `GoldPricePoint`)
/// are kept here, unused, rather than removed — see CLAUDE.md's Important Decisions for why a
/// schema-dropping migration was deliberately avoided.
public enum SchemaV3: VersionedSchema {
    public static var versionIdentifier: Schema.Version { Schema.Version(3, 0, 0) }

    public static var models: [any PersistentModel.Type] {
        SchemaV2.models + [
            Asset.self,
        ]
    }
}
