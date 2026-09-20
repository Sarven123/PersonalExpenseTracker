import Foundation
import Testing
import PETModels
@testable import PETExport

@Suite("TransactionCSVExporter")
struct TransactionCSVExporterTests {
    private static var bookingDate: Date {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        return calendar.date(from: DateComponents(year: 2026, month: 9, day: 1))!
    }

    private static func transaction(
        merchant: String = "REWE Markt GmbH",
        purpose: String? = "REWE SAGT DANKE",
        amount: Decimal = Decimal(string: "-42.17")!,
        type: TransactionType = .expense,
        category: ExpenseCategory? = nil,
        notes: String? = nil,
        source: TransactionSource = .manual
    ) -> ExpenseTransaction {
        ExpenseTransaction(
            bookingDate: bookingDate,
            amount: amount,
            type: type,
            merchant: merchant,
            rawDescription: merchant,
            purpose: purpose,
            notes: notes,
            source: source,
            category: category
        )
    }

    @Test("exports a header row followed by one row per transaction")
    func exportsHeaderAndRows() {
        let csv = TransactionCSVExporter.export([Self.transaction(), Self.transaction()])
        let lines = csv.components(separatedBy: "\r\n")
        #expect(lines.count == 3)
        #expect(lines[0] == "Date;Value Date;Category;Merchant;Purpose;Amount;Currency;Type;Source;Notes")
    }

    @Test("formats amount and date using German conventions")
    func formatsRowFields() {
        let csv = TransactionCSVExporter.export([Self.transaction()])
        let row = csv.components(separatedBy: "\r\n")[1]
        #expect(row.contains("01.09.2026"))
        #expect(row.contains("-42,17"))
        #expect(row.contains("REWE Markt GmbH"))
        #expect(row.contains("Expense"))
        #expect(row.contains("Manual"))
    }

    @Test("quotes a field containing the delimiter")
    func quotesFieldWithDelimiter() {
        let csv = TransactionCSVExporter.export([Self.transaction(purpose: "Miete; Wohnung 4B")])
        let row = csv.components(separatedBy: "\r\n")[1]
        #expect(row.contains("\"Miete; Wohnung 4B\""))
    }

    @Test("escapes an embedded quote by doubling it")
    func escapesEmbeddedQuote() {
        let csv = TransactionCSVExporter.export([Self.transaction(notes: "He said \"hi\"")])
        let row = csv.components(separatedBy: "\r\n")[1]
        #expect(row.contains("\"He said \"\"hi\"\"\""))
    }

    @Test("uses the category name when present, empty string otherwise")
    func usesCategoryNameOrEmpty() {
        let category = ExpenseCategory(name: "Food", colorHex: "#000", symbolName: "fork.knife")
        let withCategory = TransactionCSVExporter.export([Self.transaction(category: category)])
        #expect(withCategory.contains(";Food;"))

        let withoutCategory = TransactionCSVExporter.export([Self.transaction(category: nil)])
        let row = withoutCategory.components(separatedBy: "\r\n")[1]
        let fields = row.components(separatedBy: ";")
        #expect(fields[2].isEmpty)
    }

    @Test("exportData prefixes a UTF-8 byte-order mark")
    func exportDataPrefixesBOM() {
        let data = TransactionCSVExporter.exportData([Self.transaction()])
        #expect(data.prefix(3) == Data([0xEF, 0xBB, 0xBF]))
    }

    @Test("exporting an empty list still produces just the header")
    func exportsHeaderOnlyForEmptyList() {
        let csv = TransactionCSVExporter.export([])
        #expect(csv == "Date;Value Date;Category;Merchant;Purpose;Amount;Currency;Type;Source;Notes")
    }
}
