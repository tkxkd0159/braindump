import AppKit
import Testing

@testable import BrainDumpKit

// `WindowSizing.configure` is the AppKit safeguard that keeps the main window
// behaving like a normal macOS window: the zoom button and the "double-click
// the title bar" gesture can expand it to fill the screen and snap it back. The
// bug it backstops was `.windowResizability(.contentSize)` pinning the window's
// *maximum* content size to the view's intrinsic size, so zoom barely grew the
// window. These tests pin that contract without needing a live WindowServer.

@MainActor
@Test("configure unclamps the max content size so the window can fill the screen")
func configureUnclampsMaxContentSize() {
    // Reproduce `.windowResizability(.contentSize)`: a resizable window whose
    // maximum content size is pinned just above its intrinsic size. This is the
    // state that stopped zoom / title-bar double-click from filling the screen.
    let window = NSWindow(
        contentRect: NSRect(x: 0, y: 0, width: 1100, height: 760),
        styleMask: [.titled, .closable, .miniaturizable, .resizable],
        backing: .buffered,
        defer: false
    )
    window.contentMaxSize = NSSize(width: 1200, height: 820)

    // Precondition: clamped — the window cannot grow toward a large screen.
    #expect(window.contentMaxSize.width < 2000)
    #expect(window.contentMaxSize.height < 2000)

    WindowSizing.configure(window)

    // After the safeguard the ceiling is effectively unbounded, so the window
    // can zoom to fill any screen.
    #expect(window.contentMaxSize.width >= 100_000)
    #expect(window.contentMaxSize.height >= 100_000)
    #expect(window.styleMask.contains(.resizable))
    #expect(window.isZoomable)
    #expect(window.standardWindowButton(.zoomButton)?.isEnabled == true)
}

@MainActor
@Test("configure makes a fixed (non-resizable) window zoomable")
func configureMakesFixedWindowZoomable() {
    // A window with no `.resizable` bit can't be zoomed at all — there's no
    // zoom button to click and no title-bar double-click target.
    let window = NSWindow(
        contentRect: NSRect(x: 0, y: 0, width: 1100, height: 760),
        styleMask: [.titled, .closable, .miniaturizable],
        backing: .buffered,
        defer: false
    )
    #expect(!window.isZoomable)

    WindowSizing.configure(window)

    #expect(window.styleMask.contains(.resizable))
    #expect(window.isZoomable)
    #expect(window.standardWindowButton(.zoomButton)?.isEnabled == true)
}

// The title-bar double-click → zoom handler (`.hiddenTitleBar` swallows the
// native one). These pin the hit-test decision that drives `window.zoom(nil)`.
// `distanceFromTop` is window points down from the top edge; `xPosition` is from
// the left. The title-bar band is the top 44pt; controls sit left of x=120.

@Test("double-click in the title-bar band, clear of the controls, triggers zoom")
func zoomClickInTitleBarBand() {
    #expect(WindowSizing.isTitleBarZoomClick(distanceFromTop: 12, xPosition: 600, clickCount: 2))
    // far-right of the band still zooms (empty chrome above the canvas)
    #expect(WindowSizing.isTitleBarZoomClick(distanceFromTop: 4, xPosition: 1200, clickCount: 2))
    // right at the band's lower edge (50pt)
    #expect(WindowSizing.isTitleBarZoomClick(distanceFromTop: 50, xPosition: 600, clickCount: 2))
    // just past the band does not zoom
    #expect(!WindowSizing.isTitleBarZoomClick(distanceFromTop: 56, xPosition: 600, clickCount: 2))
}

@Test("a single click never zooms")
func singleClickDoesNotZoom() {
    #expect(!WindowSizing.isTitleBarZoomClick(distanceFromTop: 12, xPosition: 600, clickCount: 1))
}

@Test("double-click below the title-bar band (in content) does not zoom")
func doubleClickInContentDoesNotZoom() {
    // ~150pt down — over the date header / first rows, not the chrome
    #expect(!WindowSizing.isTitleBarZoomClick(distanceFromTop: 150, xPosition: 600, clickCount: 2))
}

// The window must never be narrower than the sidebar needs, or the sidebar
// auto-collapses into a dead zone where its toggle (and the navigation +
// Settings it holds) can't bring it back. This pins `minWidth` to the layout's
// `sidebarThreshold` even though the source can't reference it directly
// (`AppShell` is `@MainActor`).
@MainActor
@Test("the window minimum width always fits the sidebar")
func minimumWidthFitsSidebar() {
    #expect(WindowSizing.minWidth >= AppShell.sidebarThreshold)
}

@Test("double-click over the traffic-lights / sidebar toggle does not zoom")
func doubleClickOverControlsDoesNotZoom() {
    // traffic-lights region
    #expect(!WindowSizing.isTitleBarZoomClick(distanceFromTop: 12, xPosition: 40, clickCount: 2))
    // sidebar toggle region
    #expect(!WindowSizing.isTitleBarZoomClick(distanceFromTop: 12, xPosition: 92, clickCount: 2))
}
