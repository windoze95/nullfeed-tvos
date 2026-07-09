import SwiftUI

/// The focusable 0-9 + delete keypad shared by the sign-in PIN prompt
/// (`PinEntryView`) and the add-profile PIN setup (`SetPinView`). Appends digits
/// to `pin` up to `maxLength` and removes the last digit on delete; `onChange`
/// lets the host clear a stale message as the user types.
struct PinKeypadView: View {
    @Binding var pin: String
    var maxLength: Int = 8
    var onChange: () -> Void = {}

    private let keypadRows = [
        ["1", "2", "3"],
        ["4", "5", "6"],
        ["7", "8", "9"],
        ["", "0", "delete"],
    ]

    var body: some View {
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
            .buttonStyle(CardButtonStyle())
        }
    }

    private func handleKey(_ key: String) {
        onChange()
        if key == "delete" {
            if !pin.isEmpty { pin.removeLast() }
        } else if pin.count < maxLength {
            pin.append(key)
        }
    }
}
