import Foundation
import Testing
@testable import BrainDumpKit

/// Mutable stub so a single service can be refreshed first successfully, then
/// with a failing feed, to verify the keep-previous-cache behavior.
private final class StubFetcher: ICalFeedFetcher, @unchecked Sendable {
    var byURL: [String: String]
    var failURLs: Set<String>
    init(byURL: [String: String] = [:], failURLs: Set<String> = []) {
        self.byURL = byURL
        self.failURLs = failURLs
    }
    func fetch(_ url: URL) async throws -> String {
        if failURLs.contains(url.absoluteString) { throw CalendarFeedError.httpStatus(404) }
        guard let ics = byURL[url.absoluteString] else { throw CalendarFeedError.notText }
        return ics
    }
}

@MainActor
private func makeService(_ fetcher: ICalFeedFetcher, feeds: [CalendarFeed]) -> CalendarService {
    let defaults = UserDefaults(suiteName: "test.cal.\(UUID().uuidString)")!
    let store = CalendarFeedStore(defaults: defaults)
    store.save(feeds)
    let cacheURL = URL(fileURLWithPath: NSTemporaryDirectory())
        .appendingPathComponent("cal-\(UUID().uuidString).json")
    return CalendarService(
        store: store, fetcher: fetcher, cache: CalendarCache(url: cacheURL),
        now: { TestDate.at(2026, 5, 22, hour: 8) })
}

private let busyICS = """
BEGIN:VEVENT
UID:m1
SUMMARY:Meeting
DTSTART:20260522T100000Z
DTEND:20260522T110000Z
END:VEVENT
"""

@MainActor
@Test func refreshPopulatesEventsAndBusy() async {
    let url = "https://feed/a.ics"
    let svc = makeService(StubFetcher(byURL: [url: busyICS]),
                          feeds: [CalendarFeed(name: "Work", urlString: url, colorIndex: 1)])
    await svc.refresh()
    let day = TestDate.at(2026, 5, 22)
    #expect(svc.events(on: day).count == 1)
    #expect(!svc.busyRanges(on: day).isEmpty)
}

@MainActor
@Test func allDayEventsExcludedFromBusy() async {
    let ics = """
    BEGIN:VEVENT
    UID:hol
    SUMMARY:Holiday
    DTSTART;VALUE=DATE:20260522
    DTEND;VALUE=DATE:20260523
    END:VEVENT
    """
    let url = "https://feed/allday.ics"
    let svc = makeService(StubFetcher(byURL: [url: ics]),
                          feeds: [CalendarFeed(name: "H", urlString: url)])
    await svc.refresh()
    let day = TestDate.at(2026, 5, 22)
    #expect(svc.events(on: day).count == 1)
    #expect(svc.busyRanges(on: day).isEmpty)
}

@MainActor
@Test func disabledFeedIsSkipped() async {
    let url = "https://feed/a.ics"
    let svc = makeService(StubFetcher(byURL: [url: busyICS]),
                          feeds: [CalendarFeed(name: "Off", urlString: url, isEnabled: false)])
    await svc.refresh()
    #expect(svc.events(on: TestDate.at(2026, 5, 22)).isEmpty)
}

@MainActor
@Test func failedFeedRecordsErrorAndKeepsPreviousEvents() async {
    let url = "https://feed/a.ics"
    let fetcher = StubFetcher(byURL: [url: busyICS])
    let feed = CalendarFeed(name: "Work", urlString: url)
    let svc = makeService(fetcher, feeds: [feed])
    await svc.refresh()
    #expect(svc.events(on: TestDate.at(2026, 5, 22)).count == 1)

    fetcher.failURLs = [url]
    await svc.refresh()
    #expect(svc.feedErrors[feed.id] != nil)
    #expect(svc.events(on: TestDate.at(2026, 5, 22)).count == 1) // kept previous
}

@MainActor
@Test func googleStyleRecurrenceInstancesWithoutMasterAppear() async {
    // Google Calendar's basic.ics exports each recurring instance as its own
    // VEVENT carrying a RECURRENCE-ID and NO RRULE master. These are concrete
    // occurrences and must still be shown — previously materialize treated them
    // as orphan overrides with no master to graft onto and silently dropped them.
    let ics = """
    BEGIN:VEVENT
    UID:standup_R20260508T100000@google.com
    SUMMARY:Standup
    DTSTART:20260522T100000Z
    DTEND:20260522T103000Z
    RECURRENCE-ID:20260522T100000Z
    END:VEVENT
    BEGIN:VEVENT
    UID:standup_R20260508T100000@google.com
    SUMMARY:Standup
    DTSTART:20260523T100000Z
    DTEND:20260523T103000Z
    RECURRENCE-ID:20260523T100000Z
    END:VEVENT
    """
    let url = "https://feed/google.ics"
    let svc = makeService(StubFetcher(byURL: [url: ics]),
                          feeds: [CalendarFeed(name: "Work", urlString: url, colorIndex: 1)])
    await svc.refresh()
    #expect(svc.events(on: TestDate.at(2026, 5, 22)).count == 1)
    #expect(svc.events(on: TestDate.at(2026, 5, 23)).count == 1)
    #expect(!svc.busyRanges(on: TestDate.at(2026, 5, 22)).isEmpty)
}

@MainActor
@Test func mergesMultipleFeeds() async {
    let icsB = busyICS.replacingOccurrences(of: "m1", with: "m2")
        .replacingOccurrences(of: "T100000Z", with: "T140000Z")
        .replacingOccurrences(of: "T110000Z", with: "T150000Z")
    let a = "https://feed/a.ics", b = "https://feed/b.ics"
    let svc = makeService(StubFetcher(byURL: [a: busyICS, b: icsB]),
                          feeds: [CalendarFeed(name: "A", urlString: a, colorIndex: 0),
                                  CalendarFeed(name: "B", urlString: b, colorIndex: 1)])
    await svc.refresh()
    #expect(svc.events(on: TestDate.at(2026, 5, 22)).count == 2)
}

@MainActor
@Test func updateFeedChangesURLNameColorAndRefetches() async {
    // Editing a subscription must repoint the feed (URL/name/color) and, after a
    // refresh, swap in the new URL's events recolored to the new swatch.
    let urlA = "https://feed/a.ics", urlB = "https://feed/b.ics"
    let icsB = busyICS.replacingOccurrences(of: "m1", with: "m2")
        .replacingOccurrences(of: "T100000Z", with: "T140000Z")
        .replacingOccurrences(of: "T110000Z", with: "T150000Z")
    let feed = CalendarFeed(name: "Work", urlString: urlA, colorIndex: 1)
    let svc = makeService(StubFetcher(byURL: [urlA: busyICS, urlB: icsB]), feeds: [feed])
    await svc.refresh()
    #expect(svc.events(on: TestDate.at(2026, 5, 22)).first?.colorIndex == 1)

    var edited = feed
    edited.urlString = urlB
    edited.name = "Work Calendar"
    edited.colorIndex = 4
    svc.updateFeed(edited)
    await svc.refresh()

    #expect(svc.feeds.first?.name == "Work Calendar")
    #expect(svc.feeds.first?.urlString == urlB)
    let events = svc.events(on: TestDate.at(2026, 5, 22))
    #expect(events.count == 1)
    #expect(events.first?.colorIndex == 4) // recolored to the new swatch after refresh
}

@Test func mergeRangesCombinesOverlaps() {
    #expect(CalendarService.merge([60..<120, 100..<180, 300..<360]) == [60..<180, 300..<360])
}

@MainActor
@Test func removeFeedDropsItsEvents() async {
    let url = "https://feed/a.ics"
    let feed = CalendarFeed(name: "Work", urlString: url)
    let svc = makeService(StubFetcher(byURL: [url: busyICS]), feeds: [feed])
    await svc.refresh()
    #expect(svc.events(on: TestDate.at(2026, 5, 22)).count == 1)
    svc.removeFeed(id: feed.id)
    #expect(svc.events(on: TestDate.at(2026, 5, 22)).isEmpty)
    #expect(svc.feeds.isEmpty)
}

@MainActor
@Test func enablingFeedRefetchesItsEventsWithoutExplicitRefresh() async {
    let url = "https://feed/a.ics"
    let feed = CalendarFeed(name: "Work", urlString: url)
    let svc = makeService(StubFetcher(byURL: [url: busyICS]), feeds: [feed])
    await svc.refresh()
    #expect(svc.events(on: TestDate.at(2026, 5, 22)).count == 1)

    await svc.setFeedEnabled(id: feed.id, false)
    #expect(svc.events(on: TestDate.at(2026, 5, 22)).isEmpty)

    // Re-enabling must repopulate immediately (no manual refresh call).
    await svc.setFeedEnabled(id: feed.id, true)
    #expect(svc.events(on: TestDate.at(2026, 5, 22)).count == 1)
}
