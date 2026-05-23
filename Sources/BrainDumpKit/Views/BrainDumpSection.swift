import SwiftData
import SwiftUI

public struct BrainDumpSection: View {
    @Environment(\.modelContext) private var context
    let day: Day
    let isReadOnly: Bool
    let openDetail: ((TaskDetailFocus) -> Void)?

    @State private var newTitle: String = ""
    @State private var newNotes: String = ""
    @State private var newTagDraft: String = ""
    @State private var newTags: [String] = []
    @State private var hoveredID: UUID?
    @State private var expandedIDs: Set<UUID> = []
    @FocusState private var addFocus: AddFieldFocus?

    private enum AddFieldFocus: Hashable { case title, notes }

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
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(maxHeight: 500)
        }
        .modifier(DemoteDropZone(day: day, isReadOnly: isReadOnly))
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
                    openDetail?(.create(day: day))
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
                        openDetail?(
                            TaskDetailFocus(item: item, entry: scheduled, startInEditMode: true))
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
        .onHover { inside in hoveredID = inside ? item.id : (hoveredID == item.id ? nil : hoveredID)
        }
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
        let shouldExpand =
            isFocused || !newNotes.isEmpty || !newTags.isEmpty || !newTagDraft.isEmpty

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
                    .onKeyPress(.escape) { handleEscape() }
                Spacer(minLength: 0)
            }
            if shouldExpand {
                VStack(alignment: .leading, spacing: 8) {
                    TextField("Description", text: $newNotes)
                        .textFieldStyle(.plain)
                        .font(Theme.Font.bodyMd)
                        .foregroundStyle(Theme.Palette.onSurfaceVariant)
                        .padding(8)
                        .background(Theme.Palette.surfaceContainer)
                        .overlay(
                            Rectangle().strokeBorder(Theme.Palette.outlineVariant, lineWidth: 1)
                        )
                        .focused($addFocus, equals: .notes)
                        .onSubmit(submitNew)
                        .onKeyPress(.escape) { handleEscape() }
                    TagInputField(
                        tags: $newTags,
                        draft: $newTagDraft,
                        allKnownTags: taskService.allTags(),
                        isCompact: true
                    )
                    HStack(spacing: 6) {
                        Spacer(minLength: 0)
                        Button("Save", action: submitNew)
                            .buttonStyle(.plain)
                            .font(Theme.Font.labelMd)
                            .padding(.horizontal, 12)
                            .frame(height: 28)
                            .foregroundStyle(Theme.Palette.onPrimary)
                            .background(Theme.Palette.primary)
                            .disabled(
                                newTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
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

    private func submitNew() {
        let trimmedTitle = newTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedTitle.isEmpty else { return }
        let trimmedTagDraft = newTagDraft.trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
        if !trimmedTagDraft.isEmpty, !newTags.contains(trimmedTagDraft) {
            newTags.append(trimmedTagDraft)
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

    private func handleEscape() -> KeyPress.Result {
        let trimmedTitle = newTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmedTitle.isEmpty {
            newTitle = ""
            newNotes = ""
            newTags = []
            newTagDraft = ""
            addFocus = nil
        } else {
            submitNew()
        }
        return .handled
    }
}

/// Owns the section-level drop target that demotes a Top3 item back into
/// the brain dump. State lives here so the targeted-border opacity flip
/// doesn't re-evaluate the section's ScrollView (and every row inside it)
/// each time a drag enters or leaves the section.
struct DemoteDropZone: ViewModifier {
    @Environment(\.modelContext) private var context
    let day: Day
    let isReadOnly: Bool

    @State private var isDropTargeted: Bool = false
    @State private var wasTargeted: Bool = false

    func body(content: Content) -> some View {
        content
            .contentShape(Rectangle())
            .overlay(
                Rectangle()
                    .strokeBorder(Theme.Palette.primary, lineWidth: 1)
                    .opacity(isDropTargeted ? 1 : 0)
                    .padding(-4)
                    .allowsHitTesting(false)
            )
            .dropDestination(for: TaskItemDragPayload.self) { payloads, _ in
                defer { wasTargeted = false }
                // Reject the synthetic drop SwiftUI delivers when the user
                // press-and-releases on the source row without the cursor
                // ever entering the demote zone.
                guard wasTargeted else { return false }
                return handleDrop(payloads: payloads)
            } isTargeted: { targeted in
                let active = targeted && !isReadOnly && !day.top3ItemIDs.isEmpty
                isDropTargeted = active
                if active { wasTargeted = true }
            }
    }

    private func handleDrop(payloads: [TaskItemDragPayload]) -> Bool {
        guard !isReadOnly, let payload = payloads.first else { return false }
        guard day.top3ItemIDs.contains(payload.id) else { return false }
        guard let item = day.items.first(where: { $0.id == payload.id }) else { return false }
        TaskService(context: context).deescalate(item, on: day)
        return true
    }
}
