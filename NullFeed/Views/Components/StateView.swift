import SwiftUI

/// The mutually-exclusive states a data-backed screen can be in. Lets every
/// screen present loading / empty / error / content the same way (issue #5).
enum LoadState {
    case loading
    case empty(icon: String, title: String, subtitle: String?)
    case error(message: String, retry: () -> Void)
    case content
}

extension LoadState {
    /// Derives the right state from a view model's raw signals. An error only
    /// wins when there is nothing already on screen, so a refresh that fails
    /// doesn't wipe out content the user is looking at.
    static func resolve(
        isLoading: Bool,
        isEmpty: Bool,
        error: String?,
        empty: (icon: String, title: String, subtitle: String?),
        retry: @escaping () -> Void
    ) -> LoadState {
        if let error, isEmpty { return .error(message: error, retry: retry) }
        if isLoading && isEmpty { return .loading }
        if isEmpty { return .empty(icon: empty.icon, title: empty.title, subtitle: empty.subtitle) }
        return .content
    }
}

/// Renders the shared loading / empty / error / content presentation, showing
/// `content` only once there is something to display.
struct StateView<Content: View>: View {
    let state: LoadState
    let emptyActionTitle: String?
    let emptyAction: (() -> Void)?
    @ViewBuilder let content: () -> Content

    init(
        state: LoadState,
        emptyActionTitle: String? = nil,
        emptyAction: (() -> Void)? = nil,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.state = state
        self.emptyActionTitle = emptyActionTitle
        self.emptyAction = emptyAction
        self.content = content
    }

    var body: some View {
        switch state {
        case .loading:
            LoadingView()
        case let .empty(icon, title, subtitle):
            EmptyStateView(
                iconName: icon,
                title: title,
                subtitle: subtitle,
                actionTitle: emptyActionTitle,
                action: emptyAction
            )
        case let .error(message, retry):
            ErrorStateView(message: message, retry: retry)
        case .content:
            content()
        }
    }
}
