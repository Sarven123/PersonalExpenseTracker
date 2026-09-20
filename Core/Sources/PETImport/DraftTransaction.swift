import Foundation
import PETModels

/// A parsed-but-not-yet-committed row from an imported CSV file. Phase 4's
/// import UI will turn these into `ExpenseTransaction`s (with user review
/// of duplicates and column mapping) rather than writing to SwiftData directly.
public struct DraftTransaction: Sendable, Equatable {
    public let sourceRowNumber: Int
    public let bookingDate: Date
    public let valueDate: Date?
    public let amount: Decimal
    public let currencyCode: String
    public let type: TransactionType
    public let merchant: String
    public let rawDescription: String
    public let purpose: String?
    public let bookingText: String?
    public let ownIBAN: String?
    public let counterpartyIBAN: String?
    public let bic: String?
    public let dedupeHash: String
}
