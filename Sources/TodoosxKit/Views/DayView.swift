import SwiftUI
import SwiftData

public struct DayView: View {
    @Environment(\.modelContext) private var context
    @Bindable var state: AppState

    public init(state: AppState) {
        self.state = state
    }

    public var body: some View {
        let dayService = DayService(context: context)
        let day = dayService.day(for: state.selectedDate)
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                BrainDumpSection(day: day, isReadOnly: state.isPast)
                Divider()
                Top3Section(day: day, isReadOnly: state.isPast)
            }
            .frame(maxHeight: .infinity)
            Divider()
            ScheduleSection(day: day, isReadOnly: state.isPast)
                .frame(maxHeight: .infinity)
        }
        .background(Color(nsColor: .windowBackgroundColor))
        .id(day.persistentModelID)
    }

    private func placeholderSection(_ title: String) -> some View {
        VStack(alignment: .leading) {
            Text(title)
                .font(.headline)
                .padding()
            Spacer()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
