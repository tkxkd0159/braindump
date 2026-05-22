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

    public private(set) var todayDate: Date
    public var selectedDate: Date
    public var selectedDestination: SidebarDestination = .today
    public let currentWiseSaying: WiseSaying

    public init(
        context: ModelContext,
        now: @escaping () -> Date = { Date() },
        wiseSaying: WiseSaying = WiseSayings.random()
    ) {
        self.context = context
        self.now = now
        self.dayService = DayService(context: context)
        let today = now().startOfLocalDay()
        self.todayDate = today
        self.selectedDate = today
        self.currentWiseSaying = wiseSaying
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
}
