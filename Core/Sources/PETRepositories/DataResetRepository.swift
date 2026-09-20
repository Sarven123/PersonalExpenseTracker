import Foundation
import SwiftData
import PETModels

/// Backs the Settings screen's "Delete All Local Data" action. Wipes every
/// stored record, then immediately re-seeds default categories and builtin
/// merchant rules so the app stays usable without requiring a relaunch.
@MainActor
public final class DataResetRepository {
    private let context: ModelContext

    public init(context: ModelContext) {
        self.context = context
    }

    public func deleteAllData() throws {
        // Delete transactions first — everything else they reference uses
        // .nullify delete rules, so this order avoids any transient dangling
        // relationship state.
        try context.delete(model: ExpenseTransaction.self)
        try context.delete(model: RecurringSchedule.self)
        try context.delete(model: MerchantRule.self)
        try context.delete(model: ImportBatch.self)
        try context.delete(model: ExpenseCategory.self)
        try context.save()

        try CategoryRepository(context: context).seedDefaultCategoriesIfNeeded()
        try MerchantRuleRepository(context: context).seedBuiltInRulesIfNeeded()
    }
}
