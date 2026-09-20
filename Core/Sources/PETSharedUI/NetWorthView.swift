import SwiftUI
import SwiftData
import PETModels
import PETRepositories

public struct NetWorthView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Holding.createdAt, order: .reverse) private var allHoldings: [Holding]
    @Query(sort: \BalanceAccount.createdAt, order: .reverse) private var allBalanceAccounts: [BalanceAccount]

    @State private var holdingSelection: Set<UUID> = []
    @State private var isPresentingAddHolding = false
    @State private var editingHolding: Holding?
    @State private var activityRequest: ActivityRequest?
    @State private var isPresentingAddBalanceAccount = false
    @State private var isPresentingAccountManager = false
    @State private var updatingBalanceAccount: BalanceAccount?
    @State private var newBalanceText = ""
    @State private var errorMessage: String?

    public init() {}

    private var holdings: [Holding] { allHoldings.filter { !$0.isArchived } }
    private var balanceAccounts: [BalanceAccount] { allBalanceAccounts.filter { !$0.isArchived } }

    public var body: some View {
        Group {
            if holdings.isEmpty && balanceAccounts.isEmpty {
                emptyState
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 28) {
                        holdingsSection
                        balancesSection
                    }
                    .padding(24)
                }
            }
        }
        .navigationTitle("Net Worth")
        .toolbar {
            ToolbarItemGroup {
                Button {
                    isPresentingAccountManager = true
                } label: {
                    Label("Manage Accounts", systemImage: "building.columns")
                }
                Button {
                    isPresentingAddBalanceAccount = true
                } label: {
                    Label("Add Cash or Liability", systemImage: "banknote")
                }
                Button {
                    isPresentingAddHolding = true
                } label: {
                    Label("Add Holding", systemImage: "plus")
                }
            }
        }
        .sheet(isPresented: $isPresentingAddHolding) {
            HoldingEditView(mode: .create)
        }
        .sheet(item: $editingHolding) { holding in
            HoldingEditView(mode: .edit(holding))
        }
        .sheet(item: $activityRequest) { request in
            RecordHoldingActivityView(holding: request.holding, kind: request.kind)
        }
        .sheet(isPresented: $isPresentingAddBalanceAccount) {
            BalanceAccountEditView()
        }
        .sheet(isPresented: $isPresentingAccountManager) {
            InvestmentAccountManagerView()
        }
        .alert(
            "Update Balance",
            isPresented: Binding(
                get: { updatingBalanceAccount != nil },
                set: { isPresented in if !isPresented { updatingBalanceAccount = nil } }
            )
        ) {
            TextField("Amount", text: $newBalanceText)
            Button("Cancel", role: .cancel) { updatingBalanceAccount = nil }
            Button("Save") { saveBalanceUpdate() }
        } message: {
            Text("Enter the current balance for \(updatingBalanceAccount?.name ?? "this account").")
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
            Label("No Net Worth Data Yet", systemImage: "chart.line.uptrend.xyaxis")
        } description: {
            Text("Add a US stock or ETF, your physical gold holding, or track a cash balance or liability. This is a tracking tool only — nothing here places trades or shares data with anyone.")
        } actions: {
            Button("Add Holding") { isPresentingAddHolding = true }
                .buttonStyle(.borderedProminent)
            Button("Add Cash or Liability") { isPresentingAddBalanceAccount = true }
        }
    }

    private var holdingsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Holdings")
                .font(.headline)
            if holdings.isEmpty {
                Text("No holdings yet.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                Table(holdings, selection: $holdingSelection) {
                    TableColumn("Asset") { holding in
                        VStack(alignment: .leading, spacing: 2) {
                            Text(assetTitle(for: holding))
                            Text(assetSubtitle(for: holding))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .width(min: 140, ideal: 200)

                    TableColumn("Quantity") { holding in
                        Text(quantityText(for: holding))
                            .monospacedDigit()
                    }
                    .width(min: 70, ideal: 90)

                    TableColumn("Avg Cost") { holding in
                        Text(holding.averageCostPerUnit, format: .currency(code: holding.purchaseCurrencyCode))
                            .monospacedDigit()
                    }
                    .width(min: 90, ideal: 110)

                    TableColumn("Current Price") { holding in
                        if let price = holding.manualCurrentPricePerUnit {
                            Text(price, format: .currency(code: holding.purchaseCurrencyCode))
                                .monospacedDigit()
                        } else {
                            Text("Not set")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .width(min: 90, ideal: 110)

                    TableColumn("Account") { holding in
                        Text(holding.account?.name ?? "Unassigned")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .width(min: 80, ideal: 120)
                }
                .frame(minHeight: min(CGFloat(holdings.count) * 32 + 40, 320))
                .contextMenu(forSelectionType: UUID.self) { ids in
                    if ids.count == 1, let holding = holding(for: ids.first) {
                        Button("Edit…") { editingHolding = holding }
                        Button("Record Buy…") { activityRequest = ActivityRequest(holding: holding, kind: .buy) }
                        Button("Record Sell…") { activityRequest = ActivityRequest(holding: holding, kind: .sell) }
                        Button("Archive") { archive(holding) }
                    }
                    Button(ids.count > 1 ? "Delete \(ids.count) Holdings" : "Delete", role: .destructive) {
                        deleteHoldings(ids)
                    }
                } primaryAction: { ids in
                    if ids.count == 1, let holding = holding(for: ids.first) {
                        editingHolding = holding
                    }
                }
            }
        }
    }

    private var balancesSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Cash & Liabilities")
                .font(.headline)
            if balanceAccounts.isEmpty {
                Text("No cash or liability accounts yet.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                VStack(spacing: 0) {
                    ForEach(balanceAccounts) { account in
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(account.name)
                                Text(account.kind == .cash ? "Cash" : "Liability")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Text(latestBalance(for: account), format: .currency(code: account.currencyCode))
                                .monospacedDigit()
                            Button("Update…") {
                                updatingBalanceAccount = account
                                newBalanceText = "\(latestBalance(for: account))"
                            }
                            .buttonStyle(.borderless)
                        }
                        .padding(.vertical, 6)
                        if account.id != balanceAccounts.last?.id {
                            Divider()
                        }
                    }
                }
            }
        }
    }

    private func assetTitle(for holding: Holding) -> String {
        holding.displayName ?? holding.ticker ?? (holding.assetType == .physicalGold ? "Physical Gold" : "Untitled Holding")
    }

    private func assetSubtitle(for holding: Holding) -> String {
        switch holding.assetType {
        case .usEquity:
            holding.ticker ?? "—"
        case .physicalGold:
            holding.purityPerMille.map { "\($0)/1000 purity" } ?? "Physical gold"
        }
    }

    private func quantityText(for holding: Holding) -> String {
        let unit = holding.assetType == .physicalGold ? "g" : ""
        return "\(NumberFormatter.localizedString(from: holding.quantity as NSDecimalNumber, number: .decimal))\(unit)"
    }

    private func latestBalance(for account: BalanceAccount) -> Decimal {
        account.snapshots?.max(by: { $0.asOfDate < $1.asOfDate })?.amount ?? 0
    }

    private func holding(for id: UUID?) -> Holding? {
        guard let id else { return nil }
        return holdings.first { $0.id == id }
    }

    private func archive(_ holding: Holding) {
        try? HoldingRepository(context: modelContext).archive(holding)
    }

    private func deleteHoldings(_ ids: Set<UUID>) {
        let repository = HoldingRepository(context: modelContext)
        for holding in holdings where ids.contains(holding.id) {
            try? repository.delete(holding)
        }
        holdingSelection.removeAll()
    }

    private func saveBalanceUpdate() {
        guard let account = updatingBalanceAccount, let amount = Decimal(string: newBalanceText) else {
            updatingBalanceAccount = nil
            return
        }
        do {
            try BalanceAccountRepository(context: modelContext).recordSnapshot(for: account, amount: amount)
        } catch {
            errorMessage = error.localizedDescription
        }
        updatingBalanceAccount = nil
    }
}

private struct ActivityRequest: Identifiable {
    let id = UUID()
    let holding: Holding
    let kind: RecordHoldingActivityView.ActivityKind
}
