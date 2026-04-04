import SwiftUI

struct MainTabView: View {
    @EnvironmentObject var authVM: AuthViewModel
    @State private var selectedTab = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            HomeView()
                .tabItem { Label("Home",   systemImage: "house.fill") }
                .tag(0)

            MapView()
                .tabItem { Label("Map",    systemImage: "map.fill") }
                .tag(1)

            TaskListView()
                .tabItem { Label("Tasks",  systemImage: "checklist") }
                .tag(2)

            NotesVaultView()
                .tabItem { Label("Notes",  systemImage: "doc.text.fill") }
                .tag(3)

            AnalyticsView()
                .tabItem { Label("Stats",  systemImage: "chart.bar.fill") }
                .tag(4)
        }
        .accentColor(.nestPink)
        .onAppear { setupTabBarAppearance() }
    }

    private func setupTabBarAppearance() {
        let appearance = UITabBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = UIColor.systemBackground

        // Selected item pink tint
        appearance.stackedLayoutAppearance.selected.iconColor    = UIColor(Color.nestPink)
        appearance.stackedLayoutAppearance.selected.titleTextAttributes = [
            .foregroundColor: UIColor(Color.nestPink),
            .font: UIFont.systemFont(ofSize: 10, weight: .semibold)
        ]
        // Unselected grey
        appearance.stackedLayoutAppearance.normal.iconColor = UIColor.systemGray3
        appearance.stackedLayoutAppearance.normal.titleTextAttributes = [
            .foregroundColor: UIColor.systemGray3,
            .font: UIFont.systemFont(ofSize: 10, weight: .medium)
        ]

        UITabBar.appearance().standardAppearance   = appearance
        UITabBar.appearance().scrollEdgeAppearance = appearance
    }
}
