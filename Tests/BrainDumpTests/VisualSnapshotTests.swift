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
    func captureScheduleSectionWithCalendarEvents() throws {
        Fonts.registerIfNeeded()
        let context = try InMemoryStore.makeContext()
        let day = DayService(context: context).day(for: TestDate.at(2026, 5, 22))
        let taskService = TaskService(context: context)
        let scheduleService = ScheduleService(context: context)
        let focus = taskService.addBrainDumpItem(title: "Deep work", on: day)
        _ = try scheduleService.schedule(focus, on: day, startMinute: 8 * 60, durationMinutes: 60)

        let feedID = UUID()
        let events = [
            CalendarEvent(id: "e1", feedID: feedID, title: "Standup",
                          start: TestDate.at(2026, 5, 22, hour: 9, minute: 30),
                          end: TestDate.at(2026, 5, 22, hour: 10), isAllDay: false, colorIndex: 1),
            CalendarEvent(id: "e2", feedID: feedID, title: "Design review",
                          start: TestDate.at(2026, 5, 22, hour: 13),
                          end: TestDate.at(2026, 5, 22, hour: 14, minute: 30), isAllDay: false, colorIndex: 6),
            CalendarEvent(id: "e3", feedID: feedID, title: "Company Holiday",
                          start: TestDate.at(2026, 5, 22), end: TestDate.at(2026, 5, 23),
                          isAllDay: true, colorIndex: 3),
        ]

        let view = ScheduleSection(day: day, isReadOnly: false, calendarEvents: events)
            .environment(\.modelContext, context)
            .padding(24)
            .background(Theme.Palette.surface)
        renderViaHostingWindow(
            view, size: NSSize(width: 700, height: 1400),
            filename: "snapshot-schedule-calendar.png")
    }

    @Test
    func captureCalendarSettings() throws {
        Fonts.registerIfNeeded()
        let context = try InMemoryStore.makeContext()
        let defaults = UserDefaults(suiteName: "snap.cal.\(UUID().uuidString)")!
        let store = CalendarFeedStore(defaults: defaults)
        store.save([
            CalendarFeed(name: "Work", urlString: "https://calendar.google.com/calendar/ical/work/basic.ics", colorIndex: 1),
            CalendarFeed(name: "Personal", urlString: "https://calendar.google.com/calendar/ical/me/basic.ics", colorIndex: 6, isEnabled: false),
        ])
        let calendar = CalendarService(
            store: store, fetcher: URLSessionICalFeedFetcher(),
            cache: CalendarCache(url: URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("snap-\(UUID().uuidString).json")),
            now: { TestDate.at(2026, 5, 22) })
        let state = AppState(context: context, now: { TestDate.at(2026, 5, 22) },
                             defaults: defaults, calendarService: calendar)

        let view = CalendarSettingsView(state: state)
            .environment(\.modelContext, context)
            .frame(width: 560)
            .background(Theme.Palette.surfaceContainerLowest)
        renderViaHostingWindow(view, size: NSSize(width: 560, height: 640),
                               filename: "snapshot-calendar-settings.png")
    }

    @Test
    func captureCalendarSettingsEditSheet() throws {
        Fonts.registerIfNeeded()
        let view = EditFeedSheet(
            feed: CalendarFeed(
                name: "Work",
                urlString: "https://calendar.google.com/calendar/ical/work/basic.ics",
                colorIndex: 1),
            onSave: { _ in }, onCancel: {})
            .background(Theme.Palette.surfaceContainerLowest)
        renderViaHostingWindow(view, size: NSSize(width: 460, height: 360),
                               filename: "snapshot-calendar-edit-sheet.png")
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

    /// `contentTopInset` is the single inset the sidebar's first nav item and
    /// every tab's content both use, so their tops line up with the date header.
    @Test
    func contentTopInsetAlignsSidebarNavAndCanvasContent() {
        #expect(AppShell.contentTopInset == 28)
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

    @Test
    func captureBacklogScreenWithAddTaskButton() throws {
        Fonts.registerIfNeeded()
        let context = try InMemoryStore.makeContext()
        let backlog = BacklogService(context: context)
        _ = backlog.addBacklogItem(
            title: "Write conference abstract", notes: "Due in two weeks", tags: ["writing"])
        _ = backlog.addBacklogItem(title: "Update Zotero collections")
        _ = backlog.addBacklogItem(title: "Order reference texts")

        let state = AppState(
            context: context,
            now: { TestDate.at(2026, 5, 23) },
            wiseSaying: WiseSaying(quote: "x", author: "y")
        )
        let view = BacklogScreen(state: state)
            .environment(\.modelContext, context)
            .padding(.horizontal, 64)
            .padding(.top, 36)
            .background(Theme.Palette.surface)
        renderViaHostingWindow(
            view, size: NSSize(width: 1000, height: 700),
            filename: "snapshot-backlog-add-button.png")
    }

    @Test
    func captureTaskDetailSheetCreateBacklog() throws {
        Fonts.registerIfNeeded()
        let context = try InMemoryStore.makeContext()
        let view = TaskDetailSheet(focus: .createBacklog, dismiss: {})
            .environment(\.modelContext, context)
            .padding(40)
            .background(Theme.Palette.surface)
        renderViaHostingWindow(
            view,
            size: NSSize(width: 600, height: 560),
            filename: "snapshot-task-detail-create-backlog.png"
        )
    }

    @Test
    func captureScheduleBlockWithEditButton() throws {
        Fonts.registerIfNeeded()
        let context = try InMemoryStore.makeContext()
        let day = DayService(context: context).day(for: TestDate.at(2026, 5, 22))
        let task = TaskService(context: context).addBrainDumpItem(
            title: "Finalize manuscript revision", on: day
        )
        let entry = try ScheduleService(context: context).schedule(
            task, on: day, startMinute: 9 * 60, durationMinutes: 90, colorIndex: 1
        )
        let view = ScheduleBlockView(
            entry: entry,
            isReadOnly: false,
            onToggleComplete: {},
            onRemove: {},
            onEdit: {}
        )
        .frame(height: 150)
        .padding(40)
        .background(Theme.Palette.surface)
        renderViaHostingWindow(
            view,
            size: NSSize(width: 600, height: 240),
            filename: "snapshot-schedule-block-with-edit.png"
        )
    }

    @Test
    func captureTop3SwapSheet() throws {
        Fonts.registerIfNeeded()
        let context = try InMemoryStore.makeContext()
        let day = DayService(context: context).day(for: TestDate.at(2026, 5, 22))
        let taskService = TaskService(context: context)
        let a = taskService.addBrainDumpItem(title: "Finalize manuscript revision", on: day)
        let b = taskService.addBrainDumpItem(title: "Email literature review to Dr. Aris", on: day)
        let c = taskService.addBrainDumpItem(title: "Research Zotero plugin updates", on: day)
        let incoming = taskService.addBrainDumpItem(title: "Review reviewer comments", on: day)
        try taskService.escalate(a, on: day)
        try taskService.escalate(b, on: day)
        try taskService.escalate(c, on: day)

        let view = Top3SwapSheet(
            day: day,
            incomingItemID: incoming.id,
            dismiss: {}
        )
        .environment(\.modelContext, context)
        .padding(40)
        .background(Theme.Palette.surface)
        renderViaHostingWindow(
            view,
            size: NSSize(width: 600, height: 540),
            filename: "snapshot-top3-swap-sheet.png"
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
    func captureSettingsSheetHasSoftwareUpdateNavItem() throws {
        Fonts.registerIfNeeded()
        let context = try InMemoryStore.makeContext()
        let defaults = UserDefaults(suiteName: "BrainDumpTest.\(UUID().uuidString)")!
        let state = AppState(
            context: context,
            now: { TestDate.at(2026, 5, 22) },
            wiseSaying: WiseSaying(quote: "x", author: "y"),
            defaults: defaults
        )
        let view = SettingsSheet(
            state: state,
            updateModel: AppUpdateModel(isUpdaterAvailable: true, canCheckForUpdates: true),
            dismiss: {}
        )
        .environment(\.modelContext, context)
        renderViaHostingWindow(
            view,
            size: NSSize(width: 820, height: 540),
            filename: "snapshot-settings-update-nav.png"
        )
    }

    @Test
    func captureUpdatesSettingsAvailable() throws {
        Fonts.registerIfNeeded()
        let model = AppUpdateModel(
            isUpdaterAvailable: true,
            canCheckForUpdates: true,
            automaticallyChecksForUpdates: true,
            lastUpdateCheckDate: TestDate.at(2026, 6, 8, hour: 9, minute: 30),
            shortVersion: "0.1.2",
            buildVersion: "123"
        )
        let view = UpdatesSettingsView(model: model)
            .frame(width: 560, height: 400)
            .background(Theme.Palette.surfaceContainerLowest)
        renderViaHostingWindow(
            view, size: NSSize(width: 560, height: 400),
            filename: "snapshot-updates-available.png")
    }

    @Test
    func captureUpdatesSettingsUnavailable() throws {
        Fonts.registerIfNeeded()
        let model = AppUpdateModel()   // default: isUpdaterAvailable == false
        let view = UpdatesSettingsView(model: model)
            .frame(width: 560, height: 300)
            .background(Theme.Palette.surfaceContainerLowest)
        renderViaHostingWindow(
            view, size: NSSize(width: 560, height: 300),
            filename: "snapshot-updates-unavailable.png")
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

    @Test
    func captureCompletionFilterParentOff() throws {
        Fonts.registerIfNeeded()
        let view = CompletionDateFilterHarness(
            useDateRange: false,
            useSpecificDateRange: false
        )
        .padding(24)
        .background(Theme.Palette.surface)
        renderViaHostingWindow(
            view, size: NSSize(width: 600, height: 120),
            filename: "snapshot-completion-filter-off.png")
    }

    @Test
    func captureCompletionFilterParentOnSubOff() throws {
        Fonts.registerIfNeeded()
        let view = CompletionDateFilterHarness(
            useDateRange: true,
            useSpecificDateRange: false
        )
        .padding(24)
        .background(Theme.Palette.surface)
        renderViaHostingWindow(
            view, size: NSSize(width: 600, height: 180),
            filename: "snapshot-completion-filter-parent-on.png")
    }

    @Test
    func captureCompletionFilterBothOn() throws {
        Fonts.registerIfNeeded()
        let view = CompletionDateFilterHarness(
            useDateRange: true,
            useSpecificDateRange: true
        )
        .padding(24)
        .background(Theme.Palette.surface)
        renderViaHostingWindow(
            view, size: NSSize(width: 600, height: 260),
            filename: "snapshot-completion-filter-both-on.png")
    }

    /// After Clear Data the day subtree rebuilds against a fresh empty `Day`
    /// (`.id(state.dataGeneration)`). Locks that empty-Today visual and
    /// exercises the post-clear render path.
    @Test
    func captureClearedToday() throws {
        Fonts.registerIfNeeded()
        let context = try InMemoryStore.makeContext()
        let day = DayService(context: context).day(for: TestDate.at(2026, 5, 22))
        _ = TaskService(context: context).addBrainDumpItem(title: "Will be cleared", on: day)

        let defaults = UserDefaults(suiteName: "BrainDumpTest.\(UUID().uuidString)")!
        let state = AppState(
            context: context,
            now: { TestDate.at(2026, 5, 22) },
            wiseSaying: WiseSaying(quote: "A clean slate.", author: "—"),
            defaults: defaults
        )
        state.clearAllData()

        let view = DayView(state: state)
            .id(state.dataGeneration)
            .environment(\.modelContext, context)
            .padding(.horizontal, 64)
            .padding(.top, 36)
            .background(Theme.Palette.surface)
        renderViaHostingWindow(
            view, size: NSSize(width: 1180, height: 1100), filename: "snapshot-cleared-today.png")
    }

    /// When the wall clock crosses midnight while the app is open,
    /// `refreshCurrentDate()` advances `todayDate`/`selectedDate`, rolls the
    /// previous day's uncompleted items forward, and bumps `dataGeneration` so
    /// the day subtree rebuilds against the re-parented models. This renders
    /// that post-rollover Today, exercising the rebuild render path (same shape
    /// as `captureClearedToday`) and confirming yesterday's item now shows under
    /// the new day's brain dump.
    @Test
    func captureTodayAfterMidnightRollover() throws {
        Fonts.registerIfNeeded()
        let context = try InMemoryStore.makeContext()
        let defaults = UserDefaults(suiteName: "BrainDumpTest.\(UUID().uuidString)")!
        let dayService = DayService(context: context)
        let taskService = TaskService(context: context)
        let yesterday = dayService.day(for: TestDate.at(2026, 5, 21))
        _ = taskService.addBrainDumpItem(title: "Rolled over from yesterday", on: yesterday)

        var clock = TestDate.at(2026, 5, 21, hour: 23, minute: 59)
        let state = AppState(
            context: context,
            now: { clock },
            wiseSaying: WiseSaying(quote: "Each day is a fresh sheet.", author: "—"),
            defaults: defaults
        )
        // Cross midnight while the app is still open.
        clock = TestDate.at(2026, 5, 22, hour: 0, minute: 1)
        #expect(state.refreshCurrentDate())

        let view = DayView(state: state)
            .id(state.dataGeneration)
            .environment(\.modelContext, context)
            .padding(.horizontal, 64)
            .padding(.top, 36)
            .background(Theme.Palette.surface)
        renderViaHostingWindow(
            view, size: NSSize(width: 1180, height: 1100),
            filename: "snapshot-today-after-rollover.png")
    }

    /// F4 + F2 + F3 together at a realistic (not artificially tall) window:
    /// the date/saying header sits at the top line, the three sections are
    /// pulled up, and the schedule fills the window height (scrolling
    /// internally) instead of the whole page scrolling.
    @Test
    func captureTodayRealisticWindowFillsAndScrolls() throws {
        Fonts.registerIfNeeded()
        let context = try InMemoryStore.makeContext()
        let day = DayService(context: context).day(for: TestDate.at(2026, 5, 22))
        let taskService = TaskService(context: context)
        let scheduleService = ScheduleService(context: context)
        let manuscript = taskService.addBrainDumpItem(
            title: "Finalize Manuscript Revision", on: day)
        try taskService.escalate(manuscript, on: day)
        _ = taskService.addBrainDumpItem(title: "Email literature review to Dr. Aris", on: day)
        _ = taskService.addBrainDumpItem(title: "Research Zotero plugin updates", on: day)
        _ = try scheduleService.schedule(
            manuscript, on: day, startMinute: 9 * 60, durationMinutes: 120)

        let view = AppShell()
            .environment(\.modelContext, context)
        renderViaHostingWindow(
            view, size: NSSize(width: 1440, height: 900), filename: "feature-today-realistic.png")
    }

    /// F2: at a short height the schedule grid scrolls inside its card
    /// (Google-Calendar day view), showing only the top of the day window.
    @Test
    func captureScheduleSectionScrollsAtShortHeight() throws {
        Fonts.registerIfNeeded()
        let context = try InMemoryStore.makeContext()
        let day = DayService(context: context).day(for: TestDate.at(2026, 5, 22))
        let taskService = TaskService(context: context)
        let scheduleService = ScheduleService(context: context)
        let manuscript = taskService.addBrainDumpItem(
            title: "Finalize Manuscript Revision", on: day)
        _ = try scheduleService.schedule(
            manuscript, on: day, startMinute: 9 * 60, durationMinutes: 120)

        let view = ScheduleSection(day: day, isReadOnly: false)
            .environment(\.modelContext, context)
            .padding(24)
            .background(Theme.Palette.surface)
        renderViaHostingWindow(
            view, size: NSSize(width: 640, height: 520),
            filename: "feature-schedule-scrolls.png")
    }

    /// F1: the TimeBlockSheet pre-filled with the default the "Schedule" menu
    /// computes for a current time of 8:13 AM — the start clock should read
    /// 8:15 AM (rounded up to the next 15-minute step).
    @Test
    func captureTimeBlockSheetDefaultStartForCurrentTime() throws {
        Fonts.registerIfNeeded()
        let context = try InMemoryStore.makeContext()
        let defaults = UserDefaults(suiteName: "BrainDumpTest.\(UUID().uuidString)")!
        let state = AppState(
            context: context, now: { TestDate.at(2026, 5, 22, hour: 8, minute: 13) },
            wiseSaying: WiseSaying(quote: "x", author: "y"), defaults: defaults)
        let start = state.defaultScheduleStartMinute(occupied: [])
        #expect(start == 8 * 60 + 15)

        let view = TimeBlockSheet(
            initialStartMinute: start,
            initialDurationMinutes: 60,
            dayStartHour: state.dayStartHour,
            dayEndHour: state.dayEndHour,
            onConfirm: { _, _, _ in },
            onCancel: {}
        )
        .environment(\.modelContext, context)
        .padding(40)
        .background(Theme.Palette.surface)
        renderViaHostingWindow(
            view, size: NSSize(width: 540, height: 420),
            filename: "feature-timeblock-default-start.png")
    }

    /// Layout goal (toggle-on-traffic-light-line + tabs aligned to title):
    /// renders the Tasks tab through the *real* AppShell with the sidebar
    /// visible, so the "Tasks" header top can be compared against the sidebar's
    /// "Daily Timebox Planner" title top. Borderless render has no macOS
    /// traffic-lights — the toggle-vs-traffic-light alignment is verified on the
    /// real app, not here.
    @Test
    func captureTasksFullApp() throws {
        Fonts.registerIfNeeded()
        let context = try InMemoryStore.makeContext()
        let today = Date().startOfLocalDay()
        let day = DayService(context: context).day(for: today)
        let taskService = TaskService(context: context)
        _ = taskService.addBrainDumpItem(title: "Finalize Manuscript Revision", on: day)
        _ = taskService.addBrainDumpItem(title: "Email literature review to Dr. Aris", on: day)

        let view = AppShell(initialDestination: .tasks)
            .environment(\.modelContext, context)
        renderViaHostingWindow(
            view, size: NSSize(width: 1440, height: 900), filename: "feature-tasks-full-app.png")
    }

    /// Same alignment check for the Backlog tab through the real AppShell.
    @Test
    func captureBacklogFullApp() throws {
        Fonts.registerIfNeeded()
        let context = try InMemoryStore.makeContext()
        let backlog = BacklogService(context: context)
        _ = backlog.addBacklogItem(
            title: "Write conference abstract", notes: "Due in two weeks", tags: ["writing"])
        _ = backlog.addBacklogItem(title: "Update Zotero collections")

        let view = AppShell(initialDestination: .backlog)
            .environment(\.modelContext, context)
        renderViaHostingWindow(
            view, size: NSSize(width: 1440, height: 900), filename: "feature-backlog-full-app.png")
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
            VStack(alignment: .leading, spacing: 6) {
                navItem("calendar.day.timeline.left", "Today", isActive: true)
                navItem("list.bullet.clipboard", "Tasks", isActive: false)
                navItem("tray.full", "Backlog", isActive: false)
            }
            .padding(.horizontal, 16)
            .padding(.top, 28)
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
                .font(Theme.Font.navLabel)
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

private struct CompletionDateFilterHarness: View {
    @State var useDateRange: Bool
    @State var useSpecificDateRange: Bool
    @State var fromDate: Date = TestDate.at(2026, 5, 17)
    @State var toDate: Date = TestDate.at(2026, 5, 24)

    var body: some View {
        CompletionDateFilter(
            useDateRange: $useDateRange,
            useSpecificDateRange: $useSpecificDateRange,
            fromDate: $fromDate,
            toDate: $toDate
        )
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
