import SwiftUI

/// A self-contained HSB color wheel: a vivid hue/saturation disc plus a
/// brightness bar, driving a `Color` binding live. Deliberately avoids
/// SwiftUI's native `ColorPicker`, which on macOS opens the shared
/// `NSColorPanel` — a floating window that never auto-closes and offers no
/// "save" gesture.
///
/// The disc always shows full-brightness hues so hue/saturation stay easy to
/// pick; brightness is a separate gradient bar (black → the vivid hue) and
/// applies to the resulting color (and the knob fills), matching how standard
/// HSB pickers behave.
struct ColorWheelPicker: View {
    @Binding var color: Color

    // HSB is held decomposed so the brightness bar and the hue/saturation knob
    // move independently (dimming must not relocate the knob, and a knob at the
    // white center must not reset a chosen brightness).
    @State private var hue: Double
    @State private var saturation: Double
    @State private var brightness: Double

    private let diameter: CGFloat = 200
    private let knobSize: CGFloat = 22

    init(color: Binding<Color>) {
        self._color = color
        let hsb = color.wrappedValue.hsb
        _hue = State(initialValue: hsb.hue)
        _saturation = State(initialValue: hsb.saturation)
        _brightness = State(initialValue: hsb.brightness)
    }

    /// Hue spectrum at full saturation/brightness; first == last so the angular
    /// sweep wraps seamlessly back to red.
    private static let hueRing: [Color] =
        stride(from: 0.0, through: 1.0, by: 1.0 / 12.0).map {
            Color(hue: $0, saturation: 1, brightness: 1)
        }

    private var currentColor: Color {
        Color(hue: hue, saturation: saturation, brightness: brightness)
    }

    var body: some View {
        VStack(spacing: 16) {
            wheel
            brightnessBar
        }
    }

    private var wheel: some View {
        ZStack {
            Circle()
                .fill(AngularGradient(gradient: Gradient(colors: Self.hueRing), center: .center))
            Circle()
                .fill(RadialGradient(
                    gradient: Gradient(colors: [.white, .white.opacity(0)]),
                    center: .center, startRadius: 0, endRadius: diameter / 2))
            Circle()
                .strokeBorder(Theme.Palette.outlineVariant, lineWidth: 0.5)
            knob
        }
        .frame(width: diameter, height: diameter)
        .clipShape(Circle())
        .contentShape(Circle())
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { value in select(at: value.location) }
        )
    }

    private var knob: some View {
        let center = ColorWheelGeometry.point(hue: hue, saturation: saturation, diameter: diameter)
        return Circle()
            .fill(currentColor)
            .frame(width: knobSize, height: knobSize)
            .overlay(Circle().strokeBorder(.white, lineWidth: 2))
            .overlay(Circle().strokeBorder(.black.opacity(0.25), lineWidth: 0.5))
            .shadow(color: .black.opacity(0.25), radius: 1.5, y: 0.5)
            .position(x: center.x, y: center.y)
            .allowsHitTesting(false)
    }

    private var brightnessBar: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Brightness")
                .font(Theme.Font.tinyLabel)
                .tracking(1.2)
                .foregroundStyle(Theme.Palette.onSurfaceVariant)
            GeometryReader { geo in
                let width = geo.size.width
                let travel = max(1, width - knobSize)
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(LinearGradient(
                            colors: [.black, Color(hue: hue, saturation: saturation, brightness: 1)],
                            startPoint: .leading, endPoint: .trailing))
                        .frame(height: 10)
                        .overlay(Capsule().strokeBorder(Theme.Palette.outlineVariant, lineWidth: 0.5))
                    Circle()
                        .fill(currentColor)
                        .frame(width: knobSize, height: knobSize)
                        .overlay(Circle().strokeBorder(.white, lineWidth: 2))
                        .overlay(Circle().strokeBorder(.black.opacity(0.25), lineWidth: 0.5))
                        .shadow(color: .black.opacity(0.25), radius: 1.5, y: 0.5)
                        .offset(x: CGFloat(brightness) * travel)
                }
                .frame(height: knobSize)
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 0).onChanged { value in
                        let x = min(max(0, value.location.x - knobSize / 2), travel)
                        brightness = Double(x / travel)
                        pushColor()
                    }
                )
            }
            .frame(height: knobSize)
        }
    }

    private func select(at point: CGPoint) {
        let hs = ColorWheelGeometry.huesat(at: point, diameter: diameter)
        hue = hs.hue
        saturation = hs.saturation
        pushColor()
    }

    private func pushColor() {
        color = currentColor
    }
}
