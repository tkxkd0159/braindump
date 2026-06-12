import SwiftUI
import SwiftData

public struct DayView: View {
    @Environment(\.modelContext) private var context
    @Bindable var state: AppState
    @State private var detailFocus: TaskDetailFocus?
    @State private var pendingSchedule: ScheduleRequest?
    @State private var scheduleError: String?

    public init(state: AppState) {
        self.state = state
    }

    /// A "schedule this item" request raised from a priority/brain-dump context
    /// menu. Drives the shared `TimeBlockSheet` (the same modal the drag flow
    /// uses), pre-filled with the nearest available start time.
    struct ScheduleRequest: Identifiable {
        let id = UUID()
        let itemID: UUID
        let startMinute: Int
        let durationMinutes: Int
    }

    public var body: some View {
        let dayService = DayService(context: context)
        let day = dayService.day(for: state.selectedDate)
        let openDetail: (TaskDetailFocus) -> Void = { focus in
            detailFocus = focus
        }
        let onSchedule: (TaskItem) -> Void = { item in
            let occupied = day.schedule.map { $0.startMinute..<$0.endMinute }
            let start = state.defaultScheduleStartMinute(occupied: occupied)
            let duration = min(60, max(15, state.dayEndMinute - start))
            scheduleError = nil
            pendingSchedule = ScheduleRequest(
                itemID: item.id, startMinute: start, durationMinutes: duration)
        }
        GeometryReader { geo in
            let gutter: CGFloat = 24
            let available = max(0, geo.size.width - gutter)
            let leftWidth = max(360, available * 5.0 / 12.0)
            let rightWidth = max(480, available - leftWidth)
            HStack(alignment: .top, spacing: gutter) {
                VStack(alignment: .leading, spacing: 48) {
                    Top3Section(
                        day: day, isReadOnly: state.isPast, openDetail: openDetail,
                        onSchedule: onSchedule)
                    BrainDumpSection(
                        day: day, isReadOnly: state.isPast, openDetail: openDetail,
                        onSchedule: onSchedule
                    )
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                }
                .frame(width: leftWidth)
                .frame(maxHeight: .infinity, alignment: .top)

                ScheduleSection(
                    day: day,
                    isReadOnly: state.isPast,
                    dayStartHour: state.dayStartHour,
                    dayEndHour: state.dayEndHour,
                    openDetail: openDetail,
                    onScheduleChanged: { state.syncScheduleNotifications(for: day) }
                )
                .frame(width: rightWidth)
                .frame(maxHeight: .infinity, alignment: .top)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .sheet(item: $pendingSchedule) { request in
                TimeBlockSheet(
                    initialStartMinute: request.startMinute,
                    initialDurationMinutes: request.durationMinutes,
                    dayStartHour: state.dayStartHour,
                    dayEndHour: state.dayEndHour,
                    onConfirm: { startMinute, durationMinutes, colorIndex, reminderOffset in
                        confirmSchedule(
                            day: day, itemID: request.itemID, startMinute: startMinute,
                            durationMinutes: durationMinutes, colorIndex: colorIndex,
                            reminderOffsetMinutes: reminderOffset)
                    },
                    onCancel: { pendingSchedule = nil }
                )
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .id(day.persistentModelID)
        .overlay(alignment: .top) {
            if let scheduleError {
                Text(scheduleError)
                    .font(Theme.Font.caption)
                    .foregroundStyle(Theme.Palette.onPrimary)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(Theme.Palette.secondary)
                    .padding(.top, 4)
            }
        }
        .sheet(item: $detailFocus, onDismiss: { state.syncScheduleNotifications(for: day) }) { focus in
            TaskDetailSheet(focus: focus, dismiss: { detailFocus = nil })
        }
    }

    private func confirmSchedule(
        day: Day, itemID: UUID, startMinute: Int, durationMinutes: Int, colorIndex: Int,
        reminderOffsetMinutes: Int?
    ) {
        defer { pendingSchedule = nil }
        guard let item = day.items.first(where: { $0.id == itemID }) else {
            scheduleError = "Item not on this day"
            return
        }
        do {
            _ = try ScheduleService(context: context).schedule(
                item, on: day, startMinute: startMinute, durationMinutes: durationMinutes,
                colorIndex: colorIndex, reminderOffsetMinutes: reminderOffsetMinutes)
            scheduleError = nil
            state.syncScheduleNotifications(for: day)
        } catch TodoError.scheduleConflict {
            scheduleError = "Conflicts with another block"
        } catch TodoError.scheduleOutOfRange {
            scheduleError = "Out of range"
        } catch {
            scheduleError = "Could not schedule"
        }
    }
}
