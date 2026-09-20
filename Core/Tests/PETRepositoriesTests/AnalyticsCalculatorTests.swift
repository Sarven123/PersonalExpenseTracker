import Foundation
import Testing
import PETModels
@testable import PETRepositories

@Suite("AnalyticsCalculator")
struct AnalyticsCalculatorTests {
    private static func category(_ name: String, isTransferCategory: Bool = false) -> ExpenseCategory {
        ExpenseCategory(name: name, colorHex: "#FF0000", symbolName: "tag", isTransferCategory: isTransferCategory)
    }

    private static func date(_ daysFromReference: Int, reference: Date = Date(timeIntervalSince1970: 1_756_684_800)) -> Date {
        reference.addingTimeInterval(Double(daysFromReference) * 86400)
    }

    private static func transaction(
        daysFromReference: Int,
        amount: Decimal,
        type: TransactionType = .expense,
        merchant: String = "Merchant",
        category: ExpenseCategory? = nil,
        isExcludedFromAnalytics: Bool = false,
        isRecurring: Bool = false,
        recurringSchedule: RecurringSchedule? = nil
    ) -> ExpenseTransaction {
        let transaction = ExpenseTransaction(
            bookingDate: date(daysFromReference),
            amount: amount,
            type: type,
            merchant: merchant,
            rawDescription: merchant,
            isRecurring: isRecurring,
            isExcludedFromAnalytics: isExcludedFromAnalytics,
            category: category,
            recurringSchedule: recurringSchedule
        )
        return transaction
    }

    @Test("total sums absolute expense amounts within range")
    func totalSumsExpenses() {
        let transactions = [
            Self.transaction(daysFromReference: 0, amount: -10),
            Self.transaction(daysFromReference: 1, amount: -20),
            Self.transaction(daysFromReference: 10, amount: -100), // outside range
        ]
        let range = Self.date(-1)..<Self.date(5)
        #expect(AnalyticsCalculator.total(of: transactions, in: range) == 30)
    }

    @Test("total excludes transactions flagged isExcludedFromAnalytics")
    func totalExcludesFlagged() {
        let transactions = [
            Self.transaction(daysFromReference: 0, amount: -10),
            Self.transaction(daysFromReference: 0, amount: -999, isExcludedFromAnalytics: true),
        ]
        let range = Self.date(-1)..<Self.date(1)
        #expect(AnalyticsCalculator.total(of: transactions, in: range) == 10)
    }

    @Test("total excludes Transfers-category transactions by default")
    func totalExcludesTransfers() {
        let transfers = Self.category("Transfers", isTransferCategory: true)
        let transactions = [
            Self.transaction(daysFromReference: 0, amount: -10),
            Self.transaction(daysFromReference: 0, amount: -500, category: transfers),
        ]
        let range = Self.date(-1)..<Self.date(1)
        #expect(AnalyticsCalculator.total(of: transactions, in: range) == 10)
        #expect(AnalyticsCalculator.total(of: transactions, in: range, excludeTransfers: false) == 510)
    }

    @Test("monthlyOverview computes a positive percent change when spending rises")
    func monthlyOverviewPercentChange() {
        let transactions = [
            Self.transaction(daysFromReference: 0, amount: -150), // current period
            Self.transaction(daysFromReference: -35, amount: -100), // prior period
        ]
        let overview = AnalyticsCalculator.monthlyOverview(
            transactions: transactions,
            currentRange: Self.date(-5)..<Self.date(5),
            priorRange: Self.date(-40)..<Self.date(-30)
        )
        #expect(overview.currentPeriodTotal == 150)
        #expect(overview.priorPeriodTotal == 100)
        #expect(overview.percentChange == 50)
    }

    @Test("monthlyOverview returns nil percentChange when the prior period had no spending")
    func monthlyOverviewNilPercentChange() {
        let transactions = [Self.transaction(daysFromReference: 0, amount: -150)]
        let overview = AnalyticsCalculator.monthlyOverview(
            transactions: transactions,
            currentRange: Self.date(-5)..<Self.date(5),
            priorRange: Self.date(-40)..<Self.date(-30)
        )
        #expect(overview.percentChange == nil)
    }

    @Test("categoryBreakdown groups and sums by category, largest first")
    func categoryBreakdownGroupsAndSorts() {
        let food = Self.category("Food")
        let transport = Self.category("Transport")
        let transactions = [
            Self.transaction(daysFromReference: 0, amount: -10, category: food),
            Self.transaction(daysFromReference: 0, amount: -20, category: food),
            Self.transaction(daysFromReference: 0, amount: -100, category: transport),
        ]
        let breakdown = AnalyticsCalculator.categoryBreakdown(transactions: transactions, in: Self.date(-1)..<Self.date(1))
        #expect(breakdown.first?.categoryName == "Transport")
        #expect(breakdown.first?.total == 100)
        #expect(breakdown.last?.categoryName == "Food")
        #expect(breakdown.last?.total == 30)
        #expect(breakdown.last?.transactionCount == 2)
    }

    @Test("categoryBreakdown groups uncategorized transactions together")
    func categoryBreakdownGroupsUncategorized() {
        let transactions = [
            Self.transaction(daysFromReference: 0, amount: -10, category: nil),
            Self.transaction(daysFromReference: 0, amount: -5, category: nil),
        ]
        let breakdown = AnalyticsCalculator.categoryBreakdown(transactions: transactions, in: Self.date(-1)..<Self.date(1))
        #expect(breakdown.count == 1)
        #expect(breakdown.first?.categoryName == "Uncategorized")
        #expect(breakdown.first?.total == 15)
    }

    @Test("dailyTotals buckets by calendar day and sorts ascending")
    func dailyTotalsBucketsByDay() {
        var utc = Calendar(identifier: .gregorian)
        utc.timeZone = TimeZone(identifier: "UTC")!
        let transactions = [
            Self.transaction(daysFromReference: 1, amount: -10),
            Self.transaction(daysFromReference: 0, amount: -5),
            Self.transaction(daysFromReference: 0, amount: -5),
        ]
        let totals = AnalyticsCalculator.dailyTotals(transactions: transactions, in: Self.date(-1)..<Self.date(2), calendar: utc)
        #expect(totals.count == 2)
        #expect(totals[0].total == 10) // day 0: 5 + 5
        #expect(totals[1].total == 10) // day 1
        #expect(totals[0].date < totals[1].date)
    }

    @Test("topMerchants sorts descending and respects the limit")
    func topMerchantsSortsAndLimits() {
        let transactions = [
            Self.transaction(daysFromReference: 0, amount: -10, merchant: "A"),
            Self.transaction(daysFromReference: 0, amount: -50, merchant: "B"),
            Self.transaction(daysFromReference: 0, amount: -30, merchant: "C"),
        ]
        let top = AnalyticsCalculator.topMerchants(transactions: transactions, in: Self.date(-1)..<Self.date(1), limit: 2)
        #expect(top.map(\.merchant) == ["B", "C"])
    }

    @Test("weeklySummary sums the week containing the given date")
    func weeklySummarySumsTheWeek() {
        var utc = Calendar(identifier: .gregorian)
        utc.timeZone = TimeZone(identifier: "UTC")!
        let reference = Self.date(0)
        let transactions = [
            Self.transaction(daysFromReference: 0, amount: -10),
            Self.transaction(daysFromReference: 100, amount: -999), // far outside this week
        ]
        let summary = AnalyticsCalculator.weeklySummary(transactions: transactions, containing: reference, calendar: utc)
        #expect(summary.total == 10)
    }

    @Test("recurringSummary only includes transactions with an active schedule, excluding inactive schedules and one-offs")
    func recurringSummaryFiltersActiveSchedules() {
        let active = RecurringSchedule(frequency: .monthly, isActive: true)
        let inactive = RecurringSchedule(frequency: .monthly, isActive: false)
        let transactions = [
            Self.transaction(daysFromReference: 0, amount: -10, merchant: "Netflix", isRecurring: true, recurringSchedule: active),
            Self.transaction(daysFromReference: 0, amount: -10, merchant: "Old Gym", isRecurring: true, recurringSchedule: inactive),
            Self.transaction(daysFromReference: 0, amount: -10, merchant: "One-off"),
        ]
        let summary = AnalyticsCalculator.recurringSummary(transactions: transactions)
        #expect(summary.count == 1)
        #expect(summary.first?.merchant == "Netflix")
        #expect(summary.first?.frequency == .monthly)
    }

    @Test("recurringSummary includes a manually-flagged transaction with no auto-detected schedule")
    func recurringSummaryIncludesManuallyFlaggedTransactions() {
        let transactions = [
            Self.transaction(daysFromReference: 0, amount: -50, merchant: "Gym Membership", isRecurring: true),
        ]
        let summary = AnalyticsCalculator.recurringSummary(transactions: transactions)
        #expect(summary.count == 1)
        #expect(summary.first?.merchant == "Gym Membership")
        #expect(summary.first?.frequency == nil)
        #expect(summary.first?.nextExpectedDate == nil)
    }

    @Test("recurringSummary prefers an auto-detected schedule over a bare manual flag for the same merchant")
    func recurringSummaryPrefersDetectedScheduleOverManualFlag() {
        let schedule = RecurringSchedule(frequency: .weekly, isActive: true)
        let transactions = [
            Self.transaction(daysFromReference: 0, amount: -10, merchant: "Netflix", isRecurring: true),
            Self.transaction(daysFromReference: -30, amount: -10, merchant: "Netflix", isRecurring: true, recurringSchedule: schedule),
        ]
        let summary = AnalyticsCalculator.recurringSummary(transactions: transactions)
        #expect(summary.count == 1)
        #expect(summary.first?.frequency == .weekly)
    }

    @Test("monthlyTotals returns one entry per trailing month, oldest first")
    func monthlyTotalsReturnsOldestFirst() {
        var utc = Calendar(identifier: .gregorian)
        utc.timeZone = TimeZone(identifier: "UTC")!
        let reference = utc.date(from: DateComponents(year: 2026, month: 9, day: 15))!
        let transactions = [
            ExpenseTransaction(bookingDate: reference, amount: -10, type: .expense, merchant: "Merchant", rawDescription: "Merchant"),
        ]
        let totals = AnalyticsCalculator.monthlyTotals(transactions: transactions, monthsBack: 3, referenceDate: reference, calendar: utc)
        #expect(totals.count == 3)
        #expect(totals[0].month < totals[1].month)
        #expect(totals[1].month < totals[2].month)
        #expect(totals.last?.total == 10)
        #expect(totals.first?.total == 0)
    }

    @Test("monthlyTotals returns an empty array for a non-positive monthsBack")
    func monthlyTotalsHandlesZeroMonths() {
        #expect(AnalyticsCalculator.monthlyTotals(transactions: [], monthsBack: 0).isEmpty)
    }
}
