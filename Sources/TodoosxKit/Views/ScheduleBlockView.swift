import SwiftUI

public struct ScheduleBlockView: View {
    let entry: ScheduleEntry
    let isReadOnly: Bool
    let onToggleComplete: () -> Void
    let onRemove: () -> Void

    public init(
        entry: ScheduleEntry,
        isReadOnly: Bool,
        onToggleComplete: @escaping () -> Void,
        onRemove: @escaping () -> Void
    ) {
        self.entry = entry
        self.isReadOnly = isReadOnly
        self.onToggleComplete = onToggleComplete
        self.onRemove = onRemove
    }

    public var body: some View {
        HStack(spacing: 8) {
            Button(action: onToggleComplete) {
                Image(systemName: entry.isCompleted ? "checkmark.square.fill" : "square")
                    .imageScale(.large)
                    .foregroundStyle(entry.isCompleted ? Color.accentColor : .secondary)
            }
            .buttonStyle(.borderless)
            .disabled(isReadOnly)

            Text(entry.item?.title ?? "(deleted)")
                .font(.body)
                .strikethrough(entry.isCompleted)
                .foregroundStyle(entry.isCompleted ? .secondary : .primary)

            Spacer()

            Text("\(entry.durationHours)h")
                .font(.caption)
                .foregroundStyle(.secondary)

            if !isReadOnly {
                Button(action: onRemove) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.borderless)
                .opacity(0.7)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.accentColor.opacity(entry.isCompleted ? 0.10 : 0.18))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(Color.accentColor.opacity(0.35), lineWidth: 1)
        )
    }
}
