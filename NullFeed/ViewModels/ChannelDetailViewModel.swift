import Foundation

@MainActor
@Observable
final class ChannelDetailViewModel {
    var channel: Channel?
    var videos: [Video] = []
    var isLoading = false
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
        } catch {
            self.error = error.localizedDescription
        }
        isLoading = false
    }

    func downloadVideo(_ id: String) async {
        do {
            try await api.downloadVideo(id)
            if let index = videos.firstIndex(where: { $0.id == id }) {
                videos[index].status = .pending
            }
        } catch {
            self.error = error.localizedDescription
        }
    }

    func deleteVideo(_ id: String) async {
        do {
            try await api.deleteVideo(id)
            videos.removeAll { $0.id == id }
        } catch {
            self.error = error.localizedDescription
        }
    }
}
