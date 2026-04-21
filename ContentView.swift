import SwiftUI

struct MainTabView: View {
    @EnvironmentObject var authVM: AuthViewModel
    @State private var selectedTab = 0

    var body: some View {
        TabView(selection: $selectedTab) {

            HomeView()
                .tabItem { Label("Home",  systemImage: "house.fill") }
                .tag(0)

            // ── Pomodoro replaces Map in slot 1 ──
            PomodoroView()
                .tabItem { Label("Focus", systemImage: "timer") }
                .tag(1)

            TaskListView()
                .tabItem { Label("Tasks", systemImage: "checklist") }
                .tag(2)

            NotesVaultView()
                .tabItem { Label("Notes", systemImage: "doc.text.fill") }
                .tag(3)

            AnalyticsView()
                .tabItem { Label("Stats", systemImage: "chart.bar.fill") }
                .tag(4)

        }
        .accentColor(.nestPink)
        .onAppear { setupTabBarAppearance() }
    }

    private func setupTabBarAppearance() {
        let appearance = UITabBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = UIColor.systemBackground

        UITabBar.appearance().standardAppearance   = appearance
        UITabBar.appearance().scrollEdgeAppearance = appearance
    }
}
