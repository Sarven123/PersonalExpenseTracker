import Foundation
import SwiftData
import Testing
import PETModels
@testable import PETRepositories

@Suite("InvestmentAccountRepository")
struct InvestmentAccountRepositoryTests {
    @MainActor
    private func makeContainer() -> ModelContainer {
        ModelContainerFactory.makeInMemoryContainer()
    }

    @Test("Create trims whitespace and persists")
    @MainActor
    func createTrimsAndPersists() throws {
        let container = makeContainer()
        let repository = InvestmentAccountRepository(context: container.mainContext)
        let account = try repository.create(name: "  Midas  ")

        #expect(account.name == "Midas")
        #expect(try repository.fetchAll().count == 1)
    }

    @Test("Rename updates the name")
    @MainActor
    func renameUpdatesName() throws {
        let container = makeContainer()
        let repository = InvestmentAccountRepository(context: container.mainContext)
        let account = try repository.create(name: "Midas")
        try repository.rename(account, to: "Midas Brokerage")

        #expect(account.name == "Midas Brokerage")
    }

    @Test("Archive marks the account without deleting it")
    @MainActor
    func archiveMarksWithoutDeleting() throws {
        let container = makeContainer()
        let repository = InvestmentAccountRepository(context: container.mainContext)
        let account = try repository.create(name: "Old Broker")
        try repository.archive(account)

        #expect(account.isArchived == true)
        #expect(try repository.fetchAll().count == 1)
    }

    @Test("Deleting an account nullifies, not cascades, its holdings")
    @MainActor
    func deletingAccountNullifiesHoldings() throws {
        let container = makeContainer()
        let accountRepository = InvestmentAccountRepository(context: container.mainContext)
        let holdingRepository = HoldingRepository(context: container.mainContext)

        let account = try accountRepository.create(name: "Midas")
        let holding = try holdingRepository.createHolding(
            assetType: .usEquity, ticker: "AAPL", displayName: nil, initialQuantity: 1,
            purityPerMille: nil, pricePerUnit: 100, purchaseCurrencyCode: "USD",
            purchaseDate: nil, account: account, notes: nil
        )

        try accountRepository.delete(account)

        #expect(try accountRepository.fetchAll().isEmpty)
        #expect(try holdingRepository.fetchAll().count == 1)
        #expect(holding.account == nil)
    }
}
