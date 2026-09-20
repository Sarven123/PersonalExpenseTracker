import SwiftUI
import SwiftData
import PETModels
import PETRepositories

public struct MerchantRuleManagerView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \MerchantRule.priority, order: .reverse) private var rules: [MerchantRule]

    @State private var errorMessage: String?

    public init() {}

    public var body: some View {
        NavigationStack {
            List {
                if rules.isEmpty {
                    ContentUnavailableView(
                        "No Merchant Rules Yet",
                        systemImage: "wand.and.stars",
                        description: Text("Rules appear automatically once built-in defaults are seeded, or when you categorize a transaction.")
                    )
                }
                if !userRules.isEmpty {
                    Section("Your Rules") {
                        ForEach(userRules) { rule in
                            MerchantRuleRow(rule: rule)
                                .contextMenu {
                                    Button("Delete", role: .destructive) { delete(rule) }
                                }
                        }
                    }
                }
                if !builtInRules.isEmpty {
                    Section("Built-in Rules") {
                        ForEach(builtInRules) { rule in
                            MerchantRuleRow(rule: rule)
                        }
                    }
                }
                if let errorMessage {
                    Text(errorMessage)
                        .foregroundStyle(.red)
                        .font(.caption)
                }
            }
            .navigationTitle("Merchant Rules")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .frame(minWidth: 460, minHeight: 480)
    }

    private var userRules: [MerchantRule] { rules.filter { $0.origin == .userCorrection } }
    private var builtInRules: [MerchantRule] { rules.filter { $0.origin == .builtIn } }

    private func delete(_ rule: MerchantRule) {
        do {
            try MerchantRuleRepository(context: modelContext).delete(rule)
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

private struct MerchantRuleRow: View {
    let rule: MerchantRule

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(rule.pattern)
                    .font(.body.weight(.medium))
                Text(matchTypeLabel)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            CategoryBadge(category: rule.category)
            if rule.matchCount > 0 {
                Text("\(rule.matchCount)×")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(minWidth: 28, alignment: .trailing)
            }
        }
        .padding(.vertical, 2)
    }

    private var matchTypeLabel: String {
        switch rule.matchType {
        case .contains: "contains"
        case .exact: "exact match"
        case .startsWith: "starts with"
        case .regex: "regex"
        }
    }
}
