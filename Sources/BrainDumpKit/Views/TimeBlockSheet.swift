import SwiftUI

/// Reminders-style time-block editor used by the brain-dump drop flow.
/// Wraps the dual-clock TimeRangePicker plus a color swatch row.
public struct TimeBlockSheet: View {
    let initialStartMinute: Int
    let initialDurationMinutes: Int
    let dayStartHour: Int
    let dayEndHour: Int
    // startMinute, durationMinutes, colorIndex, reminderOffsetMinutes (nil = none)
    let onConfirm: (Int, Int, Int, Int?) -> Void
    let onCancel: () -> Void

    @State private var startMinute: Int
    @State private var endMinute: Int
    @State private var colorIndex: Int
    @State private var reminderOffset: Int?
    @State private var error: String?

    public init(
        initialStartMinute: Int,
        initialDurationMinutes: Int = 60,
        initialColorIndex: Int = 0,
        initialReminderOffset: Int? = nil,
        dayStartHour: Int = 5,
        dayEndHour: Int = 22,
        onConfirm: @escaping (Int, Int, Int, Int?) -> Void,
        onCancel: @escaping () -> Void
    ) {
        self.initialStartMinute = initialStartMinute
        self.initialDurationMinutes = initialDurationMinutes
        self.dayStartHour = dayStartHour
        self.dayEndHour = dayEndHour
        self.onConfirm = onConfirm
        self.onCancel = onCancel
        let snappedStart = TimeRangePicker.snap(minute: initialStartMinute)
        let snappedEnd = TimeRangePicker.snap(minute: initialStartMinute + initialDurationMinutes)
        _startMinute = State(initialValue: snappedStart)
        _endMinute = State(initialValue: max(snappedStart + 15, snappedEnd))
        _colorIndex = State(initialValue: initialColorIndex)
        _reminderOffset = State(initialValue: initialReminderOffset)
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            header
            TimeRangePicker(
                startMinute: $startMinute,
                endMinute: $endMinute,
                dayStartHour: dayStartHour,
                dayEndHour: dayEndHour
            )
            ColorSwatchRow(selected: $colorIndex)
            reminderPicker
            if let error {
                Text(error)
                    .font(Theme.Font.caption)
                    .foregroundStyle(Theme.Palette.secondary)
            }
            footer
        }
        .padding(28)
        .frame(width: 460)
        .background(Theme.Palette.surfaceContainerLowest)
        .onChange(of: startMinute) { _, newStart in
            // Keep the reminder within the day if the start time moves earlier.
            if !ReminderOffset.isValid(reminderOffset, startMinute: TimeRangePicker.snap(minute: newStart)) {
                reminderOffset = nil
            }
        }
    }

    private var reminderPicker: some View {
        HStack(spacing: 12) {
            Text("Reminder")
                .font(Theme.Font.labelMd)
                .foregroundStyle(Theme.Palette.onSurface)
            Spacer(minLength: 0)
            Picker("", selection: $reminderOffset) {
                Text("None").tag(Int?.none)
                ForEach(ReminderOffset.validPresets(startMinute: TimeRangePicker.snap(minute: startMinute)), id: \.self) { offset in
                    Text(ReminderOffset.label(offset)).tag(Int?.some(offset))
                }
            }
            .labelsHidden()
            .pickerStyle(.menu)
            .fixedSize()
        }
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
        let start = TimeRangePicker.snap(minute: startMinute)
        let end = TimeRangePicker.snap(minute: endMinute)
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
        onConfirm(start, duration, colorIndex, reminderOffset)
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
