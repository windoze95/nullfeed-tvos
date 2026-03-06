import SwiftUI

struct ServerSetupView: View {
    @Environment(StorageService.self) private var storage
    @Environment(APIClient.self) private var api
    @Environment(AppState.self) private var appState
    @Bindable var viewModel: AuthViewModel

    var body: some View {
        VStack(spacing: 40) {
            Spacer()

            Text(AppConstants.appName)
                .font(NullFeedTheme.headlineLarge)
                .foregroundStyle(NullFeedTheme.textPrimary)

            Text("Connect to your NullFeed server")
                .font(NullFeedTheme.bodyLarge)
                .foregroundStyle(NullFeedTheme.textSecondary)

            VStack(spacing: 24) {
                TextField("http://192.168.20.158:\(AppConstants.defaultServerPort)", text: $viewModel.serverUrl)
                    .textFieldStyle(.plain)
                    .font(NullFeedTheme.bodyLarge)
                    .padding(20)
                    .background(NullFeedTheme.surface)
                    .clipShape(RoundedRectangle(cornerRadius: NullFeedTheme.cardRadius))
                    .autocorrectionDisabled()

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
                .buttonStyle(.plain)
                .disabled(viewModel.isLoading)
            }
            .frame(maxWidth: 600)

            if let error = viewModel.error {
                Text(error)
                    .font(NullFeedTheme.bodyMedium)
                    .foregroundStyle(NullFeedTheme.error)
                    .multilineTextAlignment(.center)
            }

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(NullFeedTheme.background)
    }
}
