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
    @State private var selection: SidebarSection? = .dashboard

    var body: some View {
        NavigationSplitView {
            SidebarView(selection: $selection)
        } detail: {
            NavigationStack {
                destination(for: selection ?? .dashboard)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .petRequestSidebarSection)) { notification in
            if let section = notification.object as? SidebarSection {
                selection = section
            }
        }
    }

    @ViewBuilder
    private func destination(for section: SidebarSection) -> some View {
        switch section {
        case .dashboard:
            DashboardView()
        case .transactions:
            TransactionListView()
        case .insights:
            InsightsView()
        case .settings:
            SettingsView()
        }
    }
}

#Preview {
    ContentView()
}
