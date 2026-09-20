import Foundation
import SwiftData
import Testing
@testable import PETModels

@Suite("Net Worth models")
struct NetWorthModelsTests {
    @Test("Holding persists and links to its account")
    @MainActor
    func holdingAccountRelationship() throws {
        let container = ModelContainerFactory.makeInMemoryContainer()
        let context = container.mainContext

        let account = InvestmentAccount(name: "Midas")
        let holding = Holding(
            assetType: .usEquity,
            ticker: "AAPL",
            quantity: 10,
            averageCostPerUnit: 150,
            purchaseCurrencyCode: "USD",
            account: account
        )
        context.insert(account)
        context.insert(holding)
        try context.save()

        let results = try context.fetch(FetchDescriptor<Holding>())
        #expect(results.first?.account?.name == "Midas")
        #expect(account.holdings?.count == 1)
    }

    @Test("Physical gold holding stores purity and grams, never a ticker")
    @MainActor
    func physicalGoldHolding() throws {
        let container = ModelContainerFactory.makeInMemoryContainer()
        let context = container.mainContext

        let gold = Holding(
            assetType: .physicalGold,
            quantity: 11,
            purityPerMille: 995,
            averageCostPerUnit: 55,
            purchaseCurrencyCode: "EUR"
        )
        context.insert(gold)
        try context.save()

        let results = try context.fetch(FetchDescriptor<Holding>())
        #expect(results.first?.purityPerMille == 995)
        #expect(results.first?.quantity == 11)
        #expect(results.first?.ticker == nil)
    }

    @Test("HoldingActivity records a sell against a holding with a resulting-state snapshot")
    @MainActor
    func holdingActivitySellRecord() throws {
        let container = ModelContainerFactory.makeInMemoryContainer()
        let context = container.mainContext

        let holding = Holding(
            assetType: .usEquity,
            ticker: "MSFT",
            quantity: 5,
            averageCostPerUnit: 300,
            purchaseCurrencyCode: "USD"
        )
        let activity = HoldingActivity(
            activityType: .sell,
            quantity: 2,
            pricePerUnit: 350,
            currencyCode: "USD",
            resultingQuantity: 3,
            resultingAverageCost: 300,
            realizedGainEUR: 90,
            holding: holding
        )
        context.insert(holding)
        context.insert(activity)
        try context.save()

        let results = try context.fetch(FetchDescriptor<HoldingActivity>())
        #expect(results.first?.holding?.ticker == "MSFT")
        #expect(results.first?.resultingQuantity == 3)
        #expect(results.first?.realizedGainEUR == 90)
    }

    @Test("BalanceAccount tracks cash and liability kinds with snapshots")
    @MainActor
    func balanceAccountSnapshots() throws {
        let container = ModelContainerFactory.makeInMemoryContainer()
        let context = container.mainContext

        let cash = BalanceAccount(name: "Cash Wallet", kind: .cash)
        let snapshot = BalanceSnapshot(amount: 500, account: cash)
        context.insert(cash)
        context.insert(snapshot)
        try context.save()

        let results = try context.fetch(FetchDescriptor<BalanceAccount>())
        #expect(results.first?.kind == .cash)
        #expect(results.first?.snapshots?.count == 1)
    }

    @Test("Price/FX/gold cache points persist their source and currency")
    @MainActor
    func priceCachePoints() throws {
        let container = ModelContainerFactory.makeInMemoryContainer()
        let context = container.mainContext

        let price = SecurityPricePoint(ticker: "AAPL", priceDate: .now, closePrice: 190, source: "alphavantage")
        let fx = FXRatePoint(baseCurrency: "USD", rateDate: .now, rate: 0.92, source: "frankfurter")
        let gold = GoldPricePoint(priceDate: .now, pricePerTroyOunce: 2400, source: "goldapi")
        context.insert(price)
        context.insert(fx)
        context.insert(gold)
        try context.save()

        #expect(try context.fetch(FetchDescriptor<SecurityPricePoint>()).count == 1)
        #expect(try context.fetch(FetchDescriptor<FXRatePoint>()).first?.quoteCurrency == "EUR")
        #expect(try context.fetch(FetchDescriptor<GoldPricePoint>()).first?.currencyCode == "USD")
    }
}
