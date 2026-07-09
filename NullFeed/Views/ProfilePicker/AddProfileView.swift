import SwiftUI

/// Full-screen profile creation flow, presented from the profile picker. Mirrors
/// the iOS app's add-profile screen: a display name, an optional YouTube import
/// (resolve a handle -> preview identity -> multi-select the channels it
/// follows), and an optional PIN. On success it signs the new profile in, which
/// swaps the app into the main UI.
struct AddProfileView: View {
    @Bindable var viewModel: AddProfileViewModel
    let api: APIClient
    let onCancel: () -> Void

    @State private var showPinSheet = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 40) {
                Text("Add Profile")
                    .font(NullFeedTheme.headlineLarge)
                    .foregroundStyle(NullFeedTheme.textPrimary)
                    .frame(maxWidth: .infinity)

                nameSection
                importSection
                pinSection

                if let createError = viewModel.createError {
                    errorText(createError)
                        .frame(maxWidth: .infinity)
                }

                actions
            }
            .frame(maxWidth: 900)
            .frame(maxWidth: .infinity)
            .padding(NullFeedTheme.contentPadding)
        }
        .background(NullFeedBackdrop())
        .sheet(isPresented: $showPinSheet) {
            SetPinView(
                canRemove: viewModel.pin != nil,
                onSave: { newPin in
                    viewModel.pin = newPin
                    showPinSheet = false
                },
                onCancel: { showPinSheet = false }
            )
        }
    }

    // MARK: - Sections

    private var nameSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            sectionLabel("Display name")
            TextField("Display name", text: $viewModel.name)
                .textFieldStyle(.plain)
                .font(NullFeedTheme.bodyLarge)
                .padding(20)
                .background(NullFeedTheme.surface)
                .clipShape(RoundedRectangle(cornerRadius: NullFeedTheme.cardRadius))
                .disabled(viewModel.isCreating)
        }
    }

    private var importSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            sectionLabel("Import from YouTube (optional)")
            Text("Look up a YouTube profile to copy its name and avatar, and follow the channels it follows.")
                .font(NullFeedTheme.bodyMedium)
                .foregroundStyle(NullFeedTheme.textSecondary)

            HStack(spacing: 20) {
                TextField("@handle or channel URL", text: $viewModel.handle)
                    .textFieldStyle(.plain)
                    .font(NullFeedTheme.bodyLarge)
                    .padding(20)
                    .background(NullFeedTheme.surface)
                    .clipShape(RoundedRectangle(cornerRadius: NullFeedTheme.cardRadius))
                    .autocorrectionDisabled()
                    .disabled(viewModel.isCreating || viewModel.isResolving)
                    .onSubmit { Task { await viewModel.lookupHandle() } }

                Button {
                    Task { await viewModel.lookupHandle() }
                } label: {
                    Group {
                        if viewModel.isResolving {
                            ProgressView().tint(NullFeedTheme.textPrimary)
                        } else {
                            Text("Look Up").font(NullFeedTheme.titleMedium)
                        }
                    }
                    .frame(minWidth: 160)
                    .padding(.vertical, 18)
                    .padding(.horizontal, 24)
                    .background(NullFeedTheme.primary)
                    .foregroundStyle(NullFeedTheme.textPrimary)
                    .clipShape(RoundedRectangle(cornerRadius: NullFeedTheme.cardRadius))
                }
                .buttonStyle(CardButtonStyle())
                .disabled(lookupDisabled)
            }

            if let resolveError = viewModel.resolveError {
                errorText(resolveError)
            }

            if let profile = viewModel.resolvedProfile {
                identityPreview(profile)
                suggestionsSection
            }
        }
    }

    private var pinSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            sectionLabel("PIN (optional)")
            Text("Require a 4-8 digit PIN to open this profile.")
                .font(NullFeedTheme.bodyMedium)
                .foregroundStyle(NullFeedTheme.textSecondary)
            Button {
                showPinSheet = true
            } label: {
                HStack(spacing: 16) {
                    Image(systemName: viewModel.pin == nil ? "lock.open" : "lock.fill")
                    Text(viewModel.pin == nil ? "Set PIN" : "PIN set — tap to change")
                    Spacer()
                }
                .font(NullFeedTheme.bodyLarge)
                .foregroundStyle(NullFeedTheme.textPrimary)
                .padding(20)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(NullFeedTheme.card)
                .clipShape(RoundedRectangle(cornerRadius: NullFeedTheme.cardRadius))
            }
            .buttonStyle(CardButtonStyle())
            .disabled(viewModel.isCreating)
        }
    }

    private var actions: some View {
        HStack(spacing: 24) {
            Button("Cancel", action: onCancel)
                .tint(NullFeedTheme.textMuted)
                .disabled(viewModel.isCreating)

            Button {
                Task { _ = await viewModel.create() }
            } label: {
                HStack(spacing: 12) {
                    if viewModel.isCreating {
                        ProgressView().tint(NullFeedTheme.textPrimary)
                    }
                    Text(viewModel.isCreating
                        ? (viewModel.busyStatus ?? "Creating profile…")
                        : "Create Profile")
                        .font(NullFeedTheme.titleMedium)
                }
                .padding(.vertical, 18)
                .padding(.horizontal, 32)
                .background(NullFeedTheme.primary)
                .foregroundStyle(NullFeedTheme.textPrimary)
                .clipShape(RoundedRectangle(cornerRadius: NullFeedTheme.cardRadius))
            }
            .buttonStyle(CardButtonStyle())
            .disabled(!viewModel.canCreate)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 8)
    }

    // MARK: - Suggestions

    @ViewBuilder
    private var suggestionsSection: some View {
        if viewModel.isLoadingSuggestions {
            HStack(spacing: 16) {
                ProgressView().tint(NullFeedTheme.primary)
                Text("Finding channels they follow…")
                    .font(NullFeedTheme.bodyMedium)
                    .foregroundStyle(NullFeedTheme.textSecondary)
            }
        } else if let error = viewModel.suggestionsError {
            HStack(spacing: 16) {
                errorText(error)
                Spacer()
                Button("Retry") { Task { await viewModel.loadSuggestions() } }
                    .tint(NullFeedTheme.primary)
                    .disabled(viewModel.isCreating)
            }
        } else if let suggestions = viewModel.suggestions {
            if suggestions.isEmpty {
                Text("No public channels found — you can add channels later in Library.")
                    .font(NullFeedTheme.bodyMedium)
                    .foregroundStyle(NullFeedTheme.textSecondary)
                    .padding(20)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(NullFeedTheme.card)
                    .clipShape(RoundedRectangle(cornerRadius: NullFeedTheme.cardRadius))
            } else {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("Channels they follow")
                            .font(NullFeedTheme.titleMedium)
                            .foregroundStyle(NullFeedTheme.textPrimary)
                        Spacer()
                        Text("\(viewModel.selectedSuggestionIds.count) of \(suggestions.count) selected")
                            .font(NullFeedTheme.bodySmall)
                            .foregroundStyle(NullFeedTheme.textSecondary)
                    }
                    ForEach(suggestions) { suggestion in
                        suggestionRow(suggestion)
                    }
                }
            }
        }
    }

    private func suggestionRow(_ suggestion: ChannelSuggestion) -> some View {
        let isSelected = viewModel.selectedSuggestionIds.contains(suggestion.youtubeChannelId)
        return Button {
            viewModel.toggleSuggestion(suggestion.youtubeChannelId)
        } label: {
            HStack(spacing: 20) {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(NullFeedTheme.titleMedium)
                    .foregroundStyle(isSelected ? NullFeedTheme.primary : NullFeedTheme.textMuted)
                VStack(alignment: .leading, spacing: 4) {
                    Text(suggestion.name)
                        .font(NullFeedTheme.bodyLarge)
                        .foregroundStyle(NullFeedTheme.textPrimary)
                        .lineLimit(1)
                    Text(Self.sourceLabel(suggestion.source))
                        .font(NullFeedTheme.bodySmall)
                        .foregroundStyle(NullFeedTheme.textSecondary)
                }
                Spacer()
            }
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(NullFeedTheme.card)
            .clipShape(RoundedRectangle(cornerRadius: NullFeedTheme.cardRadius))
        }
        .buttonStyle(CardButtonStyle())
        .disabled(viewModel.isCreating)
    }

    // MARK: - Identity preview

    private func identityPreview(_ profile: YoutubeProfile) -> some View {
        HStack(spacing: 20) {
            avatar(for: profile)
            VStack(alignment: .leading, spacing: 6) {
                Text(profile.name)
                    .font(NullFeedTheme.titleMedium)
                    .foregroundStyle(NullFeedTheme.textPrimary)
                    .lineLimit(1)
                Text(profile.handle)
                    .font(NullFeedTheme.bodyMedium)
                    .foregroundStyle(NullFeedTheme.textSecondary)
                    .lineLimit(1)
                if let count = profile.followerCount {
                    Text(Self.formatFollowers(count))
                        .font(NullFeedTheme.bodySmall)
                        .foregroundStyle(NullFeedTheme.textSecondary)
                }
            }
            Spacer()
            Button {
                viewModel.clearImport()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(NullFeedTheme.titleMedium)
                    .foregroundStyle(NullFeedTheme.textMuted)
            }
            .buttonStyle(.bordered)
            .disabled(viewModel.isCreating)
        }
        .padding(20)
        .background(NullFeedTheme.card)
        .clipShape(RoundedRectangle(cornerRadius: NullFeedTheme.cardRadius))
    }

    @ViewBuilder
    private func avatar(for profile: YoutubeProfile) -> some View {
        if let url = api.mediaURL(profile.avatarUrl), !url.isEmpty {
            AsyncImageView(url: url, cornerRadius: 40)
                .frame(width: 80, height: 80)
                .clipShape(Circle())
        } else {
            ZStack {
                Circle()
                    .fill(NullFeedTheme.primary)
                    .frame(width: 80, height: 80)
                Text(Self.initials(profile.name))
                    .font(NullFeedTheme.titleMedium)
                    .foregroundStyle(NullFeedTheme.textPrimary)
            }
        }
    }

    // MARK: - Helpers

    private var lookupDisabled: Bool {
        viewModel.handle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            || viewModel.isResolving
            || viewModel.isCreating
    }

    private func sectionLabel(_ text: String) -> some View {
        Text(text)
            .font(NullFeedTheme.titleMedium)
            .foregroundStyle(NullFeedTheme.textPrimary)
    }

    private func errorText(_ text: String) -> some View {
        Text(text)
            .font(NullFeedTheme.bodyMedium)
            .foregroundStyle(NullFeedTheme.error)
    }

    private static func sourceLabel(_ source: String) -> String {
        switch source {
        case "featured": return "Featured channel"
        case "playlists": return "From public playlists"
        default: return source
        }
    }

    private static func formatFollowers(_ count: Int) -> String {
        if count >= 1_000_000 {
            return String(format: "%.1fM subscribers", Double(count) / 1_000_000)
        }
        if count >= 1_000 {
            return String(format: "%.1fK subscribers", Double(count) / 1_000)
        }
        return "\(count) subscribers"
    }

    private static func initials(_ name: String) -> String {
        let parts = name.split(separator: " ")
        let letters = parts.prefix(2).compactMap { $0.first }
        return String(letters).uppercased()
    }
}
