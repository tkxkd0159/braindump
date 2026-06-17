import SwiftUI

/// Visual variant for the shared sheet action buttons (Cancel / Close / Done /
/// Add / Save / Schedule). The fill logic is a pure function so the hover
/// transition is unit-testable — an offscreen snapshot can't simulate a pointer,
/// so we can't prove "color changes on hover" with a screenshot alone.
enum ActionButtonKind: Equatable {
    case primary    // filled (black) at rest
    case secondary  // outlined (white) at rest

    /// Text color. Inverts together with the fill on hover so contrast holds.
    func foreground(hovered: Bool) -> Color {
        switch self {
        case .primary: return hovered ? Theme.Palette.primary : Theme.Palette.onPrimary
        case .secondary: return hovered ? Theme.Palette.onPrimary : Theme.Palette.primary
        }
    }

    /// Fill for the current interaction state. Hover *inverts* the button: the
    /// strong black primary flips to white and the white outlined secondary flips
    /// to black. Strictly monochrome (primary ↔ onPrimary) — no accent tint. A
    /// 1pt primary border is always drawn so the white states stay visible.
    func background(hovered: Bool) -> Color {
        switch self {
        case .primary: return hovered ? Theme.Palette.onPrimary : Theme.Palette.primary
        case .secondary: return hovered ? Theme.Palette.primary : Theme.Palette.onPrimary
        }
    }
}

/// Filled primary action button (Add / Done / Save / Schedule).
struct PrimaryActionStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        ActionButtonSurface(configuration: configuration, kind: .primary)
    }
}

/// Outlined secondary action button (Cancel / Close).
struct SecondaryActionStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        ActionButtonSurface(configuration: configuration, kind: .secondary)
    }
}

/// A `ButtonStyle.makeBody` can't own `@State`, so the hover tracking lives in
/// this wrapper that both styles share. Hover is ignored while disabled.
private struct ActionButtonSurface: View {
    let configuration: ButtonStyle.Configuration
    let kind: ActionButtonKind
    @Environment(\.isEnabled) private var isEnabled
    @State private var hovering = false

    private var hovered: Bool { hovering && isEnabled }

    var body: some View {
        configuration.label
            .font(Theme.Font.labelMd)
            .tracking(0.5)
            .padding(.horizontal, 18)
            .frame(height: 34)
            .foregroundStyle(kind.foreground(hovered: hovered))
            .background(kind.background(hovered: hovered))
            .overlay { Rectangle().strokeBorder(Theme.Palette.primary, lineWidth: 1) }
            .contentShape(Rectangle())
            .opacity(isEnabled ? (configuration.isPressed ? 0.85 : 1) : 0.45)
            .onHover { hovering = $0 }
            .animation(.easeOut(duration: 0.12), value: hovered)
    }
}
