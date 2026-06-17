import SwiftUI

/// Google-Calendar-style reminder editor: a toggle plus an "N [minutes|hours]
/// before" input, replacing the absolute hour/minute clock picker. Binds to a
/// minutes-before-start offset (`nil` = no reminder); the host sheet converts
/// that to an absolute reminder time at commit and runs `ReminderTime.validate`
/// (within the day + later than now — the restriction is unchanged).
struct ReminderOffsetRow: View {
    @Binding var offsetMinutes: Int?

    @State private var amount: Int
    @State private var unit: ReminderTime.Unit

    /// Lead time applied when the reminder is first switched on.
    private static let defaultOffset = 10

    init(offsetMinutes: Binding<Int?>) {
        self._offsetMinutes = offsetMinutes
        let split = ReminderTime.split(offsetMinutes: offsetMinutes.wrappedValue ?? Self.defaultOffset)
        _amount = State(initialValue: split.amount)
        _unit = State(initialValue: split.unit)
    }

    private var enabledBinding: Binding<Bool> {
        Binding(
            get: { offsetMinutes != nil },
            set: { on in
                offsetMinutes = on ? ReminderTime.offsetMinutes(amount: amount, unit: unit) : nil
            }
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Toggle(isOn: enabledBinding) {
                Text("Reminder")
                    .font(Theme.Font.labelMd)
                    .foregroundStyle(Theme.Palette.onSurface)
            }
            .toggleStyle(.switch)
            if offsetMinutes != nil {
                HStack(spacing: 8) {
                    TextField("", value: $amount, format: .number)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 56)
                        .multilineTextAlignment(.trailing)
                        .onChange(of: amount) { _, _ in pushOffset() }
                    Picker("", selection: $unit) {
                        Text("minutes").tag(ReminderTime.Unit.minutes)
                        Text("hours").tag(ReminderTime.Unit.hours)
                    }
                    .labelsHidden()
                    .frame(width: 104)
                    .onChange(of: unit) { _, _ in pushOffset() }
                    Text("before")
                        .font(Theme.Font.bodyMd)
                        .foregroundStyle(Theme.Palette.onSurfaceVariant)
                    Spacer()
                }
            }
        }
    }

    private func pushOffset() {
        amount = max(0, amount)
        offsetMinutes = ReminderTime.offsetMinutes(amount: amount, unit: unit)
    }
}
