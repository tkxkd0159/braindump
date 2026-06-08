import Foundation
import Observation

/// Sparkle-free observable surface the update UI binds to.
///
/// The app target's `SparkleUpdaterController` constructs one with
/// `isUpdaterAvailable: true` and wires `onCheckNow` / `onSetAutomatic` to
/// Sparkle. Tests and previews use the default (unavailable) instance, so
/// `BrainDumpKit` never depends on Sparkle and `swift test` keeps building.
@MainActor
@Observable
public final class AppUpdateModel {
    /// True only when a real Sparkle updater is wired (false in tests, previews,
    /// and `swift test`, where Sparkle is absent).
    public let isUpdaterAvailable: Bool

    /// Whether a user-initiated "Check Now" is currently allowed.
    public let canCheckForUpdates: Bool

    /// Last time Sparkle completed an update check, if known.
    public let lastUpdateCheckDate: Date?

    /// Marketing version (`CFBundleShortVersionString`), for display.
    public let shortVersion: String

    /// Build number (`CFBundleVersion`), for display.
    public let buildVersion: String

    /// Two-way: the Settings toggle writes this; the setter forwards the new
    /// value to Sparkle via `onSetAutomatic`. (`didSet` does not fire for the
    /// initializer's assignment, so construction never calls the hook.)
    public var automaticallyChecksForUpdates: Bool {
        didSet { onSetAutomatic?(automaticallyChecksForUpdates) }
    }

    /// Wired by the controller to Sparkle's user-initiated check.
    public var onCheckNow: (@MainActor () -> Void)?

    /// Wired by the controller to Sparkle's `automaticallyChecksForUpdates`.
    public var onSetAutomatic: (@MainActor (Bool) -> Void)?

    public init(
        isUpdaterAvailable: Bool = false,
        canCheckForUpdates: Bool = false,
        automaticallyChecksForUpdates: Bool = true,
        lastUpdateCheckDate: Date? = nil,
        shortVersion: String = "—",
        buildVersion: String = "—"
    ) {
        self.isUpdaterAvailable = isUpdaterAvailable
        self.canCheckForUpdates = canCheckForUpdates
        self.automaticallyChecksForUpdates = automaticallyChecksForUpdates
        self.lastUpdateCheckDate = lastUpdateCheckDate
        self.shortVersion = shortVersion
        self.buildVersion = buildVersion
    }

    /// User-initiated check (menu / Settings button).
    public func checkNow() { onCheckNow?() }
}
