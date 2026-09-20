import Testing
@testable import PETImport

@Suite("CSVParser")
struct CSVParserTests {
    @Test("splits simple semicolon-delimited rows")
    func simpleRows() {
        let text = "a;b;c\n1;2;3"
        let rows = CSVParser.parse(text)
        #expect(rows == [["a", "b", "c"], ["1", "2", "3"]])
    }

    @Test("strips surrounding quotes from quoted fields")
    func quotedFields() {
        let text = "\"Auftragskonto\";\"Buchungstag\""
        let rows = CSVParser.parse(text)
        #expect(rows == [["Auftragskonto", "Buchungstag"]])
    }

    @Test("preserves a semicolon embedded in a quoted field")
    func embeddedSemicolon() {
        let text = "\"a\";\"Fitnessstudio Beitrag; Vertrag 445566\";\"c\""
        let rows = CSVParser.parse(text)
        #expect(rows == [["a", "Fitnessstudio Beitrag; Vertrag 445566", "c"]])
    }

    @Test("decodes a doubled quote inside a quoted field as one literal quote")
    func doubledQuote() {
        let text = "\"say \"\"hi\"\"\";\"b\""
        let rows = CSVParser.parse(text)
        #expect(rows == [["say \"hi\"", "b"]])
    }

    @Test("handles mixed quoted and unquoted fields on the same row")
    func mixedQuoting() {
        let text = "\"DE02120300000000202051\";01.09.2026;\"Kartenzahlung\""
        let rows = CSVParser.parse(text)
        #expect(rows == [["DE02120300000000202051", "01.09.2026", "Kartenzahlung"]])
    }

    @Test("ignores carriage returns before newlines")
    func crlfLineEndings() {
        let text = "a;b\r\n1;2\r\n"
        let rows = CSVParser.parse(text)
        #expect(rows == [["a", "b"], ["1", "2"]])
    }

    @Test("drops a fully blank trailing line")
    func blankTrailingLine() {
        let text = "a;b\n1;2\n\n"
        let rows = CSVParser.parse(text)
        #expect(rows == [["a", "b"], ["1", "2"]])
    }

    @Test("parses a row with no trailing newline at end of file")
    func noTrailingNewline() {
        let text = "a;b\n1;2"
        let rows = CSVParser.parse(text)
        #expect(rows == [["a", "b"], ["1", "2"]])
    }
}
