import SwiftUI

struct MainTabView: View {
    @Environment(AppState.self) private var appState
    @State private var selectedTab = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            HomeView()
                .tabItem {
                    Label("Home", systemImage: "house")
                }
                .tag(0)

            NavigationStack {
                QueueView()
            }
            .tabItem {
                Label("Up Next", systemImage: "rectangle.stack.badge.play")
            }
            .tag(1)

            LibraryView()
                .tabItem {
                    Label("Channels", systemImage: "rectangle.stack")
                }
                .tag(2)

            DiscoverView()
                .tabItem {
                    Label("Explore", systemImage: "sparkles")
                }
                .tag(3)

            SearchView()
                .tabItem {
                    Label("Search", systemImage: "magnifyingglass")
                }
                .tag(4)

            SettingsView()
                .tabItem {
                    Label("Settings", systemImage: "gearshape")
                }
                .tag(5)
        }
        .id(appState.serverRevision)
        .tint(NullFeedTheme.primary)
        .background(NullFeedBackdrop())
    }
}
