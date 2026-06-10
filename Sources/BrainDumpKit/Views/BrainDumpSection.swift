import SwiftData
import SwiftUI

public struct BrainDumpSection: View {
    @Environment(\.modelContext) private var context
    let day: Day
    let isReadOnly: Bool
    let openDetail: ((TaskDetailFocus) -> Void)?
    let onSchedule: ((TaskItem) -> Void)?

    @State private var newTitle: String = ""
    @State private var newNotes: String = ""
    @State private var newTagDraft: String = ""
    @State private var newTags: [String] = []
    @State private var hoveredID: UUID?
    @State private var expandedIDs: Set<UUID> = []
    @State private var escalateError: String?
    @State private var pendingSwap: PendingSwap?
    @FocusState private var addFocus: AddFieldFocus?

    private enum AddFieldFocus: Hashable { case title, notes }

    struct PendingSwap: Identifiable {
        let id = UUID()
        let incomingItemID: UUID
    }

    public init(
        day: Day,
        isReadOnly: Bool,
        openDetail: ((TaskDetailFocus) -> Void)? = nil,
        onSchedule: ((TaskItem) -> Void)? = nil
    ) {
        self.day = day
        self.isReadOnly = isReadOnly
        self.openDetail = openDetail
        self.onSchedule = onSchedule
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
        // See Top3Section: guard against a detached `day` after Clear Data
        // so we don't fault-resolve `top3ItemIDs` / `items` / `schedule`.
        if day.modelContext != nil {
            VStack(alignment: .leading, spacing: 16) {
                header
                if let escalateError {
                    Text(escalateError)
                        .font(Theme.Font.caption)
                        .foregroundStyle(Theme.Palette.secondary)
                }

                ScrollView(.vertical, showsIndicators: true) {
                    VStack(spacing: 12) {
                        ForEach(brainDumpItems, id: \.id) { item in
                            // A ForEach child can be re-evaluated against an item
                            // the Clear Data wipe just deleted — the section
                            // body's `day.modelContext` guard is bypassed for
                            // individual child updates (that is the crash). Match
                            // Top3SlotRow / ScheduleBlockView: skip a detached
                            // item before `row(for:)` reads any of its attributes.
                            if item.modelContext != nil {
                                row(for: item)
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.top, 2)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .modifier(DemoteDropZone(day: day, isReadOnly: isReadOnly))
            .sheet(item: $pendingSwap) { swap in
                Top3SwapSheet(
                    day: day,
                    incomingItemID: swap.incomingItemID,
                    dismiss: { pendingSwap = nil }
                )
            }
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
                    openDetail?(.create(day: day))
                } label: {
                    Image(systemName: "plus.circle")
                        .font(.system(size: 18, weight: .regular))
                        .foregroundStyle(Theme.Palette.onSurfaceVariant)
                }
                .buttonStyle(.plain)
                .keyboardShortcut("n", modifiers: [.command])
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
        .contextMenu {
            if !isReadOnly {
                Button("Schedule") {
                    onSchedule?(item)
                }
                Button("Move to Priority") {
                    do {
                        try taskService.escalate(item, on: day)
                        escalateError = nil
                    } catch TodoError.top3Full {
                        escalateError = nil
                        pendingSwap = PendingSwap(incomingItemID: item.id)
                    } catch {
                        escalateError = "Could not move"
                    }
                }
                Button("Move to Backlog") {
                    BacklogService(context: context).moveToBacklog(item)
                }
            }
        }
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

/// Sheet shown when escalating an item to Top 3 but the slot is full.
/// Lets the user pick which existing priority to swap out — the chosen
/// priority falls back to the brain dump and the incoming item takes
/// its slot.
struct Top3SwapSheet: View {
    @Environment(\.modelContext) private var context
    let day: Day
    let incomingItemID: UUID
    let dismiss: () -> Void

    private var taskService: TaskService { TaskService(context: context) }

    private var incomingItem: TaskItem? {
        day.items.first { $0.id == incomingItemID }
    }

    private var priorityItems: [(index: Int, item: TaskItem)] {
        day.top3ItemIDs.enumerated().compactMap { (idx, id) in
            guard let item = day.items.first(where: { $0.id == id }) else { return nil }
            return (idx, item)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            header
            if let incoming = incomingItem {
                Text("Top 3 is full. Choose a priority to swap with:")
                    .font(Theme.Font.bodyMd)
                    .foregroundStyle(Theme.Palette.onSurfaceVariant)
                Text(incoming.title)
                    .font(Theme.Font.bodyLgSemibold)
                    .foregroundStyle(Theme.Palette.onSurface)
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Theme.Palette.surfaceContainer)
                    .overlay(Rectangle().strokeBorder(Theme.Palette.outlineVariant, lineWidth: 1))
            }
            VStack(spacing: 8) {
                ForEach(priorityItems, id: \.item.id) { entry in
                    swapRow(index: entry.index, item: entry.item)
                }
            }
            footer
        }
        .padding(28)
        .frame(width: 480)
        .background(Theme.Palette.surfaceContainerLowest)
    }

    private var header: some View {
        Text("Swap Priority")
            .font(Theme.Font.tinyLabel)
            .tracking(1.5)
            .textCase(.uppercase)
            .foregroundStyle(Theme.Palette.primary)
    }

    private func swapRow(index: Int, item: TaskItem) -> some View {
        Button(action: { performSwap(at: index) }) {
            HStack(spacing: 12) {
                Text("\(index + 1)")
                    .font(Theme.Font.labelMd)
                    .tracking(0.5)
                    .foregroundStyle(Theme.Palette.primary)
                    .frame(width: 24, height: 24)
                    .overlay(Rectangle().strokeBorder(Theme.Palette.primary, lineWidth: 1))
                Text(item.title)
                    .font(Theme.Font.bodyMd)
                    .foregroundStyle(Theme.Palette.onSurface)
                    .lineLimit(1)
                Spacer(minLength: 0)
                Image(systemName: "arrow.left.arrow.right")
                    .font(.system(size: 13, weight: .regular))
                    .foregroundStyle(Theme.Palette.onSurfaceVariant)
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.Palette.surfaceContainerLowest)
            .overlay(Rectangle().strokeBorder(Theme.Palette.outlineVariant, lineWidth: 1))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var footer: some View {
        HStack {
            Spacer()
            Button("Cancel", action: dismiss)
                .buttonStyle(.plain)
                .font(Theme.Font.labelMd)
                .padding(.horizontal, 18)
                .frame(height: 34)
                .foregroundStyle(Theme.Palette.primary)
                .overlay(Rectangle().strokeBorder(Theme.Palette.primary, lineWidth: 1))
                .keyboardShortcut(.cancelAction)
        }
    }

    private func performSwap(at index: Int) {
        guard let incoming = incomingItem else {
            dismiss()
            return
        }
        taskService.moveToTop3Slot(incoming, at: index, on: day)
        dismiss()
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

    @State private var wasTargeted: Bool = false

    func body(content: Content) -> some View {
        content
            .contentShape(Rectangle())
            .dropDestination(for: TaskItemDragPayload.self) { payloads, _ in
                defer { wasTargeted = false }
                // Reject the synthetic drop SwiftUI delivers when the user
                // press-and-releases on the source row without the cursor
                // ever entering the demote zone.
                guard wasTargeted else { return false }
                return handleDrop(payloads: payloads)
            } isTargeted: { targeted in
                if targeted && !isReadOnly && !day.top3ItemIDs.isEmpty {
                    wasTargeted = true
                }
            }
    }

    private func handleDrop(payloads: [TaskItemDragPayload]) -> Bool {
        guard !isReadOnly, let payload = payloads.first else { return false }
        guard day.top3ItemIDs.contains(payload.id) else { return false }
        guard let item = day.items.first(where: { $0.id == payload.id }) else { return false }
        // Match the escalate path: defer the mutation so the drag bridge
        // can finish tearing down before the source row's view tree shifts.
        let day = self.day
        let context = self.context
        DispatchQueue.main.async {
            TaskService(context: context).deescalate(item, on: day)
        }
        return true
    }
}
