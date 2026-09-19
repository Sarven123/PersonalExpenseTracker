import SwiftUI

struct SidebarView: View {
    @Binding var selection: SidebarSection?

    var body: some View {
        List(SidebarSection.allCases, selection: $selection) { section in
            Label(section.rawValue, systemImage: section.systemImage)
                .tag(section)
        }
        .navigationTitle("Personal Expense Tracker")
        .listStyle(.sidebar)
    }
}
