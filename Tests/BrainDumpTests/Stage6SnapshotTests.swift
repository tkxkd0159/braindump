import Foundation
import SwiftUI
import SwiftData
import Testing
import AppKit
@testable import BrainDumpKit

/// In-process snapshots covering the read-only task modal, the
/// Reminders-style tag input, and the calendar-icon removal from the
/// date header.
@MainActor
struct Stage6SnapshotTests {
    @Test
    func captureReadOnlyTaskModal() throws {
        Fonts.registerIfNeeded()
        let (context, _, entry) = try seedScheduledTask()
        let focus = TaskDetailFocus(
            item: entry.item!,
            entry: entry,
            startInEditMode: false
        )
        let view = TaskDetailSheet(focus: focus, dismiss: {})
            .environment(\.modelContext, context)
        renderViaHostingWindow(view, size: NSSize(width: 540, height: 460), filename: "stage6-task-readonly.png")
    }

    @Test
    func captureEditModeAfterTogglingFromReadOnly() throws {
        Fonts.registerIfNeeded()
        let (context, _, entry) = try seedScheduledTask()
        let focus = TaskDetailFocus(
            item: entry.item!,
            entry: entry,
            startInEditMode: true
        )
        let view = TaskDetailSheet(focus: focus, dismiss: {})
            .environment(\.modelContext, context)
        renderViaHostingWindow(view, size: NSSize(width: 540, height: 760), filename: "stage6-task-edit.png")
    }

    @Test
    func captureCreateModeWithToggleOff() throws {
        Fonts.registerIfNeeded()
        let (context, day, _) = try seedScheduledTask()
        let view = TaskDetailSheet(focus: .create(day: day), dismiss: {})
            .environment(\.modelContext, context)
        renderViaHostingWindow(view, size: NSSize(width: 540, height: 540), filename: "feature23-create-toggle-off.png")
    }

    @Test
    func captureEditWithoutEntryToggleVisible() throws {
        Fonts.registerIfNeeded()
        let (context, day, _) = try seedScheduledTask()
        // Pick a brain-dump-only item (no entry yet).
        let extra = TaskService(context: context).addBrainDumpItem(title: "Draft cover letter", on: day)
        let view = TaskDetailSheet(
            focus: .edit(item: extra, entry: nil, startInEditMode: true),
            dismiss: {}
        )
        .environment(\.modelContext, context)
        renderViaHostingWindow(view, size: NSSize(width: 540, height: 560), filename: "feature23-edit-no-entry-toggle.png")
    }

    @Test
    func captureTagInputWithSuggestions() throws {
        Fonts.registerIfNeeded()
        let view = TagInputFieldHarness()
        renderViaHostingWindow(view, size: NSSize(width: 480, height: 280), filename: "stage6-tag-input.png")
    }

    // MARK: - Helpers

    private func seedScheduledTask() throws -> (ModelContext, Day, ScheduleEntry) {
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
        let entry = try scheduleService.schedule(
            manuscript,
            on: day,
            startMinute: 9 * 60 + 15,
            durationMinutes: 75,
            colorIndex: 1
        )
        // Seed extra distinct tags so the edit modal's suggestion row has content.
        let scratch = taskService.addBrainDumpItem(title: "Outline references", on: day)
        taskService.updateTags(scratch, tags: ["research", "review"])
        return (context, day, entry)
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

/// Wraps `TagInputField` with seeded state so the snapshot exercises the
/// known-tags suggestion row and an in-progress tag chip.
private struct TagInputFieldHarness: View {
    @State private var tags: [String] = ["writing"]
    @State private var draft: String = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Tags")
                .font(Theme.Font.tinyLabel)
                .tracking(1.2)
                .foregroundStyle(Theme.Palette.onSurfaceVariant)
            TagInputField(
                tags: $tags,
                draft: $draft,
                allKnownTags: ["deep-work", "research", "review", "writing"]
            )
        }
        .padding(24)
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .background(Theme.Palette.surfaceContainerLowest)
    }
}
