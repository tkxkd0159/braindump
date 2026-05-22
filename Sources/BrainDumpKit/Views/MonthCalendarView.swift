import SwiftUI
import SwiftData

public struct MonthCalendarView: View {
    @Environment(\.modelContext) private var context
    @Bindable var state: AppState
    let dismiss: () -> Void

    @State private var displayedMonth: Date

    private let calendar: Calendar = .current

    public init(state: AppState, dismiss: @escaping () -> Void) {
        self.state = state
        self.dismiss = dismiss
        _displayedMonth = State(initialValue: Self.firstOfMonth(for: state.selectedDate))
    }

    public var body: some View {
        VStack(spacing: 0) {
            header
            weekdayRow
            daysGrid
            footer
        }
        .frame(width: 320)
        .background(Theme.Palette.surfaceContainerLowest)
    }

    // MARK: Header

    private var header: some View {
        VStack(spacing: 4) {
            HStack {
                Button(action: stepMonth(by: -1)) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Theme.Palette.primary)
                        .frame(width: 28, height: 28)
                }
                .buttonStyle(.plain)

                Spacer()

                Text(monthTitle)
                    .font(Theme.Font.headlineSmall)
                    .foregroundStyle(Theme.Palette.primary)

                Spacer()

                Button(action: stepMonth(by: 1)) {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Theme.Palette.primary)
                        .frame(width: 28, height: 28)
                }
                .buttonStyle(.plain)
            }
            Text("SELECT DATE")
                .font(Theme.Font.tinyLabel)
                .tracking(1.5)
                .foregroundStyle(Theme.Palette.onSurfaceVariant)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(Theme.Palette.surfaceContainerLow)
    }

    // MARK: Weekday row

    private var weekdayRow: some View {
        HStack(spacing: 0) {
            ForEach(weekdaySymbols, id: \.self) { symbol in
                Text(symbol)
                    .font(Theme.Font.tinyLabel)
                    .tracking(1.0)
                    .foregroundStyle(Theme.Palette.onSurfaceVariant)
                    .frame(maxWidth: .infinity)
            }
        }
        .padding(.vertical, 10)
        .overlay(alignment: .bottom) {
            Rectangle().fill(Theme.Palette.outlineVariant).frame(height: 1)
        }
    }

    // MARK: Day grid

    private var daysGrid: some View {
        let cells = monthCells
        return LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 0), count: 7), spacing: 4) {
            ForEach(cells, id: \.self) { date in
                cellView(for: date)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 10)
    }

    private func cellView(for date: Date) -> some View {
        let inMonth = calendar.isDate(date, equalTo: displayedMonth, toGranularity: .month)
        let isFuture = date > state.todayDate
        let isSelected = calendar.isDate(date, inSameDayAs: state.selectedDate)
        let day = calendar.component(.day, from: date)

        let textColor: Color = {
            if isSelected { return Theme.Palette.onPrimary }
            if isFuture || !inMonth { return Theme.Palette.outlineVariant }
            return Theme.Palette.primary
        }()

        return Button(action: { selectDate(date) }) {
            Text("\(day)")
                .font(Theme.Font.bodyLg)
                .foregroundStyle(textColor)
                .frame(maxWidth: .infinity, minHeight: 40)
                .background(
                    Group {
                        if isSelected {
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Theme.Palette.primary)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .strokeBorder(Theme.Palette.primary, lineWidth: 2)
                                )
                        }
                    }
                )
                .padding(4)
        }
        .buttonStyle(.plain)
        .disabled(isFuture)
    }

    // MARK: Footer

    private var footer: some View {
        HStack {
            HStack(spacing: 8) {
                Circle()
                    .fill(Theme.Palette.secondary)
                    .frame(width: 8, height: 8)
                Text(footerLabel)
                    .font(Theme.Font.tinyLabel)
                    .tracking(1.2)
                    .foregroundStyle(Theme.Palette.onSurface)
            }
            Spacer()
            Button("Today") {
                state.goToToday()
                displayedMonth = Self.firstOfMonth(for: state.todayDate)
                dismiss()
            }
            .buttonStyle(.plain)
            .font(Theme.Font.labelMd)
            .tracking(0.5)
            .padding(.horizontal, 14)
            .frame(height: 30)
            .foregroundStyle(Theme.Palette.onPrimary)
            .background(Theme.Palette.primary)
            .disabled(state.isToday)
            .opacity(state.isToday ? 0.5 : 1)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Theme.Palette.surfaceContainerLow)
        .overlay(alignment: .top) {
            Rectangle().fill(Theme.Palette.outlineVariant).frame(height: 1)
        }
    }

    // MARK: Helpers

    private var monthTitle: String {
        let f = DateFormatter()
        f.calendar = calendar
        f.dateFormat = "LLLL yyyy"
        return f.string(from: displayedMonth)
    }

    private var weekdaySymbols: [String] {
        let symbols = calendar.veryShortStandaloneWeekdaySymbols
        let first = calendar.firstWeekday - 1
        return Array(symbols[first...] + symbols[..<first])
    }

    private var monthCells: [Date] {
        guard let monthRange = calendar.range(of: .day, in: .month, for: displayedMonth) else { return [] }
        let firstOfMonth = displayedMonth
        let weekdayOfFirst = calendar.component(.weekday, from: firstOfMonth) - calendar.firstWeekday
        let leading = (weekdayOfFirst + 7) % 7

        let totalCells = 42
        var dates: [Date] = []
        for offset in 0..<totalCells {
            let dayOffset = offset - leading
            if let date = calendar.date(byAdding: .day, value: dayOffset, to: firstOfMonth) {
                dates.append(date.startOfLocalDay())
            }
        }
        let daysInMonth = monthRange.count
        let used = leading + daysInMonth
        let trailingShown = totalCells - used
        if trailingShown >= 7 {
            return Array(dates.prefix(totalCells - 7))
        }
        return dates
    }

    private var footerLabel: String {
        let dayService = DayService(context: context)
        let selectedDay = dayService.day(for: state.selectedDate)
        if state.isToday {
            let n = dayService.incompleteItemCount(on: selectedDay)
            return "\(n) ITEM\(n == 1 ? "" : "S") TODAY"
        } else {
            let n = dayService.totalItemCount(on: selectedDay)
            let f = DateFormatter()
            f.dateFormat = "MMM d"
            return "\(n) ITEM\(n == 1 ? "" : "S") ON \(f.string(from: state.selectedDate).uppercased())"
        }
    }

    private func selectDate(_ date: Date) {
        let normalized = date.startOfLocalDay()
        guard normalized <= state.todayDate else { return }
        state.selectedDate = normalized
        dismiss()
    }

    private func stepMonth(by months: Int) -> () -> Void {
        return {
            if let next = calendar.date(byAdding: .month, value: months, to: displayedMonth) {
                displayedMonth = Self.firstOfMonth(for: next)
            }
        }
    }

    private static func firstOfMonth(for date: Date, calendar: Calendar = .current) -> Date {
        let comps = calendar.dateComponents([.year, .month], from: date)
        return calendar.date(from: comps) ?? date
    }
}
