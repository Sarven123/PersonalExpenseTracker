import Foundation
import PETModels

public struct CategoryTotal: Identifiable, Equatable, Sendable {
    public let id: String
    public let categoryName: String
    public let colorHex: String
    public let symbolName: String
    public let total: Decimal
    public let transactionCount: Int
}

public struct DailyTotal: Identifiable, Equatable, Sendable {
    public var id: Date { date }
    public let date: Date
    public let total: Decimal
}

public struct MerchantTotal: Identifiable, Equatable, Sendable {
    public var id: String { merchant }
    public let merchant: String
    public let total: Decimal
    public let transactionCount: Int
}

public struct WeeklySummary: Equatable, Sendable {
    public let total: Decimal
    public let dailyTotals: [DailyTotal]
    public let leadingCategories: [CategoryTotal]
}

public struct MonthlyOverview: Equatable, Sendable {
    public let currentPeriodTotal: Decimal
    public let priorPeriodTotal: Decimal
    /// `nil` when the prior period had no spending to compare against.
    public let percentChange: Double?
}

public struct RecurringSummaryItem: Identifiable, Equatable, Sendable {
    public var id: String { merchant }
    public let merchant: String
    public let amount: Decimal
    public let frequency: RecurringFrequency
    public let nextExpectedDate: Date?
}

/// Pure aggregation functions over an already-fetched `[ExpenseTransaction]`
/// array — no SwiftData context needed, so these are trivially unit-testable
/// and cheap to recompute reactively whenever a SwiftUI `@Query` changes.
/// Every aggregation excludes transactions with `isExcludedFromAnalytics`,
/// and (by default) transactions in a `Transfers`-flagged category, per the
/// "Transfers can be excluded from analytics" requirement.
public enum AnalyticsCalculator {
    public static func total(
        of transactions: [ExpenseTransaction],
        in range: Range<Date>,
        types: Set<TransactionType> = [.expense],
        excludeTransfers: Bool = true
    ) -> Decimal {
        filtered(transactions, in: range, types: types, excludeTransfers: excludeTransfers)
            .reduce(Decimal(0)) { $0 + abs($1.amount) }
    }

    public static func monthlyOverview(
        transactions: [ExpenseTransaction],
        currentRange: Range<Date>,
        priorRange: Range<Date>,
        excludeTransfers: Bool = true
    ) -> MonthlyOverview {
        let current = total(of: transactions, in: currentRange, excludeTransfers: excludeTransfers)
        let prior = total(of: transactions, in: priorRange, excludeTransfers: excludeTransfers)
        let percentChange: Double?
        if prior == 0 {
            percentChange = nil
        } else {
            percentChange = Double(truncating: ((current - prior) / prior) as NSDecimalNumber) * 100
        }
        return MonthlyOverview(currentPeriodTotal: current, priorPeriodTotal: prior, percentChange: percentChange)
    }

    public static func categoryBreakdown(
        transactions: [ExpenseTransaction],
        in range: Range<Date>,
        excludeTransfers: Bool = true
    ) -> [CategoryTotal] {
        let relevant = filtered(transactions, in: range, types: [.expense], excludeTransfers: excludeTransfers)

        struct Accumulator {
            var colorHex: String
            var symbolName: String
            var total: Decimal = 0
            var count: Int = 0
        }

        var byName: [String: Accumulator] = [:]
        for transaction in relevant {
            let name = transaction.category?.name ?? "Uncategorized"
            var entry = byName[name] ?? Accumulator(
                colorHex: transaction.category?.colorHex ?? "#9CA3AF",
                symbolName: transaction.category?.symbolName ?? "questionmark.circle"
            )
            entry.total += abs(transaction.amount)
            entry.count += 1
            byName[name] = entry
        }

        return byName
            .map { name, accumulator in
                CategoryTotal(
                    id: name,
                    categoryName: name,
                    colorHex: accumulator.colorHex,
                    symbolName: accumulator.symbolName,
                    total: accumulator.total,
                    transactionCount: accumulator.count
                )
            }
            .sorted { $0.total > $1.total }
    }

    public static func dailyTotals(
        transactions: [ExpenseTransaction],
        in range: Range<Date>,
        calendar: Calendar = .current,
        excludeTransfers: Bool = true
    ) -> [DailyTotal] {
        let relevant = filtered(transactions, in: range, types: [.expense], excludeTransfers: excludeTransfers)
        let grouped = Dictionary(grouping: relevant) { calendar.startOfDay(for: $0.bookingDate) }
        return grouped
            .map { day, txs in DailyTotal(date: day, total: txs.reduce(Decimal(0)) { $0 + abs($1.amount) }) }
            .sorted { $0.date < $1.date }
    }

    public static func topMerchants(
        transactions: [ExpenseTransaction],
        in range: Range<Date>,
        limit: Int = 5,
        excludeTransfers: Bool = true
    ) -> [MerchantTotal] {
        let relevant = filtered(transactions, in: range, types: [.expense], excludeTransfers: excludeTransfers)
        let grouped = Dictionary(grouping: relevant) { $0.merchant }
        return grouped
            .map { merchant, txs in
                MerchantTotal(merchant: merchant, total: txs.reduce(Decimal(0)) { $0 + abs($1.amount) }, transactionCount: txs.count)
            }
            .sorted { $0.total > $1.total }
            .prefix(limit)
            .map { $0 }
    }

    public static func weeklySummary(
        transactions: [ExpenseTransaction],
        containing date: Date,
        calendar: Calendar = .current,
        excludeTransfers: Bool = true
    ) -> WeeklySummary {
        guard let weekInterval = calendar.dateInterval(of: .weekOfYear, for: date) else {
            return WeeklySummary(total: 0, dailyTotals: [], leadingCategories: [])
        }
        let range = weekInterval.start..<weekInterval.end
        let daily = dailyTotals(transactions: transactions, in: range, calendar: calendar, excludeTransfers: excludeTransfers)
        let categories = categoryBreakdown(transactions: transactions, in: range, excludeTransfers: excludeTransfers)
        let total = daily.reduce(Decimal(0)) { $0 + $1.total }
        return WeeklySummary(total: total, dailyTotals: daily, leadingCategories: Array(categories.prefix(3)))
    }

    /// Active recurring schedules, soonest expected first.
    public static func recurringSummary(transactions: [ExpenseTransaction]) -> [RecurringSummaryItem] {
        transactions
            .compactMap { transaction -> RecurringSummaryItem? in
                guard let schedule = transaction.recurringSchedule, schedule.isActive else { return nil }
                return RecurringSummaryItem(
                    merchant: transaction.merchant,
                    amount: transaction.amount,
                    frequency: schedule.frequency,
                    nextExpectedDate: schedule.nextExpectedDate
                )
            }
            .sorted { ($0.nextExpectedDate ?? .distantFuture) < ($1.nextExpectedDate ?? .distantFuture) }
    }

    private static func filtered(
        _ transactions: [ExpenseTransaction],
        in range: Range<Date>,
        types: Set<TransactionType>,
        excludeTransfers: Bool
    ) -> [ExpenseTransaction] {
        transactions.filter { transaction in
            guard !transaction.isExcludedFromAnalytics else { return false }
            guard range.contains(transaction.bookingDate) else { return false }
            guard types.contains(transaction.type) else { return false }
            if excludeTransfers, transaction.category?.isTransferCategory == true { return false }
            return true
        }
    }
}
