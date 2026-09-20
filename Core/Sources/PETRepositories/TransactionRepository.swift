import Foundation
import SwiftData
import PETModels

@MainActor
public final class TransactionRepository {
    private let context: ModelContext

    public init(context: ModelContext) {
        self.context = context
    }

    public func fetchAll(sortedByDateDescending: Bool = true) throws -> [ExpenseTransaction] {
        var descriptor = FetchDescriptor<ExpenseTransaction>()
        descriptor.sortBy = [SortDescriptor(\.bookingDate, order: sortedByDateDescending ? .reverse : .forward)]
        return try context.fetch(descriptor)
    }

    @discardableResult
    public func createManualTransaction(
        date: Date,
        magnitude: Decimal,
        type: TransactionType,
        merchant: String,
        notes: String?,
        category: ExpenseCategory?,
        isRecurring: Bool
    ) throws -> ExpenseTransaction {
        let trimmedMerchant = merchant.trimmingCharacters(in: .whitespacesAndNewlines)
        let transaction = ExpenseTransaction(
            bookingDate: date,
            amount: Self.signedAmount(magnitude: magnitude, type: type),
            type: type,
            merchant: trimmedMerchant,
            rawDescription: trimmedMerchant,
            notes: notes?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty,
            isRecurring: isRecurring,
            source: .manual,
            category: category
        )
        context.insert(transaction)
        try context.save()
        if let category {
            try MerchantRuleRepository(context: context).recordUserCorrection(merchant: trimmedMerchant, category: category)
        }
        return transaction
    }

    public func update(
        _ transaction: ExpenseTransaction,
        date: Date,
        magnitude: Decimal,
        type: TransactionType,
        merchant: String,
        notes: String?,
        category: ExpenseCategory?,
        isRecurring: Bool
    ) throws {
        transaction.bookingDate = date
        transaction.amount = Self.signedAmount(magnitude: magnitude, type: type)
        transaction.type = type
        transaction.merchant = merchant.trimmingCharacters(in: .whitespacesAndNewlines)
        transaction.notes = notes?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
        transaction.category = category
        transaction.isRecurring = isRecurring
        transaction.modifiedAt = .now
        try context.save()
        if let category {
            try MerchantRuleRepository(context: context).recordUserCorrection(merchant: transaction.merchant, category: category)
        }
    }

    public func delete(_ transaction: ExpenseTransaction) throws {
        context.delete(transaction)
        try context.save()
    }

    private static func signedAmount(magnitude: Decimal, type: TransactionType) -> Decimal {
        let absolute = abs(magnitude)
        switch type {
        case .expense, .transfer:
            return -absolute
        case .income:
            return absolute
        }
    }
}

private extension String {
    var nilIfEmpty: String? { isEmpty ? nil : self }
}
