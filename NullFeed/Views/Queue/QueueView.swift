import SwiftUI

/// The watch-later queue ("Up Next"), reached from Home. Lists the queued videos
/// as the shared cards with the standard focus treatment; selecting one plays it
/// and each card's context menu can remove it. It reads the app-level
/// `QueueViewModel`, so removals here and the player's auto-advance stay in sync.
struct QueueView: View {
    /// Play a selected video. The host (Home) owns the navigation stack and its
    /// `Video` -> player destination, so this view stays presentation-only.
    let onPlay: (Video) -> Void

    @Environment(QueueViewModel.self) private var queue
    @Namespace private var queueFocus

    var body: some View {
        ZStack {
            NullFeedTheme.background.ignoresSafeArea()

            StateView(state: .resolve(
                isLoading: queue.isLoading,
                isEmpty: queue.isEmpty,
                error: queue.error,
                empty: (
                    icon: "rectangle.stack.badge.play",
                    title: "Your Queue Is Empty",
                    subtitle: "Add videos to your queue and they'll line up here to watch next."
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
            LazyVGrid(
                columns: Array(repeating: GridItem(.fixed(AppConstants.videoCardWidth), spacing: 40), count: 4),
                spacing: 40
            ) {
                ForEach(Array(queue.items.enumerated()), id: \.element.id) { index, video in
                    VideoCardView(video: video) { onPlay(video) }
                        .prefersDefaultFocus(index == 0, in: queueFocus)
                        .contextMenu {
                            Button(role: .destructive) {
                                Task { await queue.remove(video.id) }
                            } label: {
                                Label("Remove from Queue", systemImage: "minus.circle")
                            }
                        }
                        .onAppear {
                            // Reaching the last card pulls the next page.
                            if video.id == queue.items.last?.id {
                                Task { await queue.loadMore() }
                            }
                        }
                }
            }
            .padding(NullFeedTheme.contentPadding)
            .focusScope(queueFocus)

            if queue.isLoadingMore {
                ProgressView()
                    .tint(NullFeedTheme.primary)
                    .frame(maxWidth: .infinity)
                    .padding(.top, 8)
            }
        }
    }
}
