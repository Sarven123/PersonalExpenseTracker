import Foundation
import SwiftData
import Testing
@testable import PETModels

@Suite("SchemaV1 to SchemaV2 migration")
struct SchemaMigrationTests {
    @Test("Existing V1-shaped data survives migrating to V2's expanded schema")
    @MainActor
    func migratesExistingDataWithoutLoss() throws {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("schema-migration-test-\(UUID().uuidString).sqlite")
        defer { try? FileManager.default.removeItem(at: url) }

        // Step 1: create a store using only SchemaV1 (today's live shape, pre-Net-Worth) and seed it.
        do {
            let v1Schema = Schema(SchemaV1.models)
            let configuration = ModelConfiguration(schema: v1Schema, url: url)
            let container = try ModelContainer(for: v1Schema, configurations: [configuration])
            let context = container.mainContext

            let category = ExpenseCategory(name: "Food", colorHex: "#FF6B6B", symbolName: "fork.knife")
            context.insert(category)
            let transaction = ExpenseTransaction(
                bookingDate: .now,
                amount: Decimal(-12.34),
                type: .expense,
                merchant: "Test Merchant",
                rawDescription: "Test",
                source: .manual,
                category: category
            )
            context.insert(transaction)
            try context.save()
        }

        // Step 2: reopen the same on-disk store through the full migration plan (SchemaV2 + new tables).
        let v2Schema = Schema(SchemaV2.models)
        let configuration = ModelConfiguration(schema: v2Schema, url: url)
        let container = try ModelContainer(
            for: v2Schema,
            migrationPlan: PETMigrationPlan.self,
            configurations: [configuration]
        )
        let context = container.mainContext

        let categories = try context.fetch(FetchDescriptor<ExpenseCategory>())
        #expect(categories.count == 1)
        #expect(categories.first?.name == "Food")

        let transactions = try context.fetch(FetchDescriptor<ExpenseTransaction>())
        #expect(transactions.count == 1)
        #expect(transactions.first?.merchant == "Test Merchant")
        #expect(transactions.first?.category?.name == "Food")

        // New tables exist and are empty after a pure-addition migration.
        #expect(try context.fetch(FetchDescriptor<Holding>()).isEmpty)
        #expect(try context.fetch(FetchDescriptor<InvestmentAccount>()).isEmpty)
        #expect(try context.fetch(FetchDescriptor<BalanceAccount>()).isEmpty)
    }

    @Test("A real pre-existing Holding row survives migrating to SchemaV3 untouched")
    @MainActor
    func migratesV2HoldingDataWithoutLoss() throws {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("schema-migration-v2-v3-test-\(UUID().uuidString).sqlite")
        defer { try? FileManager.default.removeItem(at: url) }

        // Step 1: create a store using SchemaV2 (the shape shipped by Phase 9/10) and seed it with
        // the same kind of real-world row this app's live store was found to actually contain: a
        // physical-gold Holding, entered through the now-deleted Net Worth UI.
        do {
            let v2Schema = Schema(SchemaV2.models)
            let configuration = ModelConfiguration(schema: v2Schema, url: url)
            let container = try ModelContainer(for: v2Schema, configurations: [configuration])
            let context = container.mainContext

            let holding = Holding(
                assetType: .physicalGold,
                quantity: 11,
                purityPerMille: 995,
                averageCostPerUnit: 6000,
                purchaseCurrencyCode: "TL"
            )
            context.insert(holding)
            try context.save()
        }

        // Step 2: reopen the same on-disk store through the full migration plan (SchemaV3 + Asset).
        let v3Schema = Schema(SchemaV3.models)
        let configuration = ModelConfiguration(schema: v3Schema, url: url)
        let container = try ModelContainer(
            for: v3Schema,
            migrationPlan: PETMigrationPlan.self,
            configurations: [configuration]
        )
        let context = container.mainContext

        // The old Holding row is untouched — SchemaV3 keeps it in the schema, unused, rather than
        // dropping it.
        let holdings = try context.fetch(FetchDescriptor<Holding>())
        #expect(holdings.count == 1)
        #expect(holdings.first?.quantity == 11)
        #expect(holdings.first?.purityPerMille == 995)

        // The new Asset table exists and is empty — the migration itself is purely additive;
        // carrying the Holding forward into an Asset is a separate, idempotent application-code
        // step (`AssetRepository.migrateLegacyHoldingsIfNeeded()`), not part of this migration.
        #expect(try context.fetch(FetchDescriptor<Asset>()).isEmpty)
    }
}
