import Foundation
import SwiftData
import PETModels

@MainActor
public final class InvestmentAccountRepository {
    private let context: ModelContext

    public init(context: ModelContext) {
        self.context = context
    }

    public func fetchAll() throws -> [InvestmentAccount] {
        var descriptor = FetchDescriptor<InvestmentAccount>()
        descriptor.sortBy = [SortDescriptor(\.name)]
        return try context.fetch(descriptor)
    }

    @discardableResult
    public func create(name: String, notes: String? = nil) throws -> InvestmentAccount {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let account = InvestmentAccount(name: trimmed, notes: notes?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty)
        context.insert(account)
        try context.save()
        return account
    }

    public func rename(_ account: InvestmentAccount, to newName: String) throws {
        account.name = newName.trimmingCharacters(in: .whitespacesAndNewlines)
        try context.save()
    }

    public func archive(_ account: InvestmentAccount) throws {
        account.isArchived = true
        try context.save()
    }

    /// Holdings are `.nullify`'d, not cascade-deleted, per this app's convention of never
    /// cascade-deleting financial data — a holding whose account is deleted just loses its
    /// account label, it doesn't disappear.
    public func delete(_ account: InvestmentAccount) throws {
        context.delete(account)
        try context.save()
    }
}

private extension String {
    var nilIfEmpty: String? { isEmpty ? nil : self }
}
