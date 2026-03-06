import SwiftUI

struct ProgressBarView: View {
    let progress: Double
    var height: CGFloat = 6

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: height / 2)
                    .fill(NullFeedTheme.progressBackground)

                RoundedRectangle(cornerRadius: height / 2)
                    .fill(NullFeedTheme.progressForeground)
                    .frame(width: geometry.size.width * min(max(progress, 0), 1))
            }
        }
        .frame(height: height)
    }
}
