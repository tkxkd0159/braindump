import SwiftUI

/// Reminders-style time-block editor used by the brain-dump drop flow.
/// Wraps the dual-clock TimeRangePicker plus a color field and a
/// "N minutes/hours before" reminder offset input.
public struct TimeBlockSheet: View {
    let initialStartMinute: Int
    let initialDurationMinutes: Int
    let dayStartHour: Int
    let dayEndHour: Int
    /// Start-of-local-day of the day being scheduled; anchors reminder validation.
    let dayDate: Date
    /// Injected clock for the "later than now" reminder check.
    let now: Date
    // startMinute, durationMinutes, colorIndex, customColorHex, reminderMinuteOfDay (nil = none)
    let onConfirm: (Int, Int, Int, String?, Int?) -> Void
    let onCancel: () -> Void

    @State private var startMinute: Int
    @State private var endMinute: Int
    @State private var colorIndex: Int
    @State private var customColorHex: String?
    /// Minutes-before-start lead time for the reminder (`nil` = no reminder).
    @State private var reminderOffset: Int?
    @State private var error: String?
    @State private var reminderAlert: String?

    public init(
        initialStartMinute: Int,
        initialDurationMinutes: Int = 60,
        initialColorIndex: Int = 0,
        initialCustomColorHex: String? = nil,
        initialReminderOffsetMinutes: Int? = nil,
        dayStartHour: Int = 5,
        dayEndHour: Int = 22,
        dayDate: Date = Date().startOfLocalDay(),
        now: Date = Date(),
        onConfirm: @escaping (Int, Int, Int, String?, Int?) -> Void,
        onCancel: @escaping () -> Void
    ) {
        self.initialStartMinute = initialStartMinute
        self.initialDurationMinutes = initialDurationMinutes
        self.dayStartHour = dayStartHour
        self.dayEndHour = dayEndHour
        self.dayDate = dayDate
        self.now = now
        self.onConfirm = onConfirm
        self.onCancel = onCancel
        let snappedStart = TimeRangePicker.snap(minute: initialStartMinute)
        let snappedEnd = TimeRangePicker.snap(minute: initialStartMinute + initialDurationMinutes)
        _startMinute = State(initialValue: snappedStart)
        _endMinute = State(initialValue: max(snappedStart + 15, snappedEnd))
        _colorIndex = State(initialValue: initialColorIndex)
        _customColorHex = State(initialValue: initialCustomColorHex)
        _reminderOffset = State(initialValue: initialReminderOffsetMinutes)
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
            ColorField(selected: $colorIndex, customHex: $customColorHex)
            ReminderOffsetRow(offsetMinutes: $reminderOffset)
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
        .alert("Reminder", isPresented: Binding(
            get: { reminderAlert != nil },
            set: { if !$0 { reminderAlert = nil } })
        ) {
            Button("OK", role: .cancel) { reminderAlert = nil }
        } message: {
            Text(reminderAlert ?? "")
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
        // Convert the "N before" lead time into an absolute reminder time on the
        // day; storage/planning stay absolute, so only the input style changed.
        let reminderMinuteOfDay = reminderOffset.map { start - $0 }
        guard validateReminder(minuteOfDay: reminderMinuteOfDay) else { return }
        onConfirm(start, duration, colorIndex, customColorHex, reminderMinuteOfDay)
    }

    /// Enforce "within the day, later than now" on the resolved reminder time;
    /// surface an alert otherwise.
    private func validateReminder(minuteOfDay: Int?) -> Bool {
        guard let minuteOfDay else { return true }
        let result = ReminderTime.validate(minuteOfDay: minuteOfDay, dayStart: dayDate, now: now)
        reminderAlert = ReminderTime.alertMessage(for: result)
        return reminderAlert == nil
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
