import Foundation

/// Drives the add-profile flow: an optional YouTube import (resolve a handle ->
/// preview identity -> multi-select the channels it follows) plus a plain
/// name + optional PIN. `create()` makes the profile, selects it to mint a
/// session token, bulk-subscribes the chosen channels, and signs in.
@MainActor
@Observable
final class AddProfileViewModel {
    // Form fields
    var name = ""
    var handle = ""
    /// nil = no PIN; otherwise a validated 4-8 digit PIN from `SetPinView`.
    var pin: String?

    // YouTube resolve
    var resolvedProfile: YoutubeProfile?
    var isResolving = false
    var resolveError: String?

    // Suggestions
    var suggestions: [ChannelSuggestion]?
    var isLoadingSuggestions = false
    var suggestionsError: String?
    var selectedSuggestionIds: Set<String> = []

    // Create
    var isCreating = false
    var busyStatus: String?
    var createError: String?

    private let api: APIClient
    private let storage: StorageService
    private let appState: AppState

    init(api: APIClient, storage: StorageService, appState: AppState) {
        self.api = api
        self.storage = storage
        self.appState = appState
    }

    var canCreate: Bool {
        !isCreating && (resolvedProfile != nil || !name.trimmed.isEmpty)
    }

    func toggleSuggestion(_ id: String) {
        if selectedSuggestionIds.contains(id) {
            selectedSuggestionIds.remove(id)
        } else {
            selectedSuggestionIds.insert(id)
        }
    }

    /// Resolve the entered handle, then load the channels it follows. The name
    /// field is auto-filled from the resolved profile only when still empty, so
    /// a name the user typed is never clobbered.
    func lookupHandle() async {
        let trimmed = handle.trimmed
        guard !trimmed.isEmpty, !isResolving else { return }
        isResolving = true
        resolveError = nil
        resolvedProfile = nil
        suggestions = nil
        suggestionsError = nil
        selectedSuggestionIds = []
        do {
            let profile = try await api.resolveYoutubeHandle(trimmed)
            resolvedProfile = profile
            if name.trimmed.isEmpty { name = profile.name }
            isResolving = false
            await loadSuggestions()
        } catch {
            isResolving = false
            resolveError = error.localizedDescription
        }
    }

    func loadSuggestions() async {
        guard let profile = resolvedProfile else { return }
        isLoadingSuggestions = true
        suggestionsError = nil
        do {
            let items = try await api.getYoutubeSuggestions(handle: profile.handle)
            suggestions = items
            selectedSuggestionIds = Set(items.map(\.youtubeChannelId))
            isLoadingSuggestions = false
        } catch {
            isLoadingSuggestions = false
            suggestionsError = error.localizedDescription
        }
    }

    func clearImport() {
        resolvedProfile = nil
        resolveError = nil
        suggestions = nil
        suggestionsError = nil
        selectedSuggestionIds = []
    }

    /// Create the profile, sign in, and bulk-subscribe the selected channels.
    /// Returns true on success; the caller relies on the resulting auth-state
    /// flip to leave the picker.
    func create() async -> Bool {
        guard !isCreating else { return false }
        if let validationError = validate() {
            createError = validationError
            return false
        }
        let trimmedName = name.trimmed
        let resolved = resolvedProfile
        isCreating = true
        createError = nil
        busyStatus = "Creating profile…"
        do {
            let user: User
            if let resolved {
                user = try await api.createProfile(
                    displayName: trimmedName.isEmpty ? nil : trimmedName,
                    pin: pin,
                    youtubeHandle: resolved.handle
                )
            } else {
                user = try await api.createProfile(displayName: trimmedName, pin: pin)
            }

            // Select the new profile to mint a session token; bulk subscribe is
            // authenticated, so persist the token before calling it. Defer the
            // auth-state flip (appState.login) until after subscribing so the
            // picker stays put while work is in flight.
            let session = try await api.selectProfile(userId: user.id, pin: pin)
            storage.sessionToken = session.token
            storage.selectedUserId = session.user.id

            let checked = (suggestions ?? []).filter {
                selectedSuggestionIds.contains($0.youtubeChannelId)
            }
            if !checked.isEmpty {
                busyStatus = "Following \(checked.count) channels…"
                // Best effort: a follow failure shouldn't block an otherwise
                // successful sign-in (channels can be added later in Library).
                _ = try? await api.subscribeBulk(checked)
            }

            appState.login(user: session.user, token: session.token)
            return true
        } catch {
            isCreating = false
            busyStatus = nil
            createError = error.localizedDescription
            return false
        }
    }

    private func validate() -> String? {
        let trimmed = name.trimmed
        if resolvedProfile == nil && trimmed.isEmpty {
            return "Enter a name or import a profile from YouTube"
        }
        if trimmed.count > 50 {
            return "Name must be 50 characters or fewer"
        }
        return nil
    }
}

private extension String {
    var trimmed: String { trimmingCharacters(in: .whitespacesAndNewlines) }
}
