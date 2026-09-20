import SwiftUI
import SwiftData
import PETModels
import PETRepositories

public struct AssetEditView: View {
    public enum Mode {
        case create
        case edit(Asset)
    }

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    private let mode: Mode

    @State private var name: String
    @State private var ticker: String
    @State private var assetType: AssetType
    @State private var accountOrLocation: String
    @State private var quantity: Decimal
    @State private var unit: String
    @State private var purityPerMille: Int
    @State private var hasAcquisitionDate: Bool
    @State private var acquisitionDate: Date
    @State private var notes: String
    @State private var errorMessage: String?

    public init(mode: Mode) {
        self.mode = mode
        switch mode {
        case .create:
            _name = State(initialValue: "")
            _ticker = State(initialValue: "")
            _assetType = State(initialValue: .usStock)
            _accountOrLocation = State(initialValue: "")
            _quantity = State(initialValue: 0)
            _unit = State(initialValue: "shares")
            _purityPerMille = State(initialValue: 995)
            _hasAcquisitionDate = State(initialValue: false)
            _acquisitionDate = State(initialValue: .now)
            _notes = State(initialValue: "")
        case .edit(let asset):
            _name = State(initialValue: asset.name)
            _ticker = State(initialValue: asset.ticker ?? "")
            _assetType = State(initialValue: asset.assetType)
            _accountOrLocation = State(initialValue: asset.accountOrLocation ?? "")
            _quantity = State(initialValue: asset.quantity)
            _unit = State(initialValue: asset.unit)
            _purityPerMille = State(initialValue: asset.purityPerMille ?? 995)
            _hasAcquisitionDate = State(initialValue: asset.acquisitionDate != nil)
            _acquisitionDate = State(initialValue: asset.acquisitionDate ?? .now)
            _notes = State(initialValue: asset.notes ?? "")
        }
    }

    private var isEditing: Bool {
        if case .edit = mode { return true }
        return false
    }

    public var body: some View {
        NavigationStack {
            Form {
                Section("Asset") {
                    TextField("Name", text: $name)
                    TextField("Ticker / Symbol (optional)", text: $ticker)
                    Picker("Type", selection: $assetType) {
                        ForEach(AssetType.allCases, id: \.self) { type in
                            Text(type.displayName).tag(type)
                        }
                    }
                    .onChange(of: assetType) { _, newValue in
                        applyDefaultUnit(for: newValue)
                    }
                    if assetType == .physicalGold {
                        Stepper("Purity: \(purityPerMille)/1000", value: $purityPerMille, in: 1...999)
                    }
                }
                Section("Quantity") {
                    TextField("Quantity", value: $quantity, format: .number)
                    TextField("Unit (e.g. shares, grams, EUR)", text: $unit)
                }
                Section("Location") {
                    TextField("Account or Location (e.g. Midas, Physical Storage)", text: $accountOrLocation)
                }
                Section("Acquisition") {
                    Toggle("Acquisition Date Known", isOn: $hasAcquisitionDate)
                    if hasAcquisitionDate {
                        DatePicker("Acquisition Date", selection: $acquisitionDate, displayedComponents: .date)
                    }
                }
                Section("Notes") {
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
            .navigationTitle(isEditing ? "Edit Asset" : "Add Asset")
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
        .frame(minWidth: 420, minHeight: 480)
    }

    private var isValid: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty
            && quantity > 0
            && !unit.trimmingCharacters(in: .whitespaces).isEmpty
    }

    private static let defaultUnits: Set<String> = ["shares", "grams", "EUR"]

    private func applyDefaultUnit(for type: AssetType) {
        let trimmed = unit.trimmingCharacters(in: .whitespaces)
        guard trimmed.isEmpty || Self.defaultUnits.contains(trimmed) else { return }
        switch type {
        case .usStock, .usEtfOrFund:
            unit = "shares"
        case .physicalGold:
            unit = "grams"
        case .cash:
            unit = "EUR"
        case .other:
            unit = ""
        }
    }

    private func save() {
        let repository = AssetRepository(context: modelContext)
        do {
            switch mode {
            case .create:
                try repository.create(
                    name: name,
                    ticker: ticker.isEmpty ? nil : ticker,
                    assetType: assetType,
                    accountOrLocation: accountOrLocation.isEmpty ? nil : accountOrLocation,
                    quantity: quantity,
                    unit: unit,
                    purityPerMille: assetType == .physicalGold ? purityPerMille : nil,
                    acquisitionDate: hasAcquisitionDate ? acquisitionDate : nil,
                    notes: notes.isEmpty ? nil : notes
                )
            case .edit(let asset):
                try repository.update(
                    asset,
                    name: name,
                    ticker: ticker.isEmpty ? nil : ticker,
                    assetType: assetType,
                    accountOrLocation: accountOrLocation.isEmpty ? nil : accountOrLocation,
                    quantity: quantity,
                    unit: unit,
                    purityPerMille: assetType == .physicalGold ? purityPerMille : nil,
                    acquisitionDate: hasAcquisitionDate ? acquisitionDate : nil,
                    notes: notes.isEmpty ? nil : notes
                )
            }
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
