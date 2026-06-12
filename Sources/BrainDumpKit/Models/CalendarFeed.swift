import Foundation

/// A subscribed external calendar (one iCal URL). Stored as a preference in
/// UserDefaults — not user content, so it survives Clear Data / restore and is
/// excluded from the JSON backup.
public struct CalendarFeed: Codable, Identifiable, Equatable, Sendable {
    public var id: UUID
    public var name: String
    public var urlString: String
    public var colorIndex: Int
    public var isEnabled: Bool

    public init(
        id: UUID = UUID(),
        name: String,
        urlString: String,
        colorIndex: Int = 0,
        isEnabled: Bool = true
    ) {
        self.id = id
        self.name = name
        self.urlString = urlString
        self.colorIndex = colorIndex
        self.isEnabled = isEnabled
    }
}
