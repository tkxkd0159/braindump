import Foundation
import Testing
import SwiftData
@testable import TodoosxKit

@MainActor
@Test func appInitRollsOverPastDays() throws {
    let context = try InMemoryStore.makeContext()
    let dayService = DayService(context: context)
    let taskService = TaskService(context: context)
    let yesterday = dayService.day(for: TestDate.at(2026, 5, 21))
    _ = taskService.addBrainDumpItem(title: "Carry me", on: yesterday)

    let state = AppState(context: context, now: { TestDate.at(2026, 5, 22) })

    let today = dayService.day(for: state.selectedDate)
    #expect(today.items.count == 1)
}

@MainActor
@Test func goBackThenForwardChangesSelectedDate() throws {
    let context = try InMemoryStore.makeContext()
    let state = AppState(context: context, now: { TestDate.at(2026, 5, 22) })

    state.goToPreviousDay()
    #expect(state.selectedDate == TestDate.at(2026, 5, 21))

    state.goToToday()
    #expect(state.selectedDate == TestDate.at(2026, 5, 22))
}

@MainActor
@Test func cannotGoToFutureBeyondToday() throws {
    let context = try InMemoryStore.makeContext()
    let state = AppState(context: context, now: { TestDate.at(2026, 5, 22) })

    state.goToNextDay()
    #expect(state.selectedDate == TestDate.at(2026, 5, 22))
}

@MainActor
@Test func isTodayReflectsSelectedDate() throws {
    let context = try InMemoryStore.makeContext()
    let state = AppState(context: context, now: { TestDate.at(2026, 5, 22) })
    #expect(state.isToday)
    state.goToPreviousDay()
    #expect(!state.isToday)
}
