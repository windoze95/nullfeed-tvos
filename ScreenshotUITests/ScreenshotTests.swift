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

    /// Menu jumps focus to the tab bar; walk to the leftmost tab, then right
    /// to the wanted index. Blind by design — element focus queries throw when
    /// the element is missing, and tab order is stable (see MainTabView).
    private func focusTab(index: Int) {
        press(.menu)
        Thread.sleep(forTimeInterval: 0.8)
        press(.left, times: 6, delay: 0.35)
        if index > 0 {
            press(.right, times: index, delay: 0.5)
        }
        Thread.sleep(forTimeInterval: 1.2)
    }

    /// The first sign-in triggers the notifications permission alert. Focus
    /// starts on "Don't Allow"; move right to "Allow" and select. `exists`
    /// (unlike `hasFocus`) is safe on missing elements.
    private func dismissNotificationAlert(_ app: XCUIApplication) {
        let shell = XCUIApplication(bundleIdentifier: "com.apple.PineBoard")
        for host in [app, shell] where host.buttons["Allow"].exists {
            press(.right, delay: 0.5)
            press(.select)
            Thread.sleep(forTimeInterval: 1.5)
            return
        }
    }

    func testScreenshots() throws {
        continueAfterFailure = false

        let app = XCUIApplication()
        app.launchArguments += ["-server_url", "http://localhost:8484"]
        app.launch()
        Thread.sleep(forTimeInterval: 5)
        capture("launch_state")

        // 0. Server setup: the app never auto-connects, so with the saved URL
        // prefilled the first screen is ServerSetupView. Press Connect.
        if app.buttons["Connect"].waitForExistence(timeout: 10) {
            capture("server_setup")
            for _ in 0..<4 where !app.buttons["Connect"].hasFocus {
                press(.down, delay: 0.5)
            }
            press(.select)
        }

        // 1. Profile picker
        let demoUser = app.staticTexts["Demo User"]
        if !demoUser.waitForExistence(timeout: 30) {
            capture("failure_state")
            print("UI TREE DUMP:\n\(app.debugDescription)")
            XCTFail("profile picker should list Demo User")
        }
        Thread.sleep(forTimeInterval: 3)
        capture("profile_picker")

        // 2. Home: select the focused (first) profile card.
        press(.select)
        Thread.sleep(forTimeInterval: 6)
        dismissNotificationAlert(app)
        Thread.sleep(forTimeInterval: 6)  // feed + artwork
        dismissNotificationAlert(app)     // in case it appeared late
        capture("home")
        press(.down, times: 2, delay: 0.8) // scroll to richer rows
        Thread.sleep(forTimeInterval: 1.5)
        capture("home_feed")

        // 3. Channels (library)
        focusTab(index: 2)
        Thread.sleep(forTimeInterval: 4)
        capture("library")

        // 4. Explore (discover)
        focusTab(index: 3)
        Thread.sleep(forTimeInterval: 6)
        capture("discover")

        // 5. Channel detail: back to Channels, into the grid, open first channel.
        focusTab(index: 2)
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
