import Foundation

/// Pure (SwiftUI-free) conversions between `#RRGGBB` hex strings and normalized
/// RGB components, plus a luminance test that drives legible foreground choice.
/// Kept free of `Color`/AppKit so it's trivially unit-testable; the SwiftUI
/// bridge lives in `Color+Hex.swift`.
public enum HexColor {
    /// Parse `#RRGGBB` or `RRGGBB` (case-insensitive) into 0...1 components.
    /// Returns nil for anything that isn't exactly six hex digits.
    public static func parse(_ hex: String) -> (r: Double, g: Double, b: Double)? {
        var s = hex
        if s.hasPrefix("#") { s.removeFirst() }
        guard s.count == 6, let value = UInt32(s, radix: 16) else { return nil }
        let r = Double((value >> 16) & 0xFF) / 255.0
        let g = Double((value >> 8) & 0xFF) / 255.0
        let b = Double(value & 0xFF) / 255.0
        return (r, g, b)
    }

    /// Canonical uppercase `#RRGGBB`. Components are clamped to 0...1.
    public static func string(r: Double, g: Double, b: Double) -> String {
        func channel(_ v: Double) -> Int { Int((max(0, min(1, v)) * 255).rounded()) }
        return String(format: "#%02X%02X%02X", channel(r), channel(g), channel(b))
    }

    /// True when the color is light enough to need dark text on top of it.
    /// Uses perceived (sRGB) luminance with a 0.5 cutoff.
    public static func isLight(r: Double, g: Double, b: Double) -> Bool {
        luminance(r: r, g: g, b: b) > 0.5
    }

    static func luminance(r: Double, g: Double, b: Double) -> Double {
        0.299 * r + 0.587 * g + 0.114 * b
    }
}
