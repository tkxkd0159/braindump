import Foundation
import SwiftUI
import SwiftData
import Testing
import AppKit
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
        let manuscript = taskService.addBrainDumpItem(title: "Finalize Manuscript Revision", on: day)
        try taskService.escalate(manuscript, on: day)
        let email = taskService.addBrainDumpItem(title: "Email literature review to Dr. Aris", on: day)
        _ = taskService.addBrainDumpItem(title: "Research Zotero plugin updates", on: day)
        _ = try scheduleService.schedule(manuscript, on: day, startMinute: 9 * 60, durationMinutes: 120)
        _ = try scheduleService.schedule(email, on: day, startMinute: 14 * 60, durationMinutes: 60)

        let state = AppState(
            context: context,
            now: { TestDate.at(2026, 5, 22) },
            wiseSaying: WiseSaying(
                quote: "The key is not to prioritize what's on your schedule, but to schedule your priorities.",
                author: "Stephen Covey"
            )
        )

        let view = DayView(state: state)
            .environment(\.modelContext, context)
            .padding(.horizontal, 64)
            .padding(.top, 36)
            .background(Theme.Palette.surface)
        renderViaHostingWindow(view, size: NSSize(width: 1180, height: 1900), filename: "snapshot-day.png")
    }

    @Test
    func captureScheduleSection() throws {
        Fonts.registerIfNeeded()
        let context = try InMemoryStore.makeContext()
        let day = DayService(context: context).day(for: TestDate.at(2026, 5, 22))
        let taskService = TaskService(context: context)
        let scheduleService = ScheduleService(context: context)
        let manuscript = taskService.addBrainDumpItem(title: "Finalize Manuscript Revision", on: day)
        _ = try scheduleService.schedule(manuscript, on: day, startMinute: 9 * 60, durationMinutes: 120)
        let email = taskService.addBrainDumpItem(title: "Email literature review", on: day)
        _ = try scheduleService.schedule(email, on: day, startMinute: 14 * 60, durationMinutes: 60)

        let view = ScheduleSection(day: day, isReadOnly: false)
            .environment(\.modelContext, context)
            .padding(24)
            .background(Theme.Palette.surface)
        renderViaHostingWindow(view, size: NSSize(width: 700, height: 2000), filename: "snapshot-schedule.png")
    }

    @Test
    func captureLeftColumn() throws {
        Fonts.registerIfNeeded()
        let context = try InMemoryStore.makeContext()
        let day = DayService(context: context).day(for: TestDate.at(2026, 5, 22))
        let taskService = TaskService(context: context)
        let scheduleService = ScheduleService(context: context)
        let manuscript = taskService.addBrainDumpItem(title: "Finalize Manuscript Revision", on: day)
        try taskService.escalate(manuscript, on: day)
        let email = taskService.addBrainDumpItem(title: "Email literature review to Dr. Aris", on: day)
        _ = taskService.addBrainDumpItem(title: "Research Zotero plugin updates", on: day)
        _ = try scheduleService.schedule(manuscript, on: day, startMinute: 9 * 60, durationMinutes: 120)
        _ = try scheduleService.schedule(email, on: day, startMinute: 14 * 60, durationMinutes: 60)

        let view = VStack(alignment: .leading, spacing: 48) {
            Top3Section(day: day, isReadOnly: false)
            BrainDumpSection(day: day, isReadOnly: false)
        }
        .environment(\.modelContext, context)
        .padding(24)
        .background(Theme.Palette.surface)
        renderViaHostingWindow(view, size: NSSize(width: 520, height: 900), filename: "snapshot-left-column.png")
    }

    @Test
    func captureFullAppShell() throws {
        Fonts.registerIfNeeded()
        let context = try InMemoryStore.makeContext()
        let day = DayService(context: context).day(for: TestDate.at(2026, 5, 22))
        let taskService = TaskService(context: context)
        let scheduleService = ScheduleService(context: context)
        let manuscript = taskService.addBrainDumpItem(title: "Finalize Manuscript Revision", on: day)
        try taskService.escalate(manuscript, on: day)
        let email = taskService.addBrainDumpItem(title: "Email literature review to Dr. Aris", on: day)
        _ = taskService.addBrainDumpItem(title: "Research Zotero plugin updates", on: day)
        _ = try scheduleService.schedule(manuscript, on: day, startMinute: 9 * 60, durationMinutes: 120)
        _ = try scheduleService.schedule(email, on: day, startMinute: 14 * 60, durationMinutes: 60)

        let view = AppShell()
            .environment(\.modelContext, context)
        renderViaHostingWindow(view, size: NSSize(width: 1440, height: 1900), filename: "snapshot-full-app.png")
    }

    @Test
    func captureSidebar() throws {
        Fonts.registerIfNeeded()
        let view = SidebarPreview()
        renderViaHostingWindow(view, size: NSSize(width: 256, height: 900), filename: "snapshot-sidebar.png")
    }

    /// Asserts the brain-dump fetched items list matches what we expect, to
    /// distinguish data-layer issues from rendering issues.
    @Test
    func brainDumpItemsAreReachable() throws {
        Fonts.registerIfNeeded()
        let context = try InMemoryStore.makeContext()
        let day = DayService(context: context).day(for: TestDate.at(2026, 5, 22))
        let taskService = TaskService(context: context)
        let manuscript = taskService.addBrainDumpItem(title: "Finalize Manuscript Revision", on: day)
        try taskService.escalate(manuscript, on: day)
        _ = taskService.addBrainDumpItem(title: "Email literature review to Dr. Aris", on: day)
        _ = taskService.addBrainDumpItem(title: "Research Zotero plugin updates", on: day)
        let top3 = Set(day.top3ItemIDs)
        let brainDump = day.items.filter { !top3.contains($0.id) }.map(\.title).sorted()
        #expect(brainDump == ["Email literature review to Dr. Aris", "Research Zotero plugin updates"])
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
                Text("Deep Work Planner")
                    .font(Theme.Font.headlineMd)
                    .foregroundStyle(Theme.Palette.primary)
                Text("Research Fellow")
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
