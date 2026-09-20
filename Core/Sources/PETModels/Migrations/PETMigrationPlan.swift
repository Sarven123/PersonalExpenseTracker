import SwiftData

/// This app's migration plan. Every stage so far is a pure addition (SchemaV1 -> SchemaV2 added
/// the since-cancelled Net Worth models; SchemaV2 -> SchemaV3 adds the `Asset` model), which
/// qualifies for SwiftData's automatic lightweight migration — no custom willMigrate/didMigrate
/// stage has been needed yet. The one-time carry-forward of pre-existing `Holding` data into the
/// new `Asset` model happens in application code (`AssetRepository.migrateLegacyHoldingsIfNeeded()`),
/// not here — see that method's doc comment for why.
public enum PETMigrationPlan: SchemaMigrationPlan {
    public static var schemas: [any VersionedSchema.Type] {
        [SchemaV1.self, SchemaV2.self, SchemaV3.self]
    }

    public static var stages: [MigrationStage] {
        [
            .lightweight(fromVersion: SchemaV1.self, toVersion: SchemaV2.self),
            .lightweight(fromVersion: SchemaV2.self, toVersion: SchemaV3.self),
        ]
    }
}
