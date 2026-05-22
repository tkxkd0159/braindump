import SwiftUI
import SwiftData

public struct BrainDumpSection: View {
    @Environment(\.modelContext) private var context
    let day: Day
    let isReadOnly: Bool
    let openDetail: ((TaskItem, ScheduleEntry?) -> Void)?

    @State private var newTitle: String = ""
    @State private var newNotes: String = ""
    @State private var newTagDraft: String = ""
    @State private var newTags: [String] = []
    @State private var hoveredID: UUID?
    @State private var expandedIDs: Set<UUID> = []
    @FocusState private var addFocus: AddFieldFocus?

    private enum AddFieldFocus: Hashable { case title, notes, tag }

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
                    addFocus = .title
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
        let expanded = expandedIDs.contains(item.id)
        let canPromote = day.top3ItemIDs.count < 3
        let hasDetails = !item.notes.isEmpty || !item.tags.isEmpty

        return HStack(alignment: .top, spacing: 14) {
            SquareCheckbox(isOn: completed) {
                guard !isReadOnly, let entry = scheduled else { return }
                ScheduleService(context: context).setCompleted(entry, !entry.isCompleted)
            }
            .padding(.top, 2)
            .disabled(isReadOnly || scheduled == nil)

            VStack(alignment: .leading, spacing: 6) {
                titleView(for: item, completed: completed)
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
                HStack(spacing: 4) {
                    IconActionButton(
                        systemName: "xmark",
                        help: "Delete",
                        visible: hovered
                    ) {
                        taskService.delete(item)
                    }
                    IconActionButton(
                        systemName: "pencil",
                        help: "Edit",
                        visible: hovered
                    ) {
                        openDetail?(item, scheduled)
                    }
                    IconActionButton(
                        systemName: "arrow.up.to.line",
                        help: "Promote to Top Priorities",
                        visible: hovered && canPromote
                    ) {
                        try? taskService.escalate(item, on: day)
                    }
                }
            }
        }
        .padding(14)
        .background(rowBackground(scheduled: scheduled, expanded: expanded))
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
            guard hasDetails else { return }
            if expanded {
                expandedIDs.remove(item.id)
            } else {
                expandedIDs.insert(item.id)
            }
        }
        .draggable(TaskItemDragPayload(id: item.id))
    }

    private func rowBackground(scheduled: ScheduleEntry?, expanded: Bool) -> Color {
        if expanded { return Theme.Palette.surfaceContainerHigh.opacity(0.7) }
        if scheduled != nil { return Theme.Palette.surfaceContainer }
        return Theme.Palette.surfaceContainerLowest
    }

    @ViewBuilder
    private func titleView(for item: TaskItem, completed: Bool) -> some View {
        Text(item.title)
            .font(Theme.Font.bodyMd)
            .strikethrough(completed)
            .foregroundStyle(completed ? Theme.Palette.outline : Theme.Palette.onSurface)
    }

    private var addRow: some View {
        let isFocused = addFocus != nil
        let shouldExpand = isFocused || !newNotes.isEmpty || !newTags.isEmpty || !newTagDraft.isEmpty

        return VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .center, spacing: 14) {
                SquareCheckbox(isOn: false, action: {})
                    .disabled(true)
                TextField("Add new task…", text: $newTitle)
                    .textFieldStyle(.plain)
                    .font(Theme.Font.bodyMd)
                    .foregroundStyle(Theme.Palette.onSurface)
                    .focused($addFocus, equals: .title)
                    .onSubmit(submitNew)
                Spacer(minLength: 0)
            }
            if shouldExpand {
                VStack(alignment: .leading, spacing: 8) {
                    TextField("Description (optional)", text: $newNotes)
                        .textFieldStyle(.plain)
                        .font(Theme.Font.bodyMd)
                        .foregroundStyle(Theme.Palette.onSurfaceVariant)
                        .padding(8)
                        .background(Theme.Palette.surfaceContainer)
                        .overlay(Rectangle().strokeBorder(Theme.Palette.outlineVariant, lineWidth: 1))
                        .focused($addFocus, equals: .notes)
                        .onSubmit(submitNew)
                    if !newTags.isEmpty {
                        TagChipRow(tags: newTags)
                    }
                    HStack(spacing: 6) {
                        TextField("Add tag…", text: $newTagDraft)
                            .textFieldStyle(.plain)
                            .font(Theme.Font.caption)
                            .padding(.horizontal, 8)
                            .frame(height: 26)
                            .background(Theme.Palette.surfaceContainer)
                            .overlay(Rectangle().strokeBorder(Theme.Palette.outlineVariant, lineWidth: 1))
                            .focused($addFocus, equals: .tag)
                            .onSubmit(commitTag)
                        Button("Add tag", action: commitTag)
                            .buttonStyle(.plain)
                            .font(Theme.Font.caption)
                            .padding(.horizontal, 10)
                            .frame(height: 26)
                            .foregroundStyle(Theme.Palette.primary)
                            .overlay(Rectangle().strokeBorder(Theme.Palette.primary, lineWidth: 1))
                            .disabled(newTagDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        Spacer(minLength: 0)
                        Button("Save", action: submitNew)
                            .buttonStyle(.plain)
                            .font(Theme.Font.labelMd)
                            .padding(.horizontal, 12)
                            .frame(height: 28)
                            .foregroundStyle(Theme.Palette.onPrimary)
                            .background(Theme.Palette.primary)
                            .disabled(newTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                }
                .padding(.leading, 34)
            }
        }
        .padding(14)
        .background(Theme.Palette.surfaceContainerLowest)
        .overlay(
            Rectangle()
                .strokeBorder(
                    isFocused ? Theme.Palette.primary : Theme.Palette.outlineVariant,
                    lineWidth: 1
                )
        )
    }

    private func commitTag() {
        let trimmed = newTagDraft.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        defer { newTagDraft = "" }
        guard !trimmed.isEmpty, !newTags.contains(trimmed) else { return }
        newTags.append(trimmed)
        addFocus = .tag
    }

    private func submitNew() {
        let trimmedTitle = newTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedTitle.isEmpty else { return }
        if !newTagDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            commitTag()
        }
        taskService.addBrainDumpItem(
            title: trimmedTitle,
            notes: newNotes.trimmingCharacters(in: .whitespacesAndNewlines),
            tags: newTags,
            on: day
        )
        newTitle = ""
        newNotes = ""
        newTags = []
        newTagDraft = ""
        addFocus = nil
    }
}
