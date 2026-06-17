import SwiftUI

/// Palette of preset color swatches plus a native `ColorPicker` for any custom
/// color. Selecting a preset clears the custom override (`customHex = nil`);
/// choosing in the picker sets `customHex` and deselects the presets.
public struct ColorSwatchRow: View {
    @Binding var selected: Int
    @Binding var customHex: String?

    public init(selected: Binding<Int>, customHex: Binding<String?>) {
        self._selected = selected
        self._customHex = customHex
    }

    private var isCustom: Bool { customHex != nil }

    /// Drives the `ColorPicker`. Reads the custom color (or the active preset, so
    /// the well mirrors the current selection) and writes any pick as a hex.
    private var customColorBinding: Binding<Color> {
        Binding(
            get: { customHex.flatMap { Color(hexString: $0) } ?? Theme.BlockPalette.color(at: selected) },
            set: { customHex = $0.hexString }
        )
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Color")
                .font(Theme.Font.tinyLabel)
                .tracking(1.2)
                .foregroundStyle(Theme.Palette.onSurfaceVariant)
            HStack(spacing: 10) {
                ForEach(Array(Theme.BlockPalette.colors.enumerated()), id: \.offset) { idx, color in
                    Button(action: { selected = idx; customHex = nil }) {
                        Circle()
                            .fill(color)
                            .frame(width: 24, height: 24)
                            .overlay(
                                Circle()
                                    .strokeBorder(
                                        Theme.Palette.primary,
                                        lineWidth: (!isCustom && selected == idx) ? 2 : 0)
                                    .padding(-3)
                            )
                    }
                    .buttonStyle(.plain)
                    .help("Color \(idx + 1)")
                }
                customSwatch
            }
        }
    }

    private var customSwatch: some View {
        ColorPicker(selection: customColorBinding, supportsOpacity: false) {
            EmptyView()
        }
        .labelsHidden()
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .strokeBorder(Theme.Palette.primary, lineWidth: isCustom ? 2 : 0)
                .padding(-3)
        )
        .help("Custom color")
    }
}
