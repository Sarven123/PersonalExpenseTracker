import Foundation

/// Formats values for CSV export using German date/number conventions —
/// the export-direction counterpart to Phase 3's `GermanDateParser`/
/// `GermanNumberParser`. Uses a fixed UTC calendar for dates, mirroring how
/// `GermanDateParser` parses them, so a value round-trips to the same
/// calendar day regardless of the host machine's system time zone.
public enum GermanExportFormatters {
    public static func formatDate(_ date: Date) -> String {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        let components = calendar.dateComponents([.day, .month, .year], from: date)
        return String(format: "%02d.%02d.%04d", components.day ?? 1, components.month ?? 1, components.year ?? 1970)
    }

    public static func formatAmount(_ amount: Decimal) -> String {
        amount.formatted(.number.locale(Locale(identifier: "de_DE")).precision(.fractionLength(2)))
    }
}
