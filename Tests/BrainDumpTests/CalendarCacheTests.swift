import Foundation
import Testing
@testable import BrainDumpKit

@MainActor
@Test func calendarCacheRoundTrips() {
    let tmp = URL(fileURLWithPath: NSTemporaryDirectory())
        .appendingPathComponent("braindump-cache-\(UUID().uuidString).json")
    defer { try? FileManager.default.removeItem(at: tmp) }
    let cache = CalendarCache(url: tmp)
    let e = CalendarEvent(id: "1", feedID: UUID(), title: "X",
                          start: TestDate.at(2026, 5, 22, hour: 9),
                          end: TestDate.at(2026, 5, 22, hour: 10), isAllDay: false, colorIndex: 2)
    cache.save([e])
    #expect(cache.load() == [e])
}

@MainActor
@Test func calendarCacheMissingFileReturnsEmpty() {
    let tmp = URL(fileURLWithPath: NSTemporaryDirectory())
        .appendingPathComponent("missing-\(UUID().uuidString).json")
    #expect(CalendarCache(url: tmp).load().isEmpty)
}
