import SwiftUI
import SwiftData

public struct DayView: View {
    @Environment(\.modelContext) private var context
    @Bindable var state: AppState
    @State private var detailFocus: TaskDetailFocus?

    public init(state: AppState) {
        self.state = state
    }

    public var body: some View {
        let dayService = DayService(context: context)
        let day = dayService.day(for: state.selectedDate)
        let openDetail: (TaskItem, ScheduleEntry?) -> Void = { item, entry in
            detailFocus = TaskDetailFocus(item: item, entry: entry ?? day.schedule.first { $0.item?.id == item.id })
        }
        GeometryReader { geo in
            let gutter: CGFloat = 24
            let available = max(0, geo.size.width - gutter)
            let leftWidth = max(340, available * 5.0 / 12.0)
            let rightWidth = max(440, available - leftWidth)
            HStack(alignment: .top, spacing: gutter) {
                VStack(alignment: .leading, spacing: 48) {
                    Top3Section(day: day, isReadOnly: state.isPast, openDetail: openDetail)
                    BrainDumpSection(day: day, isReadOnly: state.isPast, openDetail: openDetail)
                }
                .frame(width: leftWidth, alignment: .top)

                ScheduleSection(day: day, isReadOnly: state.isPast, openDetail: openDetail)
                    .frame(width: rightWidth, alignment: .top)
            }
        }
        .frame(minHeight: 1900)
        .id(day.persistentModelID)
        .sheet(item: $detailFocus) { focus in
            TaskDetailSheet(focus: focus, dismiss: { detailFocus = nil })
        }
    }
}
