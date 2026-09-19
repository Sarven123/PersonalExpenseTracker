import SwiftUI
import SwiftData
import PETModels

@main
struct PersonalExpenseTrackerApp: App {
    let modelContainer: ModelContainer = ModelContainerFactory.makeLiveContainer()

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(modelContainer)
        .commands {
            AppCommands()
        }
    }
}
