import SwiftUI
import Testing

@testable import BrainDumpKit

/// The user-visible contract for the shared sheet buttons (Cancel / Close /
/// Done / Add / Save): hover *inverts* them — the black primary flips to white,
/// the white secondary flips to black — strictly monochrome, no accent tint. An
/// offscreen snapshot can't move a pointer, so the proof is the pure fill/text
/// functions the style calls.
@MainActor
struct ActionButtonStyleTests {
    @Test func primaryInvertsBlackToWhiteOnHover() {
        #expect(ActionButtonKind.primary.background(hovered: false) == Theme.Palette.primary)
        #expect(ActionButtonKind.primary.background(hovered: true) == Theme.Palette.onPrimary)
        #expect(ActionButtonKind.primary.foreground(hovered: false) == Theme.Palette.onPrimary)
        #expect(ActionButtonKind.primary.foreground(hovered: true) == Theme.Palette.primary)
    }

    @Test func secondaryInvertsWhiteToBlackOnHover() {
        #expect(ActionButtonKind.secondary.background(hovered: false) == Theme.Palette.onPrimary)
        #expect(ActionButtonKind.secondary.background(hovered: true) == Theme.Palette.primary)
        #expect(ActionButtonKind.secondary.foreground(hovered: false) == Theme.Palette.primary)
        #expect(ActionButtonKind.secondary.foreground(hovered: true) == Theme.Palette.onPrimary)
    }

    /// Hover swaps fill and text (a true inversion), and every state stays on the
    /// monochrome black/white poles — no blue tint.
    @Test func hoverIsAMonochromeInversion() {
        for kind in [ActionButtonKind.primary, .secondary] {
            #expect(kind.background(hovered: true) == kind.foreground(hovered: false))
            #expect(kind.foreground(hovered: true) == kind.background(hovered: false))
            for hovered in [true, false] {
                let bg = kind.background(hovered: hovered)
                #expect(bg == Theme.Palette.primary || bg == Theme.Palette.onPrimary)
            }
        }
    }
}
