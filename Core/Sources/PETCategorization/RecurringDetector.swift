import Foundation
import PETModels

public struct RecurringGroup {
    public let normalizedMerchant: String
    public let transactions: [ExpenseTransaction]
    public let frequency: RecurringFrequency
    public let averageIntervalDays: Double
}

/// Detects recurring/subscription-like spending by grouping transactions with
/// the same normalized merchant and checking whether their booking dates fall
/// at a consistent interval and their amounts are roughly stable. Purely
/// additive by design — callers should only ever *set* `isRecurring`/attach a
/// `RecurringSchedule` from these results, never clear a flag a user set.
public enum RecurringDetector {
    private static let minimumOccurrences = 3
    private static let amountTolerance: Decimal = 0.1

    private static let frequencyBands: [(RecurringFrequency, ClosedRange<Double>)] = [
        (.weekly, 4...10),
        (.biweekly, 11...18),
        (.monthly, 24...36),
        (.quarterly, 80...100),
        (.yearly, 350...380),
    ]

    public static func detectGroups(in transactions: [ExpenseTransaction]) -> [RecurringGroup] {
        let grouped = Dictionary(grouping: transactions) { MerchantNormalizer.normalize($0.merchant) }

        var groups: [RecurringGroup] = []
        for (merchant, txs) in grouped where !merchant.isEmpty && txs.count >= minimumOccurrences {
            let sorted = txs.sorted { $0.bookingDate < $1.bookingDate }
            guard amountsAreConsistent(sorted.map(\.amount)) else { continue }

            let gaps = gapsInDays(sorted.map(\.bookingDate))
            guard let frequency = classifyFrequency(gaps) else { continue }

            let average = gaps.reduce(0, +) / Double(gaps.count)
            groups.append(RecurringGroup(
                normalizedMerchant: merchant,
                transactions: sorted,
                frequency: frequency,
                averageIntervalDays: average
            ))
        }
        return groups
    }

    private static func gapsInDays(_ dates: [Date]) -> [Double] {
        zip(dates, dates.dropFirst()).map { $1.timeIntervalSince($0) / 86400 }
    }

    private static func classifyFrequency(_ gaps: [Double]) -> RecurringFrequency? {
        guard !gaps.isEmpty else { return nil }
        for (frequency, range) in frequencyBands where gaps.allSatisfy({ range.contains($0) }) {
            return frequency
        }
        return nil
    }

    private static func amountsAreConsistent(_ amounts: [Decimal]) -> Bool {
        guard let first = amounts.first, first != 0 else { return false }
        let magnitude = abs(first)
        return amounts.allSatisfy { abs(abs($0) - magnitude) / magnitude <= amountTolerance }
    }
}
