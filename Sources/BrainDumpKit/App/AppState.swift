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

    public init(
        context: ModelContext,
        now: @escaping () -> Date = { Date() },
        wiseSaying: WiseSaying = WiseSayings.random(),
        defaults: UserDefaults = .standard
    ) {
        self.context = context
        self.now = now
        self.dayService = DayService(context: context)
        self.defaults = defaults
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
}
