import Foundation
import Testing
@testable import PETImport

@Suite("GermanDateParser")
struct GermanDateParserTests {
    private static var utc: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        return calendar
    }

    @Test("parses a well-formed DD.MM.YYYY date")
    func wellFormed() throws {
        let date = try GermanDateParser.parse("01.09.2026")
        let components = Self.utc.dateComponents([.year, .month, .day], from: date)
        #expect(components.year == 2026)
        #expect(components.month == 9)
        #expect(components.day == 1)
    }

    @Test("parses the last day of the year")
    func endOfYear() throws {
        let date = try GermanDateParser.parse("31.12.2026")
        let components = Self.utc.dateComponents([.year, .month, .day], from: date)
        #expect(components.year == 2026)
        #expect(components.month == 12)
        #expect(components.day == 31)
    }

    @Test("rejects a day that doesn't exist in the given month")
    func invalidDayForMonth() {
        #expect(throws: GermanDateParsingError.self) {
            try GermanDateParser.parse("31.02.2026")
        }
    }

    @Test("rejects a month out of range")
    func invalidMonth() {
        #expect(throws: GermanDateParsingError.self) {
            try GermanDateParser.parse("15.13.2026")
        }
    }

    @Test("rejects a non-date string")
    func garbage() {
        #expect(throws: GermanDateParsingError.self) {
            try GermanDateParser.parse("not-a-date")
        }
    }

    @Test("rejects ISO-formatted dates (wrong convention)")
    func isoFormatRejected() {
        #expect(throws: GermanDateParsingError.self) {
            try GermanDateParser.parse("2026-09-01")
        }
    }
}
