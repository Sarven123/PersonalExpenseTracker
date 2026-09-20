import SwiftUI
import PETModels
import PETRepositories

/// A reusable filter editor for `FilterCriteria`, shared by `TransactionListView`
/// and `InsightsView` so filtering behaves consistently everywhere it appears.
struct FilterPopoverView: View {
    @Binding var filter: FilterCriteria
    let categories: [ExpenseCategory]

    private enum SimpleDateRange: Hashable {
        case allTime, thisWeek, thisMonth
    }

    var body: some View {
        Form {
            Section("Date Range") {
                Picker("Range", selection: dateRangeSelection) {
                    Text("All Time").tag(SimpleDateRange.allTime)
                    Text("This Week").tag(SimpleDateRange.thisWeek)
                    Text("This Month").tag(SimpleDateRange.thisMonth)
                }
                .pickerStyle(.segmented)
            }

            Section("Type") {
                ForEach(TransactionType.allCases, id: \.self) { type in
                    Toggle(typeLabel(type), isOn: typeBinding(type))
                }
            }

            Section("Source") {
                ForEach(TransactionSource.allCases, id: \.self) { source in
                    Toggle(sourceLabel(source), isOn: sourceBinding(source))
                }
            }

            Section("Category") {
                Toggle("Uncategorized Only", isOn: $filter.uncategorizedOnly)
                if !filter.uncategorizedOnly {
                    ForEach(categories) { category in
                        Toggle(isOn: categoryBinding(category)) {
                            Label(category.name, systemImage: category.symbolName)
                        }
                    }
                }
            }

            Section {
                Toggle("Exclude Transfers", isOn: $filter.excludeTransfers)
            }

            Section {
                Button("Reset Filters") { filter.reset() }
                    .disabled(!filter.isActive)
            }
        }
        .formStyle(.grouped)
        .frame(width: 320, height: 480)
    }

    private var dateRangeSelection: Binding<SimpleDateRange> {
        Binding(
            get: {
                switch filter.dateRange {
                case .allTime: .allTime
                case .thisWeek: .thisWeek
                case .thisMonth: .thisMonth
                case .custom: .allTime
                }
            },
            set: { newValue in
                switch newValue {
                case .allTime: filter.dateRange = .allTime
                case .thisWeek: filter.dateRange = .thisWeek
                case .thisMonth: filter.dateRange = .thisMonth
                }
            }
        )
    }

    private func typeBinding(_ type: TransactionType) -> Binding<Bool> {
        Binding(
            get: { filter.types.contains(type) },
            set: { isOn in
                if isOn { filter.types.insert(type) } else { filter.types.remove(type) }
            }
        )
    }

    private func sourceBinding(_ source: TransactionSource) -> Binding<Bool> {
        Binding(
            get: { filter.sources.contains(source) },
            set: { isOn in
                if isOn { filter.sources.insert(source) } else { filter.sources.remove(source) }
            }
        )
    }

    private func categoryBinding(_ category: ExpenseCategory) -> Binding<Bool> {
        Binding(
            get: { filter.categoryIDs.contains(category.id) },
            set: { isOn in
                if isOn {
                    filter.categoryIDs.insert(category.id)
                } else {
                    filter.categoryIDs.remove(category.id)
                }
            }
        )
    }

    private func typeLabel(_ type: TransactionType) -> String {
        switch type {
        case .expense: "Expense"
        case .income: "Income"
        case .transfer: "Transfer"
        }
    }

    private func sourceLabel(_ source: TransactionSource) -> String {
        switch source {
        case .manual: "Manual"
        case .imported: "Imported"
        }
    }
}
