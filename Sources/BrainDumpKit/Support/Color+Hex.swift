import AppKit
import SwiftUI

/// SwiftUI/AppKit bridge for `HexColor`. Lives apart from the pure helper so the
/// conversions stay testable without a rendering context.
public extension Color {
    /// Build an sRGB color from `#RRGGBB` / `RRGGBB`; nil if unparseable.
    init?(hexString: String) {
        guard let rgb = HexColor.parse(hexString) else { return nil }
        self.init(.sRGB, red: rgb.r, green: rgb.g, blue: rgb.b, opacity: 1)
    }

    /// Canonical `#RRGGBB` for this color, resolved in the sRGB space.
    var hexString: String? {
        guard let resolved = NSColor(self).usingColorSpace(.sRGB) else { return nil }
        return HexColor.string(
            r: Double(resolved.redComponent),
            g: Double(resolved.greenComponent),
            b: Double(resolved.blueComponent))
    }
}
