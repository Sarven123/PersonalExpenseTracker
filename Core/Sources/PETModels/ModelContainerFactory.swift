import Foundation
import SwiftData

public enum ModelContainerFactory {
    public static var schema: Schema {
        Schema(SchemaV3.models)
    }

    public static func makeLiveContainer() -> ModelContainer {
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
        do {
            return try ModelContainer(for: schema, migrationPlan: PETMigrationPlan.self, configurations: [configuration])
        } catch {
            fatalError("Failed to create ModelContainer: \(error)")
        }
    }

    public static func makeInMemoryContainer() -> ModelContainer {
        // Each call gets its own uniquely-named configuration so concurrently-created
        // in-memory containers (e.g. from parallel test execution) never collide.
        // There is no prior store to migrate from in-memory, but passing the same
        // migration plan keeps schema resolution identical to the live container.
        let configuration = ModelConfiguration(
            "in-memory-\(UUID().uuidString)",
            schema: schema,
            isStoredInMemoryOnly: true
        )
        do {
            return try ModelContainer(for: schema, migrationPlan: PETMigrationPlan.self, configurations: [configuration])
        } catch {
            fatalError("Failed to create in-memory ModelContainer: \(error)")
        }
    }

    @MainActor
    public static var previewContainer: ModelContainer {
        makeInMemoryContainer()
    }
}
