import SwiftUI
import SwiftData

public struct Top3Section: View {
    @Environment(\.modelContext) private var context
    let day: Day
    let isReadOnly: Bool

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

    private var top3Items: [TaskItem?] {
        var slots: [TaskItem?] = [nil, nil, nil]
        for (i, id) in day.top3ItemIDs.prefix(3).enumerated() {
            slots[i] = day.items.first { $0.id == id }
        }
        return slots
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Top 3")
                .font(.title3.weight(.semibold))
                .padding(.bottom, 4)

            ForEach(Array(top3Items.enumerated()), id: \.offset) { idx, item in
                slotRow(index: idx, item: item)
            }

            if !isReadOnly {
                Text("Tap the star next to a brain-dump item to escalate.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.top, 8)
            }

            Spacer()
        }
        .padding(16)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    @ViewBuilder
    private func slotRow(index: Int, item: TaskItem?) -> some View {
        let base = HStack(spacing: 8) {
            Text("\(index + 1).")
                .font(.body.weight(.semibold).monospacedDigit())
                .foregroundStyle(.secondary)
                .frame(width: 20, alignment: .leading)
            if let item {
                Text(item.title)
                    .strikethrough(isCompleted(item))
                    .foregroundStyle(isCompleted(item) ? .secondary : .primary)
                Spacer()
                if !isReadOnly {
                    Button {
                        taskService.deescalate(item, on: day)
                    } label: {
                        Image(systemName: "star.slash")
                    }
                    .buttonStyle(.borderless)
                    .foregroundStyle(.secondary)
                }
            } else {
                Text("—")
                    .foregroundStyle(.secondary)
                Spacer()
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 8)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(rowBackground(for: item))
        )

        if let item, !isReadOnly {
            base.draggable(TaskItemDragPayload(id: item.id))
        } else {
            base
        }
    }

    private func rowBackground(for item: TaskItem?) -> Color {
        guard let item else { return Color.gray.opacity(0.04) }
        return isScheduled(item) ? Color.accentColor.opacity(0.08) : Color.clear
    }
}
