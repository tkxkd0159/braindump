import Foundation
import Observation

/// Owns subscribed feeds, the merged in-memory event cache, fetch status, and
/// the disk cache. Exposes day-scoped queries the Schedule grid consumes. The
/// single orchestrator for external-calendar data; lives on `AppState`.
@MainActor
@Observable
public final class CalendarService {
    public private(set) var feeds: [CalendarFeed]
    public private(set) var allEvents: [CalendarEvent]
    public private(set) var feedErrors: [UUID: String] = [:]
    public private(set) var lastRefresh: Date?
    public private(set) var isRefreshing = false

    private let store: CalendarFeedStore
    private let fetcher: ICalFeedFetcher
    private let cache: CalendarCache
    private let now: () -> Date
    private let calendar: Calendar

    public init(
        store: CalendarFeedStore,
        fetcher: ICalFeedFetcher,
        cache: CalendarCache,
        now: @escaping () -> Date = { Date() },
        calendar: Calendar = .current
    ) {
        self.store = store
        self.fetcher = fetcher
        self.cache = cache
        self.now = now
        self.calendar = calendar
        self.feeds = store.load()
        self.allEvents = cache.load()
    }

    // MARK: Feed management

    public func addFeed(name: String, urlString: String, colorIndex: Int, customColorHex: String? = nil) {
        feeds.append(CalendarFeed(
            name: name, urlString: urlString, colorIndex: colorIndex, customColorHex: customColorHex))
        persistFeeds()
    }

    public func updateFeed(_ feed: CalendarFeed) {
        guard let i = feeds.firstIndex(where: { $0.id == feed.id }) else { return }
        feeds[i] = feed
        persistFeeds()
    }

    public func removeFeed(id: UUID) {
        feeds.removeAll { $0.id == id }
        allEvents.removeAll { $0.feedID == id }
        feedErrors[id] = nil
        persistFeeds()
        cache.save(allEvents)
    }

    public func setFeedEnabled(id: UUID, _ enabled: Bool) async {
        guard let i = feeds.firstIndex(where: { $0.id == id }) else { return }
        feeds[i].isEnabled = enabled
        persistFeeds()
        if enabled {
            // Re-fetch so the re-enabled feed's events reappear immediately
            // rather than waiting for the next scheduled refresh.
            await refresh()
        } else {
            allEvents.removeAll { $0.feedID == id }
            cache.save(allEvents)
        }
    }

    private func persistFeeds() { store.save(feeds) }

    // MARK: Refresh

    public func refresh() async {
        isRefreshing = true
        defer { isRefreshing = false }

        let todayStart = calendar.startOfDay(for: now())
        guard let lower = calendar.date(byAdding: .day, value: -7, to: todayStart),
              let upper = calendar.date(byAdding: .day, value: 60, to: todayStart)
        else { return }
        let window = lower..<upper

        let previousByFeed = Dictionary(grouping: allEvents, by: { $0.feedID })
        var merged: [CalendarEvent] = []
        var errors: [UUID: String] = [:]
        var anySuccess = false

        for feed in feeds where feed.isEnabled {
            guard let url = URL(string: feed.urlString), url.scheme != nil else {
                errors[feed.id] = "Invalid URL"
                merged.append(contentsOf: previousByFeed[feed.id] ?? [])
                continue
            }
            do {
                let text = try await fetcher.fetch(url)
                let parsed = ICalParser.parse(text, calendar: calendar)
                merged.append(contentsOf: Self.materialize(parsed, feed: feed, window: window, calendar: calendar))
                anySuccess = true
            } catch {
                errors[feed.id] = Self.describe(error)
                merged.append(contentsOf: previousByFeed[feed.id] ?? [])
            }
        }

        allEvents = merged
        feedErrors = errors
        if anySuccess { lastRefresh = now() }
        cache.save(merged)
    }

    /// Expand masters, graft RECURRENCE-ID overrides, build stable-id events.
    static func materialize(
        _ parsed: [ParsedICalEvent],
        feed: CalendarFeed,
        window: Range<Date>,
        calendar: Calendar
    ) -> [CalendarEvent] {
        let overrides = parsed.filter { $0.recurrenceID != nil }
        let masters = parsed.filter { $0.recurrenceID == nil }
        var overrideMap: [String: ParsedICalEvent] = [:]
        for o in overrides {
            overrideMap[overrideKey(uid: o.uid, date: o.recurrenceID!)] = o
        }

        var out: [CalendarEvent] = []
        var consumed: Set<String> = []
        for master in masters {
            let occ = RecurrenceExpander.occurrences(of: master, in: window, calendar: calendar)
            for (start, end) in occ {
                let key = overrideKey(uid: master.uid, date: start)
                if let ov = overrideMap[key] {
                    consumed.insert(key)
                    out.append(event(feed: feed, uid: master.uid, start: ov.start, end: ov.end,
                                     title: ov.summary, isAllDay: ov.isAllDay))
                } else {
                    out.append(event(feed: feed, uid: master.uid, start: start, end: end,
                                     title: master.summary, isAllDay: master.isAllDay))
                }
            }
        }

        // Orphan overrides: RECURRENCE-ID instances with no matching master
        // occurrence. Google Calendar's basic.ics exports recurring series this
        // way — every instance is its own VEVENT with a RECURRENCE-ID and no
        // RRULE master — so without this they'd all be dropped. They are concrete
        // occurrences; emit any that overlap the window directly.
        for o in overrides {
            let key = overrideKey(uid: o.uid, date: o.recurrenceID!)
            guard !consumed.contains(key) else { continue }
            guard o.start < window.upperBound, o.end > window.lowerBound else { continue }
            out.append(event(feed: feed, uid: o.uid, start: o.start, end: o.end,
                             title: o.summary, isAllDay: o.isAllDay))
        }
        return out
    }

    /// Stable key matching a master occurrence start to a RECURRENCE-ID override.
    private static func overrideKey(uid: String, date: Date) -> String {
        "\(uid)@\(date.timeIntervalSinceReferenceDate.rounded())"
    }

    private static func event(feed: CalendarFeed, uid: String, start: Date, end: Date,
                              title: String, isAllDay: Bool) -> CalendarEvent {
        CalendarEvent(
            id: "\(feed.id.uuidString):\(uid):\(start.timeIntervalSinceReferenceDate.rounded())",
            feedID: feed.id, title: title, start: start, end: end,
            isAllDay: isAllDay, colorIndex: feed.colorIndex, customColorHex: feed.customColorHex)
    }

    private static func describe(_ error: Error) -> String {
        switch error {
        case CalendarFeedError.httpStatus(let code): return "Server returned \(code)"
        case CalendarFeedError.notText: return "Feed wasn't readable text"
        case CalendarFeedError.invalidURL: return "Invalid URL"
        default: return "Couldn't reach feed"
        }
    }

    // MARK: Queries

    public func events(on date: Date) -> [CalendarEvent] {
        allEvents.filter { $0.intersects(date, calendar: calendar) }
            .sorted { $0.start < $1.start }
    }

    public func busyRanges(on date: Date) -> [Range<Int>] {
        let ranges = allEvents.compactMap { $0.isAllDay ? nil : $0.minuteRange(on: date, calendar: calendar) }
        return Self.merge(ranges)
    }

    /// Merge overlapping/touching ranges into a minimal sorted set.
    nonisolated static func merge(_ ranges: [Range<Int>]) -> [Range<Int>] {
        let sorted = ranges.sorted { $0.lowerBound < $1.lowerBound }
        var out: [Range<Int>] = []
        for r in sorted {
            if let last = out.last, r.lowerBound <= last.upperBound {
                out[out.count - 1] = last.lowerBound..<max(last.upperBound, r.upperBound)
            } else {
                out.append(r)
            }
        }
        return out
    }
}
