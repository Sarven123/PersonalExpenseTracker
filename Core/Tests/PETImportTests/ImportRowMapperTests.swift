import Foundation
import Testing
import PETModels
@testable import PETImport

@Suite("ImportRowMapper")
struct ImportRowMapperTests {
    private static let camtHeader = [
        "Auftragskonto", "Buchungstag", "Valutadatum", "Buchungstext", "Verwendungszweck",
        "Glaeubiger ID", "Mandatsreferenz", "Kundenreferenz (End-to-End)", "Sammlerreferenz",
        "Lastschrift Ursprungsbetrag", "Auslagenersatz Ruecklastschrift",
        "Beguenstigter/Zahlungspflichtiger", "Kontonummer/IBAN", "BIC (SWIFT-Code)", "Betrag",
        "Waehrung", "Info",
    ]

    private static let camtRow = [
        "DE02120300000000202051", "01.09.2026", "01.09.2026", "Kartenzahlung",
        "REWE SAGT DANKE//München/DE", "", "", "", "", "", "", "REWE Markt GmbH",
        "DE02120300000000202051", "BYLADEM1001", "-42,17", "EUR", "",
    ]

    @Test("maps a CAMT expense row to a draft transaction")
    func mapsExpenseRow() throws {
        let mapping = try ColumnMapping.detect(headerRow: Self.camtHeader)
        let draft = try ImportRowMapper.map(row: Self.camtRow, mapping: mapping, rowNumber: 2)

        #expect(draft.amount == Decimal(string: "-42.17"))
        #expect(draft.type == .expense)
        #expect(draft.merchant == "REWE Markt GmbH")
        #expect(draft.bookingText == "Kartenzahlung")
        #expect(draft.purpose == "REWE SAGT DANKE//München/DE")
        #expect(draft.ownIBAN == "DE02120300000000202051")
        #expect(draft.counterpartyIBAN == "DE02120300000000202051")
        #expect(draft.currencyCode == "EUR")
        #expect(draft.sourceRowNumber == 2)
    }

    @Test("classifies a positive amount as income")
    func classifiesIncome() throws {
        var row = Self.camtRow
        row[14] = "2.450,00" // Betrag column
        let mapping = try ColumnMapping.detect(headerRow: Self.camtHeader)
        let draft = try ImportRowMapper.map(row: row, mapping: mapping, rowNumber: 3)
        #expect(draft.type == .income)
        #expect(draft.amount == Decimal(string: "2450.00"))
    }

    @Test("throws invalidDate for an unparseable booking date")
    func invalidDate() throws {
        var row = Self.camtRow
        row[1] = "not-a-date"
        let mapping = try ColumnMapping.detect(headerRow: Self.camtHeader)
        #expect(throws: ImportError.self) {
            try ImportRowMapper.map(row: row, mapping: mapping, rowNumber: 2)
        }
    }

    @Test("throws invalidAmount for an unparseable amount")
    func invalidAmount() throws {
        var row = Self.camtRow
        row[14] = "not-a-number"
        let mapping = try ColumnMapping.detect(headerRow: Self.camtHeader)
        #expect(throws: ImportError.self) {
            try ImportRowMapper.map(row: row, mapping: mapping, rowNumber: 2)
        }
    }
}
