import Foundation
import AVKit

@MainActor
@Observable
final class PlayerViewModel {
    var player: AVPlayer?
    var isPreviewMode = false
    var isLoading = true
    var error: String?

    private let api: APIClient
    private let webSocket: WebSocketClient
    private var progressTimer: Timer?
    private var wsTask: Task<Void, Never>?
    private var videoId: String = ""

    init(api: APIClient, webSocket: WebSocketClient) {
        self.api = api
        self.webSocket = webSocket
    }

    func loadVideo(id: String) async {
        videoId = id
        isLoading = true
        error = nil

        do {
            let video = try await api.getVideo(id)

            // Path 1: HQ complete -- play directly
            if video.status == .complete {
                let url = api.getVideoStreamUrl(id)
                await startPlayback(url: url, video: video)
                return
            }

            // Path 2: Preview already ready -- play preview, listen for HQ
            if video.hasPreviewReady {
                let url = api.getPreviewStreamUrl(id)
                await startPlayback(url: url, video: video, isPreview: true)
                listenForHqReady()
                return
            }

            // Path 3: No preview -- request one, listen for it
            try? await api.requestPreview(id)
            listenForPreviewReady(video: video)
        } catch {
            self.error = "Failed to load video: \(error.localizedDescription)"
            isLoading = false
        }
    }

    private func startPlayback(url: String, video: Video, isPreview: Bool = false) async {
        guard let streamUrl = URL(string: url) else { return }
        let playerItem = AVPlayerItem(url: streamUrl)
        let avPlayer = AVPlayer(playerItem: playerItem)

        // Resume position (rewind 10s for re-orientation)
        if video.watchPositionSeconds > 0 {
            let resumePos = max(0, video.watchPositionSeconds - 10)
            await avPlayer.seek(to: CMTime(seconds: Double(resumePos), preferredTimescale: 1))
        }

        avPlayer.play()
        player = avPlayer
        isPreviewMode = isPreview
        isLoading = false

        startProgressTimer()
    }

    private func listenForPreviewReady(video: Video) {
        wsTask?.cancel()
        wsTask = Task {
            let timeout = Task {
                try? await Task.sleep(for: .seconds(30))
                if isLoading {
                    error = "Preview download timed out. Try again later."
                    isLoading = false
                }
            }

            for await event in webSocket.events {
                guard !Task.isCancelled else { break }
                if event.videoId == videoId {
                    if event.type == .previewReady {
                        timeout.cancel()
                        let url = api.getPreviewStreamUrl(videoId)
                        await startPlayback(url: url, video: video, isPreview: true)
                        listenForHqReady()
                        break
                    } else if event.type == .downloadComplete {
                        timeout.cancel()
                        let url = api.getVideoStreamUrl(videoId)
                        await startPlayback(url: url, video: video)
                        break
                    }
                }
            }
        }
    }

    private func listenForHqReady() {
        wsTask?.cancel()
        wsTask = Task {
            for await event in webSocket.events {
                guard !Task.isCancelled else { break }
                if event.type == .downloadComplete && event.videoId == videoId {
                    await switchToHq()
                    break
                }
            }
        }
    }

    private func switchToHq() async {
        guard let currentPlayer = player else { return }
        let currentTime = currentPlayer.currentTime()

        let url = api.getVideoStreamUrl(videoId)
        guard let streamUrl = URL(string: url) else { return }

        let newItem = AVPlayerItem(url: streamUrl)
        let newPlayer = AVPlayer(playerItem: newItem)
        await newPlayer.seek(to: currentTime)
        newPlayer.play()

        currentPlayer.pause()
        player = newPlayer
        isPreviewMode = false
    }

    private func startProgressTimer() {
        progressTimer?.invalidate()
        progressTimer = Timer.scheduledTimer(
            withTimeInterval: Double(AppConstants.progressSaveIntervalSeconds),
            repeats: true
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.saveProgress()
            }
        }
    }

    func saveProgress() {
        guard let player, player.currentItem != nil else { return }
        let position = Int(player.currentTime().seconds)
        guard position > 0 else { return }
        Task {
            try? await api.updateProgress(videoId: videoId, positionSeconds: position)
        }
    }

    func cleanup() {
        saveProgress()
        progressTimer?.invalidate()
        progressTimer = nil
        wsTask?.cancel()
        wsTask = nil
        player?.pause()
        player = nil
    }

}
