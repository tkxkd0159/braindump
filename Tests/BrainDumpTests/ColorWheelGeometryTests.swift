import CoreGraphics
import Testing

@testable import BrainDumpKit

/// Pure geometry behind the custom HSB color wheel: mapping a touch point in a
/// wheel of a given diameter to (hue, saturation) and back. SwiftUI local
/// coordinates (origin top-left, y growing downward).

@Test func colorWheelCenterHasZeroSaturation() {
    let hs = ColorWheelGeometry.huesat(at: CGPoint(x: 100, y: 100), diameter: 200)
    #expect(abs(hs.saturation) < 1e-9)
}

@Test func colorWheelRightEdgeIsHueZeroAtFullSaturation() {
    // A point one radius to the right of center: angle 0 → hue 0, edge → sat 1.
    let hs = ColorWheelGeometry.huesat(at: CGPoint(x: 200, y: 100), diameter: 200)
    #expect(abs(hs.hue) < 1e-6)
    #expect(abs(hs.saturation - 1) < 1e-9)
}

@Test func colorWheelQuarterTurnDownIsHueOneQuarter() {
    // One radius straight down from center (y grows downward).
    let hs = ColorWheelGeometry.huesat(at: CGPoint(x: 100, y: 200), diameter: 200)
    #expect(abs(hs.hue - 0.25) < 1e-6)
    #expect(abs(hs.saturation - 1) < 1e-9)
}

@Test func colorWheelClampsSaturationOutsideCircle() {
    let hs = ColorWheelGeometry.huesat(at: CGPoint(x: 320, y: 100), diameter: 200)
    #expect(hs.saturation == 1)
}

@Test func colorWheelPointRoundTripsThroughHuesat() {
    let diameter: CGFloat = 240
    for hueStep in 0..<10 {
        let hue = Double(hueStep) / 10.0
        for sat in [0.25, 0.5, 0.75, 1.0] {
            let p = ColorWheelGeometry.point(hue: hue, saturation: sat, diameter: diameter)
            let hs = ColorWheelGeometry.huesat(at: p, diameter: diameter)
            #expect(abs(hs.saturation - sat) < 1e-9)
            let dh = abs(hs.hue - hue)
            #expect(min(dh, 1 - dh) < 1e-9)  // hue is circular
        }
    }
}

@Test func colorWheelKnobForZeroSaturationSitsAtCenter() {
    let p = ColorWheelGeometry.point(hue: 0.3, saturation: 0, diameter: 200)
    #expect(abs(p.x - 100) < 1e-9)
    #expect(abs(p.y - 100) < 1e-9)
}
