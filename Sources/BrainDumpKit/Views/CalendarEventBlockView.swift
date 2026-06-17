import SwiftUI

/// Read-only schedule block for an external calendar event. Distinct from task
/// blocks: tinted/outlined (not filled), calendar glyph, no checkbox/edit/remove.
public struct CalendarEventBlockView: View {
    let event: CalendarEvent

    public init(event: CalendarEvent) { self.event = event }

    private var accent: Color { Theme.BlockPalette.color(at: event.colorIndex, customHex: event.customColorHex) }

    public var body: some View {
        HStack(alignment: .top, spacing: 0) {
            Rectangle()
                .fill(accent.opacity(0.55))
                .frame(width: 4)
            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Image(systemName: "calendar")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(accent.opacity(0.8))
                    Text(event.title.isEmpty ? "(busy)" : event.title)
                        .font(Theme.Font.bodyLgSemibold)
                        .foregroundStyle(Theme.Palette.onSurface)
                        .lineLimit(2)
                    Spacer(minLength: 0)
                }
                Text(TimeFormat.range(startMinute: minutes.lowerBound, durationMinutes: minutes.count))
                    .font(Theme.Font.caption)
                    .foregroundStyle(Theme.Palette.onSurfaceVariant)
            }
            .padding(12)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .background(accent.opacity(0.10))
        .overlay(Rectangle().strokeBorder(accent.opacity(0.45), lineWidth: 1))
        .help(event.title)
    }

    // The label shows the event's own clock time (the grid clamps the *frame*;
    // this text shows the real meeting time).
    private var minutes: Range<Int> {
        let cal = Calendar.current
        let dayStart = cal.startOfDay(for: event.start)
        let s = max(0, Int(event.start.timeIntervalSince(dayStart) / 60))
        let e = Int(event.end.timeIntervalSince(dayStart) / 60)
        return s..<max(s + 15, e)
    }
}
