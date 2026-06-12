import Foundation
import Observation
import SwiftData

public enum SidebarDestination: String, CaseIterable, Hashable {
    case today
    case tasks
    case backlog
}

@MainActor
@Observable
public final class AppState {
    private let context: ModelContext
    private let now: () -> Date
    private let dayService: DayService
    private let notificationCoordinator: NotificationCoordinator
    private let defaults: UserDefaults

    public private(set) var todayDate: Date
    public var selectedDate: Date
    public var selectedDestination: SidebarDestination = .today
    public let currentWiseSaying: WiseSaying

    public var isSidebarVisible: Bool = true

    /// External-calendar subscriptions and their fetched events. Owned here so
    /// the schedule grid (via `DayView`) can render events and block their slots.
    public let calendar: CalendarService

    /// Bumped whenever stored content is wiped. Folded into `DayView`'s SwiftUI
    /// identity so the day subtree is rebuilt against fresh models instead of
    /// re-rendered against just-deleted ones (the Clear Data crash).
    public private(set) var dataGeneration: Int = 0

    private static let dayStartHourKey = "BrainDump.dayStartHour"
    private static let dayEndHourKey = "BrainDump.dayEndHour"
    private static let digestEnabledKey = "BrainDump.backlogDigestEnabled"
    private static let digestThresholdKey = "BrainDump.backlogDigestThresholdDays"
    private static let digestHourKey = "BrainDump.backlogDigestHour"
    private static let digestMinuteKey = "BrainDump.backlogDigestMinute"

    /// Valid range for the backlog-digest age threshold, in days. The lower
    /// bound is 1 (a 0-day digest would flag every backlog item); the upper
    /// bound is generous so a directly-typed number isn't surprisingly
    /// truncated. Both the typeable field and its stepper clamp into this.
    public static let backlogDigestThresholdRange = 1...999

    public var dayStartHour: Int {
        didSet { defaults.set(dayStartHour, forKey: Self.dayStartHourKey) }
    }
    public var dayEndHour: Int {
        didSet { defaults.set(dayEndHour, forKey: Self.dayEndHourKey) }
    }

    /// Backlog-age digest preferences (persisted, like the day-window hours).
    /// Each setter re-arms the digest so a change takes effect immediately.
    public var backlogDigestEnabled: Bool {
        didSet {
            defaults.set(backlogDigestEnabled, forKey: Self.digestEnabledKey)
            syncBacklogDigest()
        }
    }
    public var backlogDigestThresholdDays: Int {
        didSet {
            defaults.set(backlogDigestThresholdDays, forKey: Self.digestThresholdKey)
            syncBacklogDigest()
        }
    }
    public var backlogDigestHour: Int {
        didSet {
            defaults.set(backlogDigestHour, forKey: Self.digestHourKey)
            syncBacklogDigest()
        }
    }
    public var backlogDigestMinute: Int {
        didSet {
            defaults.set(backlogDigestMinute, forKey: Self.digestMinuteKey)
            syncBacklogDigest()
        }
    }

    /// True if the system has denied notification permission — Settings shows a
    /// hint pointing the user to System Settings.
    public var notificationsDenied: Bool { notificationCoordinator.lastAuthorizationDenied }

    public var dayStartMinute: Int { dayStartHour * 60 }
    public var dayEndMinute: Int { dayEndHour * 60 }

    /// Minutes-since-midnight of the current wall-clock time, via the injected
    /// clock (so tests are deterministic).
    public var currentMinuteOfDay: Int {
        let c = Calendar.current.dateComponents([.hour, .minute], from: now())
        return (c.hour ?? 0) * 60 + (c.minute ?? 0)
    }

    /// Default start minute the "Schedule" menu pre-fills for the selected day:
    /// the nearest available slot at/after now (today) or the day start (any
    /// other day), within the day window, skipping `occupied` ranges.
    public func defaultScheduleStartMinute(occupied: [Range<Int>]) -> Int {
        let reference = isToday ? currentMinuteOfDay : dayStartMinute
        return ScheduleDefaults.defaultStartMinute(
            referenceMinute: reference,
            dayStartMinute: dayStartMinute,
            dayEndMinute: dayEndMinute,
            occupied: occupied
        )
    }

    public init(
        context: ModelContext,
        now: @escaping () -> Date = { Date() },
        wiseSaying: WiseSaying = WiseSayings.random(),
        defaults: UserDefaults = .standard,
        notifier: UserNotifying = NoopUserNotifying(),
        calendarService: CalendarService? = nil
    ) {
        self.context = context
        self.now = now
        self.dayService = DayService(context: context)
        self.notificationCoordinator = NotificationCoordinator(notifier: notifier)
        self.defaults = defaults
        self.calendar =
            calendarService
            ?? CalendarService(
                store: CalendarFeedStore(defaults: defaults),
                fetcher: URLSessionICalFeedFetcher(),
                cache: CalendarCache(),
                now: now
            )
        let today = now().startOfLocalDay()
        self.todayDate = today
        self.selectedDate = today
        self.currentWiseSaying = wiseSaying
        let storedStart = defaults.object(forKey: Self.dayStartHourKey) as? Int
        let storedEnd = defaults.object(forKey: Self.dayEndHourKey) as? Int
        self.dayStartHour = storedStart ?? 5
        self.dayEndHour = storedEnd ?? 22
        // Property observers don't fire during init, so these don't trigger a sync.
        self.backlogDigestEnabled = defaults.object(forKey: Self.digestEnabledKey) as? Bool ?? false
        self.backlogDigestThresholdDays =
            defaults.object(forKey: Self.digestThresholdKey) as? Int ?? 7
        self.backlogDigestHour = defaults.object(forKey: Self.digestHourKey) as? Int ?? 9
        self.backlogDigestMinute = defaults.object(forKey: Self.digestMinuteKey) as? Int ?? 0
        self.dayService.rollover(now: today)
    }

    public var isToday: Bool { selectedDate == todayDate }
    public var isPast: Bool { selectedDate < todayDate }

    public func goToPreviousDay() {
        let prev = Calendar.current.date(byAdding: .day, value: -1, to: selectedDate)!
        selectedDate = prev.startOfLocalDay()
    }

    public func goToNextDay() {
        let next = Calendar.current.date(byAdding: .day, value: 1, to: selectedDate)!
            .startOfLocalDay()
        if next > todayDate { return }
        selectedDate = next
    }

    public func goToToday() {
        selectedDate = todayDate
    }

    /// Re-reads the wall clock and, if the local day has advanced since
    /// `todayDate` was last computed, rolls the app forward to the new day:
    /// updates `todayDate`, re-runs rollover so the now-past day's uncompleted
    /// items move into the new day's brain dump, follows the selection forward
    /// when the user was viewing "today", and bumps `dataGeneration` so the day
    /// subtree rebuilds against the re-parented models (same mechanism as
    /// `clearAllData`). Returns true iff the day changed.
    ///
    /// Idempotent: repeated calls within the same local day are a cheap no-op,
    /// so it is safe to drive from a periodic timer, the `NSCalendarDayChanged`
    /// notification, and app-activation events all at once.
    @discardableResult
    public func refreshCurrentDate() -> Bool {
        let newToday = now().startOfLocalDay()
        guard newToday != todayDate else { return false }
        let wasViewingToday = selectedDate == todayDate
        todayDate = newToday
        dayService.rollover(now: newToday)
        if wasViewingToday {
            selectedDate = newToday
        }
        dataGeneration += 1
        refreshAllNotifications()
        return true
    }

    public func toggleSidebar() {
        isSidebarVisible.toggle()
    }

    // MARK: - Notifications

    /// Snapshot a day's schedule entries into the planner's input shape.
    public func scheduleReminderInputs(for day: Day) -> [ReminderInput] {
        let dayStart = day.date
        return day.schedule.map { entry in
            ReminderInput(
                entryID: entry.id, dayStart: dayStart, startMinute: entry.startMinute,
                offsetMinutes: entry.reminderOffsetMinutes, isCompleted: entry.isCompleted,
                title: entry.item?.title ?? "Scheduled task")
        }
    }

    /// Snapshot the backlog into the digest planner's input shape.
    public func backlogDigestInputs() -> [BacklogInput] {
        BacklogService(context: context).listBacklog().map { BacklogInput(createdAt: $0.createdAt) }
    }

    /// Re-arm the reminders for one day's schedule (called after edits to it).
    public func syncScheduleNotifications(for day: Day) {
        let inputs = scheduleReminderInputs(for: day)
        let n = now()
        Task { await notificationCoordinator.syncScheduleReminders(inputs: inputs, now: n) }
    }

    /// Re-arm (or cancel) the backlog digest from current settings + backlog.
    public func syncBacklogDigest() {
        let inputs = backlogDigestInputs()
        let n = now()
        let enabled = backlogDigestEnabled
        let threshold = backlogDigestThresholdDays
        let hour = backlogDigestHour
        let minute = backlogDigestMinute
        Task {
            await notificationCoordinator.syncBacklogDigest(
                inputs: inputs, enabled: enabled, thresholdDays: threshold,
                hour: hour, minute: minute, now: n)
        }
    }

    /// Reconcile every notification against current state. Safe to call from
    /// launch / activation / day-change / a timer — it never *creates* a Day
    /// (uses today's day only if it already exists), so it won't resurrect data
    /// after a wipe.
    public func refreshAllNotifications() {
        syncBacklogDigest()
        let inputs = existingDay(for: todayDate).map { scheduleReminderInputs(for: $0) } ?? []
        let n = now()
        Task { await notificationCoordinator.syncScheduleReminders(inputs: inputs, now: n) }
    }

    /// Today's `Day` if it already exists, without inserting one.
    private func existingDay(for date: Date) -> Day? {
        let target = date.startOfLocalDay()
        let predicate = #Predicate<Day> { $0.date == target }
        return (try? context.fetch(FetchDescriptor<Day>(predicate: predicate)))?.first
    }

    /// Selects the sidebar destination at `index` in the sidebar's visual order
    /// (0 = Today, 1 = Tasks, 2 = Backlog), backing the ⌘1/⌘2/⌘3 shortcuts. The
    /// order is `SidebarDestination.allCases`, which the sidebar `NavItem`s
    /// render in the same sequence. Out-of-range indices are ignored.
    public func selectSidebarItem(at index: Int) {
        let order = SidebarDestination.allCases
        guard order.indices.contains(index) else { return }
        selectedDestination = order[index]
    }

    /// Update the day-window bounds. Returns false if invalid (caller can show an
    /// error). Validation: start ∈ 0...23, end ∈ 1...24, span ≥ 4 hours.
    @discardableResult
    public func setDayBounds(startHour: Int, endHour: Int) -> Bool {
        guard startHour >= 0, startHour < 24,
            endHour > 0, endHour <= 24,
            endHour - startHour >= 4
        else { return false }
        dayStartHour = startHour
        dayEndHour = endHour
        return true
    }

    /// Parse raw text from the typeable threshold field into a valid day count.
    /// Returns the integer iff the text is a whole number inside
    /// `backlogDigestThresholdRange`; otherwise `nil`, so the UI can flag the
    /// field red and block Save rather than silently clamping out-of-range input.
    public static func parseBacklogDigestThreshold(_ raw: String) -> Int? {
        let trimmed = raw.trimmingCharacters(in: .whitespaces)
        guard let value = Int(trimmed), backlogDigestThresholdRange.contains(value) else {
            return nil
        }
        return value
    }

    /// Wipes all user data (days, tasks, schedule entries, backlog) and snaps
    /// navigation back to Today. Preferences like day bounds are preserved —
    /// "clear data" targets content, not settings.
    public func clearAllData() {
        dayService.clearAllData()
        selectedDate = todayDate
        selectedDestination = .today
        dataGeneration += 1
        refreshAllNotifications()
    }

    /// Serialize all data to a JSON backup.
    public func exportBackupData() throws -> Data {
        try BackupService(context: context).exportData()
    }

    /// Replace all data with a backup, then reset navigation to Today and
    /// rebuild the day subtree (same mechanism as `clearAllData`).
    public func importBackup(from data: Data) throws {
        try BackupService(context: context).restore(from: data)
        selectedDate = todayDate
        selectedDestination = .today
        dataGeneration += 1
        refreshAllNotifications()
    }
}
