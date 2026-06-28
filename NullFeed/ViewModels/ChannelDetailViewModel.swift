import Foundation

@MainActor
@Observable
final class ChannelDetailViewModel {
    var channel: Channel?
    var videos: [Video] = []
    var isLoading = false
    var isRefreshing = false
    var error: String?

    /// Live download progress (0...1) per video id, fed by WebSocket
    /// `download_progress` events. Absent means no active download to show.
    var downloadProgress: [String: Double] = [:]

    private let api: APIClient

    init(api: APIClient) {
        self.api = api
    }

    func load(channelId: String) async {
        isLoading = true
        error = nil
        downloadProgress = [:]
        do {
            async let channelReq = api.getChannel(channelId)
            async let videosReq = api.getChannelVideos(channelId)
            channel = try await channelReq
            videos = try await videosReq
        } catch {
            self.error = error.localizedDescription
        }
        isLoading = false
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

    func downloadVideo(_ id: String) async {
        do {
            try await api.downloadVideo(id)
            downloadProgress[id] = nil
            if let index = videos.firstIndex(where: { $0.id == id }) {
                videos[index].status = .pending
            }
        } catch {
            self.error = error.localizedDescription
        }
    }

    /// Cancel an in-flight (pending/downloading) download and return the row to
    /// its not-downloaded state.
    func cancelDownload(_ id: String) async {
        do {
            try await api.cancelDownload(id)
            downloadProgress[id] = nil
            if let index = videos.firstIndex(where: { $0.id == id }) {
                videos[index].status = .cataloged
            }
        } catch {
            self.error = error.localizedDescription
        }
    }

    func deleteVideo(_ id: String) async {
        do {
            try await api.deleteVideo(id)
            downloadProgress[id] = nil
            videos.removeAll { $0.id == id }
        } catch {
            self.error = error.localizedDescription
        }
    }

    /// Apply a live download event to the matching row. `download_progress`
    /// advances the row's progress bar (and flips it to DOWNLOADING); a
    /// `download_complete` refetches the video so it flips to playable.
    func handle(_ event: WebSocketEvent) async {
        guard let videoId = event.videoId else { return }
        switch event.type {
        case .downloadProgress:
            guard let index = videos.firstIndex(where: { $0.id == videoId }) else { return }
            if let percentage = event.percentage {
                downloadProgress[videoId] = min(max(percentage / 100, 0), 1)
            }
            if videos[index].status != .downloading {
                videos[index].status = .downloading
            }
        case .downloadComplete:
            downloadProgress[videoId] = nil
            // Refetch the single row (not the whole list) so it gains its file
            // path / playable status without disturbing scroll or focus.
            let updated = try? await api.getVideo(videoId)
            guard let index = videos.firstIndex(where: { $0.id == videoId }) else { return }
            if let updated {
                videos[index] = updated
            } else {
                videos[index].status = .complete
            }
        default:
            break
        }
    }
}
