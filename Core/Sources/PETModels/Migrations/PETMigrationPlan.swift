import SwiftData

/// This app's first-ever migration plan. SchemaV1 -> SchemaV2 is a pure addition
/// (eight new tables, nothing about the existing five models changes), which
/// qualifies for SwiftData's automatic lightweight migration — no custom
/// willMigrate/didMigrate stage is needed.
public enum PETMigrationPlan: SchemaMigrationPlan {
    public static var schemas: [any VersionedSchema.Type] {
        [SchemaV1.self, SchemaV2.self]
    }

    public static var stages: [MigrationStage] {
        [
            .lightweight(fromVersion: SchemaV1.self, toVersion: SchemaV2.self),
        ]
    }
}
