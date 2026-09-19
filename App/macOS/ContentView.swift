import SwiftUI

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
                PlaceholderView(section: selection ?? .dashboard)
            }
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
