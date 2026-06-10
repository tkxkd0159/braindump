import AppKit
import SwiftUI

/// Window sizing policy for the app's main window.
///
/// The app opens with `.windowStyle(.hiddenTitleBar)`. The behavioral fix for
/// "the window won't zoom to fill the screen" lives in the scene as
/// `.windowResizability(.contentMinSize)` — that keeps the minimum as a floor
/// but leaves the maximum unbounded (the old `.contentSize` pinned the maximum
/// to the view's intrinsic size, so the zoom button / title-bar double-click
/// barely grew the window).
///
/// ``configure(_:)`` is a small AppKit safeguard layered on top: SwiftUI's
/// `.windowResizability` semantics have shifted across macOS releases, so we
/// also assert the three things standard zoom relies on directly on the
/// `NSWindow` — it's resizable, its maximum content size is unbounded, and the
/// zoom button is enabled. It's idempotent, so it's safe on every layout pass.
public enum WindowSizing {
    /// Minimum window width. Must equal ``AppShell/sidebarThreshold`` (= canvasMin
    /// 992 + sidebarWidth 256) so the sidebar — and the navigation + Settings it
    /// holds — always fits and its toggle always works. (A narrower window used
    /// to land in a dead zone where the sidebar auto-collapsed and the toggle
    /// couldn't bring it back.) `AppShell` is `@MainActor`, so its threshold
    /// can't initialize this nonisolated constant directly; `WindowSizingTests`
    /// asserts they stay in sync.
    public static let minWidth: CGFloat = 1248
    /// Minimum content height for a usable Top 3 + Brain Dump + Schedule sheet.
    public static let minHeight: CGFloat = 760

    /// Height of the top "title bar" band that responds to a double-click-to-zoom.
    /// The real title bar is ≈32pt; this is a touch taller for an easy target,
    /// while staying clear of the date header / sidebar title (≈60pt below top).
    static let titleBarBandHeight: CGFloat = 50
    /// Double-clicks left of this x sit over the traffic-lights (end ≈x69) and the
    /// sidebar toggle (≈x76–108), so they must not trigger zoom.
    static let titleBarControlsInset: CGFloat = 120

    /// A maximum content size large enough to be effectively unbounded — the
    /// window can grow to fill any screen. AppKit's own default `contentMaxSize`
    /// uses `greatestFiniteMagnitude`, so this matches "no maximum".
    static let unboundedMax = NSSize(
        width: CGFloat.greatestFiniteMagnitude,
        height: CGFloat.greatestFiniteMagnitude
    )

    /// Guarantees the window can be zoomed to fill the screen and snapped back.
    ///
    /// Leaves the *minimum* size to SwiftUI (`.contentMinSize` + the content's
    /// `minWidth`/`minHeight`) so the two never fight over the floor.
    @MainActor
    public static func configure(_ window: NSWindow) {
        window.styleMask.insert(.resizable)
        // Unbound the maximum so zoom / title-bar double-click can fill the screen.
        window.contentMaxSize = unboundedMax
        // `.resizable` already enables the zoom button; make it explicit so the
        // green-button and title-bar double-click zoom always engage.
        window.standardWindowButton(.zoomButton)?.isEnabled = true
    }

    /// Whether a click should toggle the window's zoom (fill the visible screen /
    /// restore — distinct from the green button's native full-screen).
    ///
    /// `.windowStyle(.hiddenTitleBar)` lets SwiftUI's full-size content swallow
    /// the title bar's native double-click-to-zoom, so we detect it ourselves: a
    /// double-click in the top title-bar band, clear of the traffic-lights and the
    /// sidebar toggle. `distanceFromTop` and `xPosition` are in window points; the
    /// caller derives them from window base coordinates so the test is independent
    /// of whether the hosting content view is flipped.
    static func isTitleBarZoomClick(
        distanceFromTop: CGFloat, xPosition: CGFloat, clickCount: Int
    ) -> Bool {
        clickCount == 2
            && (0...titleBarBandHeight).contains(distanceFromTop)
            && xPosition >= titleBarControlsInset
    }
}

/// Invisible helper that grabs the hosting `NSWindow`, applies
/// ``WindowSizing/configure(_:)``, and installs a title-bar double-click → zoom
/// handler (which `.hiddenTitleBar` otherwise swallows). Add it via
/// `.background(_:)` inside a `WindowGroup`'s content so it resolves to the
/// app's main window.
public struct WindowConfigurator: NSViewRepresentable {
    public init() {}

    public func makeCoordinator() -> Coordinator { Coordinator() }

    public func makeNSView(context: Context) -> NSView {
        let view = NSView(frame: .zero)
        let coordinator = context.coordinator
        // The window isn't attached during `makeNSView`; defer one runloop turn.
        DispatchQueue.main.async { [weak view] in
            MainActor.assumeIsolated {
                guard let window = view?.window else { return }
                WindowSizing.configure(window)
                coordinator.installTitleBarZoom(on: window)
            }
        }
        return view
    }

    public func updateNSView(_ nsView: NSView, context: Context) {
        guard let window = nsView.window else { return }
        WindowSizing.configure(window)
        context.coordinator.installTitleBarZoom(on: window)
    }

    @MainActor
    public final class Coordinator {
        private weak var window: NSWindow?
        // Written once on the main actor, removed once at teardown — no race, so
        // `nonisolated(unsafe)` lets the (nonisolated) deinit clean it up.
        nonisolated(unsafe) private var monitor: Any?

        /// Installs a single app-local mouse-down monitor that toggles `zoom`
        /// when the title bar is double-clicked. Local monitors see the app's own
        /// events on the main thread before the responder chain, so they fire
        /// even though `.hiddenTitleBar` content would otherwise swallow them —
        /// and need no Accessibility permission.
        func installTitleBarZoom(on window: NSWindow) {
            self.window = window
            guard monitor == nil else { return }
            monitor = NSEvent.addLocalMonitorForEvents(matching: .leftMouseDown) {
                [weak self, weak window] event in
                // Nonisolated: compare references and read Sendable scalars only.
                guard event.window === window else { return event }
                let clickCount = event.clickCount
                let location = event.locationInWindow  // window base coords (y up)
                // Hop to the main actor (the monitor already runs there) for the
                // window/content APIs, passing only Sendable values across.
                let didZoom = MainActor.assumeIsolated { () -> Bool in
                    guard let window = self?.window, let content = window.contentView
                    else { return false }
                    let distanceFromTop = content.bounds.height - location.y
                    guard WindowSizing.isTitleBarZoomClick(
                        distanceFromTop: distanceFromTop, xPosition: location.x,
                        clickCount: clickCount
                    ) else { return false }
                    window.zoom(nil)
                    return true
                }
                return didZoom ? nil : event  // consume only when we zoomed
            }
        }

        deinit {
            if let monitor { NSEvent.removeMonitor(monitor) }
        }
    }
}
