import SwiftUI

struct SettingsView: View {
    @Environment(StorageService.self) private var storage
    @Environment(AppState.self) private var appState
    @State private var viewModel: SettingsViewModel?

    var body: some View {
        NavigationStack {
            ZStack {
                NullFeedTheme.background.ignoresSafeArea()

                if let vm = viewModel {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 40) {
                            // Server Info
                            settingsSection("Server") {
                                settingsRow("URL", value: vm.serverUrl)
                            }

                            // User Info
                            if let user = vm.currentUser {
                                settingsSection("Profile") {
                                    settingsRow("Name", value: user.displayName)
                                    settingsRow("Admin", value: user.isAdmin ? "Yes" : "No")
                                }
                            }

                            // Quality
                            settingsSection("Playback") {
                                HStack {
                                    Text("Preferred Quality")
                                        .font(NullFeedTheme.bodyMedium)
                                        .foregroundStyle(NullFeedTheme.textPrimary)
                                    Spacer()
                                    Picker("", selection: Binding(
                                        get: { vm.preferredQuality },
                                        set: { vm.preferredQuality = $0 }
                                    )) {
                                        Text("1080p").tag("1080p")
                                        Text("720p").tag("720p")
                                        Text("480p").tag("480p")
                                    }
                                    .frame(width: 200)
                                }
                                .padding(16)
                                .background(NullFeedTheme.card, in: RoundedRectangle(cornerRadius: 8))
                            }

                            // Logout
                            Button(role: .destructive) {
                                vm.logout()
                            } label: {
                                HStack {
                                    Spacer()
                                    Text("Sign Out")
                                        .font(NullFeedTheme.titleMedium)
                                    Spacer()
                                }
                                .padding(16)
                                .background(NullFeedTheme.card, in: RoundedRectangle(cornerRadius: 8))
                            }

                            // Version
                            HStack {
                                Spacer()
                                Text("NullFeed tvOS v1.0.0")
                                    .font(NullFeedTheme.caption)
                                    .foregroundStyle(NullFeedTheme.textMuted)
                                Spacer()
                            }
                        }
                        .padding(NullFeedTheme.contentPadding)
                    }
                }
            }
            .onAppear {
                if viewModel == nil {
                    viewModel = SettingsViewModel(storage: storage, appState: appState)
                }
            }
        }
    }

    private func settingsSection(_ title: String, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(title)
                .font(NullFeedTheme.headlineSmall)
                .foregroundStyle(NullFeedTheme.textPrimary)
            content()
        }
    }

    private func settingsRow(_ label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(NullFeedTheme.bodyMedium)
                .foregroundStyle(NullFeedTheme.textSecondary)
            Spacer()
            Text(value)
                .font(NullFeedTheme.bodyMedium)
                .foregroundStyle(NullFeedTheme.textPrimary)
        }
        .padding(16)
        .background(NullFeedTheme.card, in: RoundedRectangle(cornerRadius: 8))
    }
}
