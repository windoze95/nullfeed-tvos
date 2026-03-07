# NullFeed tvOS

Native SwiftUI Apple TV client for the NullFeed self-hosted YouTube media center.

## Requirements

- Xcode 16+
- tvOS 17+
- Swift 6
- [XcodeGen](https://github.com/yonaskolb/XcodeGen) (`brew install xcodegen`)

## Architecture

MVVM with `@Observable`, zero third-party dependencies.

## Build

1. Generate the Xcode project: `xcodegen generate`
2. Open `NullFeed.xcodeproj`
3. Select the **NullFeed** scheme
4. Build and run on an Apple TV simulator or device

## CI

GitHub Actions handles continuous integration:

- **CI** -- Builds and runs tests on PRs to `main`
- **TestFlight** -- Archives and uploads to TestFlight on pushes to `main`

## Related Repositories

| Repository | Description |
|------------|-------------|
| [nullfeed-backend](https://github.com/windoze95/nullfeed-backend) | Python/FastAPI backend -- Docker-based server with yt-dlp, Celery, Redis, and SQLite |
| [nullfeed-flutter](https://github.com/windoze95/nullfeed-flutter) | Flutter client for iOS |
| **nullfeed-tvos** (this repo) | **Native Swift/SwiftUI tvOS app** |
| [nullfeed-demo](https://github.com/windoze95/nullfeed-demo) | FastAPI demo server with Creative Commons content for App Store review |

## License

This project is licensed under the [GNU General Public License v3.0](LICENSE).
