import Foundation

public enum HoldingAssetType: String, Codable, CaseIterable, Sendable {
    case usEquity
    case physicalGold
}

public enum HoldingActivityType: String, Codable, CaseIterable, Sendable {
    case buy
    case sell
    case feeOnly
    case correction
}

public enum BalanceAccountKind: String, Codable, CaseIterable, Sendable {
    case cash
    case liability
}
