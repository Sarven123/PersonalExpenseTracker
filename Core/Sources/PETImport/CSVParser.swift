import Foundation

/// A quote-aware CSV parser for Sparkasse's semicolon-delimited exports.
///
/// Doubled quotes (`""`) inside a quoted field decode to a literal quote,
/// and a delimiter or newline inside a quoted field is treated as literal
/// text rather than a field/row boundary — needed because Sparkasse
/// purpose-text fields sometimes contain an embedded semicolon
/// (e.g. `"Fitnessstudio Beitrag; Vertrag 445566"`).
public enum CSVParser {
    public static func parse(_ text: String, delimiter: Character = ";") -> [[String]] {
        var rows: [[String]] = []
        var currentRow: [String] = []
        var currentField = ""
        var inQuotes = false
        let chars = Array(text)
        var i = 0

        func endField() {
            currentRow.append(currentField)
            currentField = ""
        }

        func endRow() {
            endField()
            rows.append(currentRow)
            currentRow = []
        }

        while i < chars.count {
            let c = chars[i]

            if inQuotes {
                if c == "\"" {
                    if i + 1 < chars.count, chars[i + 1] == "\"" {
                        currentField.append("\"")
                        i += 2
                    } else {
                        inQuotes = false
                        i += 1
                    }
                } else {
                    currentField.append(c)
                    i += 1
                }
                continue
            }

            switch c {
            case "\"" where currentField.isEmpty:
                inQuotes = true
                i += 1
            case delimiter:
                endField()
                i += 1
            case "\r\n", "\n":
                // Swift's Character coalesces CR+LF into a single grapheme cluster,
                // so CRLF must be matched as one case alongside plain LF.
                endRow()
                i += 1
            case "\r":
                i += 1
            default:
                currentField.append(c)
                i += 1
            }
        }

        if !currentField.isEmpty || !currentRow.isEmpty {
            endRow()
        }

        return rows.filter { !($0.count == 1 && $0[0].isEmpty) }
    }
}
