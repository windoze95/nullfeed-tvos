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
}
