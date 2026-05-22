import SwiftUI
import SwiftData

public struct TaskDetailFocus: Identifiable {
    public let id = UUID()
    public let item: TaskItem
    public let entry: ScheduleEntry?

    public init(item: TaskItem, entry: ScheduleEntry? = nil) {
        self.item = item
        self.entry = entry
    }
}

public struct TaskDetailSheet: View {
    @Environment(\.modelContext) private var context
    let focus: TaskDetailFocus
    let dismiss: () -> Void

    @State private var title: String
    @State private var notes: String
    @State private var tags: [String]
    @State private var newTagDraft: String = ""
    @State private var startHour: Int
    @State private var durationHours: Int
    @State private var colorIndex: Int
    @State private var errorText: String?

    private let hasEntry: Bool

    public init(focus: TaskDetailFocus, dismiss: @escaping () -> Void) {
        self.focus = focus
        self.dismiss = dismiss
        _title = State(initialValue: focus.item.title)
        _notes = State(initialValue: focus.item.notes)
        _tags = State(initialValue: focus.item.tags)
        if let entry = focus.entry {
            _startHour = State(initialValue: entry.startHour)
            _durationHours = State(initialValue: entry.durationHours)
            _colorIndex = State(initialValue: entry.colorIndex)
            hasEntry = true
        } else {
            _startHour = State(initialValue: 9)
            _durationHours = State(initialValue: 1)
            _colorIndex = State(initialValue: 0)
            hasEntry = false
        }
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            header
            titleField
            notesField
            tagsField
            if hasEntry {
                scheduleEditor
                colorPicker
            }
            if let errorText {
                Text(errorText)
                    .font(Theme.Font.caption)
                    .foregroundStyle(Theme.Palette.secondary)
            }
            footer
        }
        .padding(28)
        .frame(width: 480)
        .background(Theme.Palette.surfaceContainerLowest)
    }

    private var header: some View {
        Text("Task")
            .font(Theme.Font.tinyLabel)
            .tracking(1.5)
            .textCase(.uppercase)
            .foregroundStyle(Theme.Palette.primary)
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
            if !tags.isEmpty {
                FlowLayout(spacing: 6) {
                    ForEach(tags, id: \.self) { tag in
                        tagChip(tag)
                    }
                }
            }
            HStack(spacing: 8) {
                TextField("Add tag…", text: $newTagDraft)
                    .textFieldStyle(.plain)
                    .font(Theme.Font.bodyMd)
                    .padding(8)
                    .background(Theme.Palette.surfaceContainer)
                    .overlay(Rectangle().strokeBorder(Theme.Palette.outlineVariant, lineWidth: 1))
                    .onSubmit(addTag)
                Button("Add", action: addTag)
                    .buttonStyle(.plain)
                    .font(Theme.Font.labelMd)
                    .padding(.horizontal, 12)
                    .frame(height: 32)
                    .foregroundStyle(Theme.Palette.primary)
                    .overlay(Rectangle().strokeBorder(Theme.Palette.primary, lineWidth: 1))
            }
        }
    }

    private func tagChip(_ tag: String) -> some View {
        HStack(spacing: 4) {
            Text(tag)
                .font(Theme.Font.caption)
                .foregroundStyle(Theme.Palette.onSurface)
            Button(action: { tags.removeAll { $0 == tag } }) {
                Image(systemName: "xmark")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(Theme.Palette.onSurfaceVariant)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Theme.Palette.surfaceContainerHigh)
    }

    private var scheduleEditor: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Time Block")
                .font(Theme.Font.tinyLabel)
                .tracking(1.2)
                .foregroundStyle(Theme.Palette.onSurfaceVariant)
            HStack(spacing: 16) {
                Stepper(value: $startHour, in: 5...22) {
                    Text("Start: \(formattedHour(startHour))")
                        .font(Theme.Font.bodyMd)
                }
                Stepper(value: $durationHours, in: 1...max(1, 24 - startHour)) {
                    Text("Duration: \(durationHours)h")
                        .font(Theme.Font.bodyMd)
                }
            }
        }
    }

    private var colorPicker: some View {
        ColorSwatchRow(selected: $colorIndex)
    }

    private var footer: some View {
        HStack(spacing: 12) {
            Spacer()
            Button("Cancel", action: dismiss)
                .buttonStyle(.plain)
                .font(Theme.Font.labelMd)
                .padding(.horizontal, 18)
                .frame(height: 34)
                .foregroundStyle(Theme.Palette.primary)
                .overlay(Rectangle().strokeBorder(Theme.Palette.primary, lineWidth: 1))
                .keyboardShortcut(.cancelAction)
            Button("Done", action: commit)
                .buttonStyle(.plain)
                .font(Theme.Font.labelMd)
                .padding(.horizontal, 18)
                .frame(height: 34)
                .foregroundStyle(Theme.Palette.onPrimary)
                .background(Theme.Palette.primary)
                .keyboardShortcut(.defaultAction)
        }
    }

    private func addTag() {
        let trimmed = newTagDraft.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !trimmed.isEmpty, !tags.contains(trimmed) else { newTagDraft = ""; return }
        tags.append(trimmed)
        newTagDraft = ""
    }

    private func commit() {
        let taskService = TaskService(context: context)
        let scheduleService = ScheduleService(context: context)

        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedTitle.isEmpty, trimmedTitle != focus.item.title {
            taskService.rename(focus.item, to: trimmedTitle)
        }
        if notes != focus.item.notes {
            taskService.updateNotes(focus.item, notes: notes)
        }
        if tags != focus.item.tags {
            taskService.updateTags(focus.item, tags: tags)
        }
        if let entry = focus.entry {
            let timeChanged = entry.startHour != startHour || entry.durationHours != durationHours
            if timeChanged {
                do {
                    try scheduleService.reschedule(entry, startHour: startHour, durationHours: durationHours)
                } catch TodoError.scheduleConflict {
                    errorText = "Conflicts with another block"
                    return
                } catch TodoError.scheduleOutOfRange {
                    errorText = "Time range is out of bounds"
                    return
                } catch {
                    errorText = "Could not reschedule"
                    return
                }
            }
            if entry.colorIndex != colorIndex {
                scheduleService.setColorIndex(entry, colorIndex)
            }
        }
        dismiss()
    }

    private func formattedHour(_ hour: Int) -> String {
        let h = hour % 12 == 0 ? 12 : hour % 12
        let suffix = hour < 12 ? "AM" : "PM"
        return "\(h):00 \(suffix)"
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

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
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
