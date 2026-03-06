import SwiftUI
import AVKit

struct PlayerView: View {
    let videoId: String
    @Environment(APIClient.self) private var api
    @Environment(WebSocketClient.self) private var webSocket
    @State private var viewModel: PlayerViewModel?
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            if let vm = viewModel {
                if vm.isLoading {
                    ProgressView()
                        .tint(NullFeedTheme.primary)
                } else if let error = vm.error {
                    VStack(spacing: 20) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.system(size: 48))
                            .foregroundStyle(NullFeedTheme.error)
                        Text(error)
                            .font(NullFeedTheme.bodyMedium)
                            .foregroundStyle(NullFeedTheme.textSecondary)
                            .multilineTextAlignment(.center)
                    }
                } else if let player = vm.player {
                    TVPlayerView(player: player)
                        .ignoresSafeArea()

                    // Preview badge
                    if vm.isPreviewMode {
                        VStack {
                            HStack {
                                Spacer()
                                Text("360p")
                                    .font(NullFeedTheme.caption)
                                    .foregroundStyle(.white.opacity(0.7))
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .background(.black.opacity(0.6), in: RoundedRectangle(cornerRadius: 6))
                            }
                            .padding(24)
                            Spacer()
                        }
                    }
                }
            }
        }
        .onAppear {
            let vm = PlayerViewModel(api: api, webSocket: webSocket)
            viewModel = vm
            Task { await vm.loadVideo(id: videoId) }
        }
        .onDisappear {
            viewModel?.cleanup()
        }
    }
}

// UIViewControllerRepresentable for AVPlayerViewController
struct TVPlayerView: UIViewControllerRepresentable {
    let player: AVPlayer

    func makeUIViewController(context: Context) -> AVPlayerViewController {
        let vc = AVPlayerViewController()
        vc.player = player
        vc.showsPlaybackControls = true
        return vc
    }

    func updateUIViewController(_ vc: AVPlayerViewController, context: Context) {
        if vc.player !== player {
            vc.player = player
        }
    }
}
