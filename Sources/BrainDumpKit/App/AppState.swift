import Foundation
import SwiftData
import Observation

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

    public var dayStartHour: Int {
        didSet { defaults.set(dayStartHour, forKey: Self.dayStartHourKey) }
    }
    public var dayEndHour: Int {
        didSet { defaults.set(dayEndHour, forKey: Self.dayEndHourKey) }
    }

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
        calendarService: CalendarService? = nil
    ) {
        self.context = context
        self.now = now
        self.dayService = DayService(context: context)
        self.defaults = defaults
        self.calendar = calendarService ?? CalendarService(
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
        self.dayService.rollover(now: today)
    }

    public var isToday: Bool { selectedDate == todayDate }
    public var isPast: Bool { selectedDate < todayDate }

    public func goToPreviousDay() {
        let prev = Calendar.current.date(byAdding: .day, value: -1, to: selectedDate)!
        selectedDate = prev.startOfLocalDay()
    }

    public func goToNextDay() {
        let next = Calendar.current.date(byAdding: .day, value: 1, to: selectedDate)!.startOfLocalDay()
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
        return true
    }

    public func toggleSidebar() {
        isSidebarVisible.toggle()
    }

    /// Update the day-window bounds. Returns false if invalid (caller can show an
    /// error). Validation: start ∈ 0...23, end ∈ 1...24, span ≥ 4 hours.
    @discardableResult
    public func setDayBounds(startHour: Int, endHour: Int) -> Bool {
        guard startHour >= 0, startHour < 24,
              endHour > 0, endHour <= 24,
              endHour - startHour >= 4 else { return false }
        dayStartHour = startHour
        dayEndHour = endHour
        return true
    }

    /// Wipes all user data (days, tasks, schedule entries, backlog) and snaps
    /// navigation back to Today. Preferences like day bounds are preserved —
    /// "clear data" targets content, not settings.
    public func clearAllData() {
        dayService.clearAllData()
        selectedDate = todayDate
        selectedDestination = .today
        dataGeneration += 1
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
    }
}
