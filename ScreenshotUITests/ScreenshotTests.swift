// Throwaway store-screenshot driver: launches the real app against the local
// demo server, walks it with XCUIRemote, and asks a host-side helper
// (capture_server.py on :8766) to grab the simulator framebuffer.
import XCTest

@MainActor
final class ScreenshotTests: XCTestCase {

    private var remote: XCUIRemote { XCUIRemote.shared }

    /// Blocking GET keeps this free of Sendable/actor friction; the helper
    /// captures the framebuffer before responding.
    private func capture(_ name: String) {
        Thread.sleep(forTimeInterval: 1.0)
        _ = try? Data(contentsOf: URL(string: "http://localhost:8766/capture/\(name)")!)
    }

    private func press(_ button: XCUIRemote.Button, times: Int = 1, delay: TimeInterval = 0.6) {
        for _ in 0..<times {
            remote.press(button)
            Thread.sleep(forTimeInterval: delay)
        }
    }

    /// Walk focus onto the tab bar, then move right until `name` has focus.
    private func focusTab(_ app: XCUIApplication, _ name: String) {
        press(.menu)
        Thread.sleep(forTimeInterval: 0.8)
        // Move to the leftmost tab first, then scan right.
        press(.left, times: 7, delay: 0.35)
        for _ in 0..<10 {
            if app.buttons[name].hasFocus || app.otherElements[name].hasFocus { break }
            press(.right, delay: 0.5)
        }
        Thread.sleep(forTimeInterval: 1.0)
    }

    func testScreenshots() throws {
        continueAfterFailure = false

        let app = XCUIApplication()
        app.launchArguments += ["-server_url", "http://localhost:8484"]
        app.launch()

        // 1. Profile picker
        XCTAssertTrue(app.staticTexts["Demo User"].waitForExistence(timeout: 20),
                      "profile picker should list Demo User")
        Thread.sleep(forTimeInterval: 3)
        capture("profile_picker")

        // 2. Home: select the focused (first) profile card.
        press(.select)
        Thread.sleep(forTimeInterval: 10)  // feed + artwork
        capture("home")

        // 3. Channels (library)
        focusTab(app, "Channels")
        Thread.sleep(forTimeInterval: 4)
        capture("library")

        // 4. Explore (discover)
        focusTab(app, "Explore")
        Thread.sleep(forTimeInterval: 6)
        capture("discover")

        // 5. Channel detail: back to Channels, into the grid, open first channel.
        focusTab(app, "Channels")
        Thread.sleep(forTimeInterval: 2)
        press(.down)             // move focus into the channel grid
        Thread.sleep(forTimeInterval: 1)
        press(.select)           // open focused channel
        Thread.sleep(forTimeInterval: 6)
        capture("channel_detail")

        // 6. Player: focus first video in the channel and play it.
        press(.down)
        Thread.sleep(forTimeInterval: 1)
        press(.select)
        Thread.sleep(forTimeInterval: 12)  // buffer + controls auto-hide
        capture("player_clean")
        press(.down)             // reveal transport/info controls
        Thread.sleep(forTimeInterval: 1.2)
        capture("player")
    }
}
