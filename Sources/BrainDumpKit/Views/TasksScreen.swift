import SwiftData
import SwiftUI

public struct TasksScreen: View {
    @Environment(\.modelContext) private var context

    @State private var keyword: String = ""
    @State private var selectedTag: String?
    @State private var useDateRange: Bool = false
    @State private var useSpecificDateRange: Bool = false
    @State private var fromDate: Date = Calendar.current.date(
        byAdding: .day, value: -7, to: Date())!
    @State private var toDate: Date = Date()
    @State private var detailFocus: TaskDetailFocus?

    public init() {}

    private var taskService: TaskService { TaskService(context: context) }

    private var results: [TaskItem] {
        let range: ClosedRange<Date>? = {
            guard useDateRange, useSpecificDateRange else { return nil }
            let lo = fromDate.startOfLocalDay()
            let hi =
                Calendar.current.date(byAdding: .day, value: 1, to: toDate.startOfLocalDay())?
                .addingTimeInterval(-1) ?? toDate
            guard lo <= hi else { return nil }
            return lo...hi
        }()
        return taskService.searchTasks(
            keyword: keyword.isEmpty ? nil : keyword,
            tag: selectedTag,
            completedOnly: useDateRange,
            completedRange: range
        )
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            header
            searchBar
            tagFilter
            dateRangeFilter
            resultList
        }
        .sheet(item: $detailFocus) { focus in
            TaskDetailSheet(focus: focus, dismiss: { detailFocus = nil })
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Tasks")
                .font(Theme.Font.headlineLg)
                .tracking(-0.3)
                .foregroundStyle(Theme.Palette.primary)
            Text("All tasks across days, excluding the backlog.")
                .font(Theme.Font.bodyMd)
                .foregroundStyle(Theme.Palette.onSurfaceVariant)
        }
    }

    private var searchBar: some View {
        HStack(spacing: 12) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 14, weight: .regular))
                .foregroundStyle(Theme.Palette.onSurfaceVariant)
            TextField("Search title or description…", text: $keyword)
                .textFieldStyle(.plain)
                .font(Theme.Font.bodyMd)
        }
        .padding(.horizontal, 14)
        .frame(height: 38)
        .background(Theme.Palette.surfaceContainerLowest)
        .overlay(Rectangle().strokeBorder(Theme.Palette.outlineVariant, lineWidth: 1))
    }

    private var tagFilter: some View {
        let tags = taskService.allTags()
        return Group {
            if !tags.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Tag")
                        .font(Theme.Font.tinyLabel)
                        .tracking(1.2)
                        .foregroundStyle(Theme.Palette.onSurfaceVariant)
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            tagChip(label: "All", selected: selectedTag == nil, tag: nil)
                            ForEach(tags, id: \.self) { tag in
                                tagChip(label: tag, selected: selectedTag == tag, tag: tag)
                            }
                        }
                    }
                }
            }
        }
    }

    private func tagChip(label: String, selected: Bool, tag: String?) -> some View {
        Button(action: { selectedTag = tag }) {
            Text(label)
                .font(Theme.Font.labelMd)
                .padding(.horizontal, 12)
                .frame(height: 28)
                .foregroundStyle(selected ? Theme.Palette.onPrimary : Theme.Palette.primary)
                .background(selected ? Theme.Palette.primary : Theme.Palette.surfaceContainerLowest)
                .overlay(Rectangle().strokeBorder(Theme.Palette.primary, lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    private var dateRangeFilter: some View {
        CompletionDateFilter(
            useDateRange: $useDateRange,
            useSpecificDateRange: $useSpecificDateRange,
            fromDate: $fromDate,
            toDate: $toDate
        )
    }

    private var resultList: some View {
        let items = results
        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("\(items.count) RESULT\(items.count == 1 ? "" : "S")")
                    .font(Theme.Font.tinyLabel)
                    .tracking(1.2)
                    .foregroundStyle(Theme.Palette.onSurfaceVariant)
                Spacer()
            }
            if items.isEmpty {
                Text("No tasks match your filters.")
                    .font(Theme.Font.bodyMd)
                    .foregroundStyle(Theme.Palette.onSurfaceVariant)
                    .padding(.vertical, 12)
            } else {
                LazyVStack(spacing: 8) {
                    ForEach(items, id: \.id) { item in
                        taskRow(item)
                    }
                }
            }
        }
    }

    private func taskRow(_ item: TaskItem) -> some View {
        let entries = (item.day?.schedule ?? []).filter { $0.item?.id == item.id }
        let completedEntry = entries.first { $0.isCompleted }
        let isCompleted = completedEntry != nil

        return Button(action: {
            detailFocus = TaskDetailFocus(item: item, entry: entries.first)
        }) {
            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(item.title)
                            .font(Theme.Font.bodyLgSemibold)
                            .strikethrough(isCompleted)
                            .foregroundStyle(
                                isCompleted ? Theme.Palette.outline : Theme.Palette.onSurface
                            )
                            .multilineTextAlignment(.leading)
                        if !item.notes.isEmpty {
                            Text(NoteText.linkified(item.notes))
                                .font(Theme.Font.bodyMd)
                                .foregroundStyle(Theme.Palette.onSurfaceVariant)
                                .lineLimit(2)
                                .multilineTextAlignment(.leading)
                        }
                    }
                    Spacer(minLength: 8)
                    if let day = item.day {
                        Text(dateFormatter.string(from: day.date))
                            .font(Theme.Font.tinyLabel)
                            .tracking(1.0)
                            .foregroundStyle(Theme.Palette.onSurfaceVariant)
                    }
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
                if let completedEntry, let stamp = completedEntry.completedAt {
                    Text("COMPLETED \(dateTimeFormatter.string(from: stamp).uppercased())")
                        .font(Theme.Font.tinyLabel)
                        .tracking(1.2)
                        .foregroundStyle(Theme.Palette.secondary)
                }
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.Palette.surfaceContainerLowest)
            .overlay(Rectangle().strokeBorder(Theme.Palette.outlineVariant, lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    private let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "MMM d, yyyy"
        return f
    }()

    private let dateTimeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "MMM d, h:mm a"
        return f
    }()
}

struct CompletionDateFilter: View {
    @Binding var useDateRange: Bool
    @Binding var useSpecificDateRange: Bool
    @Binding var fromDate: Date
    @Binding var toDate: Date

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Toggle("Completed Only", isOn: $useDateRange)
                .font(Theme.Font.labelMd)
                .tracking(0.5)
                .toggleStyle(.checkbox)
                .foregroundStyle(Theme.Palette.onSurfaceVariant)
            if useDateRange {
                VStack(alignment: .leading, spacing: 8) {
                    Toggle("Date Range", isOn: $useSpecificDateRange)
                        .font(Theme.Font.labelMd)
                        .tracking(0.5)
                        .toggleStyle(.checkbox)
                        .foregroundStyle(Theme.Palette.onSurfaceVariant)
                    if useSpecificDateRange {
                        HStack(spacing: 16) {
                            DatePicker("From", selection: $fromDate, displayedComponents: [.date])
                                .datePickerStyle(.field)
                                .font(Theme.Font.bodyMd)
                            DatePicker("To", selection: $toDate, displayedComponents: [.date])
                                .datePickerStyle(.field)
                                .font(Theme.Font.bodyMd)
                        }
                    }
                }
                .padding(.leading, 18)
            }
        }
    }
}
