import Foundation
import AVKit

@MainActor
@Observable
final class PlayerViewModel {
    /// A pending pre-playback resume choice. Non-nil holds playback while the
    /// view shows a "Resume / Start Over" prompt; `resolveResumePrompt(resume:)`
    /// clears it and begins playback.
    struct ResumePrompt: Equatable {
        let title: String
        let positionSeconds: Int
    }

    var player: AVPlayer?
    var isPreviewMode = false
    /// Briefly true after auto-skipping a sponsor segment, so the view can show
    /// a "Skipped sponsor" toast.
    var showSkipToast = false
    var isLoading = true
    var error: String?
    /// Why this video can't play (age-restricted, members-only, …), when the
    /// server has it labeled. The view shows an explanatory screen with a
    /// "Try Anyway" escape hatch instead of a doomed stream attempt.
    var blockedReason: UnplayableReason?
    /// Set when a video opens with a saved position to return to; the view
    /// presents the resume choice and playback waits on the viewer.
    var resumePrompt: ResumePrompt?

    private let api: APIClient
    private let webSocket: WebSocketClient
    private let queue: QueueViewModel
    private var progressTimer: Timer?
    private var wsTask: Task<Void, Never>?
    /// Slow status-poll fallback for the preview -> HQ swap, in case the
    /// one-shot download_complete WS event is missed (drop/reconnect).
    private var hqPollTask: Task<Void, Never>?
    /// Guards against the WS event and the poll fallback racing into
    /// concurrent HQ swaps.
    private var switchingToHq = false
    private var videoId: String = ""
    private var video: Video?
    /// Set by "Try Anyway": skip the blockedReason gate for this screen so a
    /// stale label can heal (the backend clears it on a successful resolve).
    private var ignoreUnplayableGate = false
    /// Bounded watcher for the freshly attached item; surfaces a load failure
    /// (e.g. the instant proxy refusing a video YouTube won't serve) instead
    /// of leaving AVKit stuck on an opaque error.
    private var itemFailureTask: Task<Void, Never>?
    /// The position (seconds) the current item should begin at: the resume point
    /// the viewer chose, or 0 to start from the beginning.
    private var startPositionSeconds = 0
    private var endObserver: NSObjectProtocol?
    /// Set once the item plays to its end so the final "watched" write (which
    /// clears the resume position) can't be clobbered by a trailing progress
    /// save from the timer or `cleanup()`.
    private var didReachEnd = false
    /// The in-flight auto-advance, cancelled by `cleanup()` so a manual exit
    /// taken while the next item is being fetched can't start ghost playback.
    private var advanceTask: Task<Void, Never>?
    /// Detected sponsor segments; the playhead seeks past any it enters.
    private var adSegments: [AdSegment] = []
    /// End (seconds) of the sponsor segment whose skip-seek has been issued but
    /// hasn't landed yet. Guards `maybeSkipAd` against re-issuing a seek on every
    /// 0.5s observer tick while a from-cold seek is still buffering — that seek
    /// storm livelocks the player. Cleared once the playhead lands past it.
    private var skipSeekInFlightEnd: Double?
    /// Token for the periodic time observer that drives ad skipping; removed in
    /// teardown/cleanup before the player is released.
    private var adSkipObserver: Any?
    private var skipToastTask: Task<Void, Never>?
    /// Listens for the ad_segments_ready WS event so the first play applies
    /// segments that finished detecting after playback began.
    private var adSegmentsTask: Task<Void, Never>?

    init(api: APIClient, webSocket: WebSocketClient, queue: QueueViewModel) {
        self.api = api
        self.webSocket = webSocket
        self.queue = queue
    }

    /// Load a video and either present a resume choice or begin playback.
    ///
    /// `promptForResume` is the explicit-open path (the default): a video with a
    /// saved position the viewer hasn't finished pauses on a "Resume / Start
    /// Over" prompt before playing. Auto-advance through the queue passes
    /// `false`, continuing seamlessly -- resuming any saved position without a
    /// prompt so a binge isn't interrupted.
    func loadVideo(id: String, promptForResume: Bool = true) async {
        videoId = id
        isLoading = true
        error = nil
        blockedReason = nil
        didReachEnd = false
        resumePrompt = nil

        do {
            let video = try await api.getVideo(id)
            // Bail if the view went away while loading (e.g. a manual exit during
            // an auto-advance), so we don't start a player or preview listener for
            // an item nothing is showing. Harmless for the initial load, whose
            // task is never cancelled.
            if Task.isCancelled { isLoading = false; return }
            self.video = video

            // A video the server knows YouTube refuses (age-restricted,
            // members-only, …) can't stream; explain instead of attempting.
            // activeUnplayableReason is nil whenever a playable file exists.
            if !ignoreUnplayableGate, let reason = video.activeUnplayableReason {
                blockedReason = reason
                isLoading = false
                return
            }

            if promptForResume && Self.hasResumePoint(for: video) {
                // Hand the choice to the viewer; playback resumes in
                // `resolveResumePrompt(resume:)`.
                resumePrompt = ResumePrompt(title: video.title, positionSeconds: video.watchPositionSeconds)
                isLoading = false
                return
            }

            // No prompt: resume a saved position when there is one (e.g. an
            // auto-advanced item the viewer had partly seen), else start at 0.
            let start = Self.hasResumePoint(for: video)
                ? Self.resumeStart(forPosition: video.watchPositionSeconds)
                : 0
            await beginPlayback(from: start)
        } catch {
            self.error = "Failed to load video: \(error.localizedDescription)"
            isLoading = false
        }
    }

    /// "Try Anyway" from the blocked screen: retry with the gate off. If
    /// YouTube now serves the video (cookies fixed, premiere aired) the server
    /// clears the label and playback just starts; otherwise the normal error
    /// paths report the failure.
    func tryAnyway() {
        ignoreUnplayableGate = true
        blockedReason = nil
        let id = videoId
        Task { await loadVideo(id: id) }
    }

    /// Apply the viewer's choice from the resume prompt: resume from the saved
    /// position (rewound for re-orientation) or start over from the beginning.
    func resolveResumePrompt(resume: Bool) {
        guard let prompt = resumePrompt else { return }
        resumePrompt = nil
        isLoading = true
        let start = resume ? Self.resumeStart(forPosition: prompt.positionSeconds) : 0
        Task { await beginPlayback(from: start) }
    }

    /// Whether opening `video` should offer a resume choice: it has a saved
    /// position to return to and isn't already finished (finishing clears the
    /// position, so a watched video always starts over).
    static func hasResumePoint(for video: Video) -> Bool {
        video.watchPositionSeconds > 0 && !video.isWatched
    }

    /// The playback start for a saved position, rewound a little so the viewer
    /// re-orients before the cut they left off at. Never negative.
    static func resumeStart(forPosition seconds: Int) -> Int {
        max(0, seconds - AppConstants.resumeRewindSeconds)
    }

    /// Resolve which stream to play -- full quality, a ready preview, or a
    /// requested-and-awaited preview -- and start it at `startSeconds`.
    private func beginPlayback(from startSeconds: Int) async {
        guard let video else { return }
        startPositionSeconds = startSeconds

        // Path 1: HQ complete -- play directly
        if video.status == .complete {
            do {
                let url = try await api.getVideoStreamUrl(videoId)
                await startPlayback(url: url, video: video)
            } catch {
                failPlayback(error)
            }
            return
        }

        // Path 2: Preview already ready -- play preview, listen for HQ. A
        // warmed preview (prewarm) means nothing has enqueued the HQ download
        // yet, so request it -- without this the HQ listener waits forever.
        // Idempotent and best-effort, like the instant-stream path below.
        if video.hasPreviewReady {
            do {
                Task { [api, videoId] in try? await api.cacheVideo(videoId) }
                let url = try await api.getPreviewStreamUrl(videoId)
                await startPlayback(url: url, video: video, isPreview: true)
                listenForHqReady()
            } catch {
                failPlayback(error)
            }
            return
        }

        // Path 3: Not downloaded yet -- start instantly by proxying a
        // progressive source stream, then listen for an HQ download to swap in
        // if one lands. This replaces waiting for a preview file to be generated
        // on a cold press; the preview path below stays as a fallback.
        do {
            let url = try await api.getInstantStreamUrl(videoId)
            await startPlayback(url: url, video: video, isPreview: true)
            listenForHqReady()
            // Cache the HQ version in the background (evictable, not a library
            // download) so the player can swap preview -> HQ. Best-effort.
            Task { [api, videoId] in try? await api.cacheVideo(videoId) }
            return
        } catch {
            // Couldn't mint a ticket / reach the server -- fall back to a preview.
        }

        // Fallback: request a preview and wait for it.
        try? await api.requestPreview(videoId)
        listenForPreviewReady(video: video)
    }

    /// Surface a playback-start failure (e.g. a stream ticket couldn't be minted)
    /// and clear the loading state so the view shows the error instead of hanging.
    private func failPlayback(_ error: Error) {
        self.error = "Failed to load video: \(error.localizedDescription)"
        isLoading = false
    }

    private func startPlayback(url: String, video: Video, isPreview: Bool = false) async {
        guard let streamUrl = URL(string: url) else { return }
        let playerItem = AVPlayerItem(url: streamUrl)
        applyMetadata(to: playerItem, video: video)
        let avPlayer = AVPlayer(playerItem: playerItem)

        // Begin at the position resolved for this item -- the resume point the
        // viewer chose (already rewound), or 0 to start over / for a fresh video.
        if startPositionSeconds > 0 {
            await avPlayer.seek(to: CMTime(seconds: Double(startPositionSeconds), preferredTimescale: 1))
        }

        // A cancelled task means the view went away while we were preparing this
        // item (e.g. a manual exit during an auto-advance fetch); don't attach a
        // player nothing is showing.
        guard !Task.isCancelled else { return }

        avPlayer.play()
        player = avPlayer
        isPreviewMode = isPreview
        isLoading = false
        // Fresh item: no skip-seek is in flight yet.
        skipSeekInFlightEnd = nil

        observePlaybackEnd(of: playerItem)
        watchForItemFailure(playerItem)
        startProgressTimer()
        addAdSkipObserver(to: avPlayer)
        loadAdSegments()
    }

    /// Watch the freshly attached item until it's ready or failed. AVKit shows
    /// only an opaque error when an item dies before playing — e.g. the
    /// instant-stream proxy refusing a video YouTube won't serve — while that
    /// same failed attempt just taught the server *why* (it classifies and
    /// stores the reason on a failed resolve). Re-fetch the video and show the
    /// reason when there is one; otherwise surface a plain error.
    private func watchForItemFailure(_ item: AVPlayerItem) {
        itemFailureTask?.cancel()
        itemFailureTask = Task { [weak self] in
            let pollInterval = Duration.milliseconds(250)
            let maxPolls = 120 // ~30s at 250ms per poll
            var polls = 0
            while !Task.isCancelled && polls < maxPolls {
                if item.status == .readyToPlay { return }
                if item.status == .failed {
                    await self?.handleItemFailure()
                    return
                }
                try? await Task.sleep(for: pollInterval)
                polls += 1
            }
        }
    }

    private func handleItemFailure() async {
        // Only react while this failed item is still what the screen shows.
        guard player != nil, !didReachEnd else { return }
        player?.pause()
        player = nil
        if !ignoreUnplayableGate,
           let refreshed = try? await api.getVideo(videoId),
           let reason = refreshed.activeUnplayableReason {
            video = refreshed
            blockedReason = reason
        } else {
            error = "Playback failed. The stream could not be started."
        }
        isLoading = false
    }

    // MARK: - Sponsor skipping

    /// Best-effort: load detected sponsor segments for the current video.
    private func loadAdSegments() {
        let videoId = self.videoId
        Task { @MainActor [weak self, api] in
            let segments = (try? await api.getAdSegments(videoId)) ?? []
            guard let self else { return }
            self.adSegments = segments
            // None yet means detection is still running (first play); apply them
            // when the backend signals they're ready.
            if segments.isEmpty { self.listenForAdSegmentsReady() }
        }
    }

    private func listenForAdSegmentsReady() {
        adSegmentsTask?.cancel()
        adSegmentsTask = Task {
            for await event in webSocket.subscribe() {
                guard !Task.isCancelled else { break }
                if event.type == .adSegmentsReady && event.videoId == videoId {
                    adSegments = (try? await api.getAdSegments(videoId)) ?? []
                    break
                }
            }
        }
    }

    /// Observe playback time and seek past any sponsor segment the playhead
    /// enters. Added once to the AVPlayer; it survives the preview->HQ item swap
    /// (switchToHq reuses the same player), and is removed in teardown/cleanup.
    private func addAdSkipObserver(to player: AVPlayer) {
        removeAdSkipObserver()
        let interval = CMTime(seconds: 0.5, preferredTimescale: CMTimeScale(NSEC_PER_SEC))
        adSkipObserver = player.addPeriodicTimeObserver(
            forInterval: interval, queue: .main
        ) { [weak self] time in
            let seconds = time.seconds
            Task { @MainActor [weak self] in
                self?.maybeSkipAd(at: seconds)
            }
        }
    }

    private func removeAdSkipObserver() {
        if let token = adSkipObserver {
            player?.removeTimeObserver(token)
            adSkipObserver = nil
        }
    }

    private func maybeSkipAd(at positionSeconds: Double) {
        guard let player, !adSegments.isEmpty, positionSeconds.isFinite else { return }
        // Stand down during the HQ swap: switchToHq reuses this player and
        // replaces its item (currentTime momentarily reads ~0) then re-seeks to
        // the restored spot, so a skip-seek here would fire on a fresh,
        // unbuffered item and fight the swap's own seek — the "finished caching"
        // freeze.
        guard !switchingToHq else { return }
        let decision = Self.sponsorSkipDecision(
            position: positionSeconds,
            segments: adSegments,
            inFlightEnd: skipSeekInFlightEnd
        )
        skipSeekInFlightEnd = decision.inFlightEnd
        if let target = decision.seekTo {
            player.seek(to: CMTime(seconds: target, preferredTimescale: 1))
            flashSkipToast()
        }
    }

    /// Pure decision for the sponsor-skip guard, extracted so its anti-seek-storm
    /// behavior is unit-testable without a live player.
    ///
    /// Given the playhead `position`, the detected `segments`, and the end
    /// (seconds) of a segment whose skip-seek is already in flight
    /// (`inFlightEnd`), returns the seek target (seconds) to issue — nil when
    /// nothing should be sought — and the in-flight end to remember for the next
    /// tick.
    ///
    /// The in-flight end is the crux: while a skip-seek is still buffering the
    /// playhead keeps reporting a position inside the segment, so without this
    /// the caller would re-issue a seek on every 0.5s observer tick. Each
    /// re-seek cancels and restarts the AVPlayer seek, so on a slow-to-buffer
    /// source it never lands and the player livelocks. Issue once, then wait for
    /// the playhead to land past the segment before considering another skip.
    static func sponsorSkipDecision(
        position: Double,
        segments: [AdSegment],
        inFlightEnd: Double?
    ) -> (seekTo: Double?, inFlightEnd: Double?) {
        var inFlightEnd = inFlightEnd
        // The playhead landed past the segment we were skipping — drop the guard
        // so a later segment is free to skip.
        if let end = inFlightEnd, position >= end - 0.5 {
            inFlightEnd = nil
        }
        for segment in segments
        where position >= segment.start && position < segment.end - 0.5 {
            // This segment's skip is already in flight — hold, don't storm.
            if inFlightEnd == segment.end {
                return (nil, inFlightEnd)
            }
            return (segment.end, segment.end)
        }
        return (nil, inFlightEnd)
    }

    private func flashSkipToast() {
        showSkipToast = true
        skipToastTask?.cancel()
        skipToastTask = Task { @MainActor [weak self] in
            try? await Task.sleep(for: .seconds(2))
            self?.showSkipToast = false
        }
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

            for await event in webSocket.subscribe() {
                guard !Task.isCancelled else { break }
                if event.videoId == videoId {
                    if event.type == .previewReady {
                        timeout.cancel()
                        do {
                            // The preview request alone never enqueues the HQ
                            // download -- ask for it here so the swap the HQ
                            // listener waits for can actually happen.
                            Task { [api, videoId] in try? await api.cacheVideo(videoId) }
                            let url = try await api.getPreviewStreamUrl(videoId)
                            await startPlayback(url: url, video: video, isPreview: true)
                            listenForHqReady()
                        } catch {
                            failPlayback(error)
                        }
                        break
                    } else if event.type == .downloadComplete {
                        timeout.cancel()
                        do {
                            let url = try await api.getVideoStreamUrl(videoId)
                            await startPlayback(url: url, video: video)
                        } catch {
                            failPlayback(error)
                        }
                        break
                    }
                }
            }
        }
    }

    private func listenForHqReady() {
        wsTask?.cancel()
        wsTask = Task {
            for await event in webSocket.subscribe() {
                guard !Task.isCancelled else { break }
                if event.type == .downloadComplete && event.videoId == videoId {
                    await switchToHq()
                    break
                }
            }
        }

        // The download_complete event fires exactly once; a WS drop/reconnect
        // at the wrong moment would leave the preview playing for the whole
        // session. Poll slowly as a safety net.
        hqPollTask?.cancel()
        hqPollTask = Task {
            while !Task.isCancelled && isPreviewMode {
                try? await Task.sleep(for: .seconds(AppConstants.hqPollIntervalSeconds))
                guard !Task.isCancelled && isPreviewMode else { break }
                guard let latest = try? await api.getVideo(videoId),
                      latest.status == .complete else { continue }
                await switchToHq()
            }
        }
    }

    /// Upgrade the preview stream to the full-quality stream without a black
    /// flash. The previous implementation built a brand-new `AVPlayer`, which
    /// made the SwiftUI player view tear down and rebuild its render surface --
    /// a visible flash. Here we reuse the *same* `AVPlayer` and only swap its
    /// current item.
    ///
    /// An item only fills its playback buffer once it's attached to a player,
    /// so we attach the HQ item (the player/render surface is untouched, so no
    /// flash), seek it to the current playhead, wait until it's likely to play
    /// through without stalling, then resume at the rate the user was watching.
    private func switchToHq() async {
        guard !switchingToHq, isPreviewMode else { return }
        guard let player, let currentItem = player.currentItem, let video else { return }
        switchingToHq = true
        defer { switchingToHq = false }
        let resumeTime = currentItem.currentTime()
        let resumeRate = player.rate

        let url: String
        do {
            url = try await api.getVideoStreamUrl(videoId)
        } catch {
            // Couldn't mint a ticket for the HQ stream; stay on the preview
            // rather than interrupting playback.
            return
        }
        guard let streamUrl = URL(string: url) else { return }

        let hqItem = AVPlayerItem(url: streamUrl)
        applyMetadata(to: hqItem, video: video)

        // Hold the current frame while the HQ item buffers, then align it to the
        // preview's playhead so the same moment continues in higher quality.
        player.pause()
        player.replaceCurrentItem(with: hqItem)
        await player.seek(to: resumeTime, toleranceBefore: .zero, toleranceAfter: .zero)
        await waitUntilReadyToPlayThrough(hqItem)

        // The view may have been torn down (or swapped again) while we waited.
        guard !Task.isCancelled, self.player === player, player.currentItem === hqItem else { return }

        observePlaybackEnd(of: hqItem)
        // Any skip-seek issued against the preview item is void now that the HQ
        // item is in place — clear the guard so a sponsor the playhead is still
        // sitting in gets skipped once on the new item.
        skipSeekInFlightEnd = nil
        player.rate = resumeRate
        isPreviewMode = false
    }

    /// Suspend until the item is ready and likely to play through without
    /// stalling (or has failed). Polls `status`/`isPlaybackLikelyToKeepUp`,
    /// bounded by a timeout so a slow or unavailable stream can't hang the
    /// upgrade -- the item must be attached to a player for these to advance.
    private func waitUntilReadyToPlayThrough(_ item: AVPlayerItem) async {
        let pollInterval = Duration.milliseconds(100)
        let maxPolls = 200 // ~20s at 100ms per poll
        var polls = 0
        while !Task.isCancelled && polls < maxPolls {
            if item.status == .failed { return }
            if item.status == .readyToPlay && item.isPlaybackLikelyToKeepUp { return }
            try? await Task.sleep(for: pollInterval)
            polls += 1
        }
    }

    // MARK: - Now Playing metadata

    /// Populate the item's external metadata so the tvOS Info panel (swipe down
    /// during playback) shows the title, channel, description, and artwork
    /// instead of being blank.
    private func applyMetadata(to item: AVPlayerItem, video: Video) {
        var metadata: [AVMetadataItem] = [
            metadataItem(.commonIdentifierTitle, value: video.title as NSString)
        ]
        if !video.channelName.isEmpty {
            metadata.append(metadataItem(.iTunesMetadataTrackSubTitle, value: video.channelName as NSString))
        }
        if let description = video.description, !description.isEmpty {
            metadata.append(metadataItem(.commonIdentifierDescription, value: description as NSString))
        }
        item.externalMetadata = metadata

        // Artwork comes from the video thumbnail. Fetch it asynchronously and
        // append it once available so it never blocks playback from starting.
        loadArtwork(for: video, into: item)
    }

    private func metadataItem(_ identifier: AVMetadataIdentifier, value: any NSCopying & NSObjectProtocol) -> AVMetadataItem {
        let item = AVMutableMetadataItem()
        item.identifier = identifier
        item.value = value
        item.extendedLanguageTag = "und"
        return item.copy() as! AVMetadataItem
    }

    private func loadArtwork(for video: Video, into item: AVPlayerItem) {
        guard let urlString = api.mediaURL(video.thumbnailUrl),
              let url = URL(string: urlString) else { return }
        Task { [weak item] in
            guard let (data, _) = try? await URLSession.shared.data(from: url),
                  let item else { return }
            let artwork = AVMutableMetadataItem()
            artwork.identifier = .commonIdentifierArtwork
            artwork.value = data as NSData
            artwork.dataType = kCMMetadataBaseDataType_JPEG as String
            artwork.extendedLanguageTag = "und"
            item.externalMetadata += [artwork.copy() as! AVMetadataItem]
        }
    }

    // MARK: - Watched state

    /// Watch for the current item reaching its end so we can mark the video
    /// watched. Re-registered whenever the current item changes (e.g. the HQ
    /// upgrade swaps it).
    private func observePlaybackEnd(of item: AVPlayerItem) {
        if let endObserver {
            NotificationCenter.default.removeObserver(endObserver)
        }
        endObserver = NotificationCenter.default.addObserver(
            forName: AVPlayerItem.didPlayToEndTimeNotification,
            object: item,
            queue: .main
        ) { [weak self] _ in
            // Delivered on the main thread (queue: .main); hop onto the
            // MainActor so we can touch actor-isolated state safely.
            Task { @MainActor [weak self] in
                self?.handlePlaybackEnded()
            }
        }
    }

    private func handlePlaybackEnded() {
        guard !didReachEnd else { return }
        didReachEnd = true
        // Stop periodic saves so they can't overwrite the cleared resume below.
        progressTimer?.invalidate()
        progressTimer = nil
        // Mark watched and clear the resume position (position 0) so the video
        // drops out of Continue Watching and restarts from the beginning.
        Task { [api, videoId] in
            try? await api.updateProgress(videoId: videoId, positionSeconds: 0, isWatched: true)
        }
        // Follow the watch-later queue. Only the natural end-of-item posts this
        // notification, so a manual exit never auto-advances.
        advanceTask = Task { await advanceToNextInQueue() }
    }

    // MARK: - Auto-advance

    /// Continue with the next item in the watch-later queue when a video plays to
    /// its end. The finished (now watched) video leaves the queue. Does nothing
    /// if the finished video wasn't part of the queue or was its last item, so
    /// finishing a one-off video never pulls the user into the queue.
    private func advanceToNextInQueue() async {
        let finishedId = videoId
        await queue.ensureLoaded()
        if Task.isCancelled { return }
        guard queue.isQueued(finishedId) else { return }

        // Resolve the successor before removing the finished item, since removal
        // shifts the list. The removal is fire-and-forget: its in-memory effect
        // is immediate and the DELETE is idempotent, so the advance needn't wait
        // on the network.
        let next = queue.videoAfter(finishedId)
        Task { await queue.remove(finishedId) }

        guard let next else { return }
        teardownForNextItem()
        // Continue the binge without a prompt; a partly-seen queued item still
        // resumes from where it was left.
        await loadVideo(id: next.id, promptForResume: false)
    }

    /// Tear down the finished item's player, observers, and timers before the
    /// next item loads into the same view, so nothing leaks across the swap.
    private func teardownForNextItem() {
        wsTask?.cancel()
        wsTask = nil
        hqPollTask?.cancel()
        hqPollTask = nil
        itemFailureTask?.cancel()
        itemFailureTask = nil
        if let endObserver {
            NotificationCenter.default.removeObserver(endObserver)
            self.endObserver = nil
        }
        progressTimer?.invalidate()
        progressTimer = nil
        removeAdSkipObserver()
        skipToastTask?.cancel()
        adSegmentsTask?.cancel()
        player?.pause()
        player = nil
    }

    // MARK: - Progress

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
        guard !didReachEnd else { return }
        guard let player, player.currentItem != nil else { return }
        let position = Int(player.currentTime().seconds)
        guard position > 0 else { return }
        Task {
            try? await api.updateProgress(videoId: videoId, positionSeconds: position)
        }
    }

    func cleanup() {
        // Cancel any in-flight auto-advance first so a manual exit can't start
        // the next item after the view has gone.
        advanceTask?.cancel()
        advanceTask = nil
        saveProgress()
        progressTimer?.invalidate()
        progressTimer = nil
        wsTask?.cancel()
        wsTask = nil
        hqPollTask?.cancel()
        hqPollTask = nil
        itemFailureTask?.cancel()
        itemFailureTask = nil
        if let endObserver {
            NotificationCenter.default.removeObserver(endObserver)
            self.endObserver = nil
        }
        removeAdSkipObserver()
        skipToastTask?.cancel()
        adSegmentsTask?.cancel()
        player?.pause()
        player = nil
    }

}
