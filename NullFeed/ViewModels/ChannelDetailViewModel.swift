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
