import SwiftUI

/// Compact read-only row of all-day calendar events shown above the schedule
/// grid. All-day events don't consume time slots, so they live here, not in the
/// grid. Hidden when `events` is empty (caller checks).
public struct AllDayEventBar: View {
    let events: [CalendarEvent]

    public init(events: [CalendarEvent]) { self.events = events }

    public var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(events) { event in
                    let accent = Theme.BlockPalette.color(at: event.colorIndex, customHex: event.customColorHex)
                    HStack(spacing: 6) {
                        Circle().fill(accent.opacity(0.8)).frame(width: 8, height: 8)
                        Text(event.title.isEmpty ? "(all-day)" : event.title)
                            .font(Theme.Font.caption)
                            .foregroundStyle(Theme.Palette.onSurface)
                            .lineLimit(1)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(accent.opacity(0.10))
                    .overlay(Rectangle().strokeBorder(accent.opacity(0.35), lineWidth: 1))
                }
            }
        }
    }
}
