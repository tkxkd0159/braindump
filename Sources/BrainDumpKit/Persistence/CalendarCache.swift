import Foundation

/// JSON disk cache of the last successfully-fetched events, so the grid shows
/// events immediately on launch and offline. Best-effort: failures are silent.
public struct CalendarCache: Sendable {
    private let url: URL

    public init(url: URL = CalendarCache.defaultURL()) {
        self.url = url
    }

    /// ~/Library/Application Support/BrainDump[-debug]/calendar-cache.json —
    /// shares the build-specific app directory with the SwiftData store.
    public static func defaultURL() -> URL {
        URL.applicationSupportDirectory.appending(
            path: "\(PersistenceController.appDirectoryName)/calendar-cache.json")
    }

    public func load() -> [CalendarEvent] {
        guard let data = try? Data(contentsOf: url) else { return [] }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return (try? decoder.decode([CalendarEvent].self, from: data)) ?? []
    }

    public func save(_ events: [CalendarEvent]) {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        guard let data = try? encoder.encode(events) else { return }
        try? FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try? data.write(to: url)
    }
}
