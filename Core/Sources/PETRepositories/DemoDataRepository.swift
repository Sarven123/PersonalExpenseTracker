import Foundation
import SwiftData
import PETModels

/// Inserts clearly-fictional sample transactions so a first-time user can see
/// what the Dashboard looks like with real data in it. **Never invoked
/// automatically** — only from an explicit "Load Demo Data" action in the
/// Dashboard's empty state, per the product requirement that demo data is
/// opt-in only. Bypasses `TransactionRepository` (inserts `ExpenseTransaction`s
/// directly) so these fictional merchant names never pollute the user's real
/// `MerchantRule` set.
@MainActor
public final class DemoDataRepository {
    private let context: ModelContext

    public init(context: ModelContext) {
        self.context = context
    }

    private struct DemoEntry {
        let daysAgo: Int
        let categoryName: String
        let merchant: String
        let amount: Decimal // signed; negative = expense, positive = income
    }

    private static let entries: [DemoEntry] = [
        .init(daysAgo: 58, categoryName: "Income", merchant: "Sample Employer", amount: 2500.00),
        .init(daysAgo: 28, categoryName: "Income", merchant: "Sample Employer", amount: 2500.00),

        .init(daysAgo: 55, categoryName: "Food", merchant: "Sample Supermarket", amount: -45.20),
        .init(daysAgo: 48, categoryName: "Food", merchant: "Sample Supermarket", amount: -38.90),
        .init(daysAgo: 41, categoryName: "Food", merchant: "Sample Supermarket", amount: -52.10),
        .init(daysAgo: 34, categoryName: "Food", merchant: "Sample Supermarket", amount: -33.75),
        .init(daysAgo: 27, categoryName: "Food", merchant: "Sample Supermarket", amount: -47.60),
        .init(daysAgo: 20, categoryName: "Food", merchant: "Sample Supermarket", amount: -41.15),
        .init(daysAgo: 13, categoryName: "Food", merchant: "Sample Supermarket", amount: -36.40),
        .init(daysAgo: 6, categoryName: "Food", merchant: "Sample Supermarket", amount: -49.80),

        .init(daysAgo: 58, categoryName: "Transport", merchant: "Sample Transit Pass", amount: -49.00),
        .init(daysAgo: 28, categoryName: "Transport", merchant: "Sample Transit Pass", amount: -49.00),

        .init(daysAgo: 45, categoryName: "Entertainment", merchant: "Sample Cinema", amount: -14.50),
        .init(daysAgo: 10, categoryName: "Entertainment", merchant: "Sample Cinema", amount: -14.50),

        .init(daysAgo: 58, categoryName: "Subscriptions", merchant: "Sample Streaming Service", amount: -9.99),
        .init(daysAgo: 28, categoryName: "Subscriptions", merchant: "Sample Streaming Service", amount: -9.99),
        .init(daysAgo: 1, categoryName: "Subscriptions", merchant: "Sample Streaming Service", amount: -9.99),

        .init(daysAgo: 58, categoryName: "Housing", merchant: "Sample Landlord", amount: -850.00),
        .init(daysAgo: 28, categoryName: "Housing", merchant: "Sample Landlord", amount: -850.00),

        .init(daysAgo: 50, categoryName: "Utilities", merchant: "Sample Power Co", amount: -62.30),
        .init(daysAgo: 20, categoryName: "Utilities", merchant: "Sample Power Co", amount: -58.90),

        .init(daysAgo: 33, categoryName: "Health", merchant: "Sample Pharmacy", amount: -18.40),

        .init(daysAgo: 25, categoryName: "Shopping", merchant: "Sample Online Store", amount: -67.20),
        .init(daysAgo: 8, categoryName: "Shopping", merchant: "Sample Online Store", amount: -22.10),
    ]

    @discardableResult
    public func seedDemoData(referenceDate: Date = .now) throws -> [ExpenseTransaction] {
        let categoriesByName = Dictionary(
            uniqueKeysWithValues: try CategoryRepository(context: context).fetchAll().map { ($0.name, $0) }
        )

        var created: [ExpenseTransaction] = []
        for entry in Self.entries {
            let bookingDate = referenceDate.addingTimeInterval(-Double(entry.daysAgo) * 86400)
            let transaction = ExpenseTransaction(
                bookingDate: bookingDate,
                amount: entry.amount,
                type: entry.amount < 0 ? .expense : .income,
                merchant: entry.merchant,
                rawDescription: entry.merchant,
                notes: "Sample data — safe to delete",
                source: .manual,
                category: categoriesByName[entry.categoryName]
            )
            context.insert(transaction)
            created.append(transaction)
        }

        try context.save()
        try RecurringScheduleRepository(context: context).refreshDetectedRecurrence()
        return created
    }
}
