import SwiftUI

struct DiscoverView: View {
    @Environment(APIClient.self) private var api
    @State private var viewModel: DiscoverViewModel?
    @Namespace private var gridFocus

    var body: some View {
        NavigationStack {
            ZStack {
                NullFeedBackdrop()

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
                    Button {
                        Task { await viewModel?.refreshRecommendations() }
                    } label: {
                        Label("Refresh", systemImage: "arrow.clockwise")
                    }
                    .disabled(viewModel?.isRefreshing == true)
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
            VStack(alignment: .leading, spacing: 34) {
                ScreenHeaderView(
                    symbol: "sparkles",
                    title: "Discover",
                    subtitle: "Fresh channels picked for your profile"
                )

                LazyVGrid(columns: NullFeedLayout.channelGridColumns, spacing: NullFeedLayout.gridSpacing) {
                    ForEach(Array(vm.recommendations.enumerated()), id: \.element.id) { index, rec in
                        RecommendationCardView(
                            recommendation: rec,
                            onSubscribe: {
                                if let ytId = rec.youtubeChannelId {
                                    Task {
                                        do {
                                            try await api.subscribeToChannel(
                                                url: "https://youtube.com/channel/\(ytId)"
                                            )
                                            await vm.dismissRecommendation(rec.id)
                                        } catch {
                                            vm.error = error.localizedDescription
                                        }
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
            }
            .padding(.horizontal, NullFeedTheme.contentPadding)
            .padding(.top, 38)
            .padding(.bottom, NullFeedTheme.contentPadding)
            .focusScope(gridFocus)
        }
        .scrollClipDisabled()
    }
}
