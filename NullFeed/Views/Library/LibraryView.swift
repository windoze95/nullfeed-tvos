import SwiftUI

struct LibraryView: View {
    @Environment(APIClient.self) private var api
    @State private var viewModel: LibraryViewModel?
    @State private var showSubscribe = false

    var body: some View {
        NavigationStack {
            ZStack {
                NullFeedTheme.background.ignoresSafeArea()

                if let vm = viewModel {
                    if vm.isLoading && vm.channels.isEmpty {
                        LoadingView()
                    } else if vm.channels.isEmpty {
                        EmptyStateView(
                            iconName: "books.vertical",
                            title: "No Channels",
                            subtitle: "Subscribe to a YouTube channel to get started"
                        )
                    } else {
                        ScrollView {
                            LazyVGrid(
                                columns: Array(repeating: GridItem(.fixed(AppConstants.channelCardWidth), spacing: 40), count: 5),
                                spacing: 40
                            ) {
                                ForEach(vm.channels) { channel in
                                    NavigationLink(value: channel) {
                                        ChannelCardView(channel: channel)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            .padding(NullFeedTheme.contentPadding)
                        }
                    }
                }
            }
            .navigationDestination(for: Channel.self) { channel in
                ChannelDetailView(channelId: channel.id)
            }
            .toolbar {
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
}
