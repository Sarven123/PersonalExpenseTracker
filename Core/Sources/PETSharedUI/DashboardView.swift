import SwiftUI
import SwiftData
import Charts
import PETModels
import PETRepositories

public struct DashboardView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \ExpenseTransaction.bookingDate, order: .reverse) private var transactions: [ExpenseTransaction]

    @State private var referenceDate: Date = .now
    @State private var selectedAngle: Decimal?
    @State private var selectedDay: Date?
    @State private var errorMessage: String?

    private let calendar: Calendar = .current

    public init() {}

    public var body: some View {
        Group {
            if transactions.isEmpty {
                emptyState
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 28) {
                        overviewSection
                        categorySection
                        timeSeriesSection
                        weeklySection
                        HStack(alignment: .top, spacing: 28) {
                            recentTransactionsSection
                            topMerchantsSection
                        }
                        recurringSection
                    }
                    .padding(24)
                }
            }
        }
        .navigationTitle("Dashboard")
    }

    // MARK: - Date ranges

    private var currentMonthRange: Range<Date> {
        let interval = calendar.dateInterval(of: .month, for: referenceDate) ?? DateInterval(start: referenceDate, duration: 0)
        return interval.start..<interval.end
    }

    private var priorMonthRange: Range<Date> {
        let priorStart = calendar.date(byAdding: .month, value: -1, to: currentMonthRange.lowerBound) ?? currentMonthRange.lowerBound
        let interval = calendar.dateInterval(of: .month, for: priorStart) ?? DateInterval(start: priorStart, duration: 0)
        return interval.start..<interval.end
    }

    // MARK: - Derived analytics

    private var overview: MonthlyOverview {
        AnalyticsCalculator.monthlyOverview(transactions: transactions, currentRange: currentMonthRange, priorRange: priorMonthRange)
    }

    private var categoryBreakdown: [CategoryTotal] {
        AnalyticsCalculator.categoryBreakdown(transactions: transactions, in: currentMonthRange)
    }

    private var dailyTotals: [DailyTotal] {
        AnalyticsCalculator.dailyTotals(transactions: transactions, in: currentMonthRange, calendar: calendar)
    }

    private var weeklySummary: WeeklySummary {
        AnalyticsCalculator.weeklySummary(transactions: transactions, containing: referenceDate, calendar: calendar)
    }

    private var topMerchants: [MerchantTotal] {
        AnalyticsCalculator.topMerchants(transactions: transactions, in: currentMonthRange)
    }

    private var recurringItems: [RecurringSummaryItem] {
        AnalyticsCalculator.recurringSummary(transactions: transactions)
    }

    private var recentTransactions: [ExpenseTransaction] {
        Array(transactions.prefix(5))
    }

    /// Maps `chartAngleSelection`'s raw selected value back to the category
    /// whose cumulative slice contains it (SectorMark stacks slices in order).
    private var selectedCategoryTotal: CategoryTotal? {
        guard let selectedAngle else { return nil }
        var cumulative: Decimal = 0
        for item in categoryBreakdown {
            cumulative += item.total
            if selectedAngle <= cumulative {
                return item
            }
        }
        return categoryBreakdown.last
    }

    // MARK: - Sections

    private var overviewSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("This Month")
                .font(.headline)
                .foregroundStyle(.secondary)
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                Text(overview.currentPeriodTotal, format: .currency(code: "EUR"))
                    .font(.system(size: 34, weight: .bold))
                if let percentChange = overview.percentChange {
                    Label(
                        "\(percentChange >= 0 ? "+" : "")\(percentChange, specifier: "%.0f")%",
                        systemImage: percentChange >= 0 ? "arrow.up.right" : "arrow.down.right"
                    )
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(percentChange >= 0 ? Color.red : Color.green)
                }
            }
            Text("vs. \(overview.priorPeriodTotal, format: .currency(code: "EUR")) last month")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var categorySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Spending by Category")
                .font(.headline)
            if categoryBreakdown.isEmpty {
                Text("No spending recorded this month.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                HStack(alignment: .top, spacing: 24) {
                    Chart(categoryBreakdown) { item in
                        SectorMark(
                            angle: .value("Total", item.total),
                            innerRadius: .ratio(0.62),
                            angularInset: 1.5
                        )
                        .foregroundStyle(Color(hex: item.colorHex))
                        .opacity(selectedCategoryTotal == nil || selectedCategoryTotal?.id == item.id ? 1 : 0.35)
                    }
                    .chartAngleSelection(value: $selectedAngle)
                    .chartBackground { _ in
                        if let selected = selectedCategoryTotal {
                            VStack(spacing: 2) {
                                Text(selected.categoryName)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Text(selected.total, format: .currency(code: "EUR"))
                                    .font(.headline)
                            }
                        }
                    }
                    .frame(width: 220, height: 220)

                    categoryLegend
                }
            }
        }
    }

    private var categoryLegend: some View {
        VStack(alignment: .leading, spacing: 6) {
            ForEach(categoryBreakdown.prefix(8)) { item in
                HStack(spacing: 8) {
                    Circle()
                        .fill(Color(hex: item.colorHex))
                        .frame(width: 8, height: 8)
                    Text(item.categoryName)
                        .font(.caption)
                    Spacer(minLength: 12)
                    Text(item.total, format: .currency(code: "EUR"))
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
                .opacity(selectedCategoryTotal == nil || selectedCategoryTotal?.id == item.id ? 1 : 0.4)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var timeSeriesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Daily Spending")
                .font(.headline)
            if dailyTotals.isEmpty {
                Text("No spending recorded this month.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                Chart(dailyTotals) { item in
                    LineMark(x: .value("Date", item.date, unit: .day), y: .value("Total", item.total))
                        .interpolationMethod(.monotone)
                    AreaMark(x: .value("Date", item.date, unit: .day), y: .value("Total", item.total))
                        .interpolationMethod(.monotone)
                        .foregroundStyle(.linearGradient(
                            colors: [Color.accentColor.opacity(0.25), .clear],
                            startPoint: .top,
                            endPoint: .bottom
                        ))

                    if let selectedDay, calendar.isDate(selectedDay, inSameDayAs: item.date) {
                        RuleMark(x: .value("Date", item.date, unit: .day))
                            .foregroundStyle(Color.secondary.opacity(0.3))
                            .annotation(position: .top, alignment: .center) {
                                VStack(spacing: 2) {
                                    Text(item.date, format: .dateTime.day().month())
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                    Text(item.total, format: .currency(code: "EUR"))
                                        .font(.caption.weight(.semibold))
                                }
                                .padding(6)
                                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 6))
                            }
                    }
                }
                .chartXSelection(value: $selectedDay)
                .frame(height: 180)
            }
        }
    }

    private var weeklySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("This Week")
                .font(.headline)
            HStack {
                Text(weeklySummary.total, format: .currency(code: "EUR"))
                    .font(.title2.weight(.bold))
                Spacer()
                HStack(spacing: 6) {
                    ForEach(weeklySummary.leadingCategories) { item in
                        Label(item.categoryName, systemImage: item.symbolName)
                            .font(.caption)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 3)
                            .background(Color(hex: item.colorHex).opacity(0.15), in: Capsule())
                            .foregroundStyle(Color(hex: item.colorHex))
                    }
                }
            }
            if !weeklySummary.dailyTotals.isEmpty {
                Chart(weeklySummary.dailyTotals) { item in
                    BarMark(x: .value("Day", item.date, unit: .day), y: .value("Total", item.total))
                        .foregroundStyle(Color.accentColor)
                }
                .frame(height: 100)
            }
        }
    }

    private var recentTransactionsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Recent Transactions")
                .font(.headline)
            if recentTransactions.isEmpty {
                Text("No transactions yet.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(recentTransactions) { transaction in
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(transaction.merchant)
                                .font(.subheadline)
                            Text(transaction.bookingDate, format: .dateTime.day().month())
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Text(transaction.amount, format: .currency(code: transaction.currencyCode))
                            .font(.subheadline.monospacedDigit())
                            .foregroundStyle(transaction.amount < 0 ? Color.red : Color.green)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var topMerchantsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Top Merchants")
                .font(.headline)
            if topMerchants.isEmpty {
                Text("No spending recorded this month.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(topMerchants) { item in
                    HStack {
                        Text(item.merchant)
                            .font(.subheadline)
                        Spacer()
                        Text(item.total, format: .currency(code: "EUR"))
                            .font(.subheadline.monospacedDigit())
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var recurringSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Recurring & Subscriptions")
                .font(.headline)
            if recurringItems.isEmpty {
                Text("No recurring transactions detected yet.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(recurringItems) { item in
                    HStack {
                        Image(systemName: "repeat.circle.fill")
                            .foregroundStyle(.secondary)
                            .accessibilityHidden(true)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(item.merchant)
                                .font(.subheadline)
                            Text(frequencyLabel(item.frequency))
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        VStack(alignment: .trailing, spacing: 2) {
                            Text(item.amount, format: .currency(code: "EUR"))
                                .font(.subheadline.monospacedDigit())
                            if let next = item.nextExpectedDate {
                                Text("Next: \(next, format: .dateTime.day().month())")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }
        }
    }

    private var emptyState: some View {
        ContentUnavailableView {
            Label("No Data Yet", systemImage: "chart.pie")
        } description: {
            Text("Add some transactions to see your spending at a glance, or load sample data to preview the dashboard.")
        } actions: {
            VStack(spacing: 8) {
                Button("Load Demo Data") { loadDemoData() }
                if let errorMessage {
                    Text(errorMessage)
                        .font(.caption)
                        .foregroundStyle(.red)
                }
            }
        }
    }

    private func loadDemoData() {
        do {
            try DemoDataRepository(context: modelContext).seedDemoData(referenceDate: referenceDate)
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func frequencyLabel(_ frequency: RecurringFrequency) -> String {
        switch frequency {
        case .weekly: "Weekly"
        case .biweekly: "Every 2 weeks"
        case .monthly: "Monthly"
        case .quarterly: "Quarterly"
        case .yearly: "Yearly"
        }
    }
}
