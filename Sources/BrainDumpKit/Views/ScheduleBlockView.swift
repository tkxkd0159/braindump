import SwiftUI

public struct ScheduleBlockView: View {
    let entry: ScheduleEntry
    let isReadOnly: Bool
    let onToggleComplete: () -> Void
    let onRemove: () -> Void
    let onEdit: (() -> Void)?
    let onTap: (() -> Void)?

    @State private var hovered: Bool = false

    public init(
        entry: ScheduleEntry,
        isReadOnly: Bool,
        onToggleComplete: @escaping () -> Void,
        onRemove: @escaping () -> Void,
        onEdit: (() -> Void)? = nil,
        onTap: (() -> Void)? = nil
    ) {
        self.entry = entry
        self.isReadOnly = isReadOnly
        self.onToggleComplete = onToggleComplete
        self.onRemove = onRemove
        self.onEdit = onEdit
        self.onTap = onTap
    }

    public var body: some View {
        HStack(alignment: .top, spacing: 0) {
            Rectangle()
                .fill(blockColor.opacity(0.65))
                .frame(width: 4)
            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .top) {
                    Text(entry.item?.title ?? "(deleted)")
                        .font(Theme.Font.bodyLgSemibold)
                        .strikethrough(entry.isCompleted)
                        .foregroundStyle(foregroundColor.opacity(entry.isCompleted ? 0.6 : 1))
                        .lineLimit(2)
                    Spacer()
                    trailingControl
                }
                Text(timeRange)
                    .font(Theme.Font.caption)
                    .foregroundStyle(foregroundColor.opacity(0.7))
            }
            .padding(16)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .background(blockColor)
        .contentShape(Rectangle())
        .onHover { hovered = $0 }
        .onTapGesture { onTap?() }
    }

    private var blockColor: Color {
        Theme.BlockPalette.color(at: entry.colorIndex)
    }

    private var foregroundColor: Color {
        Theme.BlockPalette.foreground(at: entry.colorIndex)
    }

    @ViewBuilder
    private var trailingControl: some View {
        HStack(spacing: 6) {
            if !isReadOnly && hovered {
                Button(action: onRemove) {
                    Image(systemName: "xmark")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(foregroundColor.opacity(0.85))
                        .frame(width: 24, height: 22)
                        .background(blockColor.opacity(0.65))
                }
                .buttonStyle(.plain)
                .help("Remove from schedule")
                if let onEdit {
                    Button(action: onEdit) {
                        Image(systemName: "pencil")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(foregroundColor.opacity(0.85))
                            .frame(width: 24, height: 22)
                            .background(blockColor.opacity(0.65))
                    }
                    .buttonStyle(.plain)
                    .help("Edit task")
                }
            }
            Button(action: { if !isReadOnly { onToggleComplete() } }) {
                Image(systemName: entry.isCompleted ? "checkmark.square.fill" : "lock.fill")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(foregroundColor.opacity(entry.isCompleted ? 1 : 0.85))
            }
            .buttonStyle(.plain)
            .disabled(isReadOnly)
            .help(entry.isCompleted ? "Mark incomplete" : "Mark complete")
        }
    }

    private var timeRange: String {
        TimeFormat.range(startMinute: entry.startMinute, durationMinutes: entry.durationMinutes)
    }
}
