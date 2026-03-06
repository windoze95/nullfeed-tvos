import SwiftUI

struct ProfilePickerView: View {
    @Bindable var viewModel: AuthViewModel

    var body: some View {
        VStack(spacing: 48) {
            Spacer()

            Text("Who's Watching?")
                .font(NullFeedTheme.headlineLarge)
                .foregroundStyle(NullFeedTheme.textPrimary)

            if viewModel.isLoading {
                ProgressView()
                    .tint(NullFeedTheme.primary)
            } else if viewModel.profiles.isEmpty {
                Text("No profiles found on this server.")
                    .font(NullFeedTheme.bodyLarge)
                    .foregroundStyle(NullFeedTheme.textSecondary)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 32) {
                        ForEach(viewModel.profiles) { user in
                            ProfileCardView(user: user) {
                                Task {
                                    await viewModel.selectProfile(userId: user.id)
                                }
                            }
                        }
                    }
                    .padding(.horizontal, NullFeedTheme.contentPadding)
                }
            }

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
