import SwiftUI
import SwiftData

public struct BrainDumpSection: View {
    @Environment(\.modelContext) private var context
    let day: Day
    let isReadOnly: Bool

    @State private var newTitle: String = ""
    @State private var editingID: UUID?
    @State private var editingDraft: String = ""

    public init(day: Day, isReadOnly: Bool) {
        self.day = day
        self.isReadOnly = isReadOnly
    }

    private var taskService: TaskService { TaskService(context: context) }

    private func isScheduled(_ item: TaskItem) -> Bool {
        day.schedule.contains { $0.item?.id == item.id }
    }

    private func isCompleted(_ item: TaskItem) -> Bool {
        day.schedule.contains { $0.item?.id == item.id && $0.isCompleted }
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Brain Dump")
                .font(.title3.weight(.semibold))
                .padding(.bottom, 4)

            ForEach(day.items, id: \.id) { item in
                row(for: item)
            }

            if !isReadOnly {
                HStack {
                    Image(systemName: "plus")
                        .foregroundStyle(.secondary)
                    TextField("Add to brain dump", text: $newTitle)
                        .textFieldStyle(.plain)
                        .onSubmit(submitNew)
                }
                .padding(.vertical, 6)
                .padding(.horizontal, 8)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color.gray.opacity(0.06))
                )
            }

            Spacer()
        }
        .padding(16)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private func row(for item: TaskItem) -> some View {
        HStack(spacing: 8) {
            Circle()
                .stroke(isCompleted(item) ? Color.accentColor : Color.secondary, lineWidth: 1)
                .background(
                    Circle().fill(isCompleted(item) ? Color.accentColor.opacity(0.6) : Color.clear)
                )
                .frame(width: 12, height: 12)
            if editingID == item.id {
                TextField("Title", text: $editingDraft)
                    .textFieldStyle(.plain)
                    .onSubmit { commitEdit(item) }
            } else {
                Text(item.title)
                    .strikethrough(isCompleted(item))
                    .foregroundStyle(isCompleted(item) ? .secondary : .primary)
                    .onTapGesture(count: 2) {
                        if !isReadOnly {
                            editingID = item.id
                            editingDraft = item.title
                        }
                    }
            }
            Spacer()
            if !isReadOnly {
                Button {
                    try? taskService.escalate(item, on: day)
                } label: {
                    Image(systemName: day.top3ItemIDs.contains(item.id) ? "star.fill" : "star")
                        .foregroundStyle(day.top3ItemIDs.contains(item.id) ? Color.yellow : .secondary)
                }
                .buttonStyle(.borderless)
                .disabled(!day.top3ItemIDs.contains(item.id) && day.top3ItemIDs.count >= 3)

                Button {
                    taskService.delete(item)
                } label: {
                    Image(systemName: "xmark")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.borderless)
                .opacity(0.6)
            }
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 8)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(isScheduled(item) ? Color.accentColor.opacity(0.08) : Color.clear)
        )
        .draggable(TaskItemDragPayload(id: item.id))
    }

    private func submitNew() {
        let trimmed = newTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        taskService.addBrainDumpItem(title: trimmed, on: day)
        newTitle = ""
    }

    private func commitEdit(_ item: TaskItem) {
        let trimmed = editingDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty { taskService.rename(item, to: trimmed) }
        editingID = nil
    }
}
