import SwiftUI
import SwiftData
import Charts
import PETModels
import PETRepositories

public struct InsightsView: View {
    @Query(sort: \ExpenseTransaction.bookingDate, order: .reverse) private var transactions: [ExpenseTransaction]
    @Query(sort: \ExpenseCategory.sortOrder) private var categories: [ExpenseCategory]

    @State private var filter = FilterCriteria()
    @State private var isPresentingFilterPopover = false

    private let calendar: Calendar = .current

    public init() {}

    public var body: some View {
        Group {
            if transactions.isEmpty {
                ContentUnavailableView(
                    "No Data Yet",
                    systemImage: "chart.bar.xaxis",
                    description: Text("Add or import some transactions to see insights.")
                )
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 28) {
                        byCategorySection
                        byMerchantSection
                        byMonthSection
                        subscriptionsSection
                    }
                    .padding(24)
                }
            }
        }
        .navigationTitle("Insights")
        .toolbar {
            ToolbarItem {
                Button {
                    isPresentingFilterPopover = true
                } label: {
                    Label("Filter", systemImage: filter.isActive ? "line.3.horizontal.decrease.circle.fill" : "line.3.horizontal.decrease.circle")
                }
                .popover(isPresented: $isPresentingFilterPopover) {
                    FilterPopoverView(filter: $filter, categories: categories)
                }
            }
        }
    }

    private var filteredTransactions: [ExpenseTransaction] {
        transactions.filter { filter.matches($0, calendar: calendar) }
    }

    /// Ignores the date range specifically, since the by-month trend chart's
    /// whole point is to show change *across* dates.
    private var attributeFilteredTransactions: [ExpenseTransaction] {
        transactions.filter { filter.matchesAttributes($0) }
    }

    private var categoryBreakdown: [CategoryTotal] {
        AnalyticsCalculator.categoryBreakdown(transactions: filteredTransactions, in: Date.distantPast..<Date.distantFuture, excludeTransfers: filter.excludeTransfers)
    }

    private var topMerchants: [MerchantTotal] {
        AnalyticsCalculator.topMerchants(transactions: filteredTransactions, in: Date.distantPast..<Date.distantFuture, limit: 10, excludeTransfers: filter.excludeTransfers)
    }

    private var monthlyTotals: [MonthlyTotal] {
        AnalyticsCalculator.monthlyTotals(
            transactions: attributeFilteredTransactions,
            monthsBack: 12,
            calendar: calendar,
            excludeTransfers: filter.excludeTransfers
        )
    }

    private var recurringItems: [RecurringSummaryItem] {
        AnalyticsCalculator.recurringSummary(transactions: attributeFilteredTransactions)
    }

    private var byCategorySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("By Category").font(.headline)
            if categoryBreakdown.isEmpty {
                Text("No spending matches the current filters.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                Chart(categoryBreakdown) { item in
                    BarMark(x: .value("Total", item.total), y: .value("Category", item.categoryName))
                        .foregroundStyle(Color(hex: item.colorHex))
                        .annotation(position: .trailing) {
                            Text(item.total, format: .currency(code: "EUR"))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                }
                .frame(height: CGFloat(categoryBreakdown.count) * 28 + 20)
            }
        }
    }

    private var byMerchantSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("By Merchant").font(.headline)
            if topMerchants.isEmpty {
                Text("No spending matches the current filters.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(topMerchants) { item in
                    HStack {
                        Text(item.merchant).font(.subheadline)
                        Spacer()
                        Text("\(item.transactionCount)×")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(item.total, format: .currency(code: "EUR"))
                            .font(.subheadline.monospacedDigit())
                    }
                }
            }
        }
    }

    private var byMonthSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("By Month (Last 12 Months)").font(.headline)
            Chart(monthlyTotals) { item in
                BarMark(x: .value("Month", item.month, unit: .month), y: .value("Total", item.total))
                    .foregroundStyle(Color.accentColor)
            }
            .frame(height: 200)
        }
    }

    private var subscriptionsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Titled to match DashboardView's equivalent section — this lists every
            // *recurring* transaction (any category), not just ones in the
            // "Subscriptions" category, which is a separate, unrelated concept
            // shown above in "By Category". Sharing the word "Subscriptions" for
            // both was a real point of user confusion.
            Text("Recurring & Subscriptions").font(.headline)
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
                        Text(item.merchant).font(.subheadline)
                        Spacer()
                        Text(item.amount, format: .currency(code: "EUR"))
                            .font(.subheadline.monospacedDigit())
                    }
                }
            }
        }
    }
}
