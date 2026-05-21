import SwiftUI
import SwiftData

public struct AppShell: View {
    @Environment(\.modelContext) private var context
    @State private var state: AppState?

    public init() {}

    public var body: some View {
        Group {
            if let state {
                VStack(spacing: 0) {
                    DateHeader(state: state)
                    Divider()
                    DayView(state: state)
                }
            } else {
                ProgressView().controlSize(.large)
            }
        }
        .onAppear {
            if state == nil { state = AppState(context: context) }
        }
    }
}

private struct DateHeader: View {
    @Bindable var state: AppState

    private var formattedDate: String {
        let f = DateFormatter()
        f.dateStyle = .full
        return f.string(from: state.selectedDate)
    }

    var body: some View {
        HStack(spacing: 12) {
            Button(action: state.goToPreviousDay) {
                Image(systemName: "chevron.left")
                    .imageScale(.large)
            }
            .buttonStyle(.borderless)

            Text(formattedDate)
                .font(.title2.weight(.semibold))
                .frame(maxWidth: .infinity)

            Button(action: state.goToNextDay) {
                Image(systemName: "chevron.right")
                    .imageScale(.large)
            }
            .buttonStyle(.borderless)
            .disabled(state.isToday)

            Button("Today", action: state.goToToday)
                .disabled(state.isToday)
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 16)
    }
}
