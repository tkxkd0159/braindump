import Foundation

public enum CalendarFeedError: Error, Equatable, Sendable {
    case invalidURL
    case httpStatus(Int)
    case notText
}

/// Abstraction over fetching an iCal feed's text, so tests can inject canned ICS.
public protocol ICalFeedFetcher: Sendable {
    func fetch(_ url: URL) async throws -> String
}

public struct URLSessionICalFeedFetcher: ICalFeedFetcher {
    public init() {}

    /// `webcal://` (the scheme Apple Calendar advertises) is just HTTP under the
    /// hood — rewrite it to `https://` so URLSession can fetch it.
    static func normalize(_ url: URL) -> URL {
        if url.scheme == "webcal", var comps = URLComponents(url: url, resolvingAgainstBaseURL: false) {
            comps.scheme = "https"
            return comps.url ?? url
        }
        return url
    }

    public func fetch(_ url: URL) async throws -> String {
        let (data, response) = try await URLSession.shared.data(from: Self.normalize(url))
        if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
            throw CalendarFeedError.httpStatus(http.statusCode)
        }
        guard let text = String(data: data, encoding: .utf8) else { throw CalendarFeedError.notText }
        return text
    }
}
