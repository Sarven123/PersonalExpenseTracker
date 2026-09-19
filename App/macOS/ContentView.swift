import SwiftUI
import PETSharedUI

enum SidebarSection: String, CaseIterable, Identifiable, Hashable {
    case dashboard = "Dashboard"
    case transactions = "Transactions"
    case insights = "Insights"
    case settings = "Settings"

    var id: String { rawValue }

    var systemImage: String {
        switch self {
        case .dashboard: "chart.pie.fill"
        case .transactions: "list.bullet.rectangle"
        case .insights: "chart.bar.xaxis"
        case .settings: "gearshape"
        }
    }
}

struct ContentView: View {
    // Defaults to Transactions until the Dashboard is built in Phase 6 — that's
    // the only section with real functionality right now.
    @State private var selection: SidebarSection? = .transactions

    var body: some View {
        NavigationSplitView {
            SidebarView(selection: $selection)
        } detail: {
            NavigationStack {
                destination(for: selection ?? .transactions)
            }
        }
    }

    @ViewBuilder
    private func destination(for section: SidebarSection) -> some View {
        switch section {
        case .transactions:
            TransactionListView()
        case .dashboard, .insights, .settings:
            PlaceholderView(section: section)
        }
    }
}

private struct PlaceholderView: View {
    let section: SidebarSection

    var body: some View {
        ContentUnavailableView(
            section.rawValue,
            systemImage: section.systemImage,
            description: Text("\(section.rawValue) will be built in an upcoming phase.")
        )
        .navigationTitle(section.rawValue)
    }
}

#Preview {
    ContentView()
}
