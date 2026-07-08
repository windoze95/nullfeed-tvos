import Foundation

@MainActor
@Observable
final class ChannelDetailViewModel {
    var channel: Channel?
    var videos: [Video] = []
    var isLoading = false
    var isRefreshing = false
    var error: String?

    private let api: APIClient

    init(api: APIClient) {
        self.api = api
    }

    func load(channelId: String) async {
        isLoading = true
        error = nil
        do {
            async let channelReq = api.getChannel(channelId)
            async let videosReq = api.getChannelVideos(channelId)
            channel = try await channelReq
            videos = try await videosReq
            prewarmPreviews(for: videos)
        } catch {
            self.error = error.localizedDescription
        }
        isLoading = false
    }

    /// Best-effort: pre-generate previews for the not-yet-playable videos the
    /// user is most likely to open next, so a tap lands on the ready-preview
    /// fast path. Skips already-downloaded / already-previewed videos.
    private func prewarmPreviews(for videos: [Video]) {
        let ids = videos.filter { !$0.isPlayable }
            .prefix(AppConstants.prewarmBatchSize)
            .map(\.id)
        guard !ids.isEmpty else { return }
        Task { [api] in try? await api.prewarmPreviews(Array(ids)) }
    }

    /// Toggle a content type in this channel's per-channel filter (persisted
    /// server-side), then re-fetch the now-gated video list. Best-effort: a
    /// failure leaves the current state untouched.
    func toggleContentType(_ type: ContentType, channelId: String) async {
        guard let channel else { return }
        var hidden = Set(channel.hiddenContentTypes ?? [])
        if hidden.contains(type.rawValue) {
            hidden.remove(type.rawValue)
        } else {
            hidden.insert(type.rawValue)
        }
        do {
            self.channel = try await api.setContentFilter(channelId, hidden: Array(hidden))
            videos = try await api.getChannelVideos(channelId)
        } catch {
            // Leave state as-is on failure.
        }
    }

    /// Trigger a synchronous server-side poll of just this channel, then reload
    /// its detail and video list.
    func refresh(channelId: String) async {
        guard !isRefreshing else { return }
        isRefreshing = true
        try? await api.pollChannel(channelId)
        await load(channelId: channelId)
        isRefreshing = false
    }
}
