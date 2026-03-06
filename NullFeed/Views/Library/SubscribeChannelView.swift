import SwiftUI

struct SubscribeChannelView: View {
    let viewModel: LibraryViewModel
    let onDismiss: () -> Void

    @State private var youtubeUrl = ""
    @State private var trackingMode = "FUTURE_ONLY"
    @State private var isSubscribing = false

    var body: some View {
        VStack(spacing: 40) {
            Text("Subscribe to Channel")
                .font(NullFeedTheme.headlineMedium)
                .foregroundStyle(NullFeedTheme.textPrimary)

            VStack(alignment: .leading, spacing: 16) {
                Text("YouTube Channel URL")
                    .font(NullFeedTheme.bodyMedium)
                    .foregroundStyle(NullFeedTheme.textSecondary)

                TextField("https://youtube.com/@channel", text: $youtubeUrl)
                    .textFieldStyle(.plain)
                    .padding()
                    .background(NullFeedTheme.card, in: RoundedRectangle(cornerRadius: 8))
            }

            Picker("Tracking Mode", selection: $trackingMode) {
                Text("Future Videos Only").tag("FUTURE_ONLY")
                Text("All Videos").tag("ALL")
            }
            .pickerStyle(.segmented)

            HStack(spacing: 24) {
                Button("Cancel") {
                    onDismiss()
                }

                Button("Subscribe") {
                    isSubscribing = true
                    Task {
                        await viewModel.subscribeToChannel(url: youtubeUrl, trackingMode: trackingMode)
                        isSubscribing = false
                        onDismiss()
                    }
                }
                .disabled(youtubeUrl.isEmpty || isSubscribing)
            }

            if let error = viewModel.error {
                Text(error)
                    .font(NullFeedTheme.bodySmall)
                    .foregroundStyle(NullFeedTheme.error)
            }
        }
        .padding(NullFeedTheme.contentPadding)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(NullFeedTheme.background)
    }
}
