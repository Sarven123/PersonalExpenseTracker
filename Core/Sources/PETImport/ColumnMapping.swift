import Foundation
import PETModels

public enum SemanticField: String, Hashable, Sendable, Codable, CaseIterable {
    case bookingDate
    case valueDate
    /// The transaction-type label — "Buchungstext" in CAMT exports, "Umsatzart" in MT940-style exports.
    case typeText
    /// The free-text purpose/description — "Verwendungszweck" in CAMT exports, "Buchungstext" in MT940-style exports.
    case purpose
    case counterpartyName
    case counterpartyIBAN
    /// The account holder's own IBAN. Only present in CAMT exports ("Auftragskonto").
    case ownIBAN
    case bic
    case amount
    case currency
}

/// Maps a parsed CSV header row to column indices for each semantic field,
/// disambiguating which known Sparkasse layout (CAMT vs. MT940-style) the
/// file uses. The two layouts reuse the header label "Buchungstext" for
/// different semantic roles, so detection must be layout-aware rather than
/// a single flat alias table.
public struct ColumnMapping: Sendable, Equatable, Codable {
    public let sourceFormat: ImportSourceFormat
    public let indices: [SemanticField: Int]

    public func index(for field: SemanticField) -> Int? {
        indices[field]
    }

    public static func detect(headerRow: [String]) throws -> ColumnMapping {
        let normalizedHeaders = headerRow.map(normalize)

        for layout in knownLayouts {
            var indices: [SemanticField: Int] = [:]
            var matchedAllRequired = true

            for (field, aliases) in layout.aliases {
                let normalizedAliases = Set(aliases.map(normalize))
                if let idx = normalizedHeaders.firstIndex(where: { normalizedAliases.contains($0) }) {
                    indices[field] = idx
                } else if layout.requiredFields.contains(field) {
                    matchedAllRequired = false
                }
            }

            if matchedAllRequired {
                return ColumnMapping(sourceFormat: layout.sourceFormat, indices: indices)
            }
        }

        throw ImportError.unsupportedLayout
    }

    private static func normalize(_ header: String) -> String {
        header.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    private struct Layout {
        let sourceFormat: ImportSourceFormat
        let aliases: [SemanticField: [String]]
        let requiredFields: Set<SemanticField>
    }

    private static let knownLayouts: [Layout] = [
        Layout(
            sourceFormat: .camtCSV,
            aliases: [
                .ownIBAN: ["Auftragskonto"],
                .bookingDate: ["Buchungstag"],
                .valueDate: ["Valutadatum"],
                .typeText: ["Buchungstext"],
                .purpose: ["Verwendungszweck"],
                .counterpartyName: ["Beguenstigter/Zahlungspflichtiger", "Begünstigter/Zahlungspflichtiger"],
                .counterpartyIBAN: ["Kontonummer/IBAN"],
                .bic: ["BIC (SWIFT-Code)"],
                .amount: ["Betrag"],
                .currency: ["Waehrung", "Währung"],
            ],
            requiredFields: [.bookingDate, .typeText, .purpose, .counterpartyName, .amount]
        ),
        Layout(
            sourceFormat: .mt940CSV,
            aliases: [
                .bookingDate: ["Buchungsdatum"],
                .valueDate: ["Wertstellung"],
                .typeText: ["Umsatzart"],
                .purpose: ["Buchungstext"],
                .counterpartyName: ["Empfänger/Zahlungspflichtiger", "Empfaenger/Zahlungspflichtiger"],
                .counterpartyIBAN: ["IBAN"],
                .bic: ["BIC"],
                .amount: ["Betrag"],
                .currency: ["Waehrung", "Währung"],
            ],
            requiredFields: [.bookingDate, .typeText, .purpose, .counterpartyName, .amount]
        ),
    ]
}
