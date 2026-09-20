import SwiftUI
import SwiftData
import PETModels
import PETRepositories

extension AssetType {
    var displayName: String {
        switch self {
        case .usStock: "US Stock"
        case .usEtfOrFund: "US ETF / Fund"
        case .physicalGold: "Physical Gold"
        case .cash: "Cash"
        case .other: "Other"
        }
    }
}

/// A plain inventory screen — what you own and where, not a valuation or portfolio tool.
/// Deliberately shows no prices, totals, or currency-formatted values anywhere.
public struct AssetsView: View {
    private enum GroupingMode: String, CaseIterable, Identifiable {
        case name = "Name"
        case type = "Type"
        case location = "Account/Location"
        var id: String { rawValue }
    }

    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Asset.name) private var assets: [Asset]

    @State private var selection: Set<UUID> = []
    @State private var isPresentingAddSheet = false
    @State private var editingAsset: Asset?
    @State private var groupingMode: GroupingMode = .name
    @State private var errorMessage: String?

    public init() {}

    public var body: some View {
        Group {
            if assets.isEmpty {
                emptyState
            } else {
                table
            }
        }
        .navigationTitle("Assets")
        .toolbar {
            ToolbarItemGroup {
                Picker("Group By", selection: $groupingMode) {
                    ForEach(GroupingMode.allCases) { mode in
                        Text(mode.rawValue).tag(mode)
                    }
                }
                .pickerStyle(.menu)
                Button {
                    isPresentingAddSheet = true
                } label: {
                    Label("Add Asset", systemImage: "plus")
                }
            }
        }
        .sheet(isPresented: $isPresentingAddSheet) {
            AssetEditView(mode: .create)
        }
        .sheet(item: $editingAsset) { asset in
            AssetEditView(mode: .edit(asset))
        }
        .alert(
            "Something Went Wrong",
            isPresented: Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })
        ) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "")
        }
    }

    private var emptyState: some View {
        ContentUnavailableView {
            Label("No Assets Yet", systemImage: "archivebox")
        } description: {
            Text("Keep a simple inventory of what you own and where — a US stock or ETF, physical gold (e.g. 11 g at 995 purity), cash, or anything else. This is an inventory, not a valuation tool: no prices, no market data.")
        } actions: {
            Button("Add Asset") { isPresentingAddSheet = true }
                .buttonStyle(.borderedProminent)
        }
    }

    /// "Grouping" is implemented as a sort (like items cluster together, visible via the Type/
    /// Account column), not literal collapsible sections — `Table` doesn't support sectioning as
    /// naturally as `List`, and clustering-by-sort is a proportionate answer to a screen this size.
    private var sortedAssets: [Asset] {
        switch groupingMode {
        case .name:
            return assets
        case .type:
            return assets.sorted { lhs, rhs in
                lhs.assetType.displayName == rhs.assetType.displayName
                    ? lhs.name < rhs.name
                    : lhs.assetType.displayName < rhs.assetType.displayName
            }
        case .location:
            return assets.sorted { lhs, rhs in
                let lhsLocation = lhs.accountOrLocation ?? ""
                let rhsLocation = rhs.accountOrLocation ?? ""
                return lhsLocation == rhsLocation ? lhs.name < rhs.name : lhsLocation < rhsLocation
            }
        }
    }

    private var table: some View {
        Table(sortedAssets, selection: $selection) {
            TableColumn("Name") { asset in
                VStack(alignment: .leading, spacing: 2) {
                    Text(asset.name)
                    if let ticker = asset.ticker {
                        Text(ticker)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .width(min: 120, ideal: 180)

            TableColumn("Type") { asset in
                Text(asset.assetType.displayName)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .width(min: 90, ideal: 130)

            TableColumn("Account/Location") { asset in
                Text(asset.accountOrLocation ?? "—")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .width(min: 90, ideal: 140)

            TableColumn("Quantity") { asset in
                Text(quantityText(for: asset))
                    .monospacedDigit()
            }
            .width(min: 90, ideal: 130)

            TableColumn("Acquired") { asset in
                if let date = asset.acquisitionDate {
                    Text(date, format: .dateTime.day().month().year())
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    Text("—")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .width(min: 70, ideal: 100)
        }
        .contextMenu(forSelectionType: UUID.self) { ids in
            if ids.count == 1, let asset = asset(for: ids.first) {
                Button("Edit…") { editingAsset = asset }
            }
            Button(ids.count > 1 ? "Delete \(ids.count) Assets" : "Delete", role: .destructive) {
                deleteSelection(ids)
            }
        } primaryAction: { ids in
            if ids.count == 1, let asset = asset(for: ids.first) {
                editingAsset = asset
            }
        }
        .onDeleteCommand {
            deleteSelection(selection)
        }
    }

    private func quantityText(for asset: Asset) -> String {
        let quantityString = NumberFormatter.localizedString(from: asset.quantity as NSDecimalNumber, number: .decimal)
        if let purity = asset.purityPerMille {
            return "\(quantityString) \(asset.unit) · \(purity)‰"
        }
        return "\(quantityString) \(asset.unit)"
    }

    private func asset(for id: UUID?) -> Asset? {
        guard let id else { return nil }
        return assets.first { $0.id == id }
    }

    private func deleteSelection(_ ids: Set<UUID>) {
        let repository = AssetRepository(context: modelContext)
        for asset in assets where ids.contains(asset.id) {
            do {
                try repository.delete(asset)
            } catch {
                errorMessage = error.localizedDescription
            }
        }
        selection.removeAll()
    }
}
