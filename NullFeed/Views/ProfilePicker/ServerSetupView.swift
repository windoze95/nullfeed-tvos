import SwiftUI

struct ServerSetupView: View {
    @Environment(StorageService.self) private var storage
    @Environment(APIClient.self) private var api
    @Environment(AppState.self) private var appState
    @Bindable var viewModel: AuthViewModel

    var body: some View {
        VStack(spacing: 40) {
            Spacer()

            VStack(spacing: 14) {
                Image(systemName: "play.rectangle.on.rectangle.fill")
                    .font(.system(size: 58, weight: .semibold))
                    .foregroundStyle(NullFeedTheme.accent)

                Text(AppConstants.appName)
                    .font(NullFeedTheme.headlineLarge)
                    .foregroundStyle(NullFeedTheme.textPrimary)

                Text("Connect this Apple TV to your server")
                    .font(NullFeedTheme.bodyLarge)
                    .foregroundStyle(NullFeedTheme.textSecondary)
            }

            VStack(spacing: 24) {
                TextField("192.168.1.10:\(AppConstants.defaultServerPort)", text: $viewModel.serverUrl)
                    .textFieldStyle(.plain)
                    .font(NullFeedTheme.bodyLarge)
                    .padding(20)
                    .background(NullFeedTheme.surface)
                    .clipShape(RoundedRectangle(cornerRadius: NullFeedTheme.cardRadius))
                    .autocorrectionDisabled()
                    .onSubmit {
                        Task { await viewModel.connectToServer() }
                    }

                Button {
                    Task {
                        await viewModel.connectToServer()
                    }
                } label: {
                    HStack(spacing: 12) {
                        if viewModel.isLoading {
                            ProgressView()
                                .tint(NullFeedTheme.textPrimary)
                        }
                        Text("Connect")
                            .font(NullFeedTheme.titleMedium)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 18)
                    .background(NullFeedTheme.primary)
                    .foregroundStyle(NullFeedTheme.textPrimary)
                    .clipShape(RoundedRectangle(cornerRadius: NullFeedTheme.cardRadius))
                }
                .buttonStyle(CardButtonStyle())
                .disabled(viewModel.isLoading)
            }
            .padding(30)
            .frame(maxWidth: 720)
            .background(NullFeedTheme.card.opacity(0.72), in: RoundedRectangle(cornerRadius: 24))

            Text("You can leave off http:// — NullFeed will add it for you.")
                .font(NullFeedTheme.caption)
                .foregroundStyle(NullFeedTheme.textMuted)

            if let error = viewModel.error {
                Text(error)
                    .font(NullFeedTheme.bodyMedium)
                    .foregroundStyle(NullFeedTheme.error)
                    .multilineTextAlignment(.center)
            }

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(NullFeedBackdrop())
    }
}
