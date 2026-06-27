import SwiftUI

struct DiscoverView: View {
    @Environment(APIClient.self) private var api
    @State private var viewModel: DiscoverViewModel?
    @Namespace private var gridFocus

    var body: some View {
        NavigationStack {
            ZStack {
                NullFeedTheme.background.ignoresSafeArea()

                if let vm = viewModel {
                    StateView(state: .resolve(
                        isLoading: vm.isLoading,
                        isEmpty: vm.recommendations.isEmpty,
                        error: vm.error,
                        empty: (
                            icon: "sparkles",
                            title: "No Recommendations",
                            subtitle: "Subscribe to channels and recommendations will appear"
                        ),
                        retry: { Task { await vm.loadRecommendations() } }
                    )) {
                        recommendationGrid(vm)
                    }
                }
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Refresh") {
                        Task { await viewModel?.refreshRecommendations() }
                    }
                }
            }
            .onAppear {
                if viewModel == nil {
                    viewModel = DiscoverViewModel(api: api)
                }
                Task { await viewModel?.loadRecommendations() }
            }
        }
    }

    @ViewBuilder
    private func recommendationGrid(_ vm: DiscoverViewModel) -> some View {
        ScrollView {
            LazyVGrid(
                columns: Array(repeating: GridItem(.fixed(AppConstants.channelCardWidth), spacing: 40), count: 4),
                spacing: 40
            ) {
                ForEach(Array(vm.recommendations.enumerated()), id: \.element.id) { index, rec in
                    RecommendationCardView(
                        recommendation: rec,
                        onSubscribe: {
                            if let ytId = rec.youtubeChannelId {
                                Task {
                                    try? await api.subscribeToChannel(
                                        url: "https://youtube.com/channel/\(ytId)"
                                    )
                                    await vm.dismissRecommendation(rec.id)
                                }
                            }
                        },
                        onDismiss: {
                            Task { await vm.dismissRecommendation(rec.id) }
                        }
                    )
                    .prefersDefaultFocus(index == 0, in: gridFocus)
                }
            }
            .padding(NullFeedTheme.contentPadding)
            .focusScope(gridFocus)
        }
    }
}
