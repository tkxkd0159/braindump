import SwiftData
import SwiftUI

public enum TaskDetailFocus: Identifiable {
    case create(day: Day)
    case createBacklog
    case edit(item: TaskItem, entry: ScheduleEntry?, startInEditMode: Bool)

    public var id: String {
        switch self {
        case .create(let day):
            return "create-\(day.persistentModelID.hashValue)"
        case .createBacklog:
            return "create-backlog"
        case .edit(let item, _, _):
            return "edit-\(item.id.uuidString)"
        }
    }

    /// Compatibility initializer for call sites that pass (item:entry:startInEditMode:).
    /// Always returns `.edit(...)`.
    public init(item: TaskItem, entry: ScheduleEntry? = nil, startInEditMode: Bool = true) {
        self = .edit(item: item, entry: entry, startInEditMode: startInEditMode)
    }
}

public struct TaskDetailSheet: View {
    @Environment(\.modelContext) private var context
    let focus: TaskDetailFocus
    let dismiss: () -> Void

    @State private var isEditing: Bool
    @State private var title: String
    @State private var notes: String
    @State private var tags: [String]
    @State private var newTagDraft: String = ""
    @State private var startMinute: Int
    @State private var endMinute: Int
    @State private var colorIndex: Int
    @State private var customColorHex: String?
    @State private var scheduleEnabled: Bool
    /// Minutes-before-start lead time for the reminder (`nil` = no reminder).
    @State private var reminderOffset: Int?
    @State private var errorText: String?
    @State private var reminderAlert: String?

    /// Cached tag suggestions. Fetched once on first appearance — otherwise
    /// every keystroke in the title/notes fields would re-run `allTags()`
    /// (a full `TaskItem` table scan + Set+Sort) via `tagsField`'s body.
    @State private var cachedKnownTags: [String] = []
    @State private var didLoadTags: Bool = false

    private let startInEditModeAtInit: Bool
    /// Injected clock for the "later than now" reminder check.
    private let now: Date

    public init(focus: TaskDetailFocus, dismiss: @escaping () -> Void, now: Date = Date()) {
        self.focus = focus
        self.dismiss = dismiss
        self.now = now
        switch focus {
        case .create, .createBacklog:
            _isEditing = State(initialValue: true)
            _title = State(initialValue: "")
            _notes = State(initialValue: "")
            _tags = State(initialValue: [])
            _startMinute = State(initialValue: 9 * 60)
            _endMinute = State(initialValue: 10 * 60)
            _colorIndex = State(initialValue: 0)
            _customColorHex = State(initialValue: nil)
            _scheduleEnabled = State(initialValue: false)
            _reminderOffset = State(initialValue: nil)
            startInEditModeAtInit = true
        case .edit(let item, let entry, let startInEditMode):
            _isEditing = State(initialValue: startInEditMode)
            _title = State(initialValue: item.title)
            _notes = State(initialValue: item.notes)
            _tags = State(initialValue: item.tags)
            if let entry {
                _startMinute = State(initialValue: entry.startMinute)
                _endMinute = State(initialValue: entry.endMinute)
                _colorIndex = State(initialValue: entry.colorIndex)
                _customColorHex = State(initialValue: entry.customColorHex)
                _scheduleEnabled = State(initialValue: true)
                // Derive the "N before" lead time from the stored absolute
                // reminder (or a legacy offset, which is already a lead time).
                // Clamp ≥ 0 so a block dragged earlier than its reminder reads
                // as "0 minutes" rather than a negative lead time.
                _reminderOffset = State(initialValue:
                    entry.reminderMinuteOfDay.map { max(0, entry.startMinute - $0) }
                        ?? entry.reminderOffsetMinutes)
            } else {
                _startMinute = State(initialValue: 9 * 60)
                _endMinute = State(initialValue: 10 * 60)
                _colorIndex = State(initialValue: 0)
                _customColorHex = State(initialValue: nil)
                _scheduleEnabled = State(initialValue: false)
                _reminderOffset = State(initialValue: nil)
            }
            startInEditModeAtInit = startInEditMode
        }
    }

    private var focusItem: TaskItem? {
        if case .edit(let item, _, _) = focus { return item }
        return nil
    }

    private var focusEntry: ScheduleEntry? {
        if case .edit(_, let entry, _) = focus { return entry }
        return nil
    }

    private var focusDay: Day? {
        switch focus {
        case .create(let day): return day
        case .createBacklog: return nil
        case .edit(let item, _, _): return item.day
        }
    }

    private var isCreateMode: Bool {
        switch focus {
        case .create, .createBacklog: return true
        case .edit: return false
        }
    }

    private var isBacklogCreate: Bool {
        if case .createBacklog = focus { return true }
        return false
    }

    public var body: some View {
        Group {
            if isCreateMode || isEditing {
                editBody
            } else {
                readOnlyBody
            }
        }
        .padding(28)
        .frame(width: 480)
        .background(Theme.Palette.surfaceContainerLowest)
        .onAppear {
            guard !didLoadTags else { return }
            cachedKnownTags = TaskService(context: context).allTags()
            didLoadTags = true
        }
        .alert("Reminder", isPresented: Binding(
            get: { reminderAlert != nil },
            set: { if !$0 { reminderAlert = nil } })
        ) {
            Button("OK", role: .cancel) { reminderAlert = nil }
        } message: {
            Text(reminderAlert ?? "")
        }
    }

    // MARK: - Edit mode

    private var editBody: some View {
        VStack(alignment: .leading, spacing: 20) {
            editHeader
            titleField
            notesField
            tagsField
            scheduleSection
            if let errorText {
                Text(errorText)
                    .font(Theme.Font.caption)
                    .foregroundStyle(Theme.Palette.secondary)
            }
            footer
        }
    }

    private var editHeader: some View {
        Text(isCreateMode ? "New Task" : "Task")
            .font(Theme.Font.tinyLabel)
            .tracking(1.5)
            .textCase(.uppercase)
            .foregroundStyle(Theme.Palette.primary)
    }

    @ViewBuilder
    private var scheduleSection: some View {
        if isBacklogCreate {
            EmptyView()
        } else if !isCreateMode, focusEntry != nil {
            VStack(alignment: .leading, spacing: 8) {
                Text("Time Block")
                    .font(Theme.Font.tinyLabel)
                    .tracking(1.2)
                    .foregroundStyle(Theme.Palette.onSurfaceVariant)
                TimeRangePicker(
                    startMinute: $startMinute,
                    endMinute: $endMinute
                )
                ColorField(selected: $colorIndex, customHex: $customColorHex)
                reminderRow
            }
        } else {
            VStack(alignment: .leading, spacing: 10) {
                Toggle(isOn: $scheduleEnabled) {
                    Text("Add to Schedule")
                        .font(Theme.Font.bodyMd)
                        .foregroundStyle(Theme.Palette.onSurface)
                }
                .toggleStyle(.switch)
                if scheduleEnabled {
                    TimeRangePicker(
                        startMinute: $startMinute,
                        endMinute: $endMinute
                    )
                    ColorField(selected: $colorIndex, customHex: $customColorHex)
                    reminderRow
                }
            }
        }
    }

    private var reminderRow: some View {
        ReminderOffsetRow(offsetMinutes: $reminderOffset)
    }

    /// Enforce "within the day, later than now" on the resolved reminder time;
    /// surface an alert otherwise.
    private func validateReminder(minuteOfDay: Int?, dayStart: Date) -> Bool {
        guard let minuteOfDay else { return true }
        let result = ReminderTime.validate(minuteOfDay: minuteOfDay, dayStart: dayStart, now: now)
        reminderAlert = ReminderTime.alertMessage(for: result)
        return reminderAlert == nil
    }

    private var titleField: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Title")
                .font(Theme.Font.tinyLabel)
                .tracking(1.2)
                .foregroundStyle(Theme.Palette.onSurfaceVariant)
            TextField("Title", text: $title)
                .textFieldStyle(.plain)
                .font(Theme.Font.bodyLgSemibold)
                .foregroundStyle(Theme.Palette.onSurface)
                .padding(10)
                .background(Theme.Palette.surfaceContainer)
                .overlay(Rectangle().strokeBorder(Theme.Palette.outlineVariant, lineWidth: 1))
        }
    }

    private var notesField: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Description")
                .font(Theme.Font.tinyLabel)
                .tracking(1.2)
                .foregroundStyle(Theme.Palette.onSurfaceVariant)
            TextEditor(text: $notes)
                .font(Theme.Font.bodyMd)
                .foregroundStyle(Theme.Palette.onSurface)
                .scrollContentBackground(.hidden)
                .frame(minHeight: 80, maxHeight: 140)
                .padding(8)
                .background(Theme.Palette.surfaceContainer)
                .overlay(Rectangle().strokeBorder(Theme.Palette.outlineVariant, lineWidth: 1))
        }
    }

    private var tagsField: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Tags")
                .font(Theme.Font.tinyLabel)
                .tracking(1.2)
                .foregroundStyle(Theme.Palette.onSurfaceVariant)
            TagInputField(
                tags: $tags,
                draft: $newTagDraft,
                allKnownTags: cachedKnownTags
            )
        }
    }

    private var footer: some View {
        HStack(spacing: 12) {
            Spacer()
            Button("Cancel", action: cancelEdit)
                .buttonStyle(SecondaryActionStyle())
                .keyboardShortcut(.cancelAction)
            Button(isCreateMode ? "Add" : "Done", action: commit)
                .buttonStyle(PrimaryActionStyle())
                .keyboardShortcut(.defaultAction)
        }
    }

    private func cancelEdit() {
        if isCreateMode || startInEditModeAtInit {
            dismiss()
            return
        }
        title = focusItem?.title ?? ""
        notes = focusItem?.notes ?? ""
        tags = focusItem?.tags ?? []
        newTagDraft = ""
        if let entry = focusEntry {
            startMinute = entry.startMinute
            endMinute = entry.endMinute
            colorIndex = entry.colorIndex
            customColorHex = entry.customColorHex
            reminderOffset = entry.reminderMinuteOfDay.map { max(0, entry.startMinute - $0) }
                ?? entry.reminderOffsetMinutes
            scheduleEnabled = true
        } else {
            customColorHex = nil
            reminderOffset = nil
            scheduleEnabled = false
        }
        errorText = nil
        isEditing = false
    }

    private func commit() {
        let taskService = TaskService(context: context)
        let scheduleService = ScheduleService(context: context)
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)

        let item: TaskItem
        switch focus {
        case .create(let day):
            guard !trimmedTitle.isEmpty else {
                errorText = "Title is required"
                return
            }
            item = taskService.addBrainDumpItem(
                title: trimmedTitle,
                notes: notes.trimmingCharacters(in: .whitespacesAndNewlines),
                tags: tags,
                on: day
            )
        case .createBacklog:
            guard !trimmedTitle.isEmpty else {
                errorText = "Title is required"
                return
            }
            _ = BacklogService(context: context).addBacklogItem(
                title: trimmedTitle,
                notes: notes.trimmingCharacters(in: .whitespacesAndNewlines),
                tags: tags
            )
            dismiss()
            return
        case .edit(let existing, _, _):
            item = existing
            if !trimmedTitle.isEmpty, trimmedTitle != existing.title {
                taskService.rename(existing, to: trimmedTitle)
            }
            if notes != existing.notes {
                taskService.updateNotes(existing, notes: notes)
            }
            if tags != existing.tags {
                taskService.updateTags(existing, tags: tags)
            }
        }

        let entry = focusEntry
        let wantsSchedule = scheduleEnabled || entry != nil
        if wantsSchedule, let day = focusDay {
            let start = TimeRangePicker.snap(minute: startMinute)
            let end = TimeRangePicker.snap(minute: endMinute)
            guard end > start else {
                errorText = "End must be after start"
                return
            }
            let duration = end - start
            // Resolve the "N before" lead time against the (snapped) start; the
            // store stays absolute, so only the input style changed.
            let reminderMinuteOfDay = reminderOffset.map { start - $0 }
            guard validateReminder(minuteOfDay: reminderMinuteOfDay, dayStart: day.date) else { return }
            do {
                if let entry {
                    let timeChanged = entry.startMinute != start || entry.durationMinutes != duration
                    if timeChanged {
                        try scheduleService.reschedule(entry, startMinute: start, durationMinutes: duration)
                    }
                    if entry.colorIndex != colorIndex || entry.customColorHex != customColorHex {
                        scheduleService.setColorIndex(entry, colorIndex) // clears any custom
                        if let customColorHex { scheduleService.setCustomColor(entry, customColorHex) }
                    }
                    scheduleService.setReminderMinuteOfDay(entry, reminderMinuteOfDay)
                } else {
                    _ = try scheduleService.schedule(
                        item,
                        on: day,
                        startMinute: start,
                        durationMinutes: duration,
                        colorIndex: colorIndex,
                        customColorHex: customColorHex,
                        reminderMinuteOfDay: reminderMinuteOfDay
                    )
                }
            } catch TodoError.scheduleConflict {
                errorText = "Conflicts with another block"
                return
            } catch TodoError.scheduleOutOfRange {
                errorText = "Time range is out of bounds"
                return
            } catch {
                errorText = "Could not schedule"
                return
            }
        }
        dismiss()
    }

    // MARK: - Read-only mode

    @ViewBuilder
    private var readOnlyBody: some View {
        if let item = focusItem {
            readOnlyContent(item: item)
        }
    }

    private func readOnlyContent(item: TaskItem) -> some View {
        VStack(alignment: .leading, spacing: 20) {
            readOnlyHeader
            Text(item.title)
                .font(Theme.Font.headlineMd)
                .foregroundStyle(Theme.Palette.onSurface)
                .fixedSize(horizontal: false, vertical: true)
            if !item.notes.isEmpty {
                readOnlySection("Description") {
                    Text(NoteText.linkified(item.notes))
                        .font(Theme.Font.bodyMd)
                        .foregroundStyle(Theme.Palette.onSurface)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            if !item.tags.isEmpty {
                readOnlySection("Tags") {
                    TagChipRow(tags: item.tags)
                }
            }
            if let entry = focusEntry {
                HStack(spacing: 10) {
                    Rectangle()
                        .fill(Theme.BlockPalette.color(at: entry.colorIndex, customHex: entry.customColorHex))
                        .frame(width: 12, height: 12)
                    Text(
                        TimeFormat.range(
                            startMinute: entry.startMinute,
                            durationMinutes: entry.durationMinutes)
                    )
                    .font(Theme.Font.bodyMd)
                    .foregroundStyle(Theme.Palette.onSurface)
                    if entry.isCompleted {
                        Image(systemName: "checkmark")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(Theme.Palette.primary)
                    }
                }
            }
            Spacer(minLength: 0)
            readOnlyFooter
        }
        .frame(minHeight: 220, alignment: .topLeading)
    }

    private var readOnlyHeader: some View {
        HStack(alignment: .center) {
            Text("Task")
                .font(Theme.Font.tinyLabel)
                .tracking(1.5)
                .textCase(.uppercase)
                .foregroundStyle(Theme.Palette.primary)
            Spacer()
        }
    }

    private func readOnlySection<Content: View>(
        _ label: String, @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label.uppercased())
                .font(Theme.Font.tinyLabel)
                .tracking(1.2)
                .foregroundStyle(Theme.Palette.onSurfaceVariant)
            content()
        }
    }

    private var readOnlyFooter: some View {
        HStack {
            Spacer()
            Button("Close", action: dismiss)
                .buttonStyle(SecondaryActionStyle())
                .keyboardShortcut(.cancelAction)
        }
    }
}

/// Minimal wrapping layout for tag chips. Lays children left-to-right and
/// wraps to the next row when out of width.
struct FlowLayout: Layout {
    var spacing: CGFloat = 6

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > maxWidth, x > 0 {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
        let totalHeight = y + rowHeight
        return CGSize(width: maxWidth.isFinite ? maxWidth : x, height: totalHeight)
    }

    func placeSubviews(
        in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()
    ) {
        var x: CGFloat = bounds.minX
        var y: CGFloat = bounds.minY
        var rowHeight: CGFloat = 0
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > bounds.maxX, x > bounds.minX {
                x = bounds.minX
                y += rowHeight + spacing
                rowHeight = 0
            }
            subview.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}
