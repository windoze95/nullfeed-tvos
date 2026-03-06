import SwiftUI

struct DiscoverView: View {
    @Environment(APIClient.self) private var api
    @State private var viewModel: DiscoverViewModel?

    var body: some View {
        NavigationStack {
            ZStack {
                NullFeedTheme.background.ignoresSafeArea()

                if let vm = viewModel {
                    if vm.isLoading && vm.recommendations.isEmpty {
                        LoadingView()
                    } else if vm.recommendations.isEmpty {
                        EmptyStateView(
                            iconName: "sparkles",
                            title: "No Recommendations",
                            subtitle: "Subscribe to channels and recommendations will appear"
                        )
                    } else {
                        ScrollView {
                            LazyVGrid(
                                columns: Array(repeating: GridItem(.fixed(AppConstants.channelCardWidth), spacing: 40), count: 4),
                                spacing: 40
                            ) {
                                ForEach(vm.recommendations) { rec in
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
                                }
                            }
                            .padding(NullFeedTheme.contentPadding)
                        }
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
}
