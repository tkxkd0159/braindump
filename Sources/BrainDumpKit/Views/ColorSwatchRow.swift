import SwiftUI

/// Horizontal palette of color swatches the user taps to pick the block color.
public struct ColorSwatchRow: View {
    @Binding var selected: Int

    public init(selected: Binding<Int>) {
        self._selected = selected
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Color")
                .font(Theme.Font.tinyLabel)
                .tracking(1.2)
                .foregroundStyle(Theme.Palette.onSurfaceVariant)
            HStack(spacing: 10) {
                ForEach(Array(Theme.BlockPalette.colors.enumerated()), id: \.offset) { idx, color in
                    Button(action: { selected = idx }) {
                        Circle()
                            .fill(color)
                            .frame(width: 24, height: 24)
                            .overlay(
                                Circle()
                                    .strokeBorder(Theme.Palette.primary, lineWidth: selected == idx ? 2 : 0)
                                    .padding(-3)
                            )
                    }
                    .buttonStyle(.plain)
                    .help("Color \(idx + 1)")
                }
            }
        }
    }
}
