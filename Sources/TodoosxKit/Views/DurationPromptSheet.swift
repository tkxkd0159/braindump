import SwiftUI

public struct DurationPromptSheet: View {
    let startHour: Int
    let maxDuration: Int
    let onConfirm: (Int, Int) -> Void
    let onCancel: () -> Void

    @State private var duration: Int = 1
    @State private var colorIndex: Int = 0

    public init(
        startHour: Int,
        maxDuration: Int,
        onConfirm: @escaping (Int, Int) -> Void,
        onCancel: @escaping () -> Void
    ) {
        self.startHour = startHour
        self.maxDuration = maxDuration
        self.onConfirm = onConfirm
        self.onCancel = onCancel
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Time Block")
                    .font(Theme.Font.tinyLabel)
                    .tracking(1.5)
                    .textCase(.uppercase)
                    .foregroundStyle(Theme.Palette.primary)
                Text("How long for this task?")
                    .font(Theme.Font.headlineMd)
                    .foregroundStyle(Theme.Palette.onSurface)
                Text("Starting at \(formattedHour(startHour))")
                    .font(Theme.Font.bodyMd)
                    .foregroundStyle(Theme.Palette.onSurfaceVariant)
            }

            HStack(spacing: 8) {
                ForEach(1...min(4, max(1, maxDuration)), id: \.self) { value in
                    Button("\(value)h") { duration = value }
                        .buttonStyle(DurationChipStyle(selected: duration == value))
                }
                if maxDuration > 4 {
                    Stepper(value: $duration, in: 1...maxDuration) {
                        Text("\(duration) hour\(duration == 1 ? "" : "s")")
                            .font(Theme.Font.labelMd)
                    }
                }
            }

            ColorSwatchRow(selected: $colorIndex)

            HStack(spacing: 12) {
                Spacer()
                Button("Cancel", action: onCancel)
                    .buttonStyle(SecondaryActionStyle())
                    .keyboardShortcut(.cancelAction)
                Button("Schedule") { onConfirm(duration, colorIndex) }
                    .buttonStyle(PrimaryActionStyle())
                    .keyboardShortcut(.defaultAction)
            }
        }
        .padding(28)
        .frame(width: 420)
        .background(Theme.Palette.surfaceContainerLowest)
    }

    private func formattedHour(_ hour: Int) -> String {
        let h = hour % 12 == 0 ? 12 : hour % 12
        let suffix = hour < 12 ? "AM" : "PM"
        return "\(h):00 \(suffix)"
    }
}

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

private struct DurationChipStyle: ButtonStyle {
    let selected: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(Theme.Font.labelMd)
            .tracking(0.5)
            .padding(.horizontal, 14)
            .frame(height: 34)
            .foregroundStyle(selected ? Theme.Palette.onPrimary : Theme.Palette.primary)
            .background(selected ? Theme.Palette.primary : Theme.Palette.surfaceContainerLowest)
            .overlay(Rectangle().strokeBorder(Theme.Palette.primary, lineWidth: 1))
            .opacity(configuration.isPressed ? 0.85 : 1)
    }
}

private struct PrimaryActionStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(Theme.Font.labelMd)
            .tracking(0.5)
            .padding(.horizontal, 18)
            .frame(height: 34)
            .foregroundStyle(Theme.Palette.onPrimary)
            .background(Theme.Palette.primary)
            .opacity(configuration.isPressed ? 0.85 : 1)
    }
}

private struct SecondaryActionStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(Theme.Font.labelMd)
            .tracking(0.5)
            .padding(.horizontal, 18)
            .frame(height: 34)
            .foregroundStyle(Theme.Palette.primary)
            .background(Theme.Palette.surfaceContainerLowest)
            .overlay(Rectangle().strokeBorder(Theme.Palette.primary, lineWidth: 1))
            .opacity(configuration.isPressed ? 0.85 : 1)
    }
}
