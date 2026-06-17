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

@Test func feedStoreRoundTripsCustomColor() {
    let store = CalendarFeedStore(defaults: makeDefaults())
    let feed = CalendarFeed(
        name: "Work", urlString: "https://example.com/a.ics",
        colorIndex: 1, customColorHex: "#0A0B0C")
    store.save([feed])
    #expect(store.load() == [feed])
    #expect(store.load().first?.customColorHex == "#0A0B0C")
}

@Test func feedDecodesLegacyJSONWithoutCustomColorAsNil() throws {
    let legacy = """
    [{"id":"\(UUID().uuidString)","name":"Old","urlString":"https://a","colorIndex":2,"isEnabled":true}]
    """.data(using: .utf8)!
    let feeds = try JSONDecoder().decode([CalendarFeed].self, from: legacy)
    #expect(feeds.count == 1)
    #expect(feeds.first?.colorIndex == 2)
    #expect(feeds.first?.customColorHex == nil)
}

@Test func feedStoreOverwrites() {
    let store = CalendarFeedStore(defaults: makeDefaults())
    store.save([CalendarFeed(name: "A", urlString: "https://a")])
    store.save([CalendarFeed(name: "B", urlString: "https://b"),
                CalendarFeed(name: "C", urlString: "https://c")])
    #expect(store.load().map(\.name) == ["B", "C"])
}
