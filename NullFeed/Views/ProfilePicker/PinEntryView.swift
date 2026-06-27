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

    private let keypadRows = [
        ["1", "2", "3"],
        ["4", "5", "6"],
        ["7", "8", "9"],
        ["", "0", "delete"],
    ]

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

            keypad

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
        .background(NullFeedTheme.background)
    }

    private var keypad: some View {
        VStack(spacing: 20) {
            ForEach(keypadRows, id: \.self) { row in
                HStack(spacing: 20) {
                    ForEach(row, id: \.self) { key in
                        keyButton(key)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func keyButton(_ key: String) -> some View {
        if key.isEmpty {
            Color.clear.frame(width: 110, height: 110)
        } else {
            Button {
                handleKey(key)
            } label: {
                Group {
                    if key == "delete" {
                        Image(systemName: "delete.left")
                    } else {
                        Text(key)
                    }
                }
                .font(NullFeedTheme.headlineSmall)
                .foregroundStyle(NullFeedTheme.textPrimary)
                .frame(width: 110, height: 110)
                .background(NullFeedTheme.card)
                .clipShape(RoundedRectangle(cornerRadius: NullFeedTheme.cardRadius))
            }
            .buttonStyle(.plain)
        }
    }

    private func handleKey(_ key: String) {
        message = nil
        if key == "delete" {
            if !pin.isEmpty { pin.removeLast() }
        } else if pin.count < maxLength {
            pin.append(key)
        }
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
