import Foundation
import PETModels

/// A shared filter shape (date range, category, merchant search, type,
/// source, transfers include/exclude) applied consistently by any view that
/// shows transactions or transaction-derived metrics. Pure and SwiftData-context-free,
/// so it's cheap to re-evaluate reactively and trivial to unit test.
public struct FilterCriteria: Equatable {
    public enum DateRangeOption: Equatable {
        case allTime
        case thisWeek
        case thisMonth
        case custom(start: Date, end: Date)
    }

    public var dateRange: DateRangeOption
    public var categoryIDs: Set<UUID>
    public var uncategorizedOnly: Bool
    public var merchantSearchText: String
    public var types: Set<TransactionType>
    public var sources: Set<TransactionSource>
    public var excludeTransfers: Bool

    public init(
        dateRange: DateRangeOption = .allTime,
        categoryIDs: Set<UUID> = [],
        uncategorizedOnly: Bool = false,
        merchantSearchText: String = "",
        types: Set<TransactionType> = Set(TransactionType.allCases),
        sources: Set<TransactionSource> = Set(TransactionSource.allCases),
        excludeTransfers: Bool = false
    ) {
        self.dateRange = dateRange
        self.categoryIDs = categoryIDs
        self.uncategorizedOnly = uncategorizedOnly
        self.merchantSearchText = merchantSearchText
        self.types = types
        self.sources = sources
        self.excludeTransfers = excludeTransfers
    }

    public var isActive: Bool {
        dateRange != .allTime
            || !categoryIDs.isEmpty
            || uncategorizedOnly
            || !merchantSearchText.isEmpty
            || types != Set(TransactionType.allCases)
            || sources != Set(TransactionSource.allCases)
            || excludeTransfers
    }

    public mutating func reset() {
        self = FilterCriteria()
    }

    public func matches(_ transaction: ExpenseTransaction, calendar: Calendar = .current, referenceDate: Date = .now) -> Bool {
        matchesAttributes(transaction) && matchesDateRange(transaction, calendar: calendar, referenceDate: referenceDate)
    }

    /// Every filter dimension except date range — used by callers (like a
    /// "trend over the last 12 months" chart) that need to apply category/
    /// merchant/type/source filtering while intentionally ignoring the
    /// selected date range.
    public func matchesAttributes(_ transaction: ExpenseTransaction) -> Bool {
        guard types.contains(transaction.type) else { return false }
        guard sources.contains(transaction.source) else { return false }
        if excludeTransfers, transaction.category?.isTransferCategory == true { return false }

        if uncategorizedOnly {
            guard transaction.category == nil else { return false }
        } else if !categoryIDs.isEmpty {
            guard let categoryID = transaction.category?.id, categoryIDs.contains(categoryID) else {
                return false
            }
        }

        if !merchantSearchText.isEmpty {
            guard transaction.merchant.localizedCaseInsensitiveContains(merchantSearchText) else { return false }
        }

        return true
    }

    public func matchesDateRange(_ transaction: ExpenseTransaction, calendar: Calendar = .current, referenceDate: Date = .now) -> Bool {
        switch dateRange {
        case .allTime:
            return true
        case .thisWeek:
            guard let interval = calendar.dateInterval(of: .weekOfYear, for: referenceDate) else { return true }
            return interval.contains(transaction.bookingDate)
        case .thisMonth:
            guard let interval = calendar.dateInterval(of: .month, for: referenceDate) else { return true }
            return interval.contains(transaction.bookingDate)
        case let .custom(start, end):
            return transaction.bookingDate >= start && transaction.bookingDate <= end
        }
    }
}
