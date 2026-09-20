import SwiftUI
import SwiftData
import UniformTypeIdentifiers
import PETModels
import PETRepositories
import PETExport

public struct TransactionListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \ExpenseTransaction.bookingDate, order: .reverse) private var transactions: [ExpenseTransaction]
    @Query(sort: \ExpenseCategory.sortOrder) private var categories: [ExpenseCategory]

    @State private var filter = FilterCriteria()
    @State private var sortOrder: [KeyPathComparator<ExpenseTransaction>] = [KeyPathComparator(\.bookingDate, order: .reverse)]
    @State private var selection: Set<UUID> = []
    @State private var editingTransaction: ExpenseTransaction?
    @State private var isPresentingAddSheet = false
    @State private var isPresentingCategoryManager = false
    @State private var isPresentingImportSheet = false
    @State private var isPresentingMerchantRuleManager = false
    @State private var isPresentingFilterPopover = false
    @State private var isPresentingExporter = false
    @State private var exportDocument: CSVDocument?
    @State private var errorMessage: String?

    public init() {}

    private var filteredTransactions: [ExpenseTransaction] {
        transactions.filter { filter.matches($0) }.sorted(using: sortOrder)
    }

    public var body: some View {
        Group {
            if transactions.isEmpty {
                emptyState
            } else if filteredTransactions.isEmpty {
                noResultsState
            } else {
                table
            }
        }
        .searchable(text: $filter.merchantSearchText, prompt: "Search merchant")
        .navigationTitle("Transactions")
        .toolbar {
            ToolbarItemGroup {
                Button {
                    isPresentingFilterPopover = true
                } label: {
                    Label("Filter", systemImage: filter.isActive ? "line.3.horizontal.decrease.circle.fill" : "line.3.horizontal.decrease.circle")
                }
                .popover(isPresented: $isPresentingFilterPopover) {
                    FilterPopoverView(filter: $filter, categories: categories)
                }
                Button {
                    exportFilteredTransactions()
                } label: {
                    Label("Export CSV", systemImage: "square.and.arrow.up")
                }
                .disabled(filteredTransactions.isEmpty)
                Button {
                    isPresentingMerchantRuleManager = true
                } label: {
                    Label("Merchant Rules", systemImage: "wand.and.stars")
                }
                Button {
                    isPresentingCategoryManager = true
                } label: {
                    Label("Manage Categories", systemImage: "tag")
                }
                Button {
                    isPresentingImportSheet = true
                } label: {
                    Label("Import CSV", systemImage: "square.and.arrow.down")
                }
                Button {
                    isPresentingAddSheet = true
                } label: {
                    Label("Add Expense", systemImage: "plus")
                }
            }
        }
        .sheet(isPresented: $isPresentingAddSheet) {
            TransactionEditView(mode: .create)
        }
        .sheet(item: $editingTransaction) { transaction in
            TransactionEditView(mode: .edit(transaction))
        }
        .sheet(isPresented: $isPresentingCategoryManager) {
            CategoryManagerView()
        }
        .sheet(isPresented: $isPresentingImportSheet) {
            ImportCSVView()
        }
        .sheet(isPresented: $isPresentingMerchantRuleManager) {
            MerchantRuleManagerView()
        }
        .fileExporter(
            isPresented: $isPresentingExporter,
            document: exportDocument,
            contentType: .commaSeparatedText,
            defaultFilename: "Transactions"
        ) { result in
            if case let .failure(error) = result {
                errorMessage = error.localizedDescription
            }
        }
        .alert(
            "Export Failed",
            isPresented: Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })
        ) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "")
        }
        .onReceive(NotificationCenter.default.publisher(for: .petRequestAddExpense)) { _ in
            isPresentingAddSheet = true
        }
        .onReceive(NotificationCenter.default.publisher(for: .petRequestImportCSV)) { _ in
            isPresentingImportSheet = true
        }
    }

    private var emptyState: some View {
        ContentUnavailableView {
            Label("No Transactions Yet", systemImage: "tray")
        } description: {
            Text("Add your first expense manually, or import a Sparkasse CSV export.")
        } actions: {
            Button("Import CSV") { isPresentingImportSheet = true }
            Button("Add Expense") { isPresentingAddSheet = true }
                .buttonStyle(.borderedProminent)
        }
    }

    private var noResultsState: some View {
        ContentUnavailableView {
            Label("No Matching Transactions", systemImage: "line.3.horizontal.decrease.circle")
        } description: {
            Text("No transactions match the current search and filters.")
        } actions: {
            Button("Reset Filters") { filter.reset() }
        }
    }

    private var table: some View {
        Table(filteredTransactions, selection: $selection, sortOrder: $sortOrder) {
            TableColumn("Date", value: \.bookingDate) { transaction in
                Text(transaction.bookingDate, format: .dateTime.day().month().year())
            }
            .width(min: 90, ideal: 100)

            TableColumn("Merchant", value: \.merchant) { transaction in
                HStack(spacing: 4) {
                    Text(transaction.merchant)
                    if transaction.isRecurring {
                        Image(systemName: "repeat.circle.fill")
                            .foregroundStyle(.secondary)
                            .help("Recurring")
                            .accessibilityHidden(true)
                    }
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(transaction.isRecurring ? "\(transaction.merchant), recurring" : transaction.merchant)
            }
            .width(min: 140, ideal: 220)

            TableColumn("Category") { transaction in
                CategoryBadge(category: transaction.category)
            }
            .width(min: 100, ideal: 140)

            TableColumn("Amount", value: \.amount) { transaction in
                Text(transaction.amount, format: .currency(code: transaction.currencyCode))
                    .monospacedDigit()
                    .foregroundStyle(transaction.amount < 0 ? Color.red : Color.green)
            }
            .width(min: 90, ideal: 100)

            TableColumn("Source") { transaction in
                Text(transaction.source == .manual ? "Manual" : "Imported")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .width(min: 70, ideal: 90)
        }
        .contextMenu(forSelectionType: UUID.self) { ids in
            if ids.count == 1, let transaction = transaction(for: ids.first) {
                Button("Edit…") { editingTransaction = transaction }
            }
            Button(ids.count > 1 ? "Delete \(ids.count) Transactions" : "Delete", role: .destructive) {
                deleteSelection(ids)
            }
        } primaryAction: { ids in
            if ids.count == 1, let transaction = transaction(for: ids.first) {
                editingTransaction = transaction
            }
        }
        .onDeleteCommand {
            deleteSelection(selection)
        }
    }

    private func transaction(for id: UUID?) -> ExpenseTransaction? {
        guard let id else { return nil }
        return filteredTransactions.first { $0.id == id }
    }

    private func deleteSelection(_ ids: Set<UUID>) {
        let repository = TransactionRepository(context: modelContext)
        for transaction in filteredTransactions where ids.contains(transaction.id) {
            try? repository.delete(transaction)
        }
        selection.removeAll()
    }

    private func exportFilteredTransactions() {
        exportDocument = CSVDocument(data: TransactionCSVExporter.exportData(filteredTransactions))
        isPresentingExporter = true
    }
}
