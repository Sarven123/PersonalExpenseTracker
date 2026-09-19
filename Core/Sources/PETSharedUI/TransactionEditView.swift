import SwiftUI
import SwiftData
import PETModels
import PETRepositories

public struct TransactionEditView: View {
    public enum Mode {
        case create
        case edit(ExpenseTransaction)
    }

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \ExpenseCategory.sortOrder) private var categories: [ExpenseCategory]

    private let mode: Mode

    @State private var date: Date
    @State private var magnitude: Decimal
    @State private var type: TransactionType
    @State private var merchant: String
    @State private var notes: String
    @State private var categoryID: PersistentIdentifier?
    @State private var isRecurring: Bool
    @State private var errorMessage: String?

    public init(mode: Mode) {
        self.mode = mode
        switch mode {
        case .create:
            _date = State(initialValue: .now)
            _magnitude = State(initialValue: 0)
            _type = State(initialValue: .expense)
            _merchant = State(initialValue: "")
            _notes = State(initialValue: "")
            _categoryID = State(initialValue: nil)
            _isRecurring = State(initialValue: false)
        case .edit(let transaction):
            _date = State(initialValue: transaction.bookingDate)
            _magnitude = State(initialValue: abs(transaction.amount))
            _type = State(initialValue: transaction.type)
            _merchant = State(initialValue: transaction.merchant)
            _notes = State(initialValue: transaction.notes ?? "")
            _categoryID = State(initialValue: transaction.category?.persistentModelID)
            _isRecurring = State(initialValue: transaction.isRecurring)
        }
    }

    private var isEditing: Bool {
        if case .edit = mode { return true }
        return false
    }

    public var body: some View {
        NavigationStack {
            Form {
                Section("Details") {
                    TextField("Merchant / Title", text: $merchant)
                    DatePicker("Date", selection: $date, displayedComponents: .date)
                    Picker("Type", selection: $type) {
                        Text("Expense").tag(TransactionType.expense)
                        Text("Income").tag(TransactionType.income)
                        Text("Transfer").tag(TransactionType.transfer)
                    }
                    .pickerStyle(.segmented)
                    TextField("Amount", value: $magnitude, format: .currency(code: "EUR"))
                }
                Section("Category") {
                    Picker("Category", selection: $categoryID) {
                        Text("Uncategorized").tag(nil as PersistentIdentifier?)
                        ForEach(categories) { category in
                            Label(category.name, systemImage: category.symbolName)
                                .tag(Optional(category.persistentModelID))
                        }
                    }
                }
                Section("Notes") {
                    TextField("Notes", text: $notes, axis: .vertical)
                        .lineLimit(3...6)
                    Toggle("Recurring", isOn: $isRecurring)
                }
                if let errorMessage {
                    Text(errorMessage)
                        .foregroundStyle(.red)
                        .font(.caption)
                }
            }
            .formStyle(.grouped)
            .navigationTitle(isEditing ? "Edit Transaction" : "Add Expense")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(isEditing ? "Save" : "Add") { save() }
                        .disabled(merchant.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
        .frame(minWidth: 440, minHeight: 480)
    }

    private func save() {
        let category = categoryID.flatMap { id in categories.first(where: { $0.persistentModelID == id }) }
        let repository = TransactionRepository(context: modelContext)
        do {
            switch mode {
            case .create:
                try repository.createManualTransaction(
                    date: date,
                    magnitude: magnitude,
                    type: type,
                    merchant: merchant,
                    notes: notes,
                    category: category,
                    isRecurring: isRecurring
                )
            case .edit(let transaction):
                try repository.update(
                    transaction,
                    date: date,
                    magnitude: magnitude,
                    type: type,
                    merchant: merchant,
                    notes: notes,
                    category: category,
                    isRecurring: isRecurring
                )
            }
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
