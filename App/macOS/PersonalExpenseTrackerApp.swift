import SwiftUI
import SwiftData
import PETModels
import PETRepositories

@main
struct PersonalExpenseTrackerApp: App {
    let modelContainer: ModelContainer = ModelContainerFactory.makeLiveContainer()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.locale, Locale(identifier: "de_DE"))
                .task {
                    seedDefaultCategoriesIfNeeded()
                    migrateLegacyHoldingsIfNeeded()
                }
        }
        .modelContainer(modelContainer)
        .commands {
            AppCommands()
        }
    }

    @MainActor
    private func seedDefaultCategoriesIfNeeded() {
        do {
            try CategoryRepository(context: modelContainer.mainContext).seedDefaultCategoriesIfNeeded()
            try MerchantRuleRepository(context: modelContainer.mainContext).seedBuiltInRulesIfNeeded()
        } catch {
            #if DEBUG
            print("Failed to seed default categories or merchant rules: \(error)")
            #endif
        }
    }

    /// One-time carry-forward of any pre-existing `Holding` row (from the cancelled Net Worth
    /// prototype) into the new `Asset` model — see `AssetRepository.migrateLegacyHoldingsIfNeeded()`.
    @MainActor
    private func migrateLegacyHoldingsIfNeeded() {
        do {
            try AssetRepository(context: modelContainer.mainContext).migrateLegacyHoldingsIfNeeded()
        } catch {
            #if DEBUG
            print("Failed to migrate legacy holdings into Assets: \(error)")
            #endif
        }
    }
}
