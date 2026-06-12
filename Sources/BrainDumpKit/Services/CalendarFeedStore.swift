import Foundation

/// UserDefaults-backed persistence for the list of `CalendarFeed`s (JSON under
/// a single key). Mirrors how day-bounds are treated: a preference, not content.
public final class CalendarFeedStore {
    private let defaults: UserDefaults
    private static let key = "BrainDump.calendarFeeds"

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    public func load() -> [CalendarFeed] {
        guard let data = defaults.data(forKey: Self.key),
              let feeds = try? JSONDecoder().decode([CalendarFeed].self, from: data)
        else { return [] }
        return feeds
    }

    public func save(_ feeds: [CalendarFeed]) {
        guard let data = try? JSONEncoder().encode(feeds) else { return }
        defaults.set(data, forKey: Self.key)
    }
}
