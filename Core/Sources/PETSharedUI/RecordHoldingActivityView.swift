import SwiftUI
import SwiftData
import PETModels
import PETRepositories

/// Records a buy or sell against an existing `Holding`. This is the only UI path allowed to
/// change a holding's quantity/average cost — see `HoldingRepository`'s doc comment.
public struct RecordHoldingActivityView: View {
    public enum ActivityKind {
        case buy
        case sell
    }

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    private let holding: Holding
    private let kind: ActivityKind

    @State private var quantity: Decimal
    @State private var pricePerUnit: Decimal
    @State private var currencyCode: String
    @State private var fee: Decimal = 0
    @State private var date: Date = .now
    @State private var errorMessage: String?

    public init(holding: Holding, kind: ActivityKind) {
        self.holding = holding
        self.kind = kind
        _quantity = State(initialValue: 0)
        _pricePerUnit = State(initialValue: holding.averageCostPerUnit)
        _currencyCode = State(initialValue: holding.purchaseCurrencyCode)
    }

    public var body: some View {
        NavigationStack {
            Form {
                Section(kind == .buy ? "Buy" : "Sell") {
                    TextField(
                        holding.assetType == .physicalGold ? "Quantity (grams)" : "Quantity (shares)",
                        value: $quantity,
                        format: .number
                    )
                    TextField("Price per Unit", value: $pricePerUnit, format: .number.precision(.fractionLength(2)))
                    TextField("Currency Code", text: $currencyCode)
                    TextField("Fee", value: $fee, format: .number.precision(.fractionLength(2)))
                    DatePicker("Date", selection: $date, displayedComponents: .date)
                }
                if kind == .sell {
                    Text("Currently holding \(NumberFormatter.localizedString(from: holding.quantity as NSDecimalNumber, number: .decimal)).")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                if let errorMessage {
                    Text(errorMessage)
                        .foregroundStyle(.red)
                        .font(.caption)
                }
            }
            .formStyle(.grouped)
            .navigationTitle(kind == .buy ? "Record Buy" : "Record Sell")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .disabled(quantity <= 0 || pricePerUnit <= 0)
                }
            }
        }
        .frame(minWidth: 380, minHeight: 360)
    }

    private func save() {
        let repository = HoldingRepository(context: modelContext)
        do {
            switch kind {
            case .buy:
                try repository.recordBuy(
                    holding,
                    quantity: quantity,
                    pricePerUnit: pricePerUnit,
                    currencyCode: currencyCode.uppercased(),
                    fee: fee,
                    date: date
                )
            case .sell:
                try repository.recordSell(
                    holding,
                    quantity: quantity,
                    pricePerUnit: pricePerUnit,
                    currencyCode: currencyCode.uppercased(),
                    fee: fee,
                    date: date
                )
            }
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
