import SwiftUI
import SwiftData
import PETModels
import PETRepositories

public struct HoldingEditView: View {
    public enum Mode {
        case create
        case edit(Holding)
    }

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \InvestmentAccount.name) private var accounts: [InvestmentAccount]

    private let mode: Mode

    // Create-only fields (the asset type/ticker/purity/quantity/cost basis are fixed at
    // creation — later changes to quantity/cost go through Record Buy/Sell, never a plain edit).
    @State private var assetType: HoldingAssetType
    @State private var ticker: String
    @State private var initialQuantity: Decimal
    @State private var purityPerMille: Int
    @State private var pricePerUnit: Decimal
    @State private var purchaseCurrencyCode: String
    @State private var hasPurchaseDate: Bool
    @State private var purchaseDate: Date
    @State private var fee: Decimal

    // Shared/edit fields
    @State private var displayName: String
    @State private var notes: String
    @State private var accountID: UUID?
    @State private var manualPrice: Decimal
    @State private var hasManualPrice: Bool

    @State private var errorMessage: String?

    public init(mode: Mode) {
        self.mode = mode
        switch mode {
        case .create:
            _assetType = State(initialValue: .usEquity)
            _ticker = State(initialValue: "")
            _initialQuantity = State(initialValue: 0)
            _purityPerMille = State(initialValue: 995)
            _pricePerUnit = State(initialValue: 0)
            _purchaseCurrencyCode = State(initialValue: "USD")
            _hasPurchaseDate = State(initialValue: false)
            _purchaseDate = State(initialValue: .now)
            _fee = State(initialValue: 0)
            _displayName = State(initialValue: "")
            _notes = State(initialValue: "")
            _accountID = State(initialValue: nil)
            _manualPrice = State(initialValue: 0)
            _hasManualPrice = State(initialValue: false)
        case .edit(let holding):
            _assetType = State(initialValue: holding.assetType)
            _ticker = State(initialValue: holding.ticker ?? "")
            _initialQuantity = State(initialValue: holding.quantity)
            _purityPerMille = State(initialValue: holding.purityPerMille ?? 995)
            _pricePerUnit = State(initialValue: holding.averageCostPerUnit)
            _purchaseCurrencyCode = State(initialValue: holding.purchaseCurrencyCode)
            _hasPurchaseDate = State(initialValue: holding.firstPurchaseDate != nil)
            _purchaseDate = State(initialValue: holding.firstPurchaseDate ?? .now)
            _fee = State(initialValue: 0)
            _displayName = State(initialValue: holding.displayName ?? "")
            _notes = State(initialValue: holding.notes ?? "")
            _accountID = State(initialValue: holding.account?.id)
            _manualPrice = State(initialValue: holding.manualCurrentPricePerUnit ?? 0)
            _hasManualPrice = State(initialValue: holding.manualCurrentPricePerUnit != nil)
        }
    }

    private var isEditing: Bool {
        if case .edit = mode { return true }
        return false
    }

    private var editingHolding: Holding? {
        if case .edit(let holding) = mode { return holding }
        return nil
    }

    public var body: some View {
        NavigationStack {
            Form {
                if !isEditing {
                    Section("Asset") {
                        Picker("Type", selection: $assetType) {
                            Text("US Stock / ETF").tag(HoldingAssetType.usEquity)
                            Text("Physical Gold").tag(HoldingAssetType.physicalGold)
                        }
                        .pickerStyle(.segmented)
                        if assetType == .usEquity {
                            TextField("Ticker", text: $ticker)
                        } else {
                            Stepper("Purity: \(purityPerMille)/1000", value: $purityPerMille, in: 1...999)
                        }
                    }
                    Section("Initial Purchase") {
                        TextField(
                            assetType == .physicalGold ? "Quantity (grams)" : "Quantity (shares)",
                            value: $initialQuantity,
                            format: .number
                        )
                        TextField("Price per Unit", value: $pricePerUnit, format: .number.precision(.fractionLength(2)))
                        TextField("Currency Code", text: $purchaseCurrencyCode)
                        TextField("Fee", value: $fee, format: .number.precision(.fractionLength(2)))
                        Toggle("Purchase Date Known", isOn: $hasPurchaseDate)
                        if hasPurchaseDate {
                            DatePicker("Purchase Date", selection: $purchaseDate, displayedComponents: .date)
                        } else {
                            Text("A future phase's historical value chart will start from today for this holding, instead of a purchase date.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                } else {
                    Section("Position") {
                        LabeledContent("Quantity", value: quantityText)
                        LabeledContent("Average Cost", value: averageCostText)
                        Text("Use “Record Buy…”/“Record Sell…” from the holdings list to change quantity or cost — this sheet only edits metadata.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Section("Current Price (Manual)") {
                        Toggle("Set a manual price", isOn: $hasManualPrice)
                        if hasManualPrice {
                            TextField("Price per Unit", value: $manualPrice, format: .number.precision(.fractionLength(2)))
                        }
                    }
                }
                Section("Details") {
                    TextField("Display Name", text: $displayName)
                    Picker("Account", selection: $accountID) {
                        Text("Unassigned").tag(nil as UUID?)
                        ForEach(accounts) { account in
                            Text(account.name).tag(Optional(account.id))
                        }
                    }
                    TextField("Notes", text: $notes, axis: .vertical)
                        .lineLimit(2...4)
                }
                if let errorMessage {
                    Text(errorMessage)
                        .foregroundStyle(.red)
                        .font(.caption)
                }
            }
            .formStyle(.grouped)
            .navigationTitle(isEditing ? "Edit Holding" : "Add Holding")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(isEditing ? "Save" : "Add") { save() }
                        .disabled(!isValid)
                }
            }
        }
        .frame(minWidth: 440, minHeight: 480)
    }

    private var quantityText: String {
        guard let holding = editingHolding else { return "" }
        let unit = holding.assetType == .physicalGold ? " g" : ""
        return "\(NumberFormatter.localizedString(from: holding.quantity as NSDecimalNumber, number: .decimal))\(unit)"
    }

    private var averageCostText: String {
        guard let holding = editingHolding else { return "" }
        return holding.averageCostPerUnit.formatted(.currency(code: holding.purchaseCurrencyCode))
    }

    private var isValid: Bool {
        if isEditing { return true }
        guard initialQuantity > 0, pricePerUnit > 0,
              !purchaseCurrencyCode.trimmingCharacters(in: .whitespaces).isEmpty else { return false }
        if assetType == .usEquity, ticker.trimmingCharacters(in: .whitespaces).isEmpty { return false }
        return true
    }

    private func save() {
        let repository = HoldingRepository(context: modelContext)
        let account = accountID.flatMap { id in accounts.first(where: { $0.id == id }) }
        do {
            switch mode {
            case .create:
                try repository.createHolding(
                    assetType: assetType,
                    ticker: assetType == .usEquity ? ticker : nil,
                    displayName: displayName.isEmpty ? nil : displayName,
                    initialQuantity: initialQuantity,
                    purityPerMille: assetType == .physicalGold ? purityPerMille : nil,
                    pricePerUnit: pricePerUnit,
                    purchaseCurrencyCode: purchaseCurrencyCode.uppercased(),
                    purchaseDate: hasPurchaseDate ? purchaseDate : nil,
                    fee: fee,
                    account: account,
                    notes: notes.isEmpty ? nil : notes
                )
            case .edit(let holding):
                try repository.editMetadata(holding, displayName: displayName, notes: notes, account: account)
                if hasManualPrice {
                    try repository.setManualPrice(holding, pricePerUnit: manualPrice)
                }
            }
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
