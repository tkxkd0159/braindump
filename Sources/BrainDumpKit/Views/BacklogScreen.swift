import SwiftUI
import SwiftData

public struct BacklogScreen: View {
    @Environment(\.modelContext) private var context
    @Bindable var state: AppState

    @State private var newTitle: String = ""
    @State private var hoveredID: UUID?
    @State private var detailFocus: TaskDetailFocus?

    public init(state: AppState) {
        self.state = state
    }

    private var backlogService: BacklogService { BacklogService(context: context) }
    private var dayService: DayService { DayService(context: context) }

    public var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            header
            addRow
            list
        }
        .sheet(item: $detailFocus) { focus in
            TaskDetailSheet(focus: focus, dismiss: { detailFocus = nil })
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Backlog")
                .font(Theme.Font.headlineLg)
                .tracking(-0.3)
                .foregroundStyle(Theme.Palette.primary)
            Text("Tasks parked for later. Promote one to today's brain dump when you're ready.")
                .font(Theme.Font.bodyMd)
                .foregroundStyle(Theme.Palette.onSurfaceVariant)
        }
    }

    private var addRow: some View {
        HStack(spacing: 12) {
            TextField("Add to backlog…", text: $newTitle)
                .textFieldStyle(.plain)
                .font(Theme.Font.bodyMd)
                .padding(.horizontal, 14)
                .frame(height: 38)
                .background(Theme.Palette.surfaceContainerLowest)
                .overlay(Rectangle().strokeBorder(Theme.Palette.outlineVariant, lineWidth: 1))
                .onSubmit(submitNew)
            Button("Add", action: submitNew)
                .buttonStyle(.plain)
                .font(Theme.Font.labelMd)
                .padding(.horizontal, 18)
                .frame(height: 38)
                .foregroundStyle(Theme.Palette.onPrimary)
                .background(Theme.Palette.primary)
                .disabled(newTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
    }

    private var list: some View {
        let items = backlogService.listBacklog()
        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("\(items.count) ITEM\(items.count == 1 ? "" : "S")")
                    .font(Theme.Font.tinyLabel)
                    .tracking(1.2)
                    .foregroundStyle(Theme.Palette.onSurfaceVariant)
                Spacer()
            }
            if items.isEmpty {
                Text("The backlog is empty.")
                    .font(Theme.Font.bodyMd)
                    .foregroundStyle(Theme.Palette.onSurfaceVariant)
                    .padding(.vertical, 12)
            } else {
                LazyVStack(spacing: 8) {
                    ForEach(items, id: \.id) { item in
                        row(for: item)
                    }
                }
            }
        }
    }

    private func row(for item: TaskItem) -> some View {
        let hovered = hoveredID == item.id
        return HStack(alignment: .top, spacing: 14) {
            VStack(alignment: .leading, spacing: 6) {
                Text(item.title)
                    .font(Theme.Font.bodyLgSemibold)
                    .foregroundStyle(Theme.Palette.onSurface)
                if !item.notes.isEmpty {
                    Text(item.notes)
                        .font(Theme.Font.bodyMd)
                        .foregroundStyle(Theme.Palette.onSurfaceVariant)
                        .lineLimit(2)
                }
                if !item.tags.isEmpty {
                    HStack(spacing: 6) {
                        ForEach(item.tags, id: \.self) { tag in
                            Text(tag)
                                .font(Theme.Font.caption)
                                .foregroundStyle(Theme.Palette.onSurface)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Theme.Palette.surfaceContainerHigh)
                        }
                    }
                }
            }
            Spacer(minLength: 0)
            HStack(spacing: 6) {
                Button(action: { promote(item) }) {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.right.circle")
                        Text("Move to today")
                    }
                    .font(Theme.Font.labelMd)
                    .padding(.horizontal, 12)
                    .frame(height: 30)
                    .foregroundStyle(Theme.Palette.primary)
                    .overlay(Rectangle().strokeBorder(Theme.Palette.primary, lineWidth: 1))
                }
                .buttonStyle(.plain)
                .opacity(hovered ? 1 : 0.6)
                Button(action: { backlogService.delete(item) }) {
                    Image(systemName: "xmark")
                        .font(.system(size: 12, weight: .semibold))
                        .frame(width: 30, height: 30)
                        .foregroundStyle(Theme.Palette.onSurfaceVariant)
                        .overlay(Rectangle().strokeBorder(Theme.Palette.outlineVariant, lineWidth: 1))
                }
                .buttonStyle(.plain)
                .opacity(hovered ? 1 : 0)
                .allowsHitTesting(hovered)
                .help("Delete")
            }
        }
        .padding(14)
        .background(Theme.Palette.surfaceContainerLowest)
        .overlay(
            Rectangle()
                .strokeBorder(hovered ? Theme.Palette.primary : Theme.Palette.outlineVariant, lineWidth: 1)
        )
        .contentShape(Rectangle())
        .onHover { inside in hoveredID = inside ? item.id : (hoveredID == item.id ? nil : hoveredID) }
        .onTapGesture { detailFocus = TaskDetailFocus(item: item, entry: nil) }
    }

    private func submitNew() {
        let trimmed = newTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        _ = backlogService.addBacklogItem(title: trimmed)
        newTitle = ""
    }

    private func promote(_ item: TaskItem) {
        let today = dayService.day(for: state.todayDate)
        backlogService.promoteToBrainDump(item, on: today)
    }
}
