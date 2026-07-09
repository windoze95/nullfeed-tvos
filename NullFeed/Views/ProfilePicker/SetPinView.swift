import SwiftUI

/// Sheet for choosing a profile PIN while creating a profile. Collects a 4-8
/// digit PIN, asks the user to confirm it, then hands the final value back via
/// `onSave`. `onSave(nil)` clears a previously-set PIN ("Remove PIN", only shown
/// when one is already set).
struct SetPinView: View {
    let canRemove: Bool
    let onSave: (String?) -> Void
    let onCancel: () -> Void

    @State private var stage: Stage = .enter
    @State private var firstEntry = ""
    @State private var pin = ""
    @State private var message: String?

    private let minLength = 4
    private let maxLength = 8

    private enum Stage { case enter, confirm }

    var body: some View {
        VStack(spacing: 36) {
            VStack(spacing: 8) {
                Text(stage == .enter ? "Set PIN" : "Confirm PIN")
                    .font(NullFeedTheme.headlineMedium)
                    .foregroundStyle(NullFeedTheme.textPrimary)

                Text(stage == .enter
                    ? "Choose a 4-8 digit PIN for this profile."
                    : "Re-enter the PIN to confirm.")
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

                if canRemove {
                    Button("Remove PIN") { onSave(nil) }
                        .tint(NullFeedTheme.error)
                }

                Button(stage == .enter ? "Next" : "Save") { advance() }
                    .tint(NullFeedTheme.primary)
                    .disabled(pin.count < minLength)
            }
        }
        .padding(60)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(NullFeedBackdrop())
    }

    private func advance() {
        guard pin.count >= minLength else { return }
        switch stage {
        case .enter:
            firstEntry = pin
            pin = ""
            stage = .confirm
        case .confirm:
            if pin == firstEntry {
                onSave(pin)
            } else {
                message = "PINs don't match. Try again."
                pin = ""
                firstEntry = ""
                stage = .enter
            }
        }
    }
}
