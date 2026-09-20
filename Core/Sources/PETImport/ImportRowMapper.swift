import Foundation
import PETModels

/// Maps one raw CSV data row to a `DraftTransaction` using a detected
/// `ColumnMapping`. Transaction type (expense vs. income) is derived purely
/// from the amount's sign here — recognizing transfers between the user's
/// own accounts is a rule-based classification job for Phase 5's
/// `CategoryRuleEngine`, not this parsing step.
public enum ImportRowMapper {
    public static func map(row: [String], mapping: ColumnMapping, rowNumber: Int) throws -> DraftTransaction {
        func value(_ field: SemanticField) -> String? {
            guard let idx = mapping.index(for: field), idx < row.count else { return nil }
            let trimmed = row[idx].trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.isEmpty ? nil : trimmed
        }

        guard let bookingDateRaw = value(.bookingDate) else {
            throw ImportError.malformedRow(line: rowNumber, reason: "Missing booking date")
        }
        guard let amountRaw = value(.amount) else {
            throw ImportError.malformedRow(line: rowNumber, reason: "Missing amount")
        }

        let bookingDate: Date
        do {
            bookingDate = try GermanDateParser.parse(bookingDateRaw)
        } catch {
            throw ImportError.invalidDate(line: rowNumber, rawValue: bookingDateRaw)
        }

        var valueDate: Date?
        if let valueDateRaw = value(.valueDate) {
            do {
                valueDate = try GermanDateParser.parse(valueDateRaw)
            } catch {
                throw ImportError.invalidDate(line: rowNumber, rawValue: valueDateRaw)
            }
        }

        let amount: Decimal
        do {
            amount = try GermanNumberParser.parse(amountRaw)
        } catch {
            throw ImportError.invalidAmount(line: rowNumber, rawValue: amountRaw)
        }

        let typeText = value(.typeText)
        let purpose = value(.purpose)
        let merchant = value(.counterpartyName) ?? "Unknown"
        let ownIBAN = value(.ownIBAN)
        let counterpartyIBAN = value(.counterpartyIBAN)
        let bic = value(.bic)
        let currencyCode = value(.currency) ?? "EUR"
        let type: TransactionType = amount < 0 ? .expense : .income
        let rawDescription = [typeText, purpose].compactMap { $0 }.joined(separator: " \u{2013} ")

        let dedupeHash = DuplicateDetector.computeHash(
            bookingDate: bookingDate,
            amount: amount,
            currencyCode: currencyCode,
            counterpartyIBAN: counterpartyIBAN,
            merchant: merchant,
            purpose: purpose
        )

        return DraftTransaction(
            sourceRowNumber: rowNumber,
            bookingDate: bookingDate,
            valueDate: valueDate,
            amount: amount,
            currencyCode: currencyCode,
            type: type,
            merchant: merchant,
            rawDescription: rawDescription,
            purpose: purpose,
            bookingText: typeText,
            ownIBAN: ownIBAN,
            counterpartyIBAN: counterpartyIBAN,
            bic: bic,
            dedupeHash: dedupeHash
        )
    }
}
