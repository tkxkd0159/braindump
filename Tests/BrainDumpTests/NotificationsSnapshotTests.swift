import AppKit
import Foundation
import SwiftData
import SwiftUI
import Testing

@testable import BrainDumpKit

/// Offscreen renders of the notification UI: the backlog-digest settings
/// section and the per-block reminder pickers. PNGs land in
/// `/tmp/braindump-shots/` for visual inspection.
@MainActor
struct NotificationsSnapshotTests {
    @Test
    func captureNotificationsSettingsEnabled() throws {
        Fonts.registerIfNeeded()
        let context = try InMemoryStore.makeContext()
        let state = AppState(
            context: context,
            now: { TestDate.at(2026, 6, 12) },
            wiseSaying: WiseSaying(quote: "x", author: "y"),
            defaults: UserDefaults(suiteName: "BrainDumpNotif.\(UUID().uuidString)")!
        )
        state.backlogDigestEnabled = true
        state.backlogDigestThresholdDays = 7
        let view = SettingsSheet(state: state, initialSection: .notifications, dismiss: {})
        renderViaHostingWindow(
            view, size: NSSize(width: 820, height: 540),
            filename: "notifications-settings-enabled.png")
    }

    /// A large threshold exercises the typeable field — it must display
    /// multi-digit numbers cleanly and stay aligned with the "Notify at" field.
    @Test
    func captureNotificationsSettingsLargeThreshold() throws {
        Fonts.registerIfNeeded()
        let context = try InMemoryStore.makeContext()
        let state = AppState(
            context: context,
            now: { TestDate.at(2026, 6, 12) },
            wiseSaying: WiseSaying(quote: "x", author: "y"),
            defaults: UserDefaults(suiteName: "BrainDumpNotif.\(UUID().uuidString)")!
        )
        state.backlogDigestEnabled = true
        state.backlogDigestThresholdDays = 120
        let view = SettingsSheet(state: state, initialSection: .notifications, dismiss: {})
        renderViaHostingWindow(
            view, size: NSSize(width: 820, height: 540),
            filename: "notifications-settings-large-threshold.png")
    }

    /// An out-of-range threshold flags the field red (with an inline message)
    /// and dims/disables Save — instead of silently clamping to the maximum.
    @Test
    func captureNotificationsSettingsInvalidThreshold() throws {
        Fonts.registerIfNeeded()
        let context = try InMemoryStore.makeContext()
        let state = AppState(
            context: context,
            now: { TestDate.at(2026, 6, 12) },
            wiseSaying: WiseSaying(quote: "x", author: "y"),
            defaults: UserDefaults(suiteName: "BrainDumpNotif.\(UUID().uuidString)")!
        )
        state.backlogDigestEnabled = true
        // Out of range — the field seeds its text from this, so it starts invalid.
        state.backlogDigestThresholdDays = 9999
        let view = SettingsSheet(state: state, initialSection: .notifications, dismiss: {})
        renderViaHostingWindow(
            view, size: NSSize(width: 820, height: 540),
            filename: "notifications-settings-invalid-threshold.png")
    }

    @Test
    func captureTimeBlockSheetWithReminder() throws {
        Fonts.registerIfNeeded()
        let view = TimeBlockSheet(
            initialStartMinute: 9 * 60,
            initialDurationMinutes: 60,
            initialReminderOffset: 15,
            onConfirm: { _, _, _, _ in },
            onCancel: {}
        )
        renderViaHostingWindow(
            view, size: NSSize(width: 460, height: 380),
            filename: "notifications-timeblock-reminder.png")
    }

    @Test
    func captureTaskDetailWithReminder() throws {
        Fonts.registerIfNeeded()
        let context = try InMemoryStore.makeContext()
        let day = DayService(context: context).day(for: TestDate.at(2026, 6, 12))
        let item = TaskService(context: context).addBrainDumpItem(
            title: "Finalize Manuscript", notes: "Sections 3 & 4.", tags: ["writing"], on: day)
        let entry = try ScheduleService(context: context).schedule(
            item, on: day, startMinute: 9 * 60, durationMinutes: 60, reminderOffsetMinutes: 15)
        let focus = TaskDetailFocus(item: item, entry: entry, startInEditMode: true)
        let view = TaskDetailSheet(focus: focus, dismiss: {})
            .environment(\.modelContext, context)
        renderViaHostingWindow(
            view, size: NSSize(width: 480, height: 620),
            filename: "notifications-taskdetail-reminder.png")
    }

    /// The focus (navy) and invalid (crimson) highlight rings a digest field
    /// shows. Focus can't be engaged in an offscreen render, so this renders the
    /// highlight states directly to verify their appearance.
    @Test
    func captureDigestFieldHighlightStates() throws {
        Fonts.registerIfNeeded()
        let view = VStack(alignment: .leading, spacing: 20) {
            highlightSample("Focused", isFocused: true, isInvalid: false)
            highlightSample("Invalid", isFocused: false, isInvalid: true)
            highlightSample("Idle", isFocused: false, isInvalid: false)
        }
        .padding(28)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Theme.Palette.surfaceContainerLowest)
        renderViaHostingWindow(
            view, size: NSSize(width: 320, height: 260),
            filename: "notifications-digest-field-highlight.png")
    }

    private func highlightSample(_ title: String, isFocused: Bool, isInvalid: Bool) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).font(Theme.Font.labelMd).foregroundStyle(Theme.Palette.onSurface)
            DigestFieldBox(isFocused: isFocused, isInvalid: isInvalid) {
                Text("9:00 AM")
                    .foregroundStyle(Theme.Palette.onSurface)
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }
            .frame(width: 90)
        }
    }

    /// The time field highlights on click because its `NSDatePicker` reports
    /// first-responder changes — SwiftUI's `@FocusState` doesn't fire for
    /// `DatePicker` on macOS, so this AppKit hook is what drives the highlight.
    @Test
    func timeFieldReportsFocusChanges() {
        var events: [Bool] = []
        let picker = FocusReportingDatePicker()
        picker.datePickerStyle = .textField
        picker.datePickerElements = .hourMinute
        picker.focusChanged = { events.append($0) }
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 120, height: 40),
            styleMask: [.titled], backing: .buffered, defer: false)
        window.contentView?.addSubview(picker)
        window.makeKeyAndOrderFront(nil)

        #expect(window.makeFirstResponder(picker))
        #expect(events.contains(true))
        _ = window.makeFirstResponder(nil)
        #expect(events.last == false)
    }

    // MARK: - Harness (mirrors Stage5/Stage6 snapshot tests)

    private func renderViaHostingWindow<V: View>(_ view: V, size: NSSize, filename: String) {
        let hosting = NSHostingView(rootView: view.frame(width: size.width, height: size.height))
        hosting.frame = NSRect(origin: .zero, size: size)
        let window = NSWindow(
            contentRect: NSRect(origin: .zero, size: size),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        window.contentView = hosting
        window.layoutIfNeeded()
        hosting.layoutSubtreeIfNeeded()
        RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.06))
        guard let rep = hosting.bitmapImageRepForCachingDisplay(in: hosting.bounds) else {
            Issue.record("bitmapImageRepForCachingDisplay returned nil for \(filename)")
            return
        }
        hosting.cacheDisplay(in: hosting.bounds, to: rep)
        guard let data = rep.representation(using: .png, properties: [:]) else {
            Issue.record("PNG encoding failed for \(filename)")
            return
        }
        let outDir = URL(fileURLWithPath: "/tmp/braindump-shots")
        try? FileManager.default.createDirectory(at: outDir, withIntermediateDirectories: true)
        do {
            try data.write(to: outDir.appendingPathComponent(filename))
        } catch {
            Issue.record("write failed: \(error)")
        }
    }
}
