import Foundation
import Testing
import PETModels
@testable import PETCategorization

@Suite("RecurringDetector")
struct RecurringDetectorTests {
    private static func transaction(merchant: String, daysFromNow: Int, amount: Decimal) -> ExpenseTransaction {
        ExpenseTransaction(
            bookingDate: Date(timeIntervalSince1970: 1_756_684_800 + Double(daysFromNow) * 86400),
            amount: amount,
            type: .expense,
            merchant: merchant,
            rawDescription: merchant
        )
    }

    @Test("detects a monthly-cadence subscription with a stable amount")
    func detectsMonthlySubscription() {
        let transactions = [0, 30, 61, 91].map {
            Self.transaction(merchant: "Netflix", daysFromNow: $0, amount: -12.99)
        }
        let groups = RecurringDetector.detectGroups(in: transactions)
        #expect(groups.count == 1)
        #expect(groups.first?.frequency == .monthly)
        #expect(groups.first?.transactions.count == 4)
    }

    @Test("detects a weekly-cadence pattern")
    func detectsWeeklyPattern() {
        let transactions = [0, 7, 14, 21].map {
            Self.transaction(merchant: "Fitnessstudio", daysFromNow: $0, amount: -29.90)
        }
        let groups = RecurringDetector.detectGroups(in: transactions)
        #expect(groups.first?.frequency == .weekly)
    }

    @Test("requires at least 3 occurrences")
    func requiresMinimumOccurrences() {
        let transactions = [0, 30].map { Self.transaction(merchant: "Netflix", daysFromNow: $0, amount: -12.99) }
        #expect(RecurringDetector.detectGroups(in: transactions).isEmpty)
    }

    @Test("rejects a group whose amounts vary too much")
    func rejectsInconsistentAmounts() {
        let transactions = [
            Self.transaction(merchant: "Netflix", daysFromNow: 0, amount: -12.99),
            Self.transaction(merchant: "Netflix", daysFromNow: 30, amount: -19.99),
            Self.transaction(merchant: "Netflix", daysFromNow: 60, amount: -12.99),
        ]
        #expect(RecurringDetector.detectGroups(in: transactions).isEmpty)
    }

    @Test("rejects a group whose intervals are irregular")
    func rejectsIrregularIntervals() {
        let transactions = [
            Self.transaction(merchant: "Netflix", daysFromNow: 0, amount: -12.99),
            Self.transaction(merchant: "Netflix", daysFromNow: 5, amount: -12.99),
            Self.transaction(merchant: "Netflix", daysFromNow: 60, amount: -12.99),
        ]
        #expect(RecurringDetector.detectGroups(in: transactions).isEmpty)
    }

    @Test("does not group different merchants together")
    func keepsDifferentMerchantsSeparate() {
        let transactions = [
            Self.transaction(merchant: "Netflix", daysFromNow: 0, amount: -12.99),
            Self.transaction(merchant: "Spotify", daysFromNow: 30, amount: -12.99),
            Self.transaction(merchant: "Netflix", daysFromNow: 61, amount: -12.99),
        ]
        #expect(RecurringDetector.detectGroups(in: transactions).isEmpty)
    }

    @Test("one-off transactions produce no groups")
    func oneOffTransactionsProduceNoGroups() {
        let transactions = [
            Self.transaction(merchant: "REWE", daysFromNow: 0, amount: -42.17),
            Self.transaction(merchant: "dm-drogerie", daysFromNow: 1, amount: -23.45),
        ]
        #expect(RecurringDetector.detectGroups(in: transactions).isEmpty)
    }
}
