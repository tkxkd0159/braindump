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

    private func slotRow(index: Int, item: TaskItem?) -> some View {
        HStack(spacing: 8) {
            Text("\(index + 1).")
                .foregroundStyle(.secondary)
                .frame(width: 20, alignment: .leading)
            if let item {
                Text(item.title)
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
        .padding(.vertical, 6)
        .padding(.horizontal, 4)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(item == nil ? Color.gray.opacity(0.04) : Color.clear)
        )
    }
}
