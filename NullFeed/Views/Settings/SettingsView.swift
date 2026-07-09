import SwiftUI

struct SettingsView: View {
    @Environment(StorageService.self) private var storage
    @Environment(APIClient.self) private var api
    @Environment(AppState.self) private var appState
    @State private var viewModel: SettingsViewModel?
    @State private var isConfirmingSignOut = false

    var body: some View {
        NavigationStack {
            ZStack {
                NullFeedBackdrop()

                if let vm = viewModel {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 44) {
                            if let user = vm.currentUser {
                                settingsSection("Profile") {
                                    profileCard(user)
                                }
                            }

                            settingsSection("Server Connection") {
                                serverCard(vm)
                            }

                            settingsSection("Playback") {
                                infoCard(
                                    icon: "sparkles.tv",
                                    title: "Automatic best quality",
                                    detail: "Videos start immediately, then upgrade to full quality as soon as it is ready."
                                )
                            }

                            if vm.currentUser?.isAdmin == true {
                                settingsSection("YouTube Account") {
                                    youtubeAccountCard(vm)
                                }
                            }

                            settingsSection("About") {
                                HStack(spacing: 18) {
                                    Image(systemName: "play.rectangle.on.rectangle.fill")
                                        .font(.system(size: 34, weight: .semibold))
                                        .foregroundStyle(NullFeedTheme.primary)
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text("NullFeed for Apple TV")
                                            .font(NullFeedTheme.titleMedium)
                                        Text("Version \(vm.version) (\(vm.build))")
                                            .font(NullFeedTheme.caption)
                                            .foregroundStyle(NullFeedTheme.textMuted)
                                    }
                                    Spacer()
                                }
                                .padding(24)
                                .background(NullFeedTheme.card, in: RoundedRectangle(cornerRadius: NullFeedTheme.cardRadius))
                            }
                        }
                        .padding(NullFeedTheme.contentPadding)
                    }
                }
            }
            .navigationTitle("Settings")
            .alert("Switch profile?", isPresented: $isConfirmingSignOut) {
                Button("Cancel", role: .cancel) {}
                Button("Sign Out", role: .destructive) {
                    viewModel?.logout()
                }
            } message: {
                Text("You will return to the profile picker.")
            }
            .task {
                if viewModel == nil {
                    viewModel = SettingsViewModel(storage: storage, api: api, appState: appState)
                }
                if viewModel?.connectionState == .unchecked {
                    async let connection: Bool? = viewModel?.testConnection()
                    async let youtube: Void? = viewModel?.loadYouTubeAccountStatus()
                    _ = await (connection, youtube)
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

    private func profileCard(_ user: User) -> some View {
        HStack(spacing: 22) {
            AsyncImageView(url: api.mediaURL(user.avatarUrl), cornerRadius: 36)
                .frame(width: 72, height: 72)
                .overlay {
                    if user.avatarUrl?.isEmpty != false {
                        Text(user.displayName.prefix(1).uppercased())
                            .font(NullFeedTheme.headlineSmall)
                            .foregroundStyle(NullFeedTheme.accent)
                    }
                }

            VStack(alignment: .leading, spacing: 6) {
                Text(user.displayName)
                    .font(NullFeedTheme.titleLarge)
                Text(user.isAdmin ? "Administrator" : "Viewer")
                    .font(NullFeedTheme.caption)
                    .foregroundStyle(NullFeedTheme.textSecondary)
            }
            Spacer()
            Button("Switch Profile") {
                isConfirmingSignOut = true
            }
        }
        .padding(24)
        .background(NullFeedTheme.card, in: RoundedRectangle(cornerRadius: NullFeedTheme.cardRadius))
    }

    private func serverCard(_ vm: SettingsViewModel) -> some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack(spacing: 12) {
                connectionIndicator(vm.connectionState)
                Text(connectionTitle(vm.connectionState))
                    .font(NullFeedTheme.titleSmall)
                    .foregroundStyle(NullFeedTheme.textSecondary)
                Spacer()
            }

            TextField("192.168.1.10:\(AppConstants.defaultServerPort)", text: Binding(
                get: { vm.serverUrl },
                set: {
                    vm.serverUrl = $0
                    vm.connectionState = .unchecked
                    vm.message = nil
                }
            ))
            .textFieldStyle(.plain)
            .font(NullFeedTheme.bodyMedium)
            .padding(.horizontal, 18)
            .padding(.vertical, 16)
            .background(NullFeedTheme.surface, in: RoundedRectangle(cornerRadius: 10))
            .autocorrectionDisabled()

            HStack(spacing: 16) {
                Button("Test Connection") {
                    Task { await vm.testConnection() }
                }
                .disabled(vm.isCheckingConnection)

                Button("Save") {
                    Task { await vm.saveServerUrl() }
                }
                .tint(NullFeedTheme.primary)
                .disabled(vm.isCheckingConnection || !vm.hasUnsavedServerUrl)

                if vm.isCheckingConnection {
                    ProgressView()
                        .tint(NullFeedTheme.primary)
                }
                Spacer()
            }

            if let message = vm.message {
                Text(message)
                    .font(NullFeedTheme.caption)
                    .foregroundStyle(vm.connectionState == .unreachable ? NullFeedTheme.error : NullFeedTheme.textSecondary)
            }
        }
        .padding(24)
        .background(NullFeedTheme.card, in: RoundedRectangle(cornerRadius: NullFeedTheme.cardRadius))
    }

    @ViewBuilder
    private func connectionIndicator(_ state: SettingsViewModel.ConnectionState) -> some View {
        switch state {
        case .unchecked:
            Image(systemName: "circle.dotted").foregroundStyle(NullFeedTheme.textMuted)
        case .checking:
            ProgressView().tint(NullFeedTheme.primary)
        case .connected:
            Image(systemName: "checkmark.circle.fill").foregroundStyle(NullFeedTheme.success)
        case .unreachable:
            Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(NullFeedTheme.error)
        }
    }

    private func connectionTitle(_ state: SettingsViewModel.ConnectionState) -> String {
        switch state {
        case .unchecked: "Not tested"
        case .checking: "Testing connection…"
        case .connected: "Connected"
        case .unreachable: "Unavailable"
        }
    }

    private func infoCard(icon: String, title: String, detail: String) -> some View {
        HStack(spacing: 20) {
            Image(systemName: icon)
                .font(.system(size: 34, weight: .semibold))
                .foregroundStyle(NullFeedTheme.primary)
                .frame(width: 54)
            VStack(alignment: .leading, spacing: 6) {
                Text(title)
                    .font(NullFeedTheme.titleMedium)
                    .foregroundStyle(NullFeedTheme.textPrimary)
                Text(detail)
                    .font(NullFeedTheme.bodySmall)
                    .foregroundStyle(NullFeedTheme.textSecondary)
            }
            Spacer()
        }
        .padding(24)
        .background(NullFeedTheme.card, in: RoundedRectangle(cornerRadius: NullFeedTheme.cardRadius))
    }

    private func youtubeAccountCard(_ vm: SettingsViewModel) -> some View {
        let status = vm.youtubeAccountStatus
        return VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 16) {
                Image(systemName: youtubeStatusSymbol(status))
                    .font(.system(size: 28, weight: .semibold))
                    .foregroundStyle(youtubeStatusColor(status, error: vm.youtubeAccountError))

                VStack(alignment: .leading, spacing: 4) {
                    Text(youtubeStatusTitle(status, error: vm.youtubeAccountError))
                        .font(NullFeedTheme.titleMedium)
                        .foregroundStyle(NullFeedTheme.textPrimary)
                    Text("Manage YouTube cookies from NullFeed on iPhone or the web.")
                        .font(NullFeedTheme.bodySmall)
                        .foregroundStyle(NullFeedTheme.textSecondary)
                }

                Spacer()

                Button("Refresh") {
                    Task { await vm.loadYouTubeAccountStatus() }
                }
                .disabled(vm.isLoadingYouTubeAccount)
            }

            if vm.isLoadingYouTubeAccount {
                ProgressView()
                    .tint(NullFeedTheme.primary)
            } else if let detail = status?.lastError ?? vm.youtubeAccountError {
                Text(detail)
                    .font(NullFeedTheme.caption)
                    .foregroundStyle(NullFeedTheme.textMuted)
                    .lineLimit(3)
            }
        }
        .padding(24)
        .background(NullFeedTheme.card, in: RoundedRectangle(cornerRadius: NullFeedTheme.cardRadius))
    }

    private func youtubeStatusSymbol(_ status: YouTubeAccountStatus?) -> String {
        guard let status else { return "questionmark.circle" }
        if status.stale { return "exclamationmark.triangle.fill" }
        return status.configured ? "checkmark.circle.fill" : "minus.circle"
    }

    private func youtubeStatusTitle(
        _ status: YouTubeAccountStatus?,
        error: String?
    ) -> String {
        if error != nil { return "Status unavailable" }
        guard let status else { return "Checking status…" }
        if status.stale { return "Cookies need attention" }
        return status.configured ? "Connected" : "Not connected"
    }

    private func youtubeStatusColor(
        _ status: YouTubeAccountStatus?,
        error: String?
    ) -> Color {
        if error != nil || status?.stale == true { return NullFeedTheme.error }
        if status?.configured == true { return NullFeedTheme.success }
        return NullFeedTheme.textMuted
    }
}
