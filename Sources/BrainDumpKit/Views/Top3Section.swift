import SwiftUI
import SwiftData

public struct Top3Section: View {
    @Environment(\.modelContext) private var context
    let day: Day
    let isReadOnly: Bool
    let openDetail: ((TaskDetailFocus) -> Void)?

    @State private var hoveredID: UUID?
    @State private var expandedIDs: Set<UUID> = []
    @State private var dropTargetSlot: Int?

    public init(
        day: Day,
        isReadOnly: Bool,
        openDetail: ((TaskDetailFocus) -> Void)? = nil
    ) {
        self.day = day
        self.isReadOnly = isReadOnly
        self.openDetail = openDetail
    }

    private var taskService: TaskService { TaskService(context: context) }

    private func scheduleEntry(for item: TaskItem) -> ScheduleEntry? {
        day.schedule.first { $0.item?.id == item.id }
    }

    private func isCompleted(_ item: TaskItem) -> Bool {
        day.schedule.contains { $0.item?.id == item.id && $0.isCompleted }
    }

    private var top3Items: [TaskItem?] {
        var slots: [TaskItem?] = [nil, nil, nil]
        for (i, id) in day.top3ItemIDs.prefix(3).enumerated() {
            slots[i] = day.items.first { $0.id == id }
        }
        return slots
    }

    private var filledCount: Int {
        top3Items.compactMap { $0 }.count
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            header
            VStack(spacing: 16) {
                ForEach(Array(top3Items.enumerated()), id: \.offset) { idx, item in
                    slotRow(index: idx, item: item)
                }
            }
        }
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            Text("Top Priorities")
                .font(Theme.Font.sectionLabel)
                .tracking(1.4)
                .textCase(.uppercase)
                .foregroundStyle(Theme.Palette.primary)
            Spacer()
            Text("\(filledCount)/3")
                .font(Theme.Font.labelMd)
                .tracking(0.7)
                .foregroundStyle(Theme.Palette.primaryContainer)
        }
        .padding(.bottom, 8)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(Theme.Palette.primary)
                .frame(height: 1)
        }
    }

    @ViewBuilder
    private func slotRow(index: Int, item: TaskItem?) -> some View {
        if let item {
            filledRow(item: item, index: index)
        } else {
            emptyRow(index: index)
        }
    }

    private func filledRow(item: TaskItem, index: Int) -> some View {
        let scheduled = scheduleEntry(for: item)
        let completed = isCompleted(item)
        let hovered = hoveredID == item.id
        let expanded = expandedIDs.contains(item.id)
        let hasDetails = !item.notes.isEmpty || !item.tags.isEmpty

        return HStack(alignment: .top, spacing: 16) {
            SquareCheckbox(isOn: completed) {
                guard !isReadOnly, let entry = scheduled else { return }
                ScheduleService(context: context).setCompleted(entry, !entry.isCompleted)
            }
            .padding(.top, 2)
            .disabled(isReadOnly || scheduled == nil)

            VStack(alignment: .leading, spacing: 6) {
                if let scheduled {
                    HStack(spacing: 6) {
                        Image(systemName: "clock")
                            .font(.system(size: 13, weight: .regular))
                        Text(TimeFormat.clock(minute: scheduled.startMinute))
                            .font(Theme.Font.tinyLabel)
                            .tracking(-0.3)
                            .textCase(.uppercase)
                    }
                    .foregroundStyle(Theme.Palette.primary)
                }
                titleField(for: item, completed: completed)
                if !item.tags.isEmpty {
                    TagChipRow(tags: item.tags)
                }
                if expanded && !item.notes.isEmpty {
                    Text(item.notes)
                        .font(Theme.Font.bodyMd)
                        .foregroundStyle(Theme.Palette.onSurfaceVariant)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            Spacer(minLength: 0)
            if !isReadOnly {
                IconActionButton(
                    systemName: "pencil",
                    help: "Edit",
                    visible: hovered
                ) {
                    openDetail?(TaskDetailFocus(item: item, entry: scheduled, startInEditMode: true))
                }
            }
        }
        .padding(16)
        .background(rowBackground(scheduled: scheduled, expanded: expanded, targeted: dropTargetSlot == index))
        .overlay(
            Rectangle()
                .strokeBorder(
                    borderColor(hovered: hovered, targeted: dropTargetSlot == index),
                    lineWidth: 1
                )
        )
        .contentShape(Rectangle())
        .onHover { inside in hoveredID = inside ? item.id : (hoveredID == item.id ? nil : hoveredID) }
        .onTapGesture {
            guard hasDetails else { return }
            if expanded {
                expandedIDs.remove(item.id)
            } else {
                expandedIDs.insert(item.id)
            }
        }
        .draggable(TaskItemDragPayload(id: item.id))
        .dropDestination(for: TaskItemDragPayload.self) { payloads, _ in
            handleDrop(payloads: payloads, targetIndex: index)
        } isTargeted: { targeted in
            dropTargetSlot = targeted ? index : (dropTargetSlot == index ? nil : dropTargetSlot)
        }
    }

    private func rowBackground(scheduled: ScheduleEntry?, expanded: Bool, targeted: Bool) -> Color {
        if targeted { return Theme.Palette.surfaceContainerHigh.opacity(0.6) }
        if expanded { return Theme.Palette.surfaceContainerHigh.opacity(0.7) }
        if scheduled != nil { return Theme.Palette.surfaceContainer }
        return Theme.Palette.surfaceContainerLowest
    }

    private func borderColor(hovered: Bool, targeted: Bool) -> Color {
        if targeted { return Theme.Palette.primary }
        if hovered { return Theme.Palette.primary }
        return Theme.Palette.outlineVariant
    }

    private func emptyRow(index: Int) -> some View {
        let targeted = dropTargetSlot == index
        return HStack(alignment: .top, spacing: 16) {
            SquareCheckbox(isOn: false, action: {})
                .padding(.top, 2)
                .disabled(true)
            Text("Priority \(index + 1)")
                .font(Theme.Font.bodyLg)
                .foregroundStyle(Theme.Palette.outlineVariant)
            Spacer(minLength: 0)
        }
        .padding(16)
        .background(targeted ? Theme.Palette.surfaceContainerHigh.opacity(0.6) : Theme.Palette.surfaceContainerLowest)
        .overlay(
            Rectangle().strokeBorder(
                targeted ? Theme.Palette.primary : Theme.Palette.outlineVariant,
                lineWidth: 1
            )
        )
        .dropDestination(for: TaskItemDragPayload.self) { payloads, _ in
            handleDrop(payloads: payloads, targetIndex: index)
        } isTargeted: { targeted in
            dropTargetSlot = targeted ? index : (dropTargetSlot == index ? nil : dropTargetSlot)
        }
    }

    private func handleDrop(payloads: [TaskItemDragPayload], targetIndex: Int) -> Bool {
        guard !isReadOnly, let payload = payloads.first else { return false }
        guard let item = day.items.first(where: { $0.id == payload.id }) else { return false }
        taskService.moveToTop3Slot(item, at: targetIndex, on: day)
        return true
    }

    @ViewBuilder
    private func titleField(for item: TaskItem, completed: Bool) -> some View {
        Text(item.title)
            .font(Theme.Font.bodyLg)
            .strikethrough(completed)
            .foregroundStyle(completed ? Theme.Palette.outline : Theme.Palette.onSurface)
    }
}

struct SquareCheckbox: View {
    let isOn: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack {
                Rectangle()
                    .strokeBorder(
                        isOn ? Theme.Palette.primary : Theme.Palette.outline,
                        lineWidth: 1.5
                    )
                    .background(
                        Rectangle().fill(isOn ? Theme.Palette.primary : Color.clear)
                    )
                if isOn {
                    Image(systemName: "checkmark")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(Theme.Palette.onPrimary)
                }
            }
            .frame(width: 20, height: 20)
        }
        .buttonStyle(.plain)
    }
}

struct IconActionButton: View {
    let systemName: String
    let help: String
    let visible: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 14, weight: .regular))
                .frame(width: 26, height: 26)
                .foregroundStyle(Theme.Palette.onSurfaceVariant)
                .background(Theme.Palette.surfaceContainerHigh.opacity(visible ? 1 : 0))
        }
        .buttonStyle(.plain)
        .help(help)
        .opacity(visible ? 1 : 0)
        .allowsHitTesting(visible)
    }
}
