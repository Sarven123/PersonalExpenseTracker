import Foundation
import Testing
@testable import PETExport

@Suite("GermanExportFormatters")
struct GermanExportFormattersTests {
    private static var utc: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        return calendar
    }

    private static func utcDate(year: Int, month: Int, day: Int) -> Date {
        utc.date(from: DateComponents(year: year, month: month, day: day))!
    }

    @Test("formats a date as DD.MM.YYYY")
    func formatsDate() {
        #expect(GermanExportFormatters.formatDate(Self.utcDate(year: 2026, month: 9, day: 1)) == "01.09.2026")
    }

    @Test("pads single-digit day and month with a leading zero")
    func padsSingleDigits() {
        #expect(GermanExportFormatters.formatDate(Self.utcDate(year: 2026, month: 1, day: 5)) == "05.01.2026")
    }

    @Test("formats a negative amount with a decimal comma")
    func formatsNegativeAmount() {
        #expect(GermanExportFormatters.formatAmount(Decimal(string: "-42.17")!) == "-42,17")
    }

    @Test("formats a thousands amount with a thousands separator")
    func formatsThousandsAmount() {
        #expect(GermanExportFormatters.formatAmount(Decimal(string: "2450.00")!) == "2.450,00")
    }

    @Test("always shows exactly two fraction digits")
    func alwaysShowsTwoFractionDigits() {
        #expect(GermanExportFormatters.formatAmount(Decimal(300)) == "300,00")
    }
}
