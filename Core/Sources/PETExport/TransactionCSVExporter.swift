import Foundation
import PETModels

/// Exports transactions to a general-purpose CSV: English column headers
/// (matching the app's UI language) with German-formatted date/amount
/// values (matching the app's data conventions). Not meant to be
/// re-imported through the Sparkasse-specific `CSVImportPipeline` — this is
/// a plain data export/backup format, quote-escaped per RFC 4180.
public enum TransactionCSVExporter {
    private static let header = "Date;Value Date;Category;Merchant;Purpose;Amount;Currency;Type;Source;Notes"

    public static func export(_ transactions: [ExpenseTransaction]) -> String {
        ([header] + transactions.map(row)).joined(separator: "\r\n")
    }

    public static func exportData(_ transactions: [ExpenseTransaction]) -> Data {
        let bom = Data([0xEF, 0xBB, 0xBF])
        return bom + Data(export(transactions).utf8)
    }

    private static func row(for transaction: ExpenseTransaction) -> String {
        [
            GermanExportFormatters.formatDate(transaction.bookingDate),
            transaction.valueDate.map(GermanExportFormatters.formatDate) ?? "",
            transaction.category?.name ?? "",
            transaction.merchant,
            transaction.purpose ?? "",
            GermanExportFormatters.formatAmount(transaction.amount),
            transaction.currencyCode,
            typeLabel(transaction.type),
            sourceLabel(transaction.source),
            transaction.notes ?? "",
        ]
        .map(quoted)
        .joined(separator: ";")
    }

    private static func quoted(_ field: String) -> String {
        guard field.contains(";") || field.contains("\"") || field.contains("\n") || field.contains("\r") else {
            return field
        }
        return "\"\(field.replacingOccurrences(of: "\"", with: "\"\""))\""
    }

    private static func typeLabel(_ type: TransactionType) -> String {
        switch type {
        case .expense: "Expense"
        case .income: "Income"
        case .transfer: "Transfer"
        }
    }

    private static func sourceLabel(_ source: TransactionSource) -> String {
        switch source {
        case .manual: "Manual"
        case .imported: "Imported"
        }
    }
}
