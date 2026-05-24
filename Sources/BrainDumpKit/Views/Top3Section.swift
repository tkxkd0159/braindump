import SwiftUI
import SwiftData

public struct Top3Section: View {
    @Environment(\.modelContext) private var context
    let day: Day
    let isReadOnly: Bool
    let openDetail: ((TaskDetailFocus) -> Void)?

    @State private var hoveredID: UUID?
    @State private var expandedIDs: Set<UUID> = []

    public init(
        day: Day,
        isReadOnly: Bool,
        openDetail: ((TaskDetailFocus) -> Void)? = nil
    ) {
        self.day = day
        self.isReadOnly = isReadOnly
        self.openDetail = openDetail
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
                    Top3SlotRow(
                        day: day,
                        isReadOnly: isReadOnly,
                        index: idx,
                        item: item,
                        isHovered: item.map { hoveredID == $0.id } ?? false,
                        isExpanded: item.map { expandedIDs.contains($0.id) } ?? false,
                        openDetail: openDetail,
                        onHoverChange: { inside in
                            guard let item else { return }
                            if inside {
                                hoveredID = item.id
                            } else if hoveredID == item.id {
                                hoveredID = nil
                            }
                        },
                        onTapToggle: {
                            guard let item else { return }
                            if expandedIDs.contains(item.id) {
                                expandedIDs.remove(item.id)
                            } else {
                                expandedIDs.insert(item.id)
                            }
                        }
                    )
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
}

/// One slot in the Top Priorities list. Owns its own `isTargeted` state so
/// the cursor crossing a slot during a drag only re-evaluates this slot's
/// body — not the whole `Top3Section`, which would also reconstruct every
/// sibling slot's `.dropDestination` / `.draggable` and churn the AppKit
/// drag bridge. Hover and expansion state stay on the parent so they
/// follow the item by id, not the slot index.
struct Top3SlotRow: View {
    @Environment(\.modelContext) private var context
    let day: Day
    let isReadOnly: Bool
    let index: Int
    let item: TaskItem?
    let isHovered: Bool
    let isExpanded: Bool
    let openDetail: ((TaskDetailFocus) -> Void)?
    let onHoverChange: (Bool) -> Void
    let onTapToggle: () -> Void

    @State private var isTargeted: Bool = false

    private var taskService: TaskService { TaskService(context: context) }

    private func scheduleEntry(for item: TaskItem) -> ScheduleEntry? {
        day.schedule.first { $0.item?.id == item.id }
    }

    private func isCompleted(_ item: TaskItem) -> Bool {
        day.schedule.contains { $0.item?.id == item.id && $0.isCompleted }
    }

    var body: some View {
        if let item {
            filledRow(item: item)
        } else {
            emptyRow
        }
    }

    private func filledRow(item: TaskItem) -> some View {
        let scheduled = scheduleEntry(for: item)
        let completed = isCompleted(item)
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
                Text(item.title)
                    .font(Theme.Font.bodyLg)
                    .strikethrough(completed)
                    .foregroundStyle(completed ? Theme.Palette.outline : Theme.Palette.onSurface)
                if !item.tags.isEmpty {
                    TagChipRow(tags: item.tags)
                }
                if isExpanded && !item.notes.isEmpty {
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
                    visible: isHovered
                ) {
                    openDetail?(TaskDetailFocus(item: item, entry: scheduled, startInEditMode: true))
                }
            }
        }
        .padding(16)
        .background(rowBackground(scheduled: scheduled))
        .overlay(
            Rectangle()
                .strokeBorder(borderColor, lineWidth: 1)
        )
        .contentShape(Rectangle())
        .onHover { inside in onHoverChange(inside) }
        .onTapGesture {
            guard hasDetails else { return }
            onTapToggle()
        }
        .draggable(TaskItemDragPayload(id: item.id))
        .dropDestination(for: TaskItemDragPayload.self) { payloads, _ in
            handleDrop(payloads: payloads)
        } isTargeted: { targeted in
            isTargeted = targeted
        }
        .contextMenu {
            if !isReadOnly {
                Button("Move to Brain Dump") {
                    taskService.deescalate(item, on: day)
                }
            }
        }
    }

    private var emptyRow: some View {
        HStack(alignment: .top, spacing: 16) {
            SquareCheckbox(isOn: false, action: {})
                .padding(.top, 2)
                .disabled(true)
            Text("Priority \(index + 1)")
                .font(Theme.Font.bodyLg)
                .foregroundStyle(Theme.Palette.outlineVariant)
            Spacer(minLength: 0)
        }
        .padding(16)
        .background(isTargeted ? Theme.Palette.surfaceContainerHigh.opacity(0.6) : Theme.Palette.surfaceContainerLowest)
        .overlay(
            Rectangle().strokeBorder(
                isTargeted ? Theme.Palette.primary : Theme.Palette.outlineVariant,
                lineWidth: 1
            )
        )
        .dropDestination(for: TaskItemDragPayload.self) { payloads, _ in
            handleDrop(payloads: payloads)
        } isTargeted: { targeted in
            isTargeted = targeted
        }
    }

    private func rowBackground(scheduled: ScheduleEntry?) -> Color {
        if isTargeted { return Theme.Palette.surfaceContainerHigh.opacity(0.6) }
        if isExpanded { return Theme.Palette.surfaceContainerHigh.opacity(0.7) }
        if scheduled != nil { return Theme.Palette.surfaceContainer }
        return Theme.Palette.surfaceContainerLowest
    }

    private var borderColor: Color {
        if isTargeted { return Theme.Palette.primary }
        if isHovered { return Theme.Palette.primary }
        return Theme.Palette.outlineVariant
    }

    private func handleDrop(payloads: [TaskItemDragPayload]) -> Bool {
        guard !isReadOnly, let payload = payloads.first else { return false }
        guard let item = day.items.first(where: { $0.id == payload.id }) else { return false }
        if let oldIndex = day.top3ItemIDs.firstIndex(of: item.id), oldIndex == index {
            return false
        }
        // Defer the mutation by one runloop tick: when the source row lives
        // in another section (brain dump), removing it from that ForEach
        // mid-drop-finalize makes AppKit's NSDraggingSession spin for a few
        // seconds tearing down the vanished source. Letting the drop handler
        // return first gives the drag bridge a chance to finish cleanly.
        let day = self.day
        let svc = taskService
        let idx = index
        DispatchQueue.main.async {
            svc.moveToTop3Slot(item, at: idx, on: day)
        }
        return true
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
