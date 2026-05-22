import SwiftUI
import SwiftData

public struct BrainDumpSection: View {
    @Environment(\.modelContext) private var context
    let day: Day
    let isReadOnly: Bool
    let openDetail: ((TaskItem, ScheduleEntry?) -> Void)?

    @State private var newTitle: String = ""
    @State private var hoveredID: UUID?
    @State private var addFocused: Bool = false
    @FocusState private var addFieldFocused: Bool

    public init(
        day: Day,
        isReadOnly: Bool,
        openDetail: ((TaskItem, ScheduleEntry?) -> Void)? = nil
    ) {
        self.day = day
        self.isReadOnly = isReadOnly
        self.openDetail = openDetail
    }

    private var taskService: TaskService { TaskService(context: context) }

    private var brainDumpItems: [TaskItem] {
        let top3 = Set(day.top3ItemIDs)
        return day.items.filter { !top3.contains($0.id) }
    }

    private func scheduleEntry(for item: TaskItem) -> ScheduleEntry? {
        day.schedule.first { $0.item?.id == item.id }
    }

    private func isCompleted(_ item: TaskItem) -> Bool {
        day.schedule.contains { $0.item?.id == item.id && $0.isCompleted }
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            header
            ScrollView(.vertical, showsIndicators: true) {
                VStack(spacing: 12) {
                    ForEach(brainDumpItems, id: \.id) { item in
                        row(for: item)
                    }
                    if !isReadOnly {
                        addRow
                    }
                }
            }
            .frame(maxHeight: 500)
        }
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            Text("Brain Dump")
                .font(Theme.Font.sectionLabelHeavy)
                .tracking(1.4)
                .textCase(.uppercase)
                .foregroundStyle(Theme.Palette.onSurfaceVariant)
            Spacer()
            if !isReadOnly {
                Button {
                    addFieldFocused = true
                } label: {
                    Image(systemName: "plus.circle")
                        .font(.system(size: 18, weight: .regular))
                        .foregroundStyle(Theme.Palette.onSurfaceVariant)
                }
                .buttonStyle(.plain)
                .help("Add brain-dump item")
            }
        }
        .padding(.bottom, 8)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(Theme.Palette.outlineVariant)
                .frame(height: 1)
        }
    }

    private func row(for item: TaskItem) -> some View {
        let scheduled = scheduleEntry(for: item)
        let completed = isCompleted(item)
        let hovered = hoveredID == item.id
        let canPromote = day.top3ItemIDs.count < 3

        return HStack(alignment: .top, spacing: 14) {
            SquareCheckbox(isOn: completed) {
                guard !isReadOnly, let entry = scheduled else { return }
                ScheduleService(context: context).setCompleted(entry, !entry.isCompleted)
            }
            .padding(.top, 2)
            .disabled(isReadOnly || scheduled == nil)

            VStack(alignment: .leading, spacing: 4) {
                titleView(for: item, completed: completed)
            }
            Spacer(minLength: 0)
            if !isReadOnly {
                HStack(spacing: 4) {
                    IconActionButton(
                        systemName: "arrow.up.to.line",
                        help: "Promote to Top Priorities",
                        visible: hovered && canPromote
                    ) {
                        try? taskService.escalate(item, on: day)
                    }
                    IconActionButton(
                        systemName: "xmark",
                        help: "Delete",
                        visible: hovered
                    ) {
                        taskService.delete(item)
                    }
                }
            }
        }
        .padding(14)
        .background(scheduled != nil ? Theme.Palette.surfaceContainer : Theme.Palette.surfaceContainerLowest)
        .overlay(
            Rectangle()
                .strokeBorder(
                    hovered ? Theme.Palette.primary : Theme.Palette.outlineVariant,
                    lineWidth: 1
                )
        )
        .contentShape(Rectangle())
        .onHover { inside in hoveredID = inside ? item.id : (hoveredID == item.id ? nil : hoveredID) }
        .onTapGesture {
            openDetail?(item, scheduled)
        }
        .draggable(TaskItemDragPayload(id: item.id))
    }

    @ViewBuilder
    private func titleView(for item: TaskItem, completed: Bool) -> some View {
        Text(item.title)
            .font(Theme.Font.bodyMd)
            .strikethrough(completed)
            .foregroundStyle(completed ? Theme.Palette.outline : Theme.Palette.onSurface)
    }

    private var addRow: some View {
        HStack(alignment: .center, spacing: 14) {
            SquareCheckbox(isOn: false, action: {})
                .disabled(true)
            TextField("Add new task…", text: $newTitle)
                .textFieldStyle(.plain)
                .font(Theme.Font.bodyMd)
                .foregroundStyle(Theme.Palette.onSurface)
                .focused($addFieldFocused)
                .onSubmit(submitNew)
            Spacer(minLength: 0)
        }
        .padding(14)
        .background(Theme.Palette.surfaceContainerLowest)
        .overlay(
            Rectangle()
                .strokeBorder(
                    addFieldFocused ? Theme.Palette.primary : Theme.Palette.outlineVariant,
                    lineWidth: 1
                )
        )
    }

    private func submitNew() {
        let trimmed = newTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        taskService.addBrainDumpItem(title: trimmed, on: day)
        newTitle = ""
    }
}
