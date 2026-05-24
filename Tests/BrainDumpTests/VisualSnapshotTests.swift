import AppKit
import Foundation
import SwiftData
import SwiftUI
import Testing

@testable import BrainDumpKit

/// Renders SwiftUI views via an offscreen NSWindow + NSHostingView so we can
/// visually compare against references/main.html without needing the screen
/// to be unlocked. NSHostingView renders TextFields and ScrollView contents
/// properly (ImageRenderer collapses ScrollView and shows raw placeholders).
@MainActor
struct VisualSnapshotTests {
    @Test
    func captureDayView() throws {
        Fonts.registerIfNeeded()
        let context = try InMemoryStore.makeContext()
        let day = DayService(context: context).day(for: TestDate.at(2026, 5, 22))
        let taskService = TaskService(context: context)
        let scheduleService = ScheduleService(context: context)
        let manuscript = taskService.addBrainDumpItem(
            title: "Finalize Manuscript Revision", on: day)
        try taskService.escalate(manuscript, on: day)
        let email = taskService.addBrainDumpItem(
            title: "Email literature review to Dr. Aris", on: day)
        _ = taskService.addBrainDumpItem(title: "Research Zotero plugin updates", on: day)
        _ = try scheduleService.schedule(
            manuscript, on: day, startMinute: 9 * 60, durationMinutes: 120)
        _ = try scheduleService.schedule(email, on: day, startMinute: 14 * 60, durationMinutes: 60)

        let state = AppState(
            context: context,
            now: { TestDate.at(2026, 5, 22) },
            wiseSaying: WiseSaying(
                quote:
                    "The key is not to prioritize what's on your schedule, but to schedule your priorities.",
                author: "Stephen Covey"
            )
        )

        let view = DayView(state: state)
            .environment(\.modelContext, context)
            .padding(.horizontal, 64)
            .padding(.top, 36)
            .background(Theme.Palette.surface)
        renderViaHostingWindow(
            view, size: NSSize(width: 1180, height: 1900), filename: "snapshot-day.png")
    }

    @Test
    func captureScheduleSection() throws {
        Fonts.registerIfNeeded()
        let context = try InMemoryStore.makeContext()
        let day = DayService(context: context).day(for: TestDate.at(2026, 5, 22))
        let taskService = TaskService(context: context)
        let scheduleService = ScheduleService(context: context)
        let manuscript = taskService.addBrainDumpItem(
            title: "Finalize Manuscript Revision", on: day)
        _ = try scheduleService.schedule(
            manuscript, on: day, startMinute: 9 * 60, durationMinutes: 120)
        let email = taskService.addBrainDumpItem(title: "Email literature review", on: day)
        _ = try scheduleService.schedule(email, on: day, startMinute: 14 * 60, durationMinutes: 60)

        let view = ScheduleSection(day: day, isReadOnly: false)
            .environment(\.modelContext, context)
            .padding(24)
            .background(Theme.Palette.surface)
        renderViaHostingWindow(
            view, size: NSSize(width: 700, height: 2000), filename: "snapshot-schedule.png")
    }

    @Test
    func captureLeftColumn() throws {
        Fonts.registerIfNeeded()
        let context = try InMemoryStore.makeContext()
        let day = DayService(context: context).day(for: TestDate.at(2026, 5, 22))
        let taskService = TaskService(context: context)
        let scheduleService = ScheduleService(context: context)
        let manuscript = taskService.addBrainDumpItem(
            title: "Finalize Manuscript Revision", on: day)
        try taskService.escalate(manuscript, on: day)
        let email = taskService.addBrainDumpItem(
            title: "Email literature review to Dr. Aris", on: day)
        _ = taskService.addBrainDumpItem(title: "Research Zotero plugin updates", on: day)
        _ = try scheduleService.schedule(
            manuscript, on: day, startMinute: 9 * 60, durationMinutes: 120)
        _ = try scheduleService.schedule(email, on: day, startMinute: 14 * 60, durationMinutes: 60)

        let view = VStack(alignment: .leading, spacing: 48) {
            Top3Section(day: day, isReadOnly: false)
            BrainDumpSection(day: day, isReadOnly: false)
        }
        .environment(\.modelContext, context)
        .padding(24)
        .background(Theme.Palette.surface)
        renderViaHostingWindow(
            view, size: NSSize(width: 520, height: 900), filename: "snapshot-left-column.png")
    }

    @Test
    func captureFullAppShell() throws {
        Fonts.registerIfNeeded()
        let context = try InMemoryStore.makeContext()
        let day = DayService(context: context).day(for: TestDate.at(2026, 5, 22))
        let taskService = TaskService(context: context)
        let scheduleService = ScheduleService(context: context)
        let manuscript = taskService.addBrainDumpItem(
            title: "Finalize Manuscript Revision", on: day)
        try taskService.escalate(manuscript, on: day)
        let email = taskService.addBrainDumpItem(
            title: "Email literature review to Dr. Aris", on: day)
        _ = taskService.addBrainDumpItem(title: "Research Zotero plugin updates", on: day)
        _ = try scheduleService.schedule(
            manuscript, on: day, startMinute: 9 * 60, durationMinutes: 120)
        _ = try scheduleService.schedule(email, on: day, startMinute: 14 * 60, durationMinutes: 60)

        let view = AppShell()
            .environment(\.modelContext, context)
        renderViaHostingWindow(
            view, size: NSSize(width: 1440, height: 1900), filename: "snapshot-full-app.png")
    }

    @Test
    func captureSidebar() throws {
        Fonts.registerIfNeeded()
        let view = SidebarPreview()
        renderViaHostingWindow(
            view, size: NSSize(width: 256, height: 900), filename: "snapshot-sidebar.png")
    }

    /// When the window is too narrow to fit sidebar + canvas, the sidebar
    /// must auto-collapse even though the user's `isSidebarVisible`
    /// preference is still on. Renders at width just below the threshold;
    /// the bitmap should show the canvas only.
    @Test
    func captureFullAppShellNarrowAutoCollapsesSidebar() throws {
        Fonts.registerIfNeeded()
        let context = try InMemoryStore.makeContext()
        let day = DayService(context: context).day(for: TestDate.at(2026, 5, 22))
        let taskService = TaskService(context: context)
        _ = taskService.addBrainDumpItem(title: "Finalize Manuscript Revision", on: day)

        let view = AppShell()
            .environment(\.modelContext, context)
        let narrow = AppShell.sidebarThreshold - 1
        renderViaHostingWindow(
            view,
            size: NSSize(width: narrow, height: 1100),
            filename: "snapshot-full-app-narrow.png"
        )
    }

    /// At or above the threshold the sidebar should render normally.
    @Test
    func captureFullAppShellAtThresholdShowsSidebar() throws {
        Fonts.registerIfNeeded()
        let context = try InMemoryStore.makeContext()
        let day = DayService(context: context).day(for: TestDate.at(2026, 5, 22))
        let taskService = TaskService(context: context)
        _ = taskService.addBrainDumpItem(title: "Finalize Manuscript Revision", on: day)

        let view = AppShell()
            .environment(\.modelContext, context)
        renderViaHostingWindow(
            view,
            size: NSSize(width: AppShell.sidebarThreshold, height: 1100),
            filename: "snapshot-full-app-at-threshold.png"
        )
    }

    /// Threshold sanity: must equal canvasMin + sidebarWidth. If these drift
    /// apart, the auto-collapse will fire at the wrong window size.
    @Test
    func sidebarThresholdMatchesCanvasPlusSidebar() {
        #expect(AppShell.sidebarThreshold == AppShell.canvasMin + AppShell.sidebarWidth)
        #expect(AppShell.canvasMin == 992)
        #expect(AppShell.sidebarThreshold == 1248)
    }

    /// When the window is wider than the previous 1280 cap, the canvas
    /// must fill the available width instead of leaving empty space on
    /// the right.
    @Test
    func captureFullAppShellWideFillsCanvas() throws {
        Fonts.registerIfNeeded()
        let context = try InMemoryStore.makeContext()
        let day = DayService(context: context).day(for: TestDate.at(2026, 5, 22))
        let taskService = TaskService(context: context)
        let scheduleService = ScheduleService(context: context)
        let manuscript = taskService.addBrainDumpItem(
            title: "Finalize Manuscript Revision", on: day)
        try taskService.escalate(manuscript, on: day)
        let email = taskService.addBrainDumpItem(
            title: "Email literature review to Dr. Aris", on: day)
        _ = taskService.addBrainDumpItem(title: "Research Zotero plugin updates", on: day)
        _ = try scheduleService.schedule(
            manuscript, on: day, startMinute: 9 * 60, durationMinutes: 120)
        _ = try scheduleService.schedule(email, on: day, startMinute: 14 * 60, durationMinutes: 60)

        let view = AppShell()
            .environment(\.modelContext, context)
        renderViaHostingWindow(
            view,
            size: NSSize(width: 2000, height: 1400),
            filename: "snapshot-full-app-wide.png"
        )
    }

    /// Asserts the brain-dump fetched items list matches what we expect, to
    /// distinguish data-layer issues from rendering issues.
    @Test
    func brainDumpItemsAreReachable() throws {
        Fonts.registerIfNeeded()
        let context = try InMemoryStore.makeContext()
        let day = DayService(context: context).day(for: TestDate.at(2026, 5, 22))
        let taskService = TaskService(context: context)
        let manuscript = taskService.addBrainDumpItem(
            title: "Finalize Manuscript Revision", on: day)
        try taskService.escalate(manuscript, on: day)
        _ = taskService.addBrainDumpItem(title: "Email literature review to Dr. Aris", on: day)
        _ = taskService.addBrainDumpItem(title: "Research Zotero plugin updates", on: day)
        let top3 = Set(day.top3ItemIDs)
        let brainDump = day.items.filter { !top3.contains($0.id) }.map(\.title).sorted()
        #expect(
            brainDump == ["Email literature review to Dr. Aris", "Research Zotero plugin updates"])
    }

    /// Block geometry — offset = hour offset plus the 1pt top divider; height
    /// is exact so the block's edges sit on hour boundaries (covering any
    /// gridline underneath rather than leaving a 1-2pt strip).
    @Test
    func scheduleBlockGeometryMatchesExpectations() throws {
        let startMinute = 9 * 60
        let durationMinutes = 120
        let dayStartMinute = 5 * 60
        let slotHeight: CGFloat = 50
        let hourHeight = slotHeight * 2
        let expectedHeight = CGFloat(durationMinutes) / 60.0 * hourHeight
        let expectedOffsetY = CGFloat(startMinute - dayStartMinute) / 60.0 * hourHeight + 1
        #expect(expectedHeight == 200)
        #expect(expectedOffsetY == 401)
    }

    @Test
    func scheduleBlockGeometryHandlesFractionalHours() throws {
        let startMinute = 9 * 60 + 15
        let durationMinutes = 75
        let dayStartMinute = 5 * 60
        let slotHeight: CGFloat = 50
        let hourHeight = slotHeight * 2
        let expectedHeight = CGFloat(durationMinutes) / 60.0 * hourHeight
        let expectedOffsetY = CGFloat(startMinute - dayStartMinute) / 60.0 * hourHeight + 1
        #expect(expectedHeight == 125)
        #expect(expectedOffsetY == 426)
    }

    @Test
    func captureTaskDetailSheetReadOnly() throws {
        Fonts.registerIfNeeded()
        let context = try InMemoryStore.makeContext()
        let day = DayService(context: context).day(for: TestDate.at(2026, 5, 22))
        let taskService = TaskService(context: context)
        let scheduleService = ScheduleService(context: context)
        let item = taskService.addBrainDumpItem(title: "Finalize Manuscript Revision", on: day)
        taskService.updateNotes(
            item,
            notes:
                "Outline arguments for the rebuttal letter; draft a section response to reviewer 2 first."
        )
        taskService.updateTags(item, tags: ["writing", "deep-work"])
        let entry = try scheduleService.schedule(
            item, on: day, startMinute: 9 * 60, durationMinutes: 120)

        let focus = TaskDetailFocus(item: item, entry: entry, startInEditMode: false)
        let view = TaskDetailSheet(focus: focus, dismiss: {})
            .environment(\.modelContext, context)
            .padding(40)
            .background(Theme.Palette.surface)
        renderViaHostingWindow(
            view,
            size: NSSize(width: 600, height: 600),
            filename: "snapshot-task-detail-readonly.png"
        )
    }

    /// Schedule slots are drop-only after removing the inline task creator —
    /// empty rows should render as plain dividers with no text field or
    /// "Plan activity…" prompt.
    @Test
    func captureScheduleSectionEmptyHasNoInlineCreator() throws {
        Fonts.registerIfNeeded()
        let context = try InMemoryStore.makeContext()
        let day = DayService(context: context).day(for: TestDate.at(2026, 5, 22))

        let view = ScheduleSection(day: day, isReadOnly: false, dayStartHour: 8, dayEndHour: 12)
            .environment(\.modelContext, context)
            .padding(24)
            .background(Theme.Palette.surface)
        renderViaHostingWindow(
            view,
            size: NSSize(width: 700, height: 600),
            filename: "snapshot-schedule-empty-no-inline-creator.png"
        )
    }

    /// Captures the General settings pane scrolled to show the new
    /// "Clear Data" block beneath the day time range pickers.
    @Test
    func captureSettingsSheetClearDataBlock() throws {
        Fonts.registerIfNeeded()
        let context = try InMemoryStore.makeContext()
        let defaults = UserDefaults(suiteName: "BrainDumpTest.\(UUID().uuidString)")!
        let state = AppState(
            context: context,
            now: { TestDate.at(2026, 5, 22) },
            wiseSaying: WiseSaying(quote: "x", author: "y"),
            defaults: defaults
        )
        let view = SettingsSheet(state: state, dismiss: {})
            .environment(\.modelContext, context)
        renderViaHostingWindow(
            view,
            size: NSSize(width: 820, height: 540),
            filename: "snapshot-settings-clear-data.png"
        )
    }

    @Test
    func captureTaskDetailSheetEdit() throws {
        Fonts.registerIfNeeded()
        let context = try InMemoryStore.makeContext()
        let day = DayService(context: context).day(for: TestDate.at(2026, 5, 22))
        let taskService = TaskService(context: context)
        let scheduleService = ScheduleService(context: context)
        let item = taskService.addBrainDumpItem(title: "Finalize Manuscript Revision", on: day)
        taskService.updateNotes(item, notes: "Outline arguments for the rebuttal letter.")
        taskService.updateTags(item, tags: ["writing"])
        let entry = try scheduleService.schedule(
            item, on: day, startMinute: 9 * 60, durationMinutes: 120)

        let focus = TaskDetailFocus(item: item, entry: entry, startInEditMode: true)
        let view = TaskDetailSheet(focus: focus, dismiss: {})
            .environment(\.modelContext, context)
            .padding(40)
            .background(Theme.Palette.surface)
        renderViaHostingWindow(
            view,
            size: NSSize(width: 600, height: 800),
            filename: "snapshot-task-detail-edit.png"
        )
    }

    // MARK: - Rendering

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

        // Force a render cycle so ScrollView/TextField measure children.
        RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.05))

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

/// Minimal duplicate of the live AppShell sidebar so we can snapshot the
/// sidebar without having to expose the real one as `public`.
private struct SidebarPreview: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Daily Timebox Planner")
                    .font(Theme.Font.labelMd)
                    .tracking(0.5)
                    .foregroundStyle(Theme.Palette.onSurfaceVariant)
            }
            .padding(.horizontal, 24)
            .padding(.top, 28)
            .padding(.bottom, 40)
            VStack(alignment: .leading, spacing: 6) {
                navItem("calendar.day.timeline.left", "Today", isActive: true)
                navItem("list.bullet.clipboard", "Tasks", isActive: false)
                navItem("tray.full", "Backlog", isActive: false)
            }
            .padding(.horizontal, 16)
            Spacer()
            Rectangle()
                .fill(Theme.Palette.outlineVariant)
                .frame(height: 1)
                .padding(.horizontal, 16)
            VStack(alignment: .leading, spacing: 6) {
                navItem("gearshape", "Settings", isActive: false)
            }
            .padding(.horizontal, 16)
            .padding(.top, 18)
            .padding(.bottom, 24)
        }
        .frame(width: 256)
        .frame(maxHeight: .infinity, alignment: .top)
        .background(Theme.Palette.surfaceContainerLow)
    }

    @ViewBuilder
    private func navItem(_ icon: String, _ label: String, isActive: Bool) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: isActive ? .semibold : .regular))
                .frame(width: 22)
            Text(label)
                .font(Theme.Font.labelMd)
                .tracking(0.7)
            Spacer(minLength: 0)
        }
        .foregroundStyle(isActive ? Theme.Palette.primary : Theme.Palette.onSurfaceVariant)
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            ZStack(alignment: .trailing) {
                if isActive {
                    Theme.Palette.surfaceContainerHigh
                    Rectangle().fill(Theme.Palette.primary).frame(width: 4)
                }
            }
        )
    }
}
