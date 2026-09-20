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

    public init() {}

    public var body: some View {
        Group {
            if transactions.isEmpty {
                emptyState
            } else {
                list
            }
        }
        .navigationTitle("Transactions")
        .toolbar {
            ToolbarItemGroup {
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

    private var list: some View {
        List {
            ForEach(transactions) { transaction in
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
            try? repository.delete(transactions[index])
        }
    }
}

private struct TransactionRow: View {
    let transaction: ExpenseTransaction

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(transaction.merchant)
                    .font(.body.weight(.medium))
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
