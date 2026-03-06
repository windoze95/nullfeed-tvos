# NullFeed tvOS

Native SwiftUI Apple TV client for the NullFeed self-hosted YouTube media center.

## Requirements

- Xcode 16+
- tvOS 17+
- Swift 6

## Architecture

MVVM with `@Observable`, zero third-party dependencies.

## Build

1. Open `NullFeed.xcodeproj`
2. Select the **NullFeed** scheme
3. Build and run on an Apple TV simulator or device

## CI

GitHub Actions handles continuous integration:

- **CI** -- Builds and runs tests on every push and PR to `main`
- **TestFlight** -- Archives and uploads to TestFlight on pushes to `main`
