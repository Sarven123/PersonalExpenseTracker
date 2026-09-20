import Foundation
import Testing
@testable import PETImport

@Suite("GermanNumberParser")
struct GermanNumberParserTests {
    @Test("parses a simple negative amount")
    func negativeAmount() throws {
        #expect(try GermanNumberParser.parse("-42,17") == Decimal(string: "-42.17"))
    }

    @Test("parses a thousands-separated positive amount")
    func thousandsSeparator() throws {
        #expect(try GermanNumberParser.parse("2.450,00") == Decimal(string: "2450.00"))
    }

    @Test("parses a larger thousands-separated amount")
    func largeThousandsSeparator() throws {
        #expect(try GermanNumberParser.parse("1.234,56") == Decimal(string: "1234.56"))
    }

    @Test("parses a trailing-minus-sign amount")
    func trailingSign() throws {
        #expect(try GermanNumberParser.parse("42,17-") == Decimal(string: "-42.17"))
    }

    @Test("parses a whole-euro amount with no decimal part")
    func wholeEuros() throws {
        #expect(try GermanNumberParser.parse("300") == Decimal(string: "300"))
    }

    @Test("tolerates surrounding whitespace")
    func whitespace() throws {
        #expect(try GermanNumberParser.parse("  -12,99  ") == Decimal(string: "-12.99"))
    }

    @Test("rejects garbage input")
    func garbage() {
        #expect(throws: GermanNumberParsingError.self) {
            try GermanNumberParser.parse("not-a-number")
        }
    }

    @Test("rejects empty input")
    func empty() {
        #expect(throws: GermanNumberParsingError.self) {
            try GermanNumberParser.parse("")
        }
    }
}
