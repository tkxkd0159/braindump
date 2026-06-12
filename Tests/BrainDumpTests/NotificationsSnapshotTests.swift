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
