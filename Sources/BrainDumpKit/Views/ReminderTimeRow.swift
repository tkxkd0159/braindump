import SwiftUI

/// A Google-Calendar-style reminder editor: a toggle plus an absolute
/// time-of-day `DatePicker`, bound to a minute-of-day on the entry's day.
/// `minuteOfDay == nil` means no reminder. Validation ("within the day, later
/// than now") and the alert live in the hosting sheet, which has the clock.
struct ReminderTimeRow: View {
    @Binding var minuteOfDay: Int?
    /// Start-of-local-day of the entry's day; anchors the time picker.
    let dayDate: Date
    /// Minute-of-day used when the reminder is first switched on (block start).
    let defaultMinute: Int

    private var enabledBinding: Binding<Bool> {
        Binding(
            get: { minuteOfDay != nil },
            set: { on in minuteOfDay = on ? defaultMinute : nil }
        )
    }

    private var timeBinding: Binding<Date> {
        Binding(
            get: { dayDate.addingTimeInterval(TimeInterval((minuteOfDay ?? defaultMinute) * 60)) },
            set: { newDate in
                let mins = Int((newDate.timeIntervalSince(dayDate) / 60).rounded())
                minuteOfDay = max(0, min(24 * 60 - 1, mins))
            }
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Toggle(isOn: enabledBinding) {
                Text("Reminder")
                    .font(Theme.Font.labelMd)
                    .foregroundStyle(Theme.Palette.onSurface)
            }
            .toggleStyle(.switch)
            if minuteOfDay != nil {
                DatePicker("", selection: timeBinding, displayedComponents: .hourAndMinute)
                    .labelsHidden()
                    .help("Reminder time")
            }
        }
    }
}
