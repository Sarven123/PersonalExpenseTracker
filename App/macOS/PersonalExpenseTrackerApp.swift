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
}
