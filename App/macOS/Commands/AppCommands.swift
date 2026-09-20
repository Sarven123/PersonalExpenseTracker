import SwiftUI
import PETSharedUI

extension Notification.Name {
    /// Posted by Cmd+1…4 to request the main window switch to a given sidebar
    /// section. App/macOS-local (unlike `.petRequestAddExpense`/`.petRequestImportCSV`,
    /// which live in PETSharedUI) since `SidebarSection` itself is App/macOS-local.
    static let petRequestSidebarSection = Notification.Name("PET.requestSidebarSection")
}

struct AppCommands: Commands {
    var body: some Commands {
        CommandGroup(replacing: .newItem) {
            Button("New Expense…") {
                NotificationCenter.default.post(name: .petRequestAddExpense, object: nil)
            }
            .keyboardShortcut("n", modifiers: .command)

            Button("Import CSV…") {
                NotificationCenter.default.post(name: .petRequestImportCSV, object: nil)
            }
            .keyboardShortcut("i", modifiers: .command)
        }

        CommandGroup(after: .sidebar) {
            Divider()
            Button("Dashboard") { selectSidebarSection(.dashboard) }
                .keyboardShortcut("1", modifiers: .command)
            Button("Transactions") { selectSidebarSection(.transactions) }
                .keyboardShortcut("2", modifiers: .command)
            Button("Insights") { selectSidebarSection(.insights) }
                .keyboardShortcut("3", modifiers: .command)
            Button("Settings") { selectSidebarSection(.settings) }
                .keyboardShortcut("4", modifiers: .command)
        }
    }

    private func selectSidebarSection(_ section: SidebarSection) {
        NotificationCenter.default.post(name: .petRequestSidebarSection, object: section)
    }
}
