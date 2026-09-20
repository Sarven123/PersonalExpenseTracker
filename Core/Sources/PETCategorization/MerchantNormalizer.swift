import Foundation

/// Normalizes raw merchant/purpose text for reliable rule matching across
/// bank exports and manual entry: lowercases, drops the "//City/Country"
/// suffix Sparkasse CAMT purpose text often carries, strips punctuation,
/// and removes common legal-entity suffixes (GmbH, AG, SE, ...) so the same
/// merchant matches consistently whether or not an export includes them.
public enum MerchantNormalizer {
    private static let legalSuffixes: Set<String> = [
        "gmbh", "mbh", "ag", "se", "kg", "ek", "bv", "sa", "inc", "ltd", "co", "kgaa",
    ]

    public static func normalize(_ raw: String) -> String {
        var text = raw.lowercased()

        if let range = text.range(of: "//") {
            text = String(text[..<range.lowerBound])
        }

        text = text.replacingOccurrences(of: "[^\\p{L}\\p{N}\\s]", with: " ", options: .regularExpression)

        let tokens = text
            .split(separator: " ")
            .map(String.init)
            .filter { !legalSuffixes.contains($0) }

        return tokens.joined(separator: " ").trimmingCharacters(in: .whitespaces)
    }
}
