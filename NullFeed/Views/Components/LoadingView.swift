import SwiftUI

struct LoadingView: View {
    var body: some View {
        ProgressView()
            .tint(NullFeedTheme.primary)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(NullFeedTheme.background)
    }
}
