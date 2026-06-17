import SwiftUI

/// Color selector: the curated preset palette for one-tap picks, plus a rainbow
/// "custom" circle that opens a popover with a custom color wheel and an
/// explicit **Save** (the common dots + multicolor-wheel pattern).
///
/// Picking a preset sets `selected` and clears any custom override (instant);
/// the rainbow circle opens the wheel, whose **Save** stages a `#RRGGBB` into
/// `customHex` and closes the popover — so a custom color is chosen and saved
/// before the host sheet persists it. The system `ColorPicker`/`NSColorPanel`
/// (no save gesture, never auto-closes) is avoided entirely.
struct ColorField: View {
    @Binding var selected: Int
    @Binding var customHex: String?

    @State private var isPickerPresented = false
    @State private var draft: Color = .black

    init(selected: Binding<Int>, customHex: Binding<String?>) {
        self._selected = selected
        self._customHex = customHex
    }

    private var isCustom: Bool { customHex != nil }

    private var resolvedColor: Color {
        Theme.BlockPalette.color(at: selected, customHex: customHex)
    }

    /// Hue spectrum for the rainbow opener; first == last so the sweep wraps.
    private static let rainbow: [Color] =
        stride(from: 0.0, through: 1.0, by: 1.0 / 12.0).map {
            Color(hue: $0, saturation: 0.9, brightness: 1)
        }

    var body: some View {
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
                rainbowOpener
            }
        }
    }

    private var rainbowOpener: some View {
        Button {
            draft = resolvedColor
            isPickerPresented = true
        } label: {
            Circle()
                .fill(AngularGradient(gradient: Gradient(colors: Self.rainbow), center: .center))
                .frame(width: 24, height: 24)
                .overlay(Circle().strokeBorder(.white.opacity(0.7), lineWidth: 1.5))
                .overlay(Circle().strokeBorder(Theme.Palette.outlineVariant, lineWidth: 0.5))
                .overlay(
                    Circle()
                        .strokeBorder(Theme.Palette.primary, lineWidth: isCustom ? 2 : 0)
                        .padding(-3)
                )
        }
        .buttonStyle(.plain)
        .help("Custom color")
        .popover(isPresented: $isPickerPresented, arrowEdge: .bottom) {
            ColorWheelPopover(
                draft: $draft,
                onCancel: { isPickerPresented = false },
                onSave: {
                    customHex = draft.hexString
                    isPickerPresented = false
                })
        }
    }
}

/// Popover body: the wheel, a live preview of the picked color, and the explicit
/// Cancel / Save actions.
struct ColorWheelPopover: View {
    @Binding var draft: Color
    let onCancel: () -> Void
    let onSave: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("PICK A COLOR")
                .font(Theme.Font.tinyLabel)
                .tracking(1.5)
                .foregroundStyle(Theme.Palette.primary)
            ColorWheelPicker(color: $draft)
            HStack(spacing: 10) {
                RoundedRectangle(cornerRadius: 4)
                    .fill(draft)
                    .frame(width: 28, height: 28)
                    .overlay(RoundedRectangle(cornerRadius: 4).strokeBorder(Theme.Palette.outlineVariant, lineWidth: 1))
                Text(draft.hexString ?? "—")
                    .font(Theme.Font.bodyMd)
                    .foregroundStyle(Theme.Palette.onSurface)
                Spacer()
            }
            HStack(spacing: 12) {
                Spacer()
                Button("Cancel", action: onCancel)
                    .buttonStyle(.plain)
                    .font(Theme.Font.labelMd)
                    .padding(.horizontal, 16)
                    .frame(height: 30)
                    .foregroundStyle(Theme.Palette.primary)
                    .overlay(Rectangle().strokeBorder(Theme.Palette.primary, lineWidth: 1))
                    .keyboardShortcut(.cancelAction)
                Button("Save", action: onSave)
                    .buttonStyle(.plain)
                    .font(Theme.Font.labelMd)
                    .padding(.horizontal, 16)
                    .frame(height: 30)
                    .foregroundStyle(Theme.Palette.onPrimary)
                    .background(Theme.Palette.primary)
                    .keyboardShortcut(.defaultAction)
            }
        }
        .padding(20)
        .frame(width: 248)
        .background(Theme.Palette.surfaceContainerLowest)
    }
}
