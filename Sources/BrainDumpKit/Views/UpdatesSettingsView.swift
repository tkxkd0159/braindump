import SwiftUI

/// The "Software Update" settings pane: an automatic-check toggle, a manual
/// "Check Now" button, the current version, and the last-checked time. Binds to
/// an `AppUpdateModel`; when no updater is wired (`isUpdaterAvailable == false`)
/// it shows a muted "unavailable in this build" message instead of controls.
struct UpdatesSettingsView: View {
    @Bindable var model: AppUpdateModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                header
                if model.isUpdaterAvailable {
                    controls
                } else {
                    unavailable
                }
            }
            .padding(.horizontal, 28)
            .padding(.vertical, 24)
            .frame(maxWidth: .infinity, alignment: .topLeading)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("SOFTWARE UPDATE")
                .font(Theme.Font.sectionLabelHeavy)
                .tracking(1.4)
                .foregroundStyle(Theme.Palette.onSurface)
            Text("Brain Dump checks for new releases in the background and lets you install them in one click.")
                .font(Theme.Font.bodyMd)
                .foregroundStyle(Theme.Palette.onSurfaceVariant)
        }
    }

    private var controls: some View {
        VStack(alignment: .leading, spacing: 20) {
            Toggle(isOn: $model.automaticallyChecksForUpdates) {
                Text("Automatically check for updates")
                    .font(Theme.Font.bodyMd)
                    .foregroundStyle(Theme.Palette.onSurface)
            }
            .toggleStyle(.switch)
            .tint(Theme.Palette.primary)

            Button(action: { model.checkNow() }) {
                Text("Check Now")
                    .font(Theme.Font.labelMd)
                    .padding(.horizontal, 18)
                    .frame(height: 34)
                    .foregroundStyle(Theme.Palette.onPrimary)
                    .background(Theme.Palette.primary)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(!model.canCheckForUpdates)
            .opacity(model.canCheckForUpdates ? 1 : 0.5)

            VStack(alignment: .leading, spacing: 4) {
                Text("Current version: \(model.shortVersion) (\(model.buildVersion))")
                    .font(Theme.Font.caption)
                    .foregroundStyle(Theme.Palette.onSurfaceVariant)
                Text("Last checked: \(lastCheckedText)")
                    .font(Theme.Font.caption)
                    .foregroundStyle(Theme.Palette.onSurfaceVariant)
            }
        }
    }

    private var unavailable: some View {
        Text("Updates are unavailable in this build.")
            .font(Theme.Font.bodyMd)
            .foregroundStyle(Theme.Palette.onSurfaceVariant)
    }

    private let lastCheckedFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .short
        return f
    }()

    private var lastCheckedText: String {
        guard let date = model.lastUpdateCheckDate else { return "Never" }
        return lastCheckedFormatter.string(from: date)
    }
}
