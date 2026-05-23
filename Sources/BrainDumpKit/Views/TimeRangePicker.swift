import SwiftUI

/// Dual digital-clock time-range picker, MUI X MultiInput style.
/// Two synchronized scroll-snap columns at 15-minute steps with a
/// selection band highlighting the middle row of each column.
public struct TimeRangePicker: View {
    @Binding var startMinute: Int
    @Binding var endMinute: Int
    let dayStartHour: Int
    let dayEndHour: Int
    let step: Int

    public init(
        startMinute: Binding<Int>,
        endMinute: Binding<Int>,
        dayStartHour: Int = 5,
        dayEndHour: Int = 22,
        step: Int = 15
    ) {
        _startMinute = startMinute
        _endMinute = endMinute
        self.dayStartHour = dayStartHour
        self.dayEndHour = dayEndHour
        self.step = step
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 20) {
                column(label: "Starts", selection: startBinding, range: startRange)
                column(label: "Ends", selection: endBinding, range: endRange)
            }
            Text(durationLabel)
                .font(Theme.Font.tinyLabel)
                .tracking(1.2)
                .textCase(.uppercase)
                .foregroundStyle(Theme.Palette.onSurfaceVariant)
                .frame(maxWidth: .infinity, alignment: .center)
        }
    }

    private var startBinding: Binding<Int> {
        Binding(
            get: { startMinute },
            set: { newValue in
                var s = newValue
                var e = endMinute
                Self.coerce(start: &s, end: &e, step: step, movedStart: true)
                if s != startMinute { startMinute = s }
                if e != endMinute { endMinute = e }
            }
        )
    }

    private var endBinding: Binding<Int> {
        Binding(
            get: { endMinute },
            set: { newValue in
                var s = startMinute
                var e = newValue
                Self.coerce(start: &s, end: &e, step: step, movedStart: false)
                if s != startMinute { startMinute = s }
                if e != endMinute { endMinute = e }
            }
        )
    }

    @ViewBuilder
    private func column(label: String, selection: Binding<Int>, range: [Int]) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label.uppercased())
                .font(Theme.Font.tinyLabel)
                .tracking(1.2)
                .foregroundStyle(Theme.Palette.onSurfaceVariant)
            scrollColumn(selection: selection, range: range)
        }
    }

    private static let rowHeight: CGFloat = 32
    private static let visibleRows: CGFloat = 5

    @ViewBuilder
    private func scrollColumn(selection: Binding<Int>, range: [Int]) -> some View {
        ScrollViewReader { proxy in
            ScrollView(.vertical, showsIndicators: false) {
                LazyVStack(spacing: 0) {
                    ForEach(range, id: \.self) { minute in
                        timeRow(minute: minute, selected: minute == selection.wrappedValue) {
                            selection.wrappedValue = minute
                            withAnimation(.easeOut(duration: 0.18)) {
                                proxy.scrollTo(minute, anchor: .center)
                            }
                        }
                        .id(minute)
                    }
                }
                .scrollTargetLayout()
            }
            .scrollTargetBehavior(.viewAligned)
            .frame(width: 130, height: Self.rowHeight * Self.visibleRows)
            .background(Theme.Palette.surfaceContainer)
            .overlay(Rectangle().strokeBorder(Theme.Palette.outlineVariant, lineWidth: 1))
            .overlay(
                Rectangle()
                    .strokeBorder(Theme.Palette.primary.opacity(0.4), lineWidth: 1)
                    .frame(height: Self.rowHeight)
                    .allowsHitTesting(false)
            )
            .onAppear {
                proxy.scrollTo(selection.wrappedValue, anchor: .center)
            }
            .onChange(of: selection.wrappedValue) { _, newValue in
                withAnimation(.easeOut(duration: 0.18)) {
                    proxy.scrollTo(newValue, anchor: .center)
                }
            }
        }
    }

    @ViewBuilder
    private func timeRow(minute: Int, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(TimeFormat.clock(minute: minute))
                .font(selected ? Theme.Font.bodyLgSemibold : Theme.Font.bodyMd)
                .foregroundStyle(selected ? Theme.Palette.primary : Theme.Palette.onSurface)
                .frame(maxWidth: .infinity)
                .frame(height: Self.rowHeight)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var startRange: [Int] {
        Array(stride(from: dayStartHour * 60, through: dayEndHour * 60 - step, by: step))
    }

    private var endRange: [Int] {
        Array(stride(from: dayStartHour * 60 + step, through: dayEndHour * 60, by: step))
    }

    private var durationLabel: String {
        let mins = max(0, endMinute - startMinute)
        let h = mins / 60
        let m = mins % 60
        if h == 0 { return "Duration: \(m)m" }
        if m == 0 { return "Duration: \(h)h" }
        return "Duration: \(h)h \(m)m"
    }

    static func snap(minute: Int) -> Int {
        let clamped = min(24 * 60, max(0, minute))
        return Int((Double(clamped) / 15.0).rounded()) * 15
    }

    /// Enforce `end > start` and `end - start >= step` after a one-sided edit.
    static func coerce(start: inout Int, end: inout Int, step: Int, movedStart: Bool) {
        if movedStart {
            if end <= start { end = start + step }
        } else {
            if start >= end { start = end - step }
        }
    }
}
