import Foundation

public enum AssetType: String, Codable, CaseIterable, Sendable {
    case usStock
    case usEtfOrFund
    case physicalGold
    case cash
    case other
}
