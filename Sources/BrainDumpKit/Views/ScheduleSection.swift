import SwiftUI
import SwiftData

public struct ScheduleSection: View {
    @Environment(\.modelContext) private var context
    let day: Day
    let isReadOnly: Bool
    let dayStartHour: Int
    let dayEndHour: Int
    let openDetail: ((TaskItem, ScheduleEntry?) -> Void)?

    public init(
        day: Day,
        isReadOnly: Bool,
        dayStartHour: Int = 5,
        dayEndHour: Int = 22,
        openDetail: ((TaskItem, ScheduleEntry?) -> Void)? = nil
    ) {
        self.day = day
        self.isReadOnly = isReadOnly
        self.dayStartHour = dayStartHour
        self.dayEndHour = dayEndHour
        self.openDetail = openDetail
    }

    private static let slotHeight: CGFloat = 50
    private static var hourHeight: CGFloat { slotHeight * 2 }
    private static let timeLabelWidth: CGFloat = 80

    private var dayStartMinute: Int { dayStartHour * 60 }
    private var dayEndMinute: Int { dayEndHour * 60 }

    @State private var pending: PendingDrop?
    @State private var errorText: String?

    private var scheduleService: ScheduleService { ScheduleService(context: context) }
    private var taskService: TaskService { TaskService(context: context) }

    private struct PendingDrop: Identifiable {
        let id = UUID()
        let startMinute: Int
        let itemID: UUID
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            gridBody
        }
        .padding(24)
        .background(Theme.Palette.surfaceContainerLowest)
        .overlay(
            Rectangle().strokeBorder(Theme.Palette.outlineVariant, lineWidth: 1)
        )
        .shadow(color: Color(red: 0, green: 31/255, blue: 63/255, opacity: 0.03), radius: 30, x: 0, y: 10)
        .sheet(item: $pending) { drop in
            TimeBlockSheet(
                initialStartMinute: drop.startMinute,
                initialDurationMinutes: 60,
                onConfirm: { startMinute, durationMinutes, colorIndex in
                    confirmSchedule(itemID: drop.itemID, startMinute: startMinute, durationMinutes: durationMinutes, colorIndex: colorIndex)
                },
                onCancel: { pending = nil }
            )
        }
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            Text("Schedule")
                .font(Theme.Font.sectionLabel)
                .tracking(1.4)
                .textCase(.uppercase)
                .foregroundStyle(Theme.Palette.primary)
            if let errorText {
                Text(errorText)
                    .font(Theme.Font.caption)
                    .foregroundStyle(Theme.Palette.secondary)
                    .padding(.leading, 12)
            }
            Spacer()
        }
        .padding(.bottom, 32)
    }

    private var gridBody: some View {
        ZStack(alignment: .topLeading) {
            VStack(spacing: 0) {
                Rectangle()
                    .fill(Theme.Palette.outlineVariant)
                    .frame(height: 1)
                ForEach(rows(), id: \.self) { row in
                    slotRow(hour: row.hour, isTopOfHour: row.isTopOfHour)
                }
            }
            ForEach(day.schedule, id: \.id) { entry in
                if entry.endMinute > dayStartMinute && entry.startMinute < dayEndMinute {
                    let entryRef = entry
                    let visibleStart = max(entry.startMinute, dayStartMinute)
                    let visibleEnd = min(entry.endMinute, dayEndMinute)
                    let visibleMinutes = visibleEnd - visibleStart
                    ScheduleBlockView(
                        entry: entry,
                        isReadOnly: isReadOnly,
                        onToggleComplete: { scheduleService.setCompleted(entryRef, !entryRef.isCompleted) },
                        onRemove: { scheduleService.unschedule(entryRef) },
                        onTap: {
                            if let item = entryRef.item {
                                openDetail?(item, entryRef)
                            }
                        }
                    )
                    .frame(height: CGFloat(visibleMinutes) / 60.0 * Self.hourHeight)
                    .padding(.leading, Self.timeLabelWidth)
                    .frame(maxWidth: .infinity, alignment: .topLeading)
                    .offset(y: CGFloat(visibleStart - dayStartMinute) / 60.0 * Self.hourHeight + 1)
                }
            }
        }
    }

    private struct Row: Hashable {
        let hour: Int
        let isTopOfHour: Bool
    }

    private func rows() -> [Row] {
        var result: [Row] = []
        for hour in dayStartHour...dayEndHour {
            result.append(Row(hour: hour, isTopOfHour: true))
            if hour != dayEndHour {
                result.append(Row(hour: hour, isTopOfHour: false))
            }
        }
        return result
    }

    private func isOccupied(minute: Int) -> Bool {
        day.schedule.contains { entry in
            minute >= entry.startMinute && minute < entry.endMinute
        }
    }

    private func slotRow(hour: Int, isTopOfHour: Bool) -> some View {
        HStack(alignment: .top, spacing: 0) {
            timeLabel(hour: hour, isTopOfHour: isTopOfHour)
                .padding(.top, 8)
                .padding(.trailing, 16)
                .frame(width: Self.timeLabelWidth, height: Self.slotHeight, alignment: .topTrailing)
                .overlay(alignment: .trailing) {
                    Rectangle()
                        .fill(Theme.Palette.outlineVariant)
                        .frame(width: 1)
                }
            slotBody(hour: hour, isTopOfHour: isTopOfHour)
                .frame(maxWidth: .infinity, alignment: .topLeading)
                .frame(height: Self.slotHeight)
                .overlay(alignment: .bottom) {
                    Rectangle()
                        .fill(Theme.Palette.outlineVariant)
                        .frame(height: 1)
                }
        }
        .frame(height: Self.slotHeight)
    }

    @ViewBuilder
    private func timeLabel(hour: Int, isTopOfHour: Bool) -> some View {
        if isTopOfHour {
            VStack(alignment: .trailing, spacing: 1) {
                Text(hourString(hour))
                    .font(Theme.Font.timeLabelHour)
                    .foregroundStyle(Theme.Palette.primary)
                Text(periodString(hour))
                    .font(Theme.Font.tinyLabel)
                    .foregroundStyle(Theme.Palette.onSurfaceVariant)
            }
        } else {
            Text(halfHourString(hour))
                .font(Theme.Font.timeLabelHalf)
                .foregroundStyle(Theme.Palette.onSurfaceVariant.opacity(0.6))
        }
    }

    @ViewBuilder
    private func slotBody(hour: Int, isTopOfHour: Bool) -> some View {
        let slotStartMinute = hour * 60 + (isTopOfHour ? 0 : 30)
        let occupied = isOccupied(minute: slotStartMinute)
        if occupied {
            Rectangle()
                .fill(Theme.Palette.surfaceContainerLow.opacity(0.5))
        } else {
            ScheduleSlot(
                hour: hour,
                isTopOfHour: isTopOfHour,
                isReadOnly: isReadOnly,
                onSubmit: { title in submitInline(title: title, startMinute: slotStartMinute) },
                onDrop: { itemID in pending = PendingDrop(startMinute: slotStartMinute, itemID: itemID) }
            )
        }
    }

    private func submitInline(title: String, startMinute: Int) {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !isReadOnly else { return }
        let item = taskService.addBrainDumpItem(title: trimmed, on: day)
        do {
            _ = try scheduleService.schedule(item, on: day, startMinute: startMinute, durationMinutes: 60)
            errorText = nil
        } catch TodoError.scheduleConflict {
            errorText = "Conflicts with another block"
        } catch TodoError.scheduleOutOfRange {
            errorText = "Out of range"
        } catch {
            errorText = "Could not schedule"
        }
    }

    private func confirmSchedule(itemID: UUID, startMinute: Int, durationMinutes: Int, colorIndex: Int) {
        defer { pending = nil }
        guard let item = day.items.first(where: { $0.id == itemID }) else {
            errorText = "Item not on this day"
            return
        }
        do {
            _ = try scheduleService.schedule(item, on: day, startMinute: startMinute, durationMinutes: durationMinutes, colorIndex: colorIndex)
            errorText = nil
        } catch TodoError.scheduleConflict {
            errorText = "Conflicts with another block"
        } catch TodoError.scheduleOutOfRange {
            errorText = "Out of range"
        } catch {
            errorText = "Could not schedule"
        }
    }

    private func hourString(_ hour: Int) -> String {
        let h = hour % 12 == 0 ? 12 : hour % 12
        return "\(h):00"
    }

    private func halfHourString(_ hour: Int) -> String {
        let h = hour % 12 == 0 ? 12 : hour % 12
        return "\(h):30"
    }

    private func periodString(_ hour: Int) -> String {
        hour < 12 ? "AM" : "PM"
    }
}

private struct ScheduleSlot: View {
    let hour: Int
    let isTopOfHour: Bool
    let isReadOnly: Bool
    let onSubmit: (String) -> Void
    let onDrop: (UUID) -> Void

    @State private var text: String = ""
    @State private var isTargeted: Bool = false
    @State private var hovered: Bool = false
    @FocusState private var focused: Bool

    var body: some View {
        HStack(spacing: 0) {
            Rectangle()
                .fill(focused ? Theme.Palette.primary : Color.clear)
                .frame(width: 4)
            TextField(text: $text, prompt: promptText) {
                EmptyView()
            }
            .textFieldStyle(.plain)
            .font(Theme.Font.bodyMd)
            .foregroundStyle(Theme.Palette.onSurface)
            .padding(.horizontal, 16)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
            .focused($focused)
            .disabled(isReadOnly)
            .onSubmit {
                onSubmit(text)
                text = ""
            }
        }
        .background(backgroundColor)
        .contentShape(Rectangle())
        .dropDestination(for: TaskItemDragPayload.self) { payloads, _ in
            guard !isReadOnly, let p = payloads.first else { return false }
            onDrop(p.id)
            return true
        } isTargeted: { targeted in
            isTargeted = targeted && !isReadOnly
        }
        .onHover { hovered = $0 }
    }

    private var backgroundColor: Color {
        if focused { return Theme.Palette.surfaceContainerLowest }
        if isTargeted { return Theme.Palette.surfaceContainerHigh.opacity(0.6) }
        if hovered { return Theme.Palette.surfaceContainerLow.opacity(0.5) }
        return Color.clear
    }

    private var promptText: Text? {
        guard isTopOfHour else { return Text("") }
        return Text("Plan activity…")
    }
}
