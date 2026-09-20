import SwiftData

/// A retroactive label on the schema shape this app has shipped since Phase 1 —
/// the exact same five model types, unmodified. This is not a new shape; it exists
/// only so `SchemaV2` (the Net Worth feature's additive schema) has something
/// explicit to migrate from.
public enum SchemaV1: VersionedSchema {
    public static var versionIdentifier: Schema.Version { Schema.Version(1, 0, 0) }

    public static var models: [any PersistentModel.Type] {
        [
            ExpenseCategory.self,
            ExpenseTransaction.self,
            MerchantRule.self,
            ImportBatch.self,
            RecurringSchedule.self,
        ]
    }
}
