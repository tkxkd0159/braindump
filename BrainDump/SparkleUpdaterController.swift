import Foundation
import Sparkle
import BrainDumpKit

/// Owns Sparkle's updater and exposes a Sparkle-free `AppUpdateModel` for the UI.
///
/// Intentionally thin: this file is in the app target and is not reachable by
/// `swift test`, so all branchy/testable logic lives in `AppUpdateModel`.
@MainActor
final class SparkleUpdaterController {
    let model: AppUpdateModel
    private let controller: SPUStandardUpdaterController

    init() {
        // `startingUpdater: true` starts background scheduling immediately,
        // driven by the SU* keys in Info.plist (feed URL, public key, interval).
        controller = SPUStandardUpdaterController(
            startingUpdater: true,
            updaterDelegate: nil,
            userDriverDelegate: nil
        )
        let updater = controller.updater
        let info = Bundle.main.infoDictionary

        model = AppUpdateModel(
            isUpdaterAvailable: true,
            canCheckForUpdates: updater.canCheckForUpdates,
            automaticallyChecksForUpdates: updater.automaticallyChecksForUpdates,
            lastUpdateCheckDate: updater.lastUpdateCheckDate,
            shortVersion: info?["CFBundleShortVersionString"] as? String ?? "—",
            buildVersion: info?["CFBundleVersion"] as? String ?? "—"
        )

        model.onCheckNow = { [controller] in
            controller.checkForUpdates(nil)
        }
        model.onSetAutomatic = { [updater] newValue in
            updater.automaticallyChecksForUpdates = newValue
        }
    }
}
