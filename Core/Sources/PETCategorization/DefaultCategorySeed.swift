import Foundation

public struct CategorySeedDefinition: Sendable {
    public let name: String
    public let colorHex: String
    public let symbolName: String
    public let sortOrder: Int
    public let isTransferCategory: Bool

    public init(
        name: String,
        colorHex: String,
        symbolName: String,
        sortOrder: Int,
        isTransferCategory: Bool = false
    ) {
        self.name = name
        self.colorHex = colorHex
        self.symbolName = symbolName
        self.sortOrder = sortOrder
        self.isTransferCategory = isTransferCategory
    }
}

public enum DefaultCategorySeed {
    public static let all: [CategorySeedDefinition] = [
        .init(name: "Food", colorHex: "#FF6B6B", symbolName: "fork.knife", sortOrder: 0),
        .init(name: "Transport", colorHex: "#4D96FF", symbolName: "car.fill", sortOrder: 1),
        .init(name: "Entertainment", colorHex: "#A78BFA", symbolName: "film.fill", sortOrder: 2),
        .init(name: "Subscriptions", colorHex: "#F472B6", symbolName: "repeat.circle.fill", sortOrder: 3),
        .init(name: "Housing", colorHex: "#F59E0B", symbolName: "house.fill", sortOrder: 4),
        .init(name: "Utilities", colorHex: "#FBBF24", symbolName: "bolt.fill", sortOrder: 5),
        .init(name: "Health", colorHex: "#34D399", symbolName: "cross.case.fill", sortOrder: 6),
        .init(name: "Shopping", colorHex: "#FB923C", symbolName: "bag.fill", sortOrder: 7),
        .init(name: "Travel", colorHex: "#22D3EE", symbolName: "airplane", sortOrder: 8),
        .init(name: "Education", colorHex: "#818CF8", symbolName: "book.fill", sortOrder: 9),
        .init(name: "Fees", colorHex: "#94A3B8", symbolName: "eurosign.circle.fill", sortOrder: 10),
        .init(name: "Income", colorHex: "#10B981", symbolName: "arrow.down.circle.fill", sortOrder: 11),
        .init(
            name: "Transfers",
            colorHex: "#64748B",
            symbolName: "arrow.left.arrow.right.circle.fill",
            sortOrder: 12,
            isTransferCategory: true
        ),
        .init(name: "Other", colorHex: "#9CA3AF", symbolName: "ellipsis.circle.fill", sortOrder: 13),
    ]
}
