import Foundation
import Testing
@testable import BrainDumpKit

private func makeDefaults() -> UserDefaults {
    let suite = "test.calendarFeeds.\(UUID().uuidString)"
    let d = UserDefaults(suiteName: suite)!
    d.removePersistentDomain(forName: suite)
    return d
}

@Test func feedStoreStartsEmpty() {
    let store = CalendarFeedStore(defaults: makeDefaults())
    #expect(store.load().isEmpty)
}

@Test func feedStoreRoundTrips() {
    let store = CalendarFeedStore(defaults: makeDefaults())
    let feed = CalendarFeed(name: "Work", urlString: "https://example.com/a.ics", colorIndex: 1)
    store.save([feed])
    let loaded = store.load()
    #expect(loaded == [feed])
}

@Test func feedStoreOverwrites() {
    let store = CalendarFeedStore(defaults: makeDefaults())
    store.save([CalendarFeed(name: "A", urlString: "https://a")])
    store.save([CalendarFeed(name: "B", urlString: "https://b"),
                CalendarFeed(name: "C", urlString: "https://c")])
    #expect(store.load().map(\.name) == ["B", "C"])
}
