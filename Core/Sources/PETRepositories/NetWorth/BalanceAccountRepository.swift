import Foundation
import SwiftData
import PETModels

@MainActor
public final class BalanceAccountRepository {
    private let context: ModelContext

    public init(context: ModelContext) {
        self.context = context
    }

    public func fetchAll() throws -> [BalanceAccount] {
        var descriptor = FetchDescriptor<BalanceAccount>()
        descriptor.sortBy = [SortDescriptor(\.name)]
        return try context.fetch(descriptor)
    }

    @discardableResult
    public func create(
        name: String,
        kind: BalanceAccountKind,
        currencyCode: String = "EUR",
        initialBalance: Decimal? = nil,
        asOfDate: Date = .now
    ) throws -> BalanceAccount {
        let account = BalanceAccount(name: name.trimmingCharacters(in: .whitespacesAndNewlines), kind: kind, currencyCode: currencyCode)
        context.insert(account)
        if let initialBalance {
            let snapshot = BalanceSnapshot(amount: initialBalance, asOfDate: asOfDate, account: account)
            context.insert(snapshot)
        }
        try context.save()
        return account
    }

    /// Cash/liability balances have no API — the user types the number, timestamped,
    /// and it holds until the next snapshot.
    @discardableResult
    public func recordSnapshot(
        for account: BalanceAccount,
        amount: Decimal,
        asOfDate: Date = .now,
        notes: String? = nil
    ) throws -> BalanceSnapshot {
        let snapshot = BalanceSnapshot(amount: amount, asOfDate: asOfDate, notes: notes, account: account)
        context.insert(snapshot)
        try context.save()
        return snapshot
    }

    public func rename(_ account: BalanceAccount, to newName: String) throws {
        account.name = newName.trimmingCharacters(in: .whitespacesAndNewlines)
        try context.save()
    }

    public func archive(_ account: BalanceAccount) throws {
        account.isArchived = true
        try context.save()
    }

    public func delete(_ account: BalanceAccount) throws {
        context.delete(account)
        try context.save()
    }
}
