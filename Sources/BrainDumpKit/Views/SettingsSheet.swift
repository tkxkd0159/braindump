import AppKit
import SwiftUI
import UniformTypeIdentifiers

public struct SettingsSheet: View {
    @Bindable var state: AppState
    @Bindable var updateModel: AppUpdateModel
    let dismiss: () -> Void

    @State private var section: SettingsSection
    @State private var startHour: Int
    @State private var endHour: Int
    @State private var error: String?
    @State private var showClearConfirmation: Bool = false
    @State private var showImportConfirmation: Bool = false
    @State private var backupError: String?
    /// Raw text of the backlog-digest threshold field. Kept separate from the
    /// persisted `Int` so the user can type freely (including a momentarily
    /// out-of-range or empty value) — it's validated before persisting, and the
    /// field is flagged red / Save is blocked while it's invalid.
    @State private var thresholdText: String
    /// Focus of the threshold text field (`@FocusState` is reliable for text
    /// fields) and of the time picker (driven by the AppKit wrapper, since
    /// `@FocusState` doesn't fire for `DatePicker` on macOS). Each highlights its
    /// field box on click.
    @FocusState private var dayFieldFocused: Bool
    @State private var timeFieldFocused: Bool = false

    /// Shared width for the two digest fields so they're the same size.
    private let digestFieldWidth: CGFloat = 80

    public init(
        state: AppState,
        updateModel: AppUpdateModel = AppUpdateModel(),
        initialSection: SettingsSection = .general,
        dismiss: @escaping () -> Void
    ) {
        self.state = state
        self.updateModel = updateModel
        self.dismiss = dismiss
        _section = State(initialValue: initialSection)
        _startHour = State(initialValue: state.dayStartHour)
        _endHour = State(initialValue: state.dayEndHour)
        _thresholdText = State(initialValue: String(state.backlogDigestThresholdDays))
    }

    public var body: some View {
        HStack(spacing: 0) {
            navigationPane
            contentPane
        }
        .frame(width: 820, height: 540)
        .background(Theme.Palette.surfaceContainerLowest)
    }

    // MARK: - Navigation pane

    private var navigationPane: some View {
        VStack(alignment: .leading, spacing: 0) {
            navHeader
            VStack(alignment: .leading, spacing: 2) {
                navItem(.general, icon: "gearshape.fill", label: "General")
                navItem(.calendar, icon: "calendar", label: "Calendars")
                navItem(.notifications, icon: "bell.fill", label: "Notifications")
                navItem(.updates, icon: "arrow.down.circle.fill", label: "Software Update")
            }
            .padding(.horizontal, 10)
            Spacer(minLength: 0)
        }
        .frame(width: 232)
        .frame(maxHeight: .infinity, alignment: .top)
        .background(Theme.Palette.surfaceContainerLow)
        .overlay(alignment: .trailing) {
            Rectangle().fill(Theme.Palette.outlineVariant).frame(width: 1)
        }
    }

    private var navHeader: some View {
        HStack(alignment: .top, spacing: 12) {
            ZStack {
                Rectangle().fill(Theme.Palette.primary)
                Image(systemName: "brain.head.profile")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(Theme.Palette.onPrimary)
            }
            .frame(width: 36, height: 36)
            VStack(alignment: .leading, spacing: 2) {
                Text("Settings")
                    .font(Theme.Font.headlineSmall)
                    .foregroundStyle(Theme.Palette.primary)
                Text("Manage your workspace")
                    .font(Theme.Font.caption)
                    .foregroundStyle(Theme.Palette.onSurfaceVariant)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 16)
        .padding(.top, 18)
        .padding(.bottom, 22)
    }

    private func navItem(_ destination: SettingsSection, icon: String, label: String) -> some View {
        let isActive = section == destination
        return Button(action: { section = destination }) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 14, weight: isActive ? .semibold : .regular))
                    .frame(width: 20)
                Text(label)
                    .font(Theme.Font.labelMd)
                Spacer(minLength: 0)
            }
            .foregroundStyle(isActive ? Theme.Palette.primary : Theme.Palette.onSurfaceVariant)
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(
                ZStack(alignment: .leading) {
                    if isActive {
                        Theme.Palette.surfaceContainerHigh
                        Rectangle()
                            .fill(Theme.Palette.primary)
                            .frame(width: 3)
                    }
                }
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: - Content pane

    private var contentPane: some View {
        VStack(spacing: 0) {
            contentHeader
            Rectangle().fill(Theme.Palette.outlineVariant).frame(height: 1)
            contentBody
            Rectangle().fill(Theme.Palette.outlineVariant).frame(height: 1)
            footer
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var contentHeader: some View {
        HStack(spacing: 0) {
            Text(sectionTitle)
                .font(Theme.Font.headlineMd)
                .foregroundStyle(Theme.Palette.onSurface)
            Spacer()
            Button(action: dismiss) {
                Image(systemName: "xmark")
                    .font(.system(size: 13, weight: .regular))
                    .foregroundStyle(Theme.Palette.onSurfaceVariant)
                    .frame(width: 28, height: 28)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .keyboardShortcut(.cancelAction)
        }
        .padding(.horizontal, 28)
        .padding(.vertical, 18)
    }

    private var sectionTitle: String {
        switch section {
        case .general: return "General Settings"
        case .calendar: return "Calendar Subscriptions"
        case .notifications: return "Notifications"
        case .updates: return "Software Update"
        }
    }

    @ViewBuilder
    private var contentBody: some View {
        switch section {
        case .general:
            generalSection
        case .calendar:
            CalendarSettingsView(state: state)
        case .notifications:
            notificationsSection
        case .updates:
            updatesSection
        }
    }

    private var generalSection: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 32) {
                VStack(alignment: .leading, spacing: 24) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("DAY TIME RANGE")
                            .font(Theme.Font.sectionLabelHeavy)
                            .tracking(1.4)
                            .foregroundStyle(Theme.Palette.onSurface)
                        Text("Set the default start and end times for your schedule grid.")
                            .font(Theme.Font.bodyMd)
                            .foregroundStyle(Theme.Palette.onSurfaceVariant)
                    }
                    HStack(alignment: .top, spacing: 20) {
                        hourPicker(label: "Day starts at", selection: $startHour, range: 0...20)
                        hourPicker(label: "Day ends at", selection: $endHour, range: 4...24)
                    }
                    if let error {
                        Text(error)
                            .font(Theme.Font.caption)
                            .foregroundStyle(Theme.Palette.secondary)
                    }
                }
                Rectangle()
                    .fill(Theme.Palette.outlineVariant)
                    .frame(height: 1)
                backupBlock
                Rectangle()
                    .fill(Theme.Palette.outlineVariant)
                    .frame(height: 1)
                clearDataBlock
            }
            .padding(.horizontal, 28)
            .padding(.vertical, 24)
            .frame(maxWidth: .infinity, alignment: .topLeading)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .alert("Clear all data?", isPresented: $showClearConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Clear Data", role: .destructive) {
                state.clearAllData()
                dismiss()
            }
        } message: {
            Text(
                "This permanently deletes every task, schedule entry, and backlog item across all days. This cannot be undone."
            )
        }
        .alert("Import backup?", isPresented: $showImportConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Import", role: .destructive) { importBackup() }
        } message: {
            Text(
                "Importing replaces every task, schedule entry, and backlog item with the backup's contents. This cannot be undone."
            )
        }
    }

    private var backupBlock: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("BACKUP")
                .font(Theme.Font.sectionLabelHeavy)
                .tracking(1.4)
                .foregroundStyle(Theme.Palette.onSurface)
            Text("Export all your data to a JSON file, or restore from a previous backup.")
                .font(Theme.Font.bodyMd)
                .foregroundStyle(Theme.Palette.onSurfaceVariant)
            HStack(spacing: 10) {
                Button(action: exportBackup) {
                    Text("Export Backup…")
                        .font(Theme.Font.labelMd)
                        .padding(.horizontal, 18)
                        .frame(height: 34)
                        .foregroundStyle(Theme.Palette.onPrimary)
                        .background(Theme.Palette.primary)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                Button(action: { showImportConfirmation = true }) {
                    Text("Import Backup…")
                        .font(Theme.Font.labelMd)
                        .padding(.horizontal, 18)
                        .frame(height: 34)
                        .foregroundStyle(Theme.Palette.primary)
                        .overlay(Rectangle().strokeBorder(Theme.Palette.primary, lineWidth: 1))
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
            if let backupError {
                Text(backupError)
                    .font(Theme.Font.caption)
                    .foregroundStyle(Theme.Palette.secondary)
            }
        }
    }

    private var clearDataBlock: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("CLEAR DATA")
                .font(Theme.Font.sectionLabelHeavy)
                .tracking(1.4)
                .foregroundStyle(Theme.Palette.onSurface)
            Text(
                "Remove all tasks, schedule entries, and backlog items. Settings such as day time range are preserved."
            )
            .font(Theme.Font.bodyMd)
            .foregroundStyle(Theme.Palette.onSurfaceVariant)
            Button(action: { showClearConfirmation = true }) {
                Text("Clear Data")
                    .font(Theme.Font.labelMd)
                    .padding(.horizontal, 18)
                    .frame(height: 34)
                    .foregroundStyle(Theme.Palette.onPrimary)
                    .background(Theme.Palette.secondary)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
    }

    private var notificationsSection: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("BACKLOG REMINDERS")
                        .font(Theme.Font.sectionLabelHeavy)
                        .tracking(1.4)
                        .foregroundStyle(Theme.Palette.onSurface)
                    Text(
                        "Once a day, get a notification counting how many backlog tasks are older than your threshold."
                    )
                    .font(Theme.Font.bodyMd)
                    .foregroundStyle(Theme.Palette.onSurfaceVariant)
                }

                Toggle(isOn: $state.backlogDigestEnabled) {
                    Text("Enable daily backlog reminder")
                        .font(Theme.Font.bodyMd)
                        .foregroundStyle(Theme.Palette.onSurface)
                }
                .toggleStyle(.switch)

                if state.backlogDigestEnabled {
                    HStack(alignment: .top, spacing: 32) {
                        digestField(label: "Older than") {
                            HStack(spacing: 8) {
                                DigestFieldBox(
                                    isFocused: dayFieldFocused, isInvalid: !isThresholdValid
                                ) {
                                    TextField("", text: $thresholdText)
                                        .textFieldStyle(.plain)
                                        .multilineTextAlignment(.trailing)
                                        .focused($dayFieldFocused)
                                        .focusEffectDisabled()
                                }
                                .frame(width: digestFieldWidth)
                                .help(isThresholdValid ? "" : thresholdErrorMessage)
                                Text("days")
                                    .foregroundStyle(Theme.Palette.onSurfaceVariant)
                            }
                        }
                        digestField(label: "Notify at") {
                            DigestFieldBox(isFocused: timeFieldFocused, isInvalid: false) {
                                DigestTimeField(
                                    date: digestTimeBinding,
                                    onFocusChange: { timeFieldFocused = $0 }
                                )
                            }
                            .frame(width: digestFieldWidth)
                        }
                    }

                    if !isThresholdValid {
                        Text(thresholdErrorMessage)
                            .font(Theme.Font.caption)
                            .foregroundStyle(Theme.Palette.secondary)
                    }

                    if state.notificationsDenied {
                        Text(
                            "Notifications are turned off for Brain Dump. Turn them on in System Settings \u{203A} Notifications to receive reminders."
                        )
                        .font(Theme.Font.caption)
                        .foregroundStyle(Theme.Palette.secondary)
                    }
                }
            }
            .padding(.horizontal, 28)
            .padding(.vertical, 24)
            .frame(maxWidth: .infinity, alignment: .topLeading)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    /// The typed threshold parsed into a valid day count, or nil when the field
    /// holds something out of range / non-numeric.
    private var parsedThreshold: Int? {
        AppState.parseBacklogDigestThreshold(thresholdText)
    }

    private var isThresholdValid: Bool { parsedThreshold != nil }

    /// Save is blocked while the (visible) threshold field is invalid, so the
    /// sheet can't be committed with an out-of-range value.
    private var thresholdBlocksSave: Bool {
        state.backlogDigestEnabled && !isThresholdValid
    }

    private var thresholdErrorMessage: String {
        let range = AppState.backlogDigestThresholdRange
        return "Enter a whole number from \(range.lowerBound) to \(range.upperBound)."
    }

    /// One labeled control in the backlog-digest row. Both "Older than" and
    /// "Notify at" go through this so they share an identical label font,
    /// label→control spacing, and a fixed control-row height — keeping the two
    /// fields the same size and vertically aligned as a matched pair.
    @ViewBuilder
    private func digestField<Control: View>(
        label: String, @ViewBuilder control: () -> Control
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(label)
                .font(Theme.Font.labelMd)
                .foregroundStyle(Theme.Palette.onSurface)
            control()
                .frame(height: 24, alignment: .leading)
        }
    }

    /// Bridges the stored hour/minute to the `DatePicker`'s `Date` API.
    private var digestTimeBinding: Binding<Date> {
        Binding(
            get: {
                Calendar.current.date(
                    bySettingHour: state.backlogDigestHour,
                    minute: state.backlogDigestMinute, second: 0, of: Date()) ?? Date()
            },
            set: { newValue in
                let c = Calendar.current.dateComponents([.hour, .minute], from: newValue)
                state.backlogDigestHour = c.hour ?? 9
                state.backlogDigestMinute = c.minute ?? 0
            })
    }

    private var updatesSection: some View {
        UpdatesSettingsView(model: updateModel)
    }

    private func hourPicker(label: String, selection: Binding<Int>, range: ClosedRange<Int>)
        -> some View
    {
        VStack(alignment: .leading, spacing: 8) {
            Text(label)
                .font(Theme.Font.labelMd)
                .foregroundStyle(Theme.Palette.onSurface)
            Picker("", selection: selection) {
                ForEach(Array(range), id: \.self) { hour in
                    Text(displayHour(hour)).tag(hour)
                }
            }
            .labelsHidden()
            .pickerStyle(.menu)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func displayHour(_ hour: Int) -> String {
        if hour == 24 { return "12:00 AM (next)" }
        let h = hour % 12 == 0 ? 12 : hour % 12
        let suffix = hour < 12 ? "AM" : "PM"
        return String(format: "%02d:00 %@", h, suffix)
    }

    private var footer: some View {
        HStack(spacing: 10) {
            Spacer()
            Button("Cancel", action: dismiss)
                .buttonStyle(SecondaryActionStyle())
            Button("Save", action: save)
                .buttonStyle(PrimaryActionStyle())
                .disabled(thresholdBlocksSave)
                .keyboardShortcut(.defaultAction)
        }
        .padding(.horizontal, 28)
        .padding(.vertical, 16)
        .background(Theme.Palette.surfaceContainerLow)
    }

    private func exportBackup() {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.json]
        panel.nameFieldStringValue = "BrainDump-backup.json"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            try state.exportBackupData().write(to: url)
            backupError = nil
        } catch {
            backupError = "Export failed."
        }
    }

    private func importBackup() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.json]
        panel.allowsMultipleSelection = false
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            try state.importBackup(from: Data(contentsOf: url))
            backupError = nil
            dismiss()
        } catch {
            backupError = "Import failed: the file isn't a valid BrainDump backup."
        }
    }

    private func save() {
        // The threshold is committed only here (not live), so a momentarily
        // out-of-range value typed into the field is never persisted — Save is
        // disabled while it's invalid; this guard is defense-in-depth.
        guard !thresholdBlocksSave else { return }
        guard state.setDayBounds(startHour: startHour, endHour: endHour) else {
            error = "Day must span at least 4 hours"
            return
        }
        if let value = parsedThreshold {
            state.backlogDigestThresholdDays = value
        }
        dismiss()
    }
}

public enum SettingsSection {
    case general, calendar, notifications, updates
}

/// A backlog-digest input field's chrome: a thin bordered box that turns
/// Primary Navy when focused and Crimson when its value is invalid (invalid
/// wins). Both digest fields wrap their control in one of these, so they're the
/// same size with identical styling — and the date picker highlights on click
/// just like the text field. Its own view so the focused/invalid appearance can
/// be snapshot-tested (focus can't be engaged in an offscreen render).
struct DigestFieldBox<Content: View>: View {
    var isFocused: Bool
    var isInvalid: Bool
    @ViewBuilder var content: Content

    var body: some View {
        content
            .padding(.horizontal, 8)
            .frame(maxWidth: .infinity, minHeight: 24, maxHeight: 24)
            .background(Theme.Palette.surfaceContainerLowest)
            .overlay(
                RoundedRectangle(cornerRadius: 5)
                    .strokeBorder(borderColor, lineWidth: isFocused || isInvalid ? 1.5 : 1)
            )
    }

    private var borderColor: Color {
        if isInvalid { return Theme.Palette.secondary }
        if isFocused { return Theme.Palette.primary }
        return Theme.Palette.outlineVariant
    }
}

/// Borderless hour/minute picker that reports first-responder (focus) changes,
/// so its surrounding `DigestFieldBox` can highlight on click. SwiftUI's
/// `DatePicker` doesn't drive `@FocusState` on macOS, hence the AppKit wrapper;
/// borderless so the box (not the control) draws the field's border.
struct DigestTimeField: NSViewRepresentable {
    @Binding var date: Date
    var onFocusChange: (Bool) -> Void

    func makeNSView(context: Context) -> FocusReportingDatePicker {
        let picker = FocusReportingDatePicker()
        picker.datePickerStyle = .textField
        picker.datePickerElements = .hourMinute
        picker.isBordered = false
        picker.drawsBackground = false
        picker.target = context.coordinator
        picker.action = #selector(Coordinator.dateChanged(_:))
        picker.dateValue = date
        picker.focusChanged = onFocusChange
        return picker
    }

    func updateNSView(_ nsView: FocusReportingDatePicker, context: Context) {
        context.coordinator.parent = self
        nsView.focusChanged = onFocusChange
        let cal = Calendar.current
        if cal.component(.hour, from: nsView.dateValue) != cal.component(.hour, from: date)
            || cal.component(.minute, from: nsView.dateValue) != cal.component(.minute, from: date)
        {
            nsView.dateValue = date
        }
    }

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    final class Coordinator: NSObject {
        var parent: DigestTimeField
        init(_ parent: DigestTimeField) { self.parent = parent }
        @MainActor @objc func dateChanged(_ sender: NSDatePicker) {
            parent.date = sender.dateValue
        }
    }
}

/// `NSDatePicker` that reports gaining/losing first-responder status, so SwiftUI
/// can show a focus highlight on click.
final class FocusReportingDatePicker: NSDatePicker {
    var focusChanged: ((Bool) -> Void)?

    override func becomeFirstResponder() -> Bool {
        let didBecome = super.becomeFirstResponder()
        if didBecome { focusChanged?(true) }
        return didBecome
    }

    override func resignFirstResponder() -> Bool {
        let didResign = super.resignFirstResponder()
        if didResign { focusChanged?(false) }
        return didResign
    }
}
