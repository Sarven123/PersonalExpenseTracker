import Foundation

public enum GermanNumberParsingError: Error, Equatable, Sendable {
    case invalidFormat(String)
}

/// Parses German-convention decimal numbers ("-42,17", "2.450,00") into `Decimal`.
/// Sparkasse exports normally lead with the sign, but a trailing sign
/// ("42,17-") shows up in some Soll/Haben-style exports, so both are accepted.
public enum GermanNumberParser {
    public static func parse(_ raw: String) throws -> Decimal {
        var working = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !working.isEmpty else {
            throw GermanNumberParsingError.invalidFormat(raw)
        }

        var isNegative = false
        if working.hasSuffix("-") {
            isNegative = true
            working.removeLast()
        }
        working = working.trimmingCharacters(in: .whitespaces)
        if working.hasPrefix("-") {
            isNegative = true
            working.removeFirst()
        } else if working.hasPrefix("+") {
            working.removeFirst()
        }
        working = working.trimmingCharacters(in: .whitespaces)

        guard !working.isEmpty else {
            throw GermanNumberParsingError.invalidFormat(raw)
        }

        // German convention: "." groups thousands, "," is the decimal separator.
        let normalized = working
            .replacingOccurrences(of: ".", with: "")
            .replacingOccurrences(of: ",", with: ".")

        guard normalized.range(of: "^[0-9]+(\\.[0-9]+)?$", options: .regularExpression) != nil,
              let value = Decimal(string: normalized, locale: Locale(identifier: "en_US_POSIX")) else {
            throw GermanNumberParsingError.invalidFormat(raw)
        }

        return isNegative ? -value : value
    }
}
