import SwiftUI
import PETModels

public struct CategoryBadge: View {
    private let category: ExpenseCategory?

    public init(category: ExpenseCategory?) {
        self.category = category
    }

    public var body: some View {
        if let category {
            Label(category.name, systemImage: category.symbolName)
                .labelStyle(.titleAndIcon)
                .font(.caption.weight(.medium))
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(Color(hex: category.colorHex).opacity(0.18), in: Capsule())
                .foregroundStyle(Color(hex: category.colorHex))
        } else {
            Label("Uncategorized", systemImage: "questionmark.circle")
                .labelStyle(.titleAndIcon)
                .font(.caption.weight(.medium))
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(Color.secondary.opacity(0.15), in: Capsule())
                .foregroundStyle(.secondary)
        }
    }
}
