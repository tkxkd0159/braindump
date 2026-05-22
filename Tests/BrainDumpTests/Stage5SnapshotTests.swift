import Foundation
import SwiftUI
import SwiftData
import Testing
import AppKit
@testable import BrainDumpKit

/// In-process rendering of the Stage 5 changes (sidebar toggle, inline task
/// contents, settings sheet, minute-precision schedule). These complement the
/// live-app screenshot verification — useful when the live window can't be
/// captured (multi-display setups where the window lands off the recordable
/// region).
@MainActor
struct Stage5SnapshotTests {
    @Test
    func captureSidebarVisible() throws {
        Fonts.registerIfNeeded()
        let (context, day) = try seed()
        let state = AppState(
            context: context,
            now: { TestDate.at(2026, 5, 22) },
            wiseSaying: WiseSaying(quote: "Discipline equals freedom.", author: "Jocko Willink"),
            defaults: ephemeralDefaults()
        )
        let view = compositeShell(state: state, day: day, context: context)
        renderViaHostingWindow(view, size: NSSize(width: 1280, height: 1100), filename: "stage5-sidebar-visible.png")
    }

    @Test
    func captureSidebarHidden() throws {
        Fonts.registerIfNeeded()
        let (context, day) = try seed()
        let state = AppState(
            context: context,
            now: { TestDate.at(2026, 5, 22) },
            wiseSaying: WiseSaying(quote: "Discipline equals freedom.", author: "Jocko Willink"),
            defaults: ephemeralDefaults()
        )
        state.isSidebarVisible = false
        let view = compositeShell(state: state, day: day, context: context)
        renderViaHostingWindow(view, size: NSSize(width: 1024, height: 1100), filename: "stage5-sidebar-hidden.png")
    }

    @Test
    func captureExpandedTaskCard() throws {
        Fonts.registerIfNeeded()
        let (context, day) = try seed()
        let view = BrainDumpSection(day: day, isReadOnly: false, openDetail: nil)
            .environment(\.modelContext, context)
            .padding(24)
            .frame(width: 520, height: 700)
            .background(Theme.Palette.surface)
        renderViaHostingWindow(view, size: NSSize(width: 520, height: 700), filename: "stage5-brain-dump.png")
    }

    @Test
    func captureTimeBlockSheet() throws {
        Fonts.registerIfNeeded()
        let view = TimeBlockSheet(
            initialStartMinute: 9 * 60 + 15,
            initialDurationMinutes: 75,
            initialColorIndex: 1,
            onConfirm: { _, _, _ in },
            onCancel: {}
        )
        renderViaHostingWindow(view, size: NSSize(width: 420, height: 360), filename: "stage5-time-block-sheet.png")
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
        renderViaHostingWindow(view, size: NSSize(width: 440, height: 320), filename: "stage5-settings-sheet.png")
    }

    @Test
    func captureCustomDayBoundsSchedule() throws {
        Fonts.registerIfNeeded()
        let (context, day) = try seed(includeFractionalEntry: true)
        let view = ScheduleSection(day: day, isReadOnly: false, dayStartHour: 8, dayEndHour: 18)
            .environment(\.modelContext, context)
            .padding(24)
            .background(Theme.Palette.surface)
        renderViaHostingWindow(view, size: NSSize(width: 700, height: 1200), filename: "stage5-schedule-custom-bounds.png")
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
            _ = try scheduleService.schedule(manuscript, on: day, startMinute: 9 * 60 + 15, durationMinutes: 75)
            _ = try scheduleService.schedule(email, on: day, startMinute: 14 * 60, durationMinutes: 60)
        } else {
            _ = try scheduleService.schedule(manuscript, on: day, startMinute: 9 * 60, durationMinutes: 120)
            _ = try scheduleService.schedule(email, on: day, startMinute: 14 * 60, durationMinutes: 60)
        }
        return (context, day)
    }

    private func ephemeralDefaults() -> UserDefaults {
        UserDefaults(suiteName: "BrainDumpStage5.\(UUID().uuidString)")!
    }

    /// Composite that approximates AppShell layout without requiring its
    /// private implementation; renders both visible and hidden sidebar
    /// states by toggling `state.isSidebarVisible`.
    private func compositeShell(state: AppState, day: Day, context: ModelContext) -> some View {
        HStack(spacing: 0) {
            if state.isSidebarVisible {
                MiniSidebar()
            }
            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    Image(systemName: "sidebar.left")
                        .font(.system(size: 16))
                        .foregroundStyle(Theme.Palette.onSurfaceVariant)
                        .frame(width: 32, height: 32)
                    Spacer()
                }
                .padding(.horizontal, 24)
                .padding(.top, 12)
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        Text("Friday, May 22, 2026")
                            .font(Theme.Font.headlineLg)
                            .foregroundStyle(Theme.Palette.primary)
                            .padding(.horizontal, 64)
                            .padding(.bottom, 24)
                        HStack(alignment: .top, spacing: 24) {
                            VStack(alignment: .leading, spacing: 32) {
                                Top3Section(day: day, isReadOnly: false)
                                BrainDumpSection(day: day, isReadOnly: false)
                            }
                            .frame(width: 360, alignment: .top)
                            ScheduleSection(
                                day: day,
                                isReadOnly: false,
                                dayStartHour: state.dayStartHour,
                                dayEndHour: state.dayEndHour
                            )
                            .frame(maxWidth: .infinity, alignment: .top)
                        }
                        .padding(.horizontal, 64)
                    }
                }
            }
            .background(Theme.Palette.surface)
        }
        .environment(\.modelContext, context)
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

private struct MiniSidebar: View {
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
                nav("calendar.day.timeline.left", "Today", active: true)
                nav("list.bullet.clipboard", "Tasks", active: false)
                nav("tray.full", "Backlog", active: false)
            }
            .padding(.horizontal, 16)
            Spacer()
            Rectangle().fill(Theme.Palette.outlineVariant).frame(height: 1).padding(.horizontal, 16)
            HStack(spacing: 12) {
                Image(systemName: "gearshape").font(.system(size: 16)).frame(width: 22)
                Text("Settings").font(Theme.Font.labelMd).tracking(0.7)
                Spacer()
            }
            .foregroundStyle(Theme.Palette.onSurfaceVariant)
            .padding(.horizontal, 32)
            .padding(.vertical, 18)
            .padding(.bottom, 12)
        }
        .frame(width: 256)
        .frame(maxHeight: .infinity, alignment: .top)
        .background(Theme.Palette.surfaceContainerLow)
        .overlay(alignment: .trailing) {
            Rectangle().fill(Theme.Palette.outlineVariant).frame(width: 1)
        }
    }

    private func nav(_ icon: String, _ label: String, active: Bool) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon).font(.system(size: 16, weight: active ? .semibold : .regular)).frame(width: 22)
            Text(label).font(Theme.Font.labelMd).tracking(0.7)
            Spacer()
        }
        .foregroundStyle(active ? Theme.Palette.primary : Theme.Palette.onSurfaceVariant)
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(active ? Theme.Palette.surfaceContainerHigh : Color.clear)
    }
}
