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
    /// `nil` when the transaction was manually flagged `isRecurring` by the
    /// user but no cadence has been auto-detected yet (no `RecurringSchedule`).
    public let frequency: RecurringFrequency?
    public let nextExpectedDate: Date?
}

public struct MonthlyTotal: Identifiable, Equatable, Sendable {
    public var id: Date { month }
    /// The first day of the month, in the calendar passed to `monthlyTotals`.
    public let month: Date
    public let total: Decimal
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

    /// Every transaction that's recurring — either because a `RecurringSchedule`
    /// was auto-detected (`RecurringScheduleRepository`) or because the user
    /// manually flagged it via the "Recurring" toggle on the transaction editor,
    /// which sets `isRecurring` directly with no schedule attached. A schedule,
    /// when present, is authoritative: an active one always contributes its known
    /// cadence (overriding any bare manual flag for the same merchant), an
    /// inactive one always excludes the merchant regardless of `isRecurring`. The
    /// bare `isRecurring` flag is only consulted when there's no schedule at all.
    /// One entry per merchant, soonest expected date first.
    public static func recurringSummary(transactions: [ExpenseTransaction]) -> [RecurringSummaryItem] {
        var byMerchant: [String: RecurringSummaryItem] = [:]

        for transaction in transactions {
            if let schedule = transaction.recurringSchedule {
                guard schedule.isActive else { continue }
                byMerchant[transaction.merchant] = RecurringSummaryItem(
                    merchant: transaction.merchant,
                    amount: transaction.amount,
                    frequency: schedule.frequency,
                    nextExpectedDate: schedule.nextExpectedDate
                )
            } else if transaction.isRecurring, byMerchant[transaction.merchant] == nil {
                byMerchant[transaction.merchant] = RecurringSummaryItem(
                    merchant: transaction.merchant,
                    amount: transaction.amount,
                    frequency: nil,
                    nextExpectedDate: nil
                )
            }
        }

        return byMerchant.values.sorted { ($0.nextExpectedDate ?? .distantFuture) < ($1.nextExpectedDate ?? .distantFuture) }
    }

    /// Total spending per calendar month for the trailing `monthsBack` months
    /// (inclusive of the month containing `referenceDate`), oldest first.
    public static func monthlyTotals(
        transactions: [ExpenseTransaction],
        monthsBack: Int,
        referenceDate: Date = .now,
        calendar: Calendar = .current,
        excludeTransfers: Bool = true
    ) -> [MonthlyTotal] {
        guard monthsBack > 0 else { return [] }
        return (0..<monthsBack).reversed().compactMap { offset -> MonthlyTotal? in
            guard let monthDate = calendar.date(byAdding: .month, value: -offset, to: referenceDate),
                  let interval = calendar.dateInterval(of: .month, for: monthDate) else {
                return nil
            }
            let monthTotal = total(of: transactions, in: interval.start..<interval.end, excludeTransfers: excludeTransfers)
            return MonthlyTotal(month: interval.start, total: monthTotal)
        }
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
