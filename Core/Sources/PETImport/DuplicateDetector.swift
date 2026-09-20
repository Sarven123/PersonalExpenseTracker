import CryptoKit
import Foundation

/// Computes a stable hash identifying a transaction across re-imports of
/// overlapping date ranges, and partitions a batch of drafts into unique
/// vs. already-seen rows.
public enum DuplicateDetector {
    public static func computeHash(
        bookingDate: Date,
        amount: Decimal,
        currencyCode: String,
        counterpartyIBAN: String?,
        merchant: String,
        purpose: String?
    ) -> String {
        let dateComponent = String(Int(bookingDate.timeIntervalSince1970))
        let amountComponent = NSDecimalNumber(decimal: amount).stringValue
        let identity = counterpartyIBAN?.uppercased() ?? merchant.lowercased()
        let raw = [
            dateComponent,
            amountComponent,
            currencyCode.uppercased(),
            identity,
            purpose?.lowercased() ?? "",
        ].joined(separator: "|")

        let digest = SHA256.hash(data: Data(raw.utf8))
        return digest.map { String(format: "%02x", $0) }.joined()
    }

    /// - Parameter existingHashes: dedupe hashes of transactions already stored (e.g. from a prior import).
    public static func partition(
        drafts: [DraftTransaction],
        existingHashes: Set<String>
    ) -> (unique: [DraftTransaction], duplicates: [DraftTransaction]) {
        var seen = existingHashes
        var unique: [DraftTransaction] = []
        var duplicates: [DraftTransaction] = []

        for draft in drafts {
            if seen.contains(draft.dedupeHash) {
                duplicates.append(draft)
            } else {
                unique.append(draft)
                seen.insert(draft.dedupeHash)
            }
        }

        return (unique, duplicates)
    }
}
