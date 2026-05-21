import SwiftUI
import SwiftData

public struct ScheduleSection: View {
    @Environment(\.modelContext) private var context
    let day: Day
    let isReadOnly: Bool

    public init(day: Day, isReadOnly: Bool) {
        self.day = day
        self.isReadOnly = isReadOnly
    }

    private let hours = Array(5...23)
    private let rowHeight: CGFloat = 44

    @State private var pending: PendingDrop?
    @State private var errorText: String?

    private var scheduleService: ScheduleService { ScheduleService(context: context) }

    private struct PendingDrop: Identifiable {
        let id = UUID()
        let hour: Int
        let itemID: UUID
    }

    private func startsAt(_ hour: Int) -> ScheduleEntry? {
        day.schedule.first { $0.startHour == hour }
    }

    private func coveredBy(_ hour: Int) -> ScheduleEntry? {
        day.schedule.first { $0.startHour < hour && hour < $0.startHour + $0.durationHours }
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Schedule")
                    .font(.title3.weight(.semibold))
                if let errorText {
                    Text(errorText)
                        .font(.caption)
                        .foregroundStyle(.red)
                        .padding(.leading, 8)
                }
            }
            ScrollView {
                VStack(spacing: 4) {
                    ForEach(hours, id: \.self) { hour in
                        hourRow(hour: hour)
                    }
                }
                .padding(.trailing, 4)
            }
        }
        .padding(16)
        .sheet(item: $pending) { drop in
            DurationPromptSheet(
                startHour: drop.hour,
                maxDuration: 24 - drop.hour,
                onConfirm: { duration in
                    confirmSchedule(itemID: drop.itemID, hour: drop.hour, duration: duration)
                },
                onCancel: { pending = nil }
            )
        }
    }

    private func hourRow(hour: Int) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Text(label(for: hour))
                .font(.caption.monospaced())
                .foregroundStyle(.secondary)
                .frame(width: 60, alignment: .trailing)
                .padding(.top, 12)

            if let starting = startsAt(hour) {
                ScheduleBlockView(
                    entry: starting,
                    isReadOnly: isReadOnly,
                    onToggleComplete: { scheduleService.setCompleted(starting, !starting.isCompleted) },
                    onRemove: { scheduleService.unschedule(starting) }
                )
                .frame(height: rowHeight * CGFloat(starting.durationHours) - 4)
            } else if coveredBy(hour) != nil {
                Color.clear.frame(height: rowHeight - 4)
            } else {
                emptySlot(hour: hour)
            }
        }
        .frame(minHeight: rowHeight, alignment: .top)
    }

    private func emptySlot(hour: Int) -> some View {
        RoundedRectangle(cornerRadius: 6)
            .strokeBorder(
                Color.gray.opacity(0.20),
                style: StrokeStyle(lineWidth: 1, dash: [3, 3])
            )
            .frame(height: rowHeight - 4)
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
            .dropDestination(for: TaskItemDragPayload.self) { payloads, _ in
                guard !isReadOnly, let p = payloads.first else { return false }
                pending = PendingDrop(hour: hour, itemID: p.id)
                return true
            }
    }

    private func confirmSchedule(itemID: UUID, hour: Int, duration: Int) {
        defer { pending = nil }
        guard let item = day.items.first(where: { $0.id == itemID }) else {
            errorText = "Item not on this day"
            return
        }
        do {
            _ = try scheduleService.schedule(item, on: day, startHour: hour, durationHours: duration)
            errorText = nil
        } catch TodoError.scheduleConflict {
            errorText = "Conflicts with another block"
        } catch TodoError.scheduleOutOfRange {
            errorText = "Out of range"
        } catch {
            errorText = "Could not schedule"
        }
    }

    private func label(for hour: Int) -> String {
        let h = hour % 12 == 0 ? 12 : hour % 12
        return "\(h) \(hour < 12 ? "AM" : "PM")"
    }
}
