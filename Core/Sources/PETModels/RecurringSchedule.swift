import Foundation
import SwiftData

@Model
public final class RecurringSchedule {
    @Attribute(.unique) public var id: UUID
    public var frequency: RecurringFrequency
    public var interval: Int
    public var startDate: Date
    public var endDate: Date?
    public var dayOfMonth: Int?
    public var nextExpectedDate: Date?
    public var isActive: Bool

    @Relationship(deleteRule: .nullify, inverse: \Transaction.recurringSchedule)
    public var transaction: Transaction?

    public init(
        id: UUID = UUID(),
        frequency: RecurringFrequency,
        interval: Int = 1,
        startDate: Date = .now,
        endDate: Date? = nil,
        dayOfMonth: Int? = nil,
        nextExpectedDate: Date? = nil,
        isActive: Bool = true
    ) {
        self.id = id
        self.frequency = frequency
        self.interval = interval
        self.startDate = startDate
        self.endDate = endDate
        self.dayOfMonth = dayOfMonth
        self.nextExpectedDate = nextExpectedDate
        self.isActive = isActive
    }
}
