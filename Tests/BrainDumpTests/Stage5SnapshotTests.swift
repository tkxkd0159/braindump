import AppKit
import Foundation
import SwiftData
import SwiftUI
import Testing

@testable import BrainDumpKit

/// In-process rendering of the Stage 5 changes (inline task contents,
/// settings sheet, minute-precision schedule). These complement the
/// live-app screenshot verification — useful when the live window can't be
/// captured (multi-display setups where the window lands off the recordable
/// region).
@MainActor
struct Stage5SnapshotTests {
    @Test
    func captureExpandedTaskCard() throws {
        Fonts.registerIfNeeded()
        let (context, day) = try seed()
        let view = BrainDumpSection(day: day, isReadOnly: false, openDetail: nil)
            .environment(\.modelContext, context)
            .padding(24)
            .frame(width: 520, height: 700)
            .background(Theme.Palette.surface)
        renderViaHostingWindow(
            view, size: NSSize(width: 520, height: 700), filename: "stage5-brain-dump.png")
    }

    @Test
    func captureTimeBlockSheet() throws {
        Fonts.registerIfNeeded()
        let view = TimeBlockSheet(
            initialStartMinute: 9 * 60 + 15,
            initialDurationMinutes: 75,
            initialColorIndex: 1,
            onConfirm: { _, _, _, _ in },
            onCancel: {}
        )
        renderViaHostingWindow(
            view, size: NSSize(width: 420, height: 360), filename: "stage5-time-block-sheet.png")
    }

    @Test
    func captureSettingsSheet() throws {
        Fonts.registerIfNeeded()
        let (context, _) = try seed()
        let state = AppState(
            context: context,
            now: { TestDate.at(2026, 5, 22) },
            wiseSaying: WiseSaying(quote: "x", author: "y"),
            defaults: ephemeralDefaults()
        )
        let view = SettingsSheet(state: state, dismiss: {})
        renderViaHostingWindow(
            view, size: NSSize(width: 820, height: 540), filename: "stage5-settings-sheet.png")
    }

    @Test
    func captureCustomDayBoundsSchedule() throws {
        Fonts.registerIfNeeded()
        let (context, day) = try seed(includeFractionalEntry: true)
        let view = ScheduleSection(day: day, isReadOnly: false, dayStartHour: 8, dayEndHour: 18)
            .environment(\.modelContext, context)
            .padding(24)
            .background(Theme.Palette.surface)
        renderViaHostingWindow(
            view, size: NSSize(width: 700, height: 1200),
            filename: "stage5-schedule-custom-bounds.png")
    }

    // MARK: - Helpers

    private func seed(includeFractionalEntry: Bool = false) throws -> (ModelContext, Day) {
        let context = try InMemoryStore.makeContext()
        let day = DayService(context: context).day(for: TestDate.at(2026, 5, 22))
        let taskService = TaskService(context: context)
        let scheduleService = ScheduleService(context: context)
        let manuscript = taskService.addBrainDumpItem(
            title: "Finalize Manuscript Revision",
            notes: "Pass over sections 3 & 4 carefully — references are stale.",
            tags: ["writing", "deep-work"],
            on: day
        )
        try taskService.escalate(manuscript, on: day)
        let email = taskService.addBrainDumpItem(
            title: "Email literature review to Dr. Aris",
            notes: "Attach the latest draft.",
            tags: ["correspondence"],
            on: day
        )
        _ = taskService.addBrainDumpItem(title: "Research Zotero plugin updates", on: day)
        if includeFractionalEntry {
            _ = try scheduleService.schedule(
                manuscript, on: day, startMinute: 9 * 60 + 15, durationMinutes: 75)
            _ = try scheduleService.schedule(
                email, on: day, startMinute: 14 * 60, durationMinutes: 60)
        } else {
            _ = try scheduleService.schedule(
                manuscript, on: day, startMinute: 9 * 60, durationMinutes: 120)
            _ = try scheduleService.schedule(
                email, on: day, startMinute: 14 * 60, durationMinutes: 60)
        }
        return (context, day)
    }

    private func ephemeralDefaults() -> UserDefaults {
        UserDefaults(suiteName: "BrainDumpStage5.\(UUID().uuidString)")!
    }

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