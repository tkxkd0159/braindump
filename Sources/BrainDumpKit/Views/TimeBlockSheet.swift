import SwiftUI

/// Reminders-style time-block editor used by both the brain-dump drop flow
/// (replacing the old hour-only DurationPromptSheet) and the TaskDetailSheet.
/// Provides two DatePickers snapped to 15-minute increments, plus the
/// existing color swatch row.
public struct TimeBlockSheet: View {
    let initialStartMinute: Int
    let initialDurationMinutes: Int
    let onConfirm: (Int, Int, Int) -> Void  // startMinute, durationMinutes, colorIndex
    let onCancel: () -> Void

    @State private var startDate: Date
    @State private var endDate: Date
    @State private var colorIndex: Int
    @State private var error: String?

    public init(
        initialStartMinute: Int,
        initialDurationMinutes: Int = 60,
        initialColorIndex: Int = 0,
        onConfirm: @escaping (Int, Int, Int) -> Void,
        onCancel: @escaping () -> Void
    ) {
        self.initialStartMinute = initialStartMinute
        self.initialDurationMinutes = initialDurationMinutes
        self.onConfirm = onConfirm
        self.onCancel = onCancel
        _startDate = State(initialValue: TimeBlockSheet.referenceDate(forMinute: initialStartMinute))
        _endDate = State(initialValue: TimeBlockSheet.referenceDate(forMinute: initialStartMinute + initialDurationMinutes))
        _colorIndex = State(initialValue: initialColorIndex)
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            header
            timeRow
            ColorSwatchRow(selected: $colorIndex)
            if let error {
                Text(error)
                    .font(Theme.Font.caption)
                    .foregroundStyle(Theme.Palette.secondary)
            }
            footer
        }
        .padding(28)
        .frame(width: 420)
        .background(Theme.Palette.surfaceContainerLowest)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Time Block")
                .font(Theme.Font.tinyLabel)
                .tracking(1.5)
                .textCase(.uppercase)
                .foregroundStyle(Theme.Palette.primary)
            Text("When should this run?")
                .font(Theme.Font.headlineMd)
                .foregroundStyle(Theme.Palette.onSurface)
        }
    }

    private var timeRow: some View {
        HStack(alignment: .center, spacing: 16) {
            timeField(label: "Starts", date: $startDate)
            Image(systemName: "arrow.right")
                .font(.system(size: 13, weight: .regular))
                .foregroundStyle(Theme.Palette.onSurfaceVariant)
            timeField(label: "Ends", date: $endDate)
        }
    }

    @ViewBuilder
    private func timeField(label: String, date: Binding<Date>) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(Theme.Font.tinyLabel)
                .tracking(1.2)
                .foregroundStyle(Theme.Palette.onSurfaceVariant)
            DatePicker(
                "",
                selection: date,
                displayedComponents: .hourAndMinute
            )
            .labelsHidden()
            .datePickerStyle(.field)
        }
    }

    private var footer: some View {
        HStack(spacing: 12) {
            Spacer()
            Button("Cancel", action: onCancel)
                .buttonStyle(SecondaryActionStyle())
                .keyboardShortcut(.cancelAction)
            Button("Schedule", action: commit)
                .buttonStyle(PrimaryActionStyle())
                .keyboardShortcut(.defaultAction)
        }
    }

    private func commit() {
        let start = Self.snapMinute(date: startDate)
        let end = Self.snapMinute(date: endDate)
        guard end > start else {
            error = "End must be after start"
            return
        }
        let duration = end - start
        guard duration >= 15 else {
            error = "Block must be at least 15 minutes"
            return
        }
        guard start >= 0, end <= 24 * 60 else {
            error = "Time must be within the day"
            return
        }
        onConfirm(start, duration, colorIndex)
    }

    private static func snapMinute(date: Date) -> Int {
        let cal = Calendar(identifier: .gregorian)
        let comps = cal.dateComponents([.hour, .minute], from: date)
        let raw = (comps.hour ?? 0) * 60 + (comps.minute ?? 0)
        let snapped = Int((Double(raw) / 15.0).rounded()) * 15
        return min(24 * 60, max(0, snapped))
    }

    private static func referenceDate(forMinute minute: Int) -> Date {
        let cal = Calendar(identifier: .gregorian)
        let base = cal.startOfDay(for: Date(timeIntervalSinceReferenceDate: 0))
        return cal.date(byAdding: .minute, value: min(24 * 60 - 1, max(0, minute)), to: base) ?? base
    }
}

private struct PrimaryActionStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(Theme.Font.labelMd)
            .tracking(0.5)
            .padding(.horizontal, 18)
            .frame(height: 34)
            .foregroundStyle(Theme.Palette.onPrimary)
            .background(Theme.Palette.primary)
            .opacity(configuration.isPressed ? 0.85 : 1)
    }
}

private struct SecondaryActionStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(Theme.Font.labelMd)
            .tracking(0.5)
            .padding(.horizontal, 18)
            .frame(height: 34)
            .foregroundStyle(Theme.Palette.primary)
            .background(Theme.Palette.surfaceContainerLowest)
            .overlay(Rectangle().strokeBorder(Theme.Palette.primary, lineWidth: 1))
            .opacity(configuration.isPressed ? 0.85 : 1)
    }
}
