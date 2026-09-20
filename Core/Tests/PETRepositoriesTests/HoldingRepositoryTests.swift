import Foundation
import SwiftData
import Testing
import PETModels
@testable import PETRepositories

@Suite("HoldingRepository")
struct HoldingRepositoryTests {
    @MainActor
    private func makeContainer() -> ModelContainer {
        ModelContainerFactory.makeInMemoryContainer()
    }

    @Test("Creating a holding also appends its first buy activity")
    @MainActor
    func createHoldingAppendsBuyActivity() throws {
        let container = makeContainer()
        let repository = HoldingRepository(context: container.mainContext)
        let holding = try repository.createHolding(
            assetType: .usEquity,
            ticker: "aapl",
            displayName: "Apple Inc.",
            initialQuantity: 10,
            purityPerMille: nil,
            pricePerUnit: 150,
            purchaseCurrencyCode: "USD",
            purchaseDate: nil,
            account: nil,
            notes: nil
        )
        #expect(holding.ticker == "AAPL")
        #expect(holding.quantity == 10)
        #expect(holding.averageCostPerUnit == 150)
        #expect(holding.activities?.count == 1)
        #expect(holding.activities?.first?.activityType == .buy)
    }

    @Test("A second buy recomputes a weighted average cost")
    @MainActor
    func buyRecomputesWeightedAverageCost() throws {
        let container = makeContainer()
        let repository = HoldingRepository(context: container.mainContext)
        let holding = try repository.createHolding(
            assetType: .usEquity,
            ticker: "MSFT",
            displayName: nil,
            initialQuantity: 10,
            purityPerMille: nil,
            pricePerUnit: 100,
            purchaseCurrencyCode: "USD",
            purchaseDate: nil,
            account: nil,
            notes: nil
        )
        try repository.recordBuy(holding, quantity: 10, pricePerUnit: 200, currencyCode: "USD")

        #expect(holding.quantity == 20)
        // (10*100 + 10*200) / 20 == 150
        #expect(holding.averageCostPerUnit == 150)
        #expect(holding.activities?.count == 2)
    }

    @Test("A sell leaves average cost unchanged and records an approximate realized gain")
    @MainActor
    func sellLeavesAverageCostUnchanged() throws {
        let container = makeContainer()
        let repository = HoldingRepository(context: container.mainContext)
        let holding = try repository.createHolding(
            assetType: .usEquity,
            ticker: "MSFT",
            displayName: nil,
            initialQuantity: 10,
            purityPerMille: nil,
            pricePerUnit: 100,
            purchaseCurrencyCode: "USD",
            purchaseDate: nil,
            account: nil,
            notes: nil
        )
        let activity = try repository.recordSell(holding, quantity: 4, pricePerUnit: 150, currencyCode: "USD")

        #expect(holding.quantity == 6)
        #expect(holding.averageCostPerUnit == 100)
        #expect(holding.soldQuantity == 4)
        // (150 - 100) * 4 == 200
        #expect(holding.realizedGainEUR == 200)
        #expect(activity.resultingQuantity == 6)
        #expect(activity.resultingAverageCost == 100)
    }

    @Test("Selling the full quantity auto-archives the holding")
    @MainActor
    func sellingFullQuantityArchives() throws {
        let container = makeContainer()
        let repository = HoldingRepository(context: container.mainContext)
        let holding = try repository.createHolding(
            assetType: .usEquity,
            ticker: "MSFT",
            displayName: nil,
            initialQuantity: 5,
            purityPerMille: nil,
            pricePerUnit: 100,
            purchaseCurrencyCode: "USD",
            purchaseDate: nil,
            account: nil,
            notes: nil
        )
        try repository.recordSell(holding, quantity: 5, pricePerUnit: 120, currencyCode: "USD")

        #expect(holding.quantity == 0)
        #expect(holding.isArchived == true)
    }

    @Test("Selling more than the held quantity throws")
    @MainActor
    func sellingTooMuchThrows() throws {
        let container = makeContainer()
        let repository = HoldingRepository(context: container.mainContext)
        let holding = try repository.createHolding(
            assetType: .usEquity,
            ticker: "MSFT",
            displayName: nil,
            initialQuantity: 5,
            purityPerMille: nil,
            pricePerUnit: 100,
            purchaseCurrencyCode: "USD",
            purchaseDate: nil,
            account: nil,
            notes: nil
        )
        #expect(throws: HoldingRepositoryError.insufficientQuantity) {
            try repository.recordSell(holding, quantity: 6, pricePerUnit: 120, currencyCode: "USD")
        }
    }

    @Test("Zero or negative quantity is rejected on buy, sell, and create")
    @MainActor
    func rejectsNonPositiveQuantity() throws {
        let container = makeContainer()
        let repository = HoldingRepository(context: container.mainContext)
        #expect(throws: HoldingRepositoryError.invalidQuantity) {
            try repository.createHolding(
                assetType: .usEquity, ticker: "X", displayName: nil, initialQuantity: 0,
                purityPerMille: nil, pricePerUnit: 10, purchaseCurrencyCode: "USD",
                purchaseDate: nil, account: nil, notes: nil
            )
        }

        let holding = try repository.createHolding(
            assetType: .usEquity, ticker: "X", displayName: nil, initialQuantity: 5,
            purityPerMille: nil, pricePerUnit: 10, purchaseCurrencyCode: "USD",
            purchaseDate: nil, account: nil, notes: nil
        )
        #expect(throws: HoldingRepositoryError.invalidQuantity) {
            try repository.recordBuy(holding, quantity: -1, pricePerUnit: 10, currencyCode: "USD")
        }
        #expect(throws: HoldingRepositoryError.invalidQuantity) {
            try repository.recordSell(holding, quantity: 0, pricePerUnit: 10, currencyCode: "USD")
        }
    }

    @Test("Physical gold holding stores grams and purity, with no ticker")
    @MainActor
    func physicalGoldHoldingCreation() throws {
        let container = makeContainer()
        let repository = HoldingRepository(context: container.mainContext)
        let gold = try repository.createHolding(
            assetType: .physicalGold,
            ticker: nil,
            displayName: "Physical Gold",
            initialQuantity: 11,
            purityPerMille: 995,
            pricePerUnit: 55,
            purchaseCurrencyCode: "EUR",
            purchaseDate: nil,
            account: nil,
            notes: nil
        )
        #expect(gold.ticker == nil)
        #expect(gold.purityPerMille == 995)
        #expect(gold.quantity == 11)
    }

    @Test("Metadata edit never touches quantity or average cost")
    @MainActor
    func metadataEditIsIsolatedFromAccounting() throws {
        let container = makeContainer()
        let repository = HoldingRepository(context: container.mainContext)
        let holding = try repository.createHolding(
            assetType: .usEquity, ticker: "MSFT", displayName: nil, initialQuantity: 5,
            purityPerMille: nil, pricePerUnit: 100, purchaseCurrencyCode: "USD",
            purchaseDate: nil, account: nil, notes: nil
        )
        try repository.editMetadata(holding, displayName: "Microsoft Corp.", notes: "Long-term hold", account: nil)

        #expect(holding.displayName == "Microsoft Corp.")
        #expect(holding.notes == "Long-term hold")
        #expect(holding.quantity == 5)
        #expect(holding.averageCostPerUnit == 100)
    }

    @Test("Setting a manual price stamps its as-of date")
    @MainActor
    func manualPriceIsStamped() throws {
        let container = makeContainer()
        let repository = HoldingRepository(context: container.mainContext)
        let holding = try repository.createHolding(
            assetType: .usEquity, ticker: "MSFT", displayName: nil, initialQuantity: 5,
            purityPerMille: nil, pricePerUnit: 100, purchaseCurrencyCode: "USD",
            purchaseDate: nil, account: nil, notes: nil
        )
        let asOf = Date(timeIntervalSince1970: 1_700_000_000)
        try repository.setManualPrice(holding, pricePerUnit: 175, asOf: asOf)

        #expect(holding.manualCurrentPricePerUnit == 175)
        #expect(holding.manualCurrentPriceAsOf == asOf)
    }

    @Test("Recording a fee updates the running total without touching quantity")
    @MainActor
    func recordFeeUpdatesRunningTotal() throws {
        let container = makeContainer()
        let repository = HoldingRepository(context: container.mainContext)
        let holding = try repository.createHolding(
            assetType: .usEquity, ticker: "MSFT", displayName: nil, initialQuantity: 5,
            purityPerMille: nil, pricePerUnit: 100, purchaseCurrencyCode: "USD",
            purchaseDate: nil, account: nil, notes: nil
        )
        try repository.recordFee(holding, amount: 4.95, currencyCode: "USD")

        #expect(holding.totalFeesPaidEUR == Decimal(4.95))
        #expect(holding.quantity == 5)
        #expect(holding.activities?.count == 2)
    }
}
