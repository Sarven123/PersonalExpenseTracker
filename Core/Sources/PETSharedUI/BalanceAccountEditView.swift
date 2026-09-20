import SwiftUI
import SwiftData
import PETModels
import PETRepositories

public struct BalanceAccountEditView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var kind: BalanceAccountKind = .cash
    @State private var currencyCode = "EUR"
    @State private var initialBalance: Decimal = 0
    @State private var errorMessage: String?

    public init() {}

    public var body: some View {
        NavigationStack {
            Form {
                Section("Account") {
                    TextField("Name", text: $name)
                    Picker("Kind", selection: $kind) {
                        Text("Cash").tag(BalanceAccountKind.cash)
                        Text("Liability").tag(BalanceAccountKind.liability)
                    }
                    .pickerStyle(.segmented)
                    TextField("Currency Code", text: $currencyCode)
                }
                Section(kind == .cash ? "Current Balance" : "Current Amount Owed") {
                    TextField("Amount", value: $initialBalance, format: .number.precision(.fractionLength(2)))
                }
                if let errorMessage {
                    Text(errorMessage)
                        .foregroundStyle(.red)
                        .font(.caption)
                }
            }
            .formStyle(.grouped)
            .navigationTitle("Add Cash or Liability")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") { save() }
                        .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
        .frame(minWidth: 380, minHeight: 320)
    }

    private func save() {
        do {
            try BalanceAccountRepository(context: modelContext).create(
                name: name,
                kind: kind,
                currencyCode: currencyCode.uppercased(),
                initialBalance: initialBalance
            )
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
