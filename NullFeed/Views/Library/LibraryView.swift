import SwiftUI

struct LibraryView: View {
    @Environment(APIClient.self) private var api
    @State private var viewModel: LibraryViewModel?
    @State private var showSubscribe = false
    @Namespace private var gridFocus

    var body: some View {
        NavigationStack {
            ZStack {
                NullFeedTheme.background.ignoresSafeArea()

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
                    Button("Refresh") {
                        Task { await viewModel?.refresh() }
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Subscribe") {
                        showSubscribe = true
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
            LazyVGrid(
                columns: Array(repeating: GridItem(.fixed(AppConstants.channelCardWidth), spacing: 40), count: 5),
                spacing: 40
            ) {
                ForEach(Array(vm.channels.enumerated()), id: \.element.id) { index, channel in
                    NavigationLink(value: channel) {
                        ChannelCardView(channel: channel)
                    }
                    .buttonStyle(CardButtonStyle())
                    .prefersDefaultFocus(index == 0, in: gridFocus)
                }
            }
            .padding(NullFeedTheme.contentPadding)
            .focusScope(gridFocus)
        }
    }
}
