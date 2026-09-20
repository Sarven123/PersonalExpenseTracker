import Testing
import PETModels
@testable import PETImport

@Suite("ColumnMapping")
struct ColumnMappingTests {
    private static let camtHeader = [
        "Auftragskonto", "Buchungstag", "Valutadatum", "Buchungstext", "Verwendungszweck",
        "Glaeubiger ID", "Mandatsreferenz", "Kundenreferenz (End-to-End)", "Sammlerreferenz",
        "Lastschrift Ursprungsbetrag", "Auslagenersatz Ruecklastschrift",
        "Beguenstigter/Zahlungspflichtiger", "Kontonummer/IBAN", "BIC (SWIFT-Code)", "Betrag",
        "Waehrung", "Info",
    ]

    private static let mt940Header = [
        "Buchungsdatum", "Wertstellung", "Umsatzart", "Buchungstext",
        "Empfänger/Zahlungspflichtiger", "IBAN", "BIC", "Betrag", "Waehrung",
    ]

    @Test("detects the CAMT layout and maps its distinct 'Buchungstext' role correctly")
    func camtLayout() throws {
        let mapping = try ColumnMapping.detect(headerRow: Self.camtHeader)
        #expect(mapping.sourceFormat == .camtCSV)
        #expect(mapping.index(for: .bookingDate) == 1)
        #expect(mapping.index(for: .typeText) == 3)
        #expect(mapping.index(for: .purpose) == 4)
        #expect(mapping.index(for: .ownIBAN) == 0)
        #expect(mapping.index(for: .counterpartyIBAN) == 12)
        #expect(mapping.index(for: .amount) == 14)
    }

    @Test("detects the MT940 layout, where 'Buchungstext' means purpose instead of type")
    func mt940Layout() throws {
        let mapping = try ColumnMapping.detect(headerRow: Self.mt940Header)
        #expect(mapping.sourceFormat == .mt940CSV)
        #expect(mapping.index(for: .bookingDate) == 0)
        #expect(mapping.index(for: .typeText) == 2)
        #expect(mapping.index(for: .purpose) == 3)
        #expect(mapping.index(for: .ownIBAN) == nil)
        #expect(mapping.index(for: .counterpartyIBAN) == 5)
        #expect(mapping.index(for: .amount) == 7)
    }

    @Test("throws for a header row that matches no known layout")
    func unknownLayout() {
        #expect(throws: ImportError.self) {
            try ColumnMapping.detect(headerRow: ["Date", "Amount", "Description"])
        }
    }
}
