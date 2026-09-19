import SwiftUI
import PETSharedUI

struct AppCommands: Commands {
    var body: some Commands {
        CommandGroup(replacing: .newItem) {
            Button("New Expense…") {
                NotificationCenter.default.post(name: .petRequestAddExpense, object: nil)
            }
            .keyboardShortcut("n", modifiers: .command)
        }
    }
}
