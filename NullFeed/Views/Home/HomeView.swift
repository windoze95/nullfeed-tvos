import SwiftUI

struct HomeView: View {
    @Environment(APIClient.self) private var api
    @State private var viewModel: HomeViewModel?

    var body: some View {
        Group {
            if let viewModel {
                if viewModel.isLoading && viewModel.isEmpty {
                    LoadingView()
                } else if viewModel.isEmpty {
                    EmptyStateView(
                        iconName: "play.rectangle.on.rectangle",
                        title: "Nothing Here Yet",
                        subtitle: "Subscribe to channels and download videos to start watching."
                    )
                } else {
                    feedContent(viewModel: viewModel)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(NullFeedTheme.background)
        .task {
            if viewModel == nil {
                viewModel = HomeViewModel(api: api)
            }
            await viewModel?.loadFeed()
        }
    }

    @ViewBuilder
    private func feedContent(viewModel: HomeViewModel) -> some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 40) {
                if !viewModel.continueWatching.isEmpty {
                    ContentRowView(title: "Continue Watching") {
                        ForEach(viewModel.continueWatching) { item in
                            VideoCardView(feedItem: item)
                        }
                    }
                }

                if !viewModel.newEpisodes.isEmpty {
                    ContentRowView(title: "New Episodes") {
                        ForEach(viewModel.newEpisodes) { item in
                            VideoCardView(feedItem: item)
                        }
                    }
                }

                if !viewModel.recentlyAdded.isEmpty {
                    ContentRowView(title: "Recently Added") {
                        ForEach(viewModel.recentlyAdded) { item in
                            VideoCardView(feedItem: item)
                        }
                    }
                }
            }
            .padding(.vertical, NullFeedTheme.contentPadding)
        }
    }
}
