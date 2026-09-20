import SwiftData

/// SchemaV1's five expense-tracking models plus the eight new Net Worth models.
/// Purely additive — no existing model's attributes, types, or relationships change.
public enum SchemaV2: VersionedSchema {
    public static var versionIdentifier: Schema.Version { Schema.Version(2, 0, 0) }

    public static var models: [any PersistentModel.Type] {
        SchemaV1.models + [
            InvestmentAccount.self,
            Holding.self,
            HoldingActivity.self,
            BalanceAccount.self,
            BalanceSnapshot.self,
            SecurityPricePoint.self,
            FXRatePoint.self,
            GoldPricePoint.self,
        ]
    }
}
