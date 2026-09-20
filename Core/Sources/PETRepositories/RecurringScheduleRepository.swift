import Foundation
import SwiftData
import PETModels
import PETCategorization

@MainActor
public final class RecurringScheduleRepository {
    private let context: ModelContext

    public init(context: ModelContext) {
        self.context = context
    }

    /// Scans every stored transaction for recurring patterns and flags matches.
    /// Purely additive — only ever sets `isRecurring`/attaches a `RecurringSchedule`,
    /// never clears a flag a user (or an earlier detection pass) already set,
    /// since `isRecurring` is a user-editable field.
    public func refreshDetectedRecurrence() throws {
        var descriptor = FetchDescriptor<ExpenseTransaction>()
        descriptor.sortBy = [SortDescriptor(\.bookingDate)]
        let transactions = try context.fetch(descriptor)

        let groups = RecurringDetector.detectGroups(in: transactions)
        guard !groups.isEmpty else { return }

        for group in groups {
            for transaction in group.transactions {
                transaction.isRecurring = true
            }

            guard let anchor = group.transactions.last else { continue }
            let nextExpectedDate = Self.nextExpectedDate(after: anchor.bookingDate, averageIntervalDays: group.averageIntervalDays)

            if let schedule = anchor.recurringSchedule {
                schedule.frequency = group.frequency
                schedule.nextExpectedDate = nextExpectedDate
            } else {
                let schedule = RecurringSchedule(
                    frequency: group.frequency,
                    startDate: group.transactions.first?.bookingDate ?? anchor.bookingDate,
                    nextExpectedDate: nextExpectedDate
                )
                context.insert(schedule)
                schedule.transaction = anchor
            }
        }

        try context.save()
    }

    private static func nextExpectedDate(after date: Date, averageIntervalDays: Double) -> Date {
        date.addingTimeInterval(averageIntervalDays * 86400)
    }
}
