import SwiftUI

/// The watch-later queue ("Up Next"), exposed as a first-class tab. Lists the
/// queued videos as the shared cards with the standard focus treatment;
/// selecting one plays it and each card's context menu can remove it. It reads the app-level
/// `QueueViewModel`, so removals here and the player's auto-advance stay in sync.
struct QueueView: View {
    @Environment(QueueViewModel.self) private var queue
    @Environment(AppState.self) private var appState
    @Namespace private var queueFocus

    var body: some View {
        ZStack {
            NullFeedBackdrop()

            StateView(state: .resolve(
                isLoading: queue.isLoading,
                isEmpty: queue.isEmpty,
                error: queue.error,
                empty: (
                    icon: "rectangle.stack.badge.play",
                    title: "Up Next Is Empty",
                    subtitle: "Long-press any video and add it here to line up what you want to watch."
                ),
                retry: { Task { await queue.load() } }
            )) {
                grid
            }
        }
        .navigationTitle("Up Next")
        // Reload on appear so the list reflects items watched (and auto-removed)
        // or queued elsewhere since the last visit.
        .task { await queue.load() }
    }

    @ViewBuilder
    private var grid: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 34) {
                ScreenHeaderView(
                    symbol: "rectangle.stack.badge.play.fill",
                    title: "Up Next",
                    subtitle: "\(queue.total) \(queue.total == 1 ? "video" : "videos") ready to play"
                )

                LazyVGrid(columns: NullFeedLayout.videoGridColumns, spacing: NullFeedLayout.gridSpacing) {
                    ForEach(Array(queue.items.enumerated()), id: \.element.id) { index, video in
                        VideoCardView(video: video) { appState.openVideo(video.id) }
                            .prefersDefaultFocus(index == 0, in: queueFocus)
                            .onAppear {
                                // Reaching the last card pulls the next page.
                                if video.id == queue.items.last?.id {
                                    Task { await queue.loadMore() }
                                }
                            }
                    }
                }
            }
            .padding(.horizontal, NullFeedTheme.contentPadding)
            .padding(.top, 38)
            .padding(.bottom, NullFeedTheme.contentPadding)
            .focusScope(queueFocus)

            if queue.isLoadingMore {
                ProgressView()
                    .tint(NullFeedTheme.primary)
                    .frame(maxWidth: .infinity)
                    .padding(.top, 8)
            }
        }
        .scrollClipDisabled()
    }
}
