import CoreGraphics
import Foundation

/// Pure geometry for the custom HSB color wheel — kept free of SwiftUI so the
/// point⇄(hue, saturation) mapping is unit-testable without a rendering context.
///
/// Coordinates are SwiftUI-local (origin top-left, y growing downward). Hue is
/// expressed in turns `[0, 1)` measured clockwise from the +x axis (so straight
/// down is a quarter turn), and saturation is the radial distance from the
/// center, `[0, 1]`, clamped at the rim.
public enum ColorWheelGeometry {
    public static func huesat(at point: CGPoint, diameter: CGFloat) -> (hue: Double, saturation: Double) {
        let radius = diameter / 2
        guard radius > 0 else { return (0, 0) }
        let dx = Double(point.x - radius)
        let dy = Double(point.y - radius)
        let distance = (dx * dx + dy * dy).squareRoot()
        let saturation = min(1, distance / Double(radius))
        guard distance > 0 else { return (0, 0) }
        var hue = atan2(dy, dx) / (2 * .pi)
        if hue < 0 { hue += 1 }
        return (hue, saturation)
    }

    public static func point(hue: Double, saturation: Double, diameter: CGFloat) -> CGPoint {
        let radius = diameter / 2
        let clampedSat = max(0, min(1, saturation))
        let theta = hue * 2 * .pi
        let distance = clampedSat * Double(radius)
        return CGPoint(
            x: Double(radius) + cos(theta) * distance,
            y: Double(radius) + sin(theta) * distance)
    }
}
