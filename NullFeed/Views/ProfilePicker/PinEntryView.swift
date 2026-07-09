import SwiftUI

/// Focusable PIN pad shown when a profile is PIN-protected. Collects 4-8 digits
/// (matching the backend's `^\d{4,8}$` rule) and reports the result back so the
/// caller can re-prompt on a wrong PIN or surface a lockout.
struct PinEntryView: View {
    let user: User
    let onSubmit: (String) async -> ProfileSelectOutcome
    let onCancel: () -> Void

    @State private var pin = ""
    @State private var message: String?
    @State private var isSubmitting = false

    private let minLength = 4
    private let maxLength = 8

    var body: some View {
        VStack(spacing: 36) {
            VStack(spacing: 8) {
                Text("Enter PIN")
                    .font(NullFeedTheme.headlineMedium)
                    .foregroundStyle(NullFeedTheme.textPrimary)

                Text(user.displayName)
                    .font(NullFeedTheme.bodyLarge)
                    .foregroundStyle(NullFeedTheme.textSecondary)
            }

            Text(pin.isEmpty ? " " : String(repeating: "\u{25CF}", count: pin.count))
                .font(.system(size: 44, weight: .bold))
                .foregroundStyle(NullFeedTheme.textPrimary)
                .frame(height: 56)

            PinKeypadView(pin: $pin, maxLength: maxLength, onChange: { message = nil })

            if let message {
                Text(message)
                    .font(NullFeedTheme.bodyMedium)
                    .foregroundStyle(NullFeedTheme.error)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 600)
            }

            HStack(spacing: 24) {
                Button("Cancel", action: onCancel)
                    .tint(NullFeedTheme.textMuted)

                Button("Sign In") { submit() }
                    .tint(NullFeedTheme.primary)
                    .disabled(pin.count < minLength || isSubmitting)
            }
        }
        .padding(60)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(NullFeedBackdrop())
    }

    private func submit() {
        guard pin.count >= minLength, !isSubmitting else { return }
        isSubmitting = true
        Task {
            let outcome = await onSubmit(pin)
            isSubmitting = false
            switch outcome {
            case .success:
                break // RootView swaps to the main UI once authenticated.
            case .incorrectPin:
                message = "Incorrect PIN. Try again."
                pin = ""
            case .lockedOut:
                message = "Too many failed attempts. Try again in 30 seconds."
                pin = ""
            case .failed(let detail):
                message = detail
            }
        }
    }
}
