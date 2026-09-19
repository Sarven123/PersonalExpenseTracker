import Foundation
import SwiftData

@Model
public final class ExpenseTransaction {
    @Attribute(.unique) public var id: UUID
    public var bookingDate: Date
    public var valueDate: Date?
    public var amount: Decimal
    public var currencyCode: String
    public var type: TransactionType
    public var merchant: String
    public var rawDescription: String
    public var purpose: String?
    public var bookingText: String?
    public var iban: String?
    public var counterpartyIBAN: String?
    public var notes: String?
    public var isRecurring: Bool
    public var source: TransactionSource
    public var isExcludedFromAnalytics: Bool
    public var dedupeHash: String
    public var categorySuggestionSource: String?
    public var createdAt: Date
    public var modifiedAt: Date

    public var category: ExpenseCategory?
    public var importBatch: ImportBatch?
    public var recurringSchedule: RecurringSchedule?

    public init(
        id: UUID = UUID(),
        bookingDate: Date,
        valueDate: Date? = nil,
        amount: Decimal,
        currencyCode: String = "EUR",
        type: TransactionType,
        merchant: String,
        rawDescription: String,
        purpose: String? = nil,
        bookingText: String? = nil,
        iban: String? = nil,
        counterpartyIBAN: String? = nil,
        notes: String? = nil,
        isRecurring: Bool = false,
        source: TransactionSource = .manual,
        isExcludedFromAnalytics: Bool = false,
        dedupeHash: String = "",
        categorySuggestionSource: String? = nil,
        createdAt: Date = .now,
        modifiedAt: Date = .now,
        category: ExpenseCategory? = nil,
        importBatch: ImportBatch? = nil,
        recurringSchedule: RecurringSchedule? = nil
    ) {
        self.id = id
        self.bookingDate = bookingDate
        self.valueDate = valueDate
        self.amount = amount
        self.currencyCode = currencyCode
        self.type = type
        self.merchant = merchant
        self.rawDescription = rawDescription
        self.purpose = purpose
        self.bookingText = bookingText
        self.iban = iban
        self.counterpartyIBAN = counterpartyIBAN
        self.notes = notes
        self.isRecurring = isRecurring
        self.source = source
        self.isExcludedFromAnalytics = isExcludedFromAnalytics
        self.dedupeHash = dedupeHash
        self.categorySuggestionSource = categorySuggestionSource
        self.createdAt = createdAt
        self.modifiedAt = modifiedAt
        self.category = category
        self.importBatch = importBatch
        self.recurringSchedule = recurringSchedule
    }
}
