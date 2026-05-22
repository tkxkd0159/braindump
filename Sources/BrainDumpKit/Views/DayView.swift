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
        let openDetail: (TaskDetailFocus) -> Void = { focus in
            detailFocus = focus
        }
        GeometryReader { geo in
            let gutter: CGFloat = 24
            let available = max(0, geo.size.width - gutter)
            let leftWidth = max(360, available * 5.0 / 12.0)
            let rightWidth = max(480, available - leftWidth)
            HStack(alignment: .top, spacing: gutter) {
                VStack(alignment: .leading, spacing: 48) {
                    Top3Section(day: day, isReadOnly: state.isPast, openDetail: openDetail)
                    BrainDumpSection(day: day, isReadOnly: state.isPast, openDetail: openDetail)
                }
                .frame(width: leftWidth, alignment: .top)

                ScheduleSection(
                    day: day,
                    isReadOnly: state.isPast,
                    dayStartHour: state.dayStartHour,
                    dayEndHour: state.dayEndHour,
                    openDetail: openDetail
                )
                .frame(width: rightWidth, alignment: .top)
            }
        }
        .frame(minHeight: scheduleHeight(state: state))
        .id(day.persistentModelID)
        .sheet(item: $detailFocus) { focus in
            TaskDetailSheet(focus: focus, dismiss: { detailFocus = nil })
        }
    }

    private func scheduleHeight(state: AppState) -> CGFloat {
        // ScheduleSection grid uses 100 pt per hour plus header/padding (~140).
        let hourHeight: CGFloat = 100
        let hours = max(1, state.dayEndHour - state.dayStartHour) + 1
        return CGFloat(hours) * hourHeight + 200
    }
}
