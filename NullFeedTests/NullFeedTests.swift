import XCTest
@testable import NullFeed

final class NullFeedTests: XCTestCase {
    func testVideoStatusDecoding() throws {
        let json = """
        {
            "id": "test-id",
            "youtube_video_id": "abc123",
            "channel_id": "ch-1",
            "title": "Test Video",
            "duration_seconds": 3600,
            "status": "COMPLETE",
            "watch_position_seconds": 120,
            "is_watched": false,
            "channel_name": "Test Channel"
        }
        """.data(using: .utf8)!

        let video = try JSONDecoder.nullFeed.decode(Video.self, from: json)
        XCTAssertEqual(video.id, "test-id")
        XCTAssertEqual(video.status, .complete)
        XCTAssertTrue(video.isPlayable)
        XCTAssertFalse(video.hasPreviewReady)
        XCTAssertEqual(video.formattedDuration, "1:00:00")
        XCTAssertEqual(video.watchProgress, 120.0 / 3600.0, accuracy: 0.001)
    }

    func testUserDecoding() throws {
        let json = """
        {
            "id": "user-1",
            "display_name": "Test User",
            "is_admin": true,
            "created_at": "2024-01-01T00:00:00Z"
        }
        """.data(using: .utf8)!

        let user = try JSONDecoder.nullFeed.decode(User.self, from: json)
        XCTAssertEqual(user.id, "user-1")
        XCTAssertEqual(user.displayName, "Test User")
        XCTAssertTrue(user.isAdmin)
        XCTAssertFalse(user.hasPin) // absent has_pin defaults to false
    }

    func testUserHasPinDecoding() throws {
        let json = """
        {
            "id": "user-2",
            "display_name": "PIN User",
            "is_admin": false,
            "has_pin": true,
            "created_at": "2024-01-01T00:00:00Z"
        }
        """.data(using: .utf8)!

        let user = try JSONDecoder.nullFeed.decode(User.self, from: json)
        XCTAssertTrue(user.hasPin)
    }

    func testChannelDecoding() throws {
        let json = """
        {
            "id": "ch-1",
            "youtube_channel_id": "UC123",
            "name": "Test Channel",
            "slug": "test-channel"
        }
        """.data(using: .utf8)!

        let channel = try JSONDecoder.nullFeed.decode(Channel.self, from: json)
        XCTAssertEqual(channel.id, "ch-1")
        XCTAssertEqual(channel.name, "Test Channel")
    }

    func testDurationFormatting() {
        XCTAssertEqual(90.formattedDuration, "1:30")
        XCTAssertEqual(3661.formattedDuration, "1:01:01")
        XCTAssertEqual(0.formattedDuration, "0:00")
        XCTAssertEqual(60.formattedDuration, "1:00")
    }

    func testVideoComputedProperties() throws {
        let json = """
        {
            "id": "v-1",
            "youtube_video_id": "yt-1",
            "channel_id": "ch-1",
            "title": "Preview Video",
            "status": "CATALOGED",
            "preview_status": "READY",
            "channel_name": ""
        }
        """.data(using: .utf8)!

        let video = try JSONDecoder.nullFeed.decode(Video.self, from: json)
        XCTAssertTrue(video.isPlayable)
        XCTAssertTrue(video.hasPreviewReady)
        XCTAssertTrue(video.isPreviewOnly)
    }

    func testVideoThumbnailDecoding() throws {
        // Backend serves thumbnail_url as a relative path on each VideoOut.
        let json = """
        {
            "id": "v-thumb",
            "youtube_video_id": "yt-thumb",
            "channel_id": "ch-1",
            "title": "Thumb Video",
            "status": "COMPLETE",
            "thumbnail_url": "/data/thumbnails/yt-thumb.jpg",
            "channel_name": "Chan"
        }
        """.data(using: .utf8)!

        let video = try JSONDecoder.nullFeed.decode(Video.self, from: json)
        XCTAssertEqual(video.thumbnailUrl, "/data/thumbnails/yt-thumb.jpg")
    }

    func testVideoMissingThumbnailDecodesToNil() throws {
        let json = """
        {
            "id": "v-no-thumb",
            "youtube_video_id": "yt-x",
            "channel_id": "ch-1",
            "title": "No Thumb",
            "status": "COMPLETE",
            "channel_name": "Chan"
        }
        """.data(using: .utf8)!

        let video = try JSONDecoder.nullFeed.decode(Video.self, from: json)
        XCTAssertNil(video.thumbnailUrl)
    }

    func testVideoDescriptionDecoding() throws {
        // The Now Playing / Info panel surfaces a description when the backend
        // provides one; it must decode off the top-level `description` key.
        let json = """
        {
            "id": "v-desc",
            "youtube_video_id": "yt-desc",
            "channel_id": "ch-1",
            "title": "Described Video",
            "status": "COMPLETE",
            "description": "A detailed summary of the video.",
            "channel_name": "Chan"
        }
        """.data(using: .utf8)!

        let video = try JSONDecoder.nullFeed.decode(Video.self, from: json)
        XCTAssertEqual(video.description, "A detailed summary of the video.")
    }

    func testVideoMissingDescriptionDecodesToNil() throws {
        // Absent description must default to nil, not throw, so the metadata
        // builder simply omits it.
        let json = """
        {
            "id": "v-no-desc",
            "youtube_video_id": "yt-y",
            "channel_id": "ch-1",
            "title": "No Desc",
            "status": "COMPLETE",
            "channel_name": "Chan"
        }
        """.data(using: .utf8)!

        let video = try JSONDecoder.nullFeed.decode(Video.self, from: json)
        XCTAssertNil(video.description)
    }

    // MARK: - Unplayable reason

    func testVideoUnplayableReasonDecoding() throws {
        let json = """
        {
            "id": "v-blocked",
            "youtube_video_id": "yt-b",
            "channel_id": "ch-1",
            "title": "Members Episode",
            "status": "CATALOGED",
            "unplayable_reason": "members_only",
            "channel_name": "Chan"
        }
        """.data(using: .utf8)!

        let video = try JSONDecoder.nullFeed.decode(Video.self, from: json)
        XCTAssertEqual(video.unplayableReason, "members_only")
        XCTAssertEqual(video.activeUnplayableReason, .membersOnly)
        XCTAssertEqual(video.activeUnplayableReason?.label, "Members only")
    }

    func testVideoUnplayableReasonAbsentDecodesToNil() throws {
        let json = """
        {
            "id": "v-ok",
            "youtube_video_id": "yt-ok",
            "channel_id": "ch-1",
            "title": "Normal",
            "status": "CATALOGED",
            "channel_name": "Chan"
        }
        """.data(using: .utf8)!

        let video = try JSONDecoder.nullFeed.decode(Video.self, from: json)
        XCTAssertNil(video.unplayableReason)
        XCTAssertNil(video.activeUnplayableReason)
    }

    func testVideoUnplayableReasonSuppressedWhenPlayable() throws {
        // A stale label on a video the server holds a playable file for is
        // ignored — the file plays regardless of what YouTube refuses.
        let json = """
        {
            "id": "v-stale",
            "youtube_video_id": "yt-s",
            "channel_id": "ch-1",
            "title": "Downloaded anyway",
            "status": "COMPLETE",
            "unplayable_reason": "age_restricted",
            "channel_name": "Chan"
        }
        """.data(using: .utf8)!

        let video = try JSONDecoder.nullFeed.decode(Video.self, from: json)
        XCTAssertEqual(video.unplayableReason, "age_restricted")
        XCTAssertNil(video.activeUnplayableReason)
    }

    func testUnknownUnplayableReasonStillBanners() {
        // Forward-compat: vocabulary this client doesn't know yet must still
        // produce a (generic) banner rather than crashing or vanishing.
        let reason = UnplayableReason(wireValue: "some_future_reason")
        XCTAssertEqual(reason, .unknown)
        XCTAssertEqual(reason.label, "Unavailable")
    }

    // MARK: - Recommendation

    func testRecommendationDecoding() throws {
        // Mirrors the backend RecommendationOut shape (key is `reason`, not
        // `reasoning`). Regression guard for the Discover decode crash.
        let json = """
        {
            "id": "rec-1",
            "channel_name": "Cool Channel",
            "youtube_channel_id": "UCabc123",
            "reason": "Because you watch similar creators.",
            "dismissed": false
        }
        """.data(using: .utf8)!

        let rec = try JSONDecoder.nullFeed.decode(Recommendation.self, from: json)
        XCTAssertEqual(rec.id, "rec-1")
        XCTAssertEqual(rec.channelName, "Cool Channel")
        XCTAssertEqual(rec.youtubeChannelId, "UCabc123")
        XCTAssertEqual(rec.reason, "Because you watch similar creators.")
        XCTAssertFalse(rec.dismissed)
    }

    func testRecommendationListDecoding() throws {
        // Discover decodes an array of recommendations; a null/absent reason
        // must not throw.
        let json = """
        [
            {
                "id": "rec-1",
                "channel_name": "A",
                "youtube_channel_id": "UC1",
                "reason": null,
                "dismissed": false
            },
            {
                "id": "rec-2",
                "channel_name": "B",
                "dismissed": false
            }
        ]
        """.data(using: .utf8)!

        let recs = try JSONDecoder.nullFeed.decode([Recommendation].self, from: json)
        XCTAssertEqual(recs.count, 2)
        XCTAssertNil(recs[0].reason)
        XCTAssertNil(recs[1].youtubeChannelId)
    }

    // MARK: - Home feed

    func testHomeFeedDecoding() throws {
        // Unified /feed/home payload: snake_case rows map to the camelCase
        // properties and each item is the per-feed {channel, video} shape.
        let json = """
        {
            "continue_watching": [
                {
                    "channel": {
                        "id": "ch-1",
                        "youtube_channel_id": "UC123",
                        "name": "Test Channel",
                        "slug": "test-channel"
                    },
                    "video": {
                        "id": "v-1",
                        "youtube_video_id": "yt-1",
                        "channel_id": "ch-1",
                        "title": "Ep 1"
                    }
                }
            ],
            "new_episodes": [],
            "recently_added": []
        }
        """.data(using: .utf8)!

        let feed = try JSONDecoder.nullFeed.decode(HomeFeed.self, from: json)
        XCTAssertEqual(feed.continueWatching.count, 1)
        XCTAssertEqual(feed.continueWatching.first?.id, "v-1")
        XCTAssertEqual(feed.continueWatching.first?.channel.name, "Test Channel")
        XCTAssertTrue(feed.newEpisodes.isEmpty)
        XCTAssertTrue(feed.recentlyAdded.isEmpty)
    }

    func testHomeFeedMissingRowsDefaultToEmpty() throws {
        // Rows the server omits must decode to empty arrays, not throw.
        let json = "{}".data(using: .utf8)!
        let feed = try JSONDecoder.nullFeed.decode(HomeFeed.self, from: json)
        XCTAssertTrue(feed.continueWatching.isEmpty)
        XCTAssertTrue(feed.newEpisodes.isEmpty)
        XCTAssertTrue(feed.recentlyAdded.isEmpty)
    }

    // MARK: - Search

    func testVideoSearchPageDecoding() throws {
        // GET /api/videos?q=... returns {items, total, next_cursor}; next_cursor
        // must map to nextCursor via the snake_case decoder.
        let json = """
        {
            "items": [
                {
                    "id": "v-1",
                    "youtube_video_id": "yt-1",
                    "channel_id": "ch-1",
                    "title": "Found Video",
                    "status": "COMPLETE",
                    "channel_name": "Found Channel"
                }
            ],
            "total": 42,
            "next_cursor": "eyJvZmZzZXQiOiAyMH0="
        }
        """.data(using: .utf8)!

        let page = try JSONDecoder.nullFeed.decode(VideoSearchPage.self, from: json)
        XCTAssertEqual(page.items.count, 1)
        XCTAssertEqual(page.items.first?.id, "v-1")
        XCTAssertEqual(page.items.first?.channelName, "Found Channel")
        XCTAssertEqual(page.total, 42)
        XCTAssertEqual(page.nextCursor, "eyJvZmZzZXQiOiAyMH0=")
    }

    func testVideoSearchPageLastPageHasNilCursor() throws {
        // The final page omits next_cursor; it must decode to nil (no more pages)
        // and absent items/total default to empty rather than throwing.
        let json = """
        {
            "items": [],
            "total": 0
        }
        """.data(using: .utf8)!

        let page = try JSONDecoder.nullFeed.decode(VideoSearchPage.self, from: json)
        XCTAssertTrue(page.items.isEmpty)
        XCTAssertEqual(page.total, 0)
        XCTAssertNil(page.nextCursor)
    }

    // MARK: - YouTube import

    func testYoutubeProfileDecoding() throws {
        // POST /api/youtube/resolve returns the resolved identity; snake_case
        // keys (channel_id, avatar_url, follower_count) map to camelCase.
        let json = """
        {
            "handle": "@example",
            "channel_id": "UCexample",
            "name": "Example Channel",
            "description": "A channel",
            "avatar_url": "https://example.com/a.jpg",
            "banner_url": null,
            "follower_count": 12345
        }
        """.data(using: .utf8)!

        let profile = try JSONDecoder.nullFeed.decode(YoutubeProfile.self, from: json)
        XCTAssertEqual(profile.handle, "@example")
        XCTAssertEqual(profile.channelId, "UCexample")
        XCTAssertEqual(profile.name, "Example Channel")
        XCTAssertEqual(profile.avatarUrl, "https://example.com/a.jpg")
        XCTAssertNil(profile.bannerUrl)
        XCTAssertEqual(profile.followerCount, 12345)
    }

    func testChannelSuggestionDecoding() throws {
        // POST /api/youtube/suggestions returns {suggestions: [...]}; each item's
        // youtube_channel_id is the identity used for selection and bulk subscribe.
        let json = """
        {
            "youtube_channel_id": "UCabc",
            "name": "Suggested Channel",
            "handle": "@suggested",
            "avatar_url": null,
            "source": "featured",
            "score": 7
        }
        """.data(using: .utf8)!

        let suggestion = try JSONDecoder.nullFeed.decode(ChannelSuggestion.self, from: json)
        XCTAssertEqual(suggestion.youtubeChannelId, "UCabc")
        XCTAssertEqual(suggestion.id, "UCabc") // Identifiable maps to the YT id
        XCTAssertEqual(suggestion.name, "Suggested Channel")
        XCTAssertEqual(suggestion.source, "featured")
        XCTAssertEqual(suggestion.score, 7)
    }

    func testBulkSubscribeResultDecoding() throws {
        // POST /api/channels/subscribe-bulk returns {results: [...]}; per-item
        // status is "subscribed" | "already_subscribed" | "error".
        let json = """
        {
            "youtube_channel_id": "UCabc",
            "status": "subscribed",
            "channel_id": "ch-1",
            "detail": null
        }
        """.data(using: .utf8)!

        let result = try JSONDecoder.nullFeed.decode(BulkSubscribeResult.self, from: json)
        XCTAssertEqual(result.youtubeChannelId, "UCabc")
        XCTAssertEqual(result.status, "subscribed")
        XCTAssertEqual(result.channelId, "ch-1")
        XCTAssertNil(result.detail)
    }

    // MARK: - WebSocket events

    func testWebSocketDownloadProgressParsing() {
        // Progress is delivered under the `percentage` key (0-100).
        let json: [String: Any] = [
            "type": "download_progress",
            "data": ["video_id": "v-9", "percentage": 42.5],
        ]
        let event = WebSocketEvent.from(json: json)
        XCTAssertEqual(event.type, .downloadProgress)
        XCTAssertEqual(event.videoId, "v-9")
        XCTAssertEqual(event.percentage ?? -1, 42.5, accuracy: 0.001)
    }

    func testWebSocketDownloadCompleteParsing() {
        let json: [String: Any] = [
            "type": "download_complete",
            "data": ["video_id": "v-10"],
        ]
        let event = WebSocketEvent.from(json: json)
        XCTAssertEqual(event.type, .downloadComplete)
        XCTAssertEqual(event.videoId, "v-10")
        XCTAssertNil(event.percentage)
    }

    func testWebSocketPreviewReadyParsing() {
        let json: [String: Any] = [
            "type": "preview_ready",
            "data": ["video_id": "v-11"],
        ]
        let event = WebSocketEvent.from(json: json)
        XCTAssertEqual(event.type, .previewReady)
        XCTAssertEqual(event.videoId, "v-11")
    }

    func testWebSocketProgressUpdatedParsing() {
        // progress_updated carries the video plus its new position/watched flag;
        // HomeView only needs the type + video to trigger a feed reload.
        let json: [String: Any] = [
            "type": "progress_updated",
            "data": ["video_id": "v-12", "position_seconds": 90, "is_watched": false],
        ]
        let event = WebSocketEvent.from(json: json)
        XCTAssertEqual(event.type, .progressUpdated)
        XCTAssertEqual(event.videoId, "v-12")
    }

    func testWebSocketUnknownTypeParsing() {
        let event = WebSocketEvent.from(json: ["type": "totally_unknown", "data": [:]])
        XCTAssertEqual(event.type, .unknown)
    }

    // MARK: - Queue

    @MainActor
    func testQueueMembershipAndNextItem() throws {
        // The pure in-memory logic behind the action-menu labels and the player's
        // auto-advance: membership and "what plays after this one".
        let queue = QueueViewModel(api: APIClient(storage: StorageService()))
        queue.items = try ["q-1", "q-2", "q-3"].map(makeVideo)

        XCTAssertTrue(queue.isQueued("q-2"))
        XCTAssertFalse(queue.isQueued("missing"))

        XCTAssertEqual(queue.videoAfter("q-1")?.id, "q-2")
        XCTAssertEqual(queue.videoAfter("q-2")?.id, "q-3")
        XCTAssertNil(queue.videoAfter("q-3"), "the last item has no successor")
        XCTAssertNil(queue.videoAfter("missing"), "an unqueued video has no successor")
    }

    // MARK: - Resume prompt

    @MainActor
    func testResumePointDetection() throws {
        // A partly-watched video offers a resume choice.
        let partly = try makeVideo(id: "p", positionSeconds: 90, isWatched: false)
        XCTAssertTrue(PlayerViewModel.hasResumePoint(for: partly))

        // A finished video (position cleared, watched set) starts over.
        let finished = try makeVideo(id: "f", positionSeconds: 0, isWatched: true)
        XCTAssertFalse(PlayerViewModel.hasResumePoint(for: finished))

        // A never-started video has nothing to resume.
        let fresh = try makeVideo(id: "n", positionSeconds: 0, isWatched: false)
        XCTAssertFalse(PlayerViewModel.hasResumePoint(for: fresh))

        // Defensive: a saved position with the watched flag set still starts over.
        let watchedWithPos = try makeVideo(id: "w", positionSeconds: 120, isWatched: true)
        XCTAssertFalse(PlayerViewModel.hasResumePoint(for: watchedWithPos))
    }

    @MainActor
    func testResumeStartRewinds() {
        // Resume rewinds a few seconds for re-orientation, clamped at zero.
        XCTAssertEqual(PlayerViewModel.resumeStart(forPosition: 90), 90 - AppConstants.resumeRewindSeconds)
        XCTAssertEqual(PlayerViewModel.resumeStart(forPosition: 5), 0)
        XCTAssertEqual(PlayerViewModel.resumeStart(forPosition: 0), 0)
    }

    // MARK: - Sponsor skip

    @MainActor
    func testSponsorSkipSeeksToSegmentEndOnFirstEntry() {
        let segs = [AdSegment(start: 0, end: 30)]
        let d = PlayerViewModel.sponsorSkipDecision(position: 0, segments: segs, inFlightEnd: nil)
        XCTAssertEqual(d.seekTo, 30.0)
        XCTAssertEqual(d.inFlightEnd, 30.0)
    }

    @MainActor
    func testSponsorSkipDoesNotReissueWhileInFlight() {
        // Playhead still stuck inside the segment (seek buffering) — no re-seek.
        let segs = [AdSegment(start: 0, end: 30)]
        let d = PlayerViewModel.sponsorSkipDecision(position: 0.2, segments: segs, inFlightEnd: 30)
        XCTAssertNil(d.seekTo)
        XCTAssertEqual(d.inFlightEnd, 30.0)
    }

    @MainActor
    func testSponsorSkipYieldsExactlyOneSeekOverManyTicks() {
        // Regression guard: a start sponsor whose seek can't land yet must not
        // fire a seek on every 0.5s observer tick.
        let segs = [AdSegment(start: 0, end: 30)]
        var inFlight: Double?
        var seeks = 0
        for _ in 0..<100 {
            let d = PlayerViewModel.sponsorSkipDecision(position: 0.1, segments: segs, inFlightEnd: inFlight)
            inFlight = d.inFlightEnd
            if d.seekTo != nil { seeks += 1 }
        }
        XCTAssertEqual(seeks, 1)
    }

    @MainActor
    func testSponsorSkipClearsGuardOncePastSegment() {
        let segs = [AdSegment(start: 0, end: 30)]
        let d = PlayerViewModel.sponsorSkipDecision(position: 30, segments: segs, inFlightEnd: 30)
        XCTAssertNil(d.seekTo)
        XCTAssertNil(d.inFlightEnd)
    }

    @MainActor
    func testSponsorSkipSkipsLaterSegmentAfterPassingEarlier() {
        let segs = [AdSegment(start: 0, end: 30), AdSegment(start: 60, end: 75)]
        let past = PlayerViewModel.sponsorSkipDecision(position: 30, segments: segs, inFlightEnd: 30)
        XCTAssertNil(past.seekTo)
        XCTAssertNil(past.inFlightEnd)
        let second = PlayerViewModel.sponsorSkipDecision(position: 60, segments: segs, inFlightEnd: past.inFlightEnd)
        XCTAssertEqual(second.seekTo, 75.0)
        XCTAssertEqual(second.inFlightEnd, 75.0)
    }

    @MainActor
    func testSponsorSkipChainsIntoAdjacentSegment() {
        let segs = [AdSegment(start: 0, end: 30), AdSegment(start: 30, end: 45)]
        // First skip lands at 30.0, the start of the next segment; skip straight in.
        let d = PlayerViewModel.sponsorSkipDecision(position: 30, segments: segs, inFlightEnd: 30)
        XCTAssertEqual(d.seekTo, 45.0)
        XCTAssertEqual(d.inFlightEnd, 45.0)
    }

    @MainActor
    func testSponsorSkipNoSeekOutsideSegments() {
        let segs = [AdSegment(start: 0, end: 30)]
        let d = PlayerViewModel.sponsorSkipDecision(position: 45, segments: segs, inFlightEnd: nil)
        XCTAssertNil(d.seekTo)
        XCTAssertNil(d.inFlightEnd)
    }

    @MainActor
    func testSponsorSkipRespectsTailMargin() {
        // Inside the last 0.5s of the segment — let it play out, no seek.
        let segs = [AdSegment(start: 0, end: 30)]
        let d = PlayerViewModel.sponsorSkipDecision(position: 29.6, segments: segs, inFlightEnd: nil)
        XCTAssertNil(d.seekTo)
    }

    @MainActor
    func testSponsorSkipNoSegmentsNoDecision() {
        let d = PlayerViewModel.sponsorSkipDecision(position: 10, segments: [], inFlightEnd: nil)
        XCTAssertNil(d.seekTo)
        XCTAssertNil(d.inFlightEnd)
    }

    private func makeVideo(id: String) throws -> Video {
        let json = """
        {
            "id": "\(id)",
            "youtube_video_id": "yt-\(id)",
            "channel_id": "ch-1",
            "title": "Video \(id)",
            "status": "COMPLETE",
            "channel_name": "Chan"
        }
        """.data(using: .utf8)!
        return try JSONDecoder.nullFeed.decode(Video.self, from: json)
    }

    private func makeVideo(id: String, positionSeconds: Int, isWatched: Bool) throws -> Video {
        let json = """
        {
            "id": "\(id)",
            "youtube_video_id": "yt-\(id)",
            "channel_id": "ch-1",
            "title": "Video \(id)",
            "status": "COMPLETE",
            "watch_position_seconds": \(positionSeconds),
            "is_watched": \(isWatched),
            "channel_name": "Chan"
        }
        """.data(using: .utf8)!
        return try JSONDecoder.nullFeed.decode(Video.self, from: json)
    }
}
