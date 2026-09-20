import Foundation
import SwiftData
import Testing
import PETModels
@testable import PETRepositories

@Suite("BalanceAccountRepository")
struct BalanceAccountRepositoryTests {
    @MainActor
    private func makeContainer() -> ModelContainer {
        ModelContainerFactory.makeInMemoryContainer()
    }

    @Test("Create with an initial balance also records a snapshot")
    @MainActor
    func createWithInitialBalanceRecordsSnapshot() throws {
        let container = makeContainer()
        let repository = BalanceAccountRepository(context: container.mainContext)
        let account = try repository.create(name: "Cash Wallet", kind: .cash, initialBalance: 500)

        #expect(account.kind == .cash)
        #expect(account.snapshots?.count == 1)
        #expect(account.snapshots?.first?.amount == 500)
    }

    @Test("Create without an initial balance records no snapshot")
    @MainActor
    func createWithoutInitialBalanceRecordsNoSnapshot() throws {
        let container = makeContainer()
        let repository = BalanceAccountRepository(context: container.mainContext)
        let account = try repository.create(name: "Car Loan", kind: .liability)

        #expect(account.snapshots?.isEmpty == true)
    }

    @Test("Recording a snapshot appends without replacing prior ones")
    @MainActor
    func recordingSnapshotAppends() throws {
        let container = makeContainer()
        let repository = BalanceAccountRepository(context: container.mainContext)
        let account = try repository.create(name: "Cash Wallet", kind: .cash, initialBalance: 500)
        try repository.recordSnapshot(for: account, amount: 600)

        #expect(account.snapshots?.count == 2)
    }

    @Test("Archive marks the account without deleting it")
    @MainActor
    func archiveMarksWithoutDeleting() throws {
        let container = makeContainer()
        let repository = BalanceAccountRepository(context: container.mainContext)
        let account = try repository.create(name: "Old Liability", kind: .liability)
        try repository.archive(account)

        #expect(account.isArchived == true)
        #expect(try repository.fetchAll().count == 1)
    }
}
