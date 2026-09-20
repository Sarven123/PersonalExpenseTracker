import Foundation

public enum GermanDateParsingError: Error, Equatable, Sendable {
    case invalidFormat(String)
}

/// Parses German-convention DD.MM.YYYY dates into `Date`, using a fixed
/// UTC Gregorian calendar so results don't depend on the host machine's
/// time zone or locale.
public enum GermanDateParser {
    private static var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        return calendar
    }

    public static func parse(_ raw: String) throws -> Date {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        let parts = trimmed.split(separator: ".", omittingEmptySubsequences: false)
        guard parts.count == 3,
              let day = Int(parts[0]), let month = Int(parts[1]), let year = Int(parts[2]),
              (1...31).contains(day), (1...12).contains(month), year > 1900 else {
            throw GermanDateParsingError.invalidFormat(raw)
        }

        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = day
        components.hour = 0
        components.minute = 0
        components.second = 0

        let calendar = Self.calendar
        guard let date = calendar.date(from: components) else {
            throw GermanDateParsingError.invalidFormat(raw)
        }

        // Reject dates that overflowed into the next month (e.g. "31.02.2026").
        let roundTrip = calendar.dateComponents([.year, .month, .day], from: date)
        guard roundTrip.year == year, roundTrip.month == month, roundTrip.day == day else {
            throw GermanDateParsingError.invalidFormat(raw)
        }

        return date
    }
}
