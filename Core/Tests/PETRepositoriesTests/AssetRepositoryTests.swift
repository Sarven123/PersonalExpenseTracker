import Foundation
import SwiftData
import Testing
import PETModels
@testable import PETRepositories

@Suite("AssetRepository")
struct AssetRepositoryTests {
    @MainActor
    private func makeContainer() -> ModelContainer {
        ModelContainerFactory.makeInMemoryContainer()
    }

    @Test("Create trims fields and persists")
    @MainActor
    func createTrimsAndPersists() throws {
        let container = makeContainer()
        let repository = AssetRepository(context: container.mainContext)
        let asset = try repository.create(
            name: "  Apple Inc.  ",
            ticker: " AAPL ",
            assetType: .usStock,
            accountOrLocation: " Midas ",
            quantity: 10,
            unit: "shares",
            purityPerMille: nil,
            acquisitionDate: nil,
            notes: nil
        )

        #expect(asset.name == "Apple Inc.")
        #expect(asset.ticker == "AAPL")
        #expect(asset.accountOrLocation == "Midas")
        #expect(try repository.fetchAll().count == 1)
    }

    @Test("Physical gold asset stores purity and grams")
    @MainActor
    func physicalGoldAsset() throws {
        let container = makeContainer()
        let repository = AssetRepository(context: container.mainContext)
        let asset = try repository.create(
            name: "Physical Gold",
            ticker: nil,
            assetType: .physicalGold,
            accountOrLocation: "Physical Storage",
            quantity: 11,
            unit: "grams",
            purityPerMille: 995,
            acquisitionDate: nil,
            notes: nil
        )

        #expect(asset.assetType == .physicalGold)
        #expect(asset.purityPerMille == 995)
        #expect(asset.quantity == 11)
    }

    @Test("Update replaces every field, including clearing optionals")
    @MainActor
    func updateReplacesFields() throws {
        let container = makeContainer()
        let repository = AssetRepository(context: container.mainContext)
        let asset = try repository.create(
            name: "Cash",
            ticker: nil,
            assetType: .cash,
            accountOrLocation: "Wallet",
            quantity: 500,
            unit: "EUR",
            purityPerMille: nil,
            acquisitionDate: nil,
            notes: "Emergency fund"
        )

        try repository.update(
            asset,
            name: "Cash Savings",
            ticker: nil,
            assetType: .cash,
            accountOrLocation: nil,
            quantity: 600,
            unit: "EUR",
            purityPerMille: nil,
            acquisitionDate: nil,
            notes: nil
        )

        #expect(asset.name == "Cash Savings")
        #expect(asset.accountOrLocation == nil)
        #expect(asset.quantity == 600)
        #expect(asset.notes == nil)
    }

    @Test("Delete removes the asset")
    @MainActor
    func deleteRemovesAsset() throws {
        let container = makeContainer()
        let repository = AssetRepository(context: container.mainContext)
        let asset = try repository.create(
            name: "Other Item", ticker: nil, assetType: .other, accountOrLocation: nil,
            quantity: 1, unit: "item", purityPerMille: nil, acquisitionDate: nil, notes: nil
        )
        try repository.delete(asset)

        #expect(try repository.fetchAll().isEmpty)
    }

    @Test("Legacy holding carryover creates a matching Asset, dropping cost-basis fields")
    @MainActor
    func legacyHoldingCarryoverCreatesAsset() throws {
        let container = makeContainer()
        let context = container.mainContext

        let account = InvestmentAccount(name: "Midas")
        let holding = Holding(
            assetType: .physicalGold,
            displayName: "Physical Gold",
            quantity: 11,
            purityPerMille: 995,
            averageCostPerUnit: 6000,
            purchaseCurrencyCode: "TL",
            firstPurchaseDate: Date(timeIntervalSince1970: 1_758_000_000),
            notes: "Test note",
            account: account
        )
        context.insert(account)
        context.insert(holding)
        try context.save()

        let repository = AssetRepository(context: context)
        let migrated = try repository.migrateLegacyHoldingsIfNeeded()

        #expect(migrated.count == 1)
        let asset = try #require(migrated.first)
        #expect(asset.name == "Physical Gold")
        #expect(asset.assetType == .physicalGold)
        #expect(asset.quantity == 11)
        #expect(asset.unit == "grams")
        #expect(asset.purityPerMille == 995)
        #expect(asset.accountOrLocation == "Midas")
        #expect(asset.acquisitionDate == holding.firstPurchaseDate)
        #expect(asset.notes == "Test note")

        // The original Holding row is untouched — carryover copies, never deletes.
        #expect(try context.fetch(FetchDescriptor<Holding>()).count == 1)
    }

    @Test("Legacy holding carryover is idempotent — running it twice does not duplicate")
    @MainActor
    func legacyHoldingCarryoverIsIdempotent() throws {
        let container = makeContainer()
        let context = container.mainContext

        let holding = Holding(
            assetType: .physicalGold, quantity: 11, purityPerMille: 995,
            averageCostPerUnit: 6000, purchaseCurrencyCode: "TL"
        )
        context.insert(holding)
        try context.save()

        let repository = AssetRepository(context: context)
        try repository.migrateLegacyHoldingsIfNeeded()
        try repository.migrateLegacyHoldingsIfNeeded()

        #expect(try repository.fetchAll().count == 1)
    }

    @Test("Legacy holding carryover no-ops when a real Asset already exists")
    @MainActor
    func legacyHoldingCarryoverSkipsWhenAssetsExist() throws {
        let container = makeContainer()
        let context = container.mainContext

        let holding = Holding(
            assetType: .usEquity, ticker: "MSFT", quantity: 5,
            averageCostPerUnit: 300, purchaseCurrencyCode: "USD"
        )
        context.insert(holding)
        try context.save()

        let repository = AssetRepository(context: context)
        try repository.create(
            name: "Manually Added", ticker: nil, assetType: .other, accountOrLocation: nil,
            quantity: 1, unit: "item", purityPerMille: nil, acquisitionDate: nil, notes: nil
        )

        let migrated = try repository.migrateLegacyHoldingsIfNeeded()

        #expect(migrated.isEmpty)
        #expect(try repository.fetchAll().count == 1)
    }

    @Test("Legacy holding carryover no-ops when there are no legacy holdings")
    @MainActor
    func legacyHoldingCarryoverNoOpsWithoutHoldings() throws {
        let container = makeContainer()
        let repository = AssetRepository(context: container.mainContext)

        let migrated = try repository.migrateLegacyHoldingsIfNeeded()

        #expect(migrated.isEmpty)
        #expect(try repository.fetchAll().isEmpty)
    }
}
