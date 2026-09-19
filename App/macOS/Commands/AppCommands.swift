import SwiftUI

struct AppCommands: Commands {
    var body: some Commands {
        CommandGroup(replacing: .newItem) {
            Button("New Expense…") {
                // Wired up to the Add Expense flow in an upcoming phase.
            }
            .keyboardShortcut("n", modifiers: .command)
        }
    }
}
