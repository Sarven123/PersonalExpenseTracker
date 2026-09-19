import Foundation

public extension Notification.Name {
    /// Posted by platform-specific menu commands (e.g. Cmd+N on macOS) to request
    /// that the currently visible transaction list present its "Add Expense" sheet.
    static let petRequestAddExpense = Notification.Name("PET.requestAddExpense")
}
