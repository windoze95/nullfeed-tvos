import SwiftUI

struct ProfilePickerView: View {
    @Environment(APIClient.self) private var api
    @Environment(StorageService.self) private var storage
    @Environment(AppState.self) private var appState
    @Bindable var viewModel: AuthViewModel
    @State private var pinUser: User?
    @State private var addProfileViewModel: AddProfileViewModel?
    @State private var showAddProfile = false

    var body: some View {
        VStack(spacing: 48) {
            Spacer()

            Text("Who's Watching?")
                .font(NullFeedTheme.headlineLarge)
                .foregroundStyle(NullFeedTheme.textPrimary)

            if viewModel.isLoading {
                ProgressView()
                    .tint(NullFeedTheme.primary)
            } else {
                if viewModel.profiles.isEmpty {
                    Text("No profiles yet — add one to get started.")
                        .font(NullFeedTheme.bodyLarge)
                        .foregroundStyle(NullFeedTheme.textSecondary)
                }

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 32) {
                        ForEach(viewModel.profiles) { user in
                            ProfileCardView(user: user) {
                                if user.hasPin {
                                    pinUser = user
                                } else {
                                    Task { await viewModel.selectProfile(userId: user.id) }
                                }
                            }
                        }

                        AddProfileCard { openAddProfile() }
                    }
                    .padding(.horizontal, NullFeedTheme.contentPadding)
                }
                .sheet(isPresented: $showAddProfile) {
                    if let addProfileViewModel {
                        AddProfileView(viewModel: addProfileViewModel, api: api) {
                            showAddProfile = false
                        }
                    }
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
        .sheet(item: $pinUser) { user in
            PinEntryView(
                user: user,
                onSubmit: { pin in
                    await viewModel.selectProfile(userId: user.id, pin: pin)
                },
                onCancel: { pinUser = nil }
            )
        }
    }

    private func openAddProfile() {
        addProfileViewModel = AddProfileViewModel(api: api, storage: storage, appState: appState)
        showAddProfile = true
    }
}

/// The "+" entry that opens the add-profile flow. Sits at the end of the profile
/// row and is the only way to onboard a profile from the TV (issue #15), so it
/// shows even when the server has no profiles yet.
private struct AddProfileCard: View {
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            VStack(spacing: 16) {
                ZStack {
                    Circle()
                        .strokeBorder(
                            NullFeedTheme.textMuted,
                            style: StrokeStyle(lineWidth: 3, dash: [8])
                        )
                        .frame(width: 120, height: 120)

                    Image(systemName: "plus")
                        .font(.system(size: 48, weight: .semibold))
                        .foregroundStyle(NullFeedTheme.textSecondary)
                }

                Text("Add Profile")
                    .font(NullFeedTheme.titleMedium)
                    .foregroundStyle(NullFeedTheme.textPrimary)
                    .lineLimit(1)
            }
            .padding(24)
            .background(NullFeedTheme.card)
            .clipShape(RoundedRectangle(cornerRadius: NullFeedTheme.cardRadius))
        }
        .buttonStyle(CardButtonStyle())
    }
}
