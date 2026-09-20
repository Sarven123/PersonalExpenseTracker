import SwiftUI
import SwiftData
import PETModels
import PETRepositories

public struct TransactionListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \ExpenseTransaction.bookingDate, order: .reverse) private var transactions: [ExpenseTransaction]

    @State private var editingTransaction: ExpenseTransaction?
    @State private var isPresentingAddSheet = false
    @State private var isPresentingCategoryManager = false
    @State private var isPresentingImportSheet = false
    @State private var isPresentingMerchantRuleManager = false
    @State private var showUncategorizedOnly = false

    public init() {}

    private var displayedTransactions: [ExpenseTransaction] {
        showUncategorizedOnly ? transactions.filter { $0.category == nil } : transactions
    }

    public var body: some View {
        Group {
            if transactions.isEmpty {
                emptyState
            } else if displayedTransactions.isEmpty {
                nothingToReviewState
            } else {
                list
            }
        }
        .navigationTitle("Transactions")
        .toolbar {
            ToolbarItemGroup {
                Toggle(isOn: $showUncategorizedOnly) {
                    Label("Uncategorized Only", systemImage: "questionmark.circle")
                }
                .toggleStyle(.button)
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

    private var nothingToReviewState: some View {
        ContentUnavailableView {
            Label("Nothing to Review", systemImage: "checkmark.circle")
        } description: {
            Text("Every transaction already has a category.")
        } actions: {
            Button("Show All Transactions") { showUncategorizedOnly = false }
        }
    }

    private var list: some View {
        List {
            ForEach(displayedTransactions) { transaction in
                Button {
                    editingTransaction = transaction
                } label: {
                    TransactionRow(transaction: transaction)
                }
                .buttonStyle(.plain)
                .contextMenu {
                    Button("Edit…") { editingTransaction = transaction }
                    Button("Delete", role: .destructive) { delete(transaction) }
                }
            }
            .onDelete(perform: deleteOffsets)
        }
    }

    private func delete(_ transaction: ExpenseTransaction) {
        try? TransactionRepository(context: modelContext).delete(transaction)
    }

    private func deleteOffsets(_ offsets: IndexSet) {
        let repository = TransactionRepository(context: modelContext)
        for index in offsets {
            try? repository.delete(displayedTransactions[index])
        }
    }
}

private struct TransactionRow: View {
    let transaction: ExpenseTransaction

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 4) {
                    Text(transaction.merchant)
                        .font(.body.weight(.medium))
                    if transaction.isRecurring {
                        Image(systemName: "repeat.circle.fill")
                            .foregroundStyle(.secondary)
                            .help("Recurring")
                    }
                }
                Text(transaction.bookingDate, format: .dateTime.day().month().year())
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            CategoryBadge(category: transaction.category)
            Text(transaction.amount, format: .currency(code: transaction.currencyCode))
                .monospacedDigit()
                .foregroundStyle(transaction.amount < 0 ? Color.red : Color.green)
                .frame(minWidth: 90, alignment: .trailing)
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
    }
}
