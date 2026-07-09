import SwiftUI

struct LibraryView: View {
    @Environment(APIClient.self) private var api
    @State private var viewModel: LibraryViewModel?
    @State private var showSubscribe = false
    @Namespace private var gridFocus

    var body: some View {
        NavigationStack {
            ZStack {
                NullFeedBackdrop()

                if let vm = viewModel {
                    StateView(state: .resolve(
                        isLoading: vm.isLoading,
                        isEmpty: vm.channels.isEmpty,
                        error: vm.error,
                        empty: (
                            icon: "books.vertical",
                            title: "No Channels",
                            subtitle: "Subscribe to a YouTube channel to get started"
                        ),
                        retry: { Task { await vm.loadChannels() } }
                    )) {
                        channelGrid(vm)
                    }
                }
            }
            .navigationDestination(for: Channel.self) { channel in
                ChannelDetailView(channelId: channel.id)
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        Task { await viewModel?.refresh() }
                    } label: {
                        Label("Refresh", systemImage: "arrow.clockwise")
                    }
                    .disabled(viewModel?.isRefreshing == true)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showSubscribe = true
                    } label: {
                        Label("Add Channel", systemImage: "plus")
                    }
                }
            }
            .sheet(isPresented: $showSubscribe) {
                if let vm = viewModel {
                    SubscribeChannelView(viewModel: vm) {
                        showSubscribe = false
                    }
                }
            }
            .onAppear {
                if viewModel == nil {
                    viewModel = LibraryViewModel(api: api)
                }
                Task { await viewModel?.loadChannels() }
            }
        }
    }

    @ViewBuilder
    private func channelGrid(_ vm: LibraryViewModel) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 34) {
                ScreenHeaderView(
                    symbol: "rectangle.stack.fill",
                    title: "Library",
                    subtitle: "\(vm.channels.count) subscribed \(vm.channels.count == 1 ? "channel" : "channels")"
                )

                LazyVGrid(columns: NullFeedLayout.channelGridColumns, spacing: NullFeedLayout.gridSpacing) {
                    ForEach(Array(vm.channels.enumerated()), id: \.element.id) { index, channel in
                        NavigationLink(value: channel) {
                            ChannelCardView(channel: channel)
                        }
                        .buttonStyle(CardButtonStyle())
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
