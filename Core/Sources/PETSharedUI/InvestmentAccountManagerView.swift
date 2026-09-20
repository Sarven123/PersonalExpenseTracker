import SwiftUI
import SwiftData
import PETModels
import PETRepositories

/// Manages `InvestmentAccount` labels (e.g. "Midas") — purely a place holdings live.
/// This view never asks for credentials and never talks to any external service; there is
/// nothing here to wire up to a brokerage API even by accident.
public struct InvestmentAccountManagerView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \InvestmentAccount.name) private var accounts: [InvestmentAccount]

    @State private var newAccountName = ""
    @State private var errorMessage: String?
    @State private var renamingAccount: InvestmentAccount?
    @State private var renameText = ""

    public init() {}

    public var body: some View {
        NavigationStack {
            List {
                Section("Investment Accounts") {
                    if accounts.isEmpty {
                        Text("No accounts yet.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    ForEach(accounts) { account in
                        HStack {
                            Label(account.name, systemImage: "building.columns")
                            if account.isArchived {
                                Spacer()
                                Text("Archived")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .contentShape(Rectangle())
                        .contextMenu {
                            Button("Rename…") {
                                renamingAccount = account
                                renameText = account.name
                            }
                            if !account.isArchived {
                                Button("Archive") { archive(account) }
                            }
                            Button("Delete", role: .destructive) { delete(account) }
                        }
                    }
                }
                Section("New Account") {
                    TextField("Name (e.g. Midas)", text: $newAccountName)
                    Button("Add Account") { addAccount() }
                        .disabled(newAccountName.trimmingCharacters(in: .whitespaces).isEmpty)
                }
                if let errorMessage {
                    Text(errorMessage)
                        .foregroundStyle(.red)
                        .font(.caption)
                }
            }
            .navigationTitle("Manage Investment Accounts")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .alert(
                "Rename Account",
                isPresented: Binding(
                    get: { renamingAccount != nil },
                    set: { isPresented in if !isPresented { renamingAccount = nil } }
                )
            ) {
                TextField("Name", text: $renameText)
                Button("Cancel", role: .cancel) { renamingAccount = nil }
                Button("Save") {
                    if let account = renamingAccount {
                        rename(account, to: renameText)
                    }
                    renamingAccount = nil
                }
            }
        }
        .frame(minWidth: 380, minHeight: 420)
    }

    private func addAccount() {
        do {
            try InvestmentAccountRepository(context: modelContext).create(name: newAccountName)
            newAccountName = ""
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func rename(_ account: InvestmentAccount, to newName: String) {
        do {
            try InvestmentAccountRepository(context: modelContext).rename(account, to: newName)
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func archive(_ account: InvestmentAccount) {
        try? InvestmentAccountRepository(context: modelContext).archive(account)
    }

    private func delete(_ account: InvestmentAccount) {
        try? InvestmentAccountRepository(context: modelContext).delete(account)
    }
}
