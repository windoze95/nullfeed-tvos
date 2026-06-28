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
        XCTAssertTrue(video.isDownloadable) // cataloged status = downloadable
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
}
