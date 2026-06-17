import Foundation

/// A subscribed external calendar (one iCal URL). Stored as a preference in
/// UserDefaults — not user content, so it survives Clear Data / restore and is
/// excluded from the JSON backup.
public struct CalendarFeed: Codable, Identifiable, Equatable, Sendable {
    public var id: UUID
    public var name: String
    public var urlString: String
    public var colorIndex: Int
    /// Arbitrary `#RRGGBB` color overriding `colorIndex` when non-nil. Optional so
    /// existing stored feeds (no key) decode to nil — preserving palette colors.
    public var customColorHex: String?
    public var isEnabled: Bool

    public init(
        id: UUID = UUID(),
        name: String,
        urlString: String,
        colorIndex: Int = 0,
        customColorHex: String? = nil,
        isEnabled: Bool = true
    ) {
        self.id = id
        self.name = name
        self.urlString = urlString
        self.colorIndex = colorIndex
        self.customColorHex = customColorHex
        self.isEnabled = isEnabled
    }
}
