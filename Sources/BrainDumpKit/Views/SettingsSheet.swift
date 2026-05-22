import SwiftUI

public struct SettingsSheet: View {
    @Bindable var state: AppState
    let dismiss: () -> Void

    @State private var startHour: Int
    @State private var endHour: Int
    @State private var error: String?

    public init(state: AppState, dismiss: @escaping () -> Void) {
        self.state = state
        self.dismiss = dismiss
        _startHour = State(initialValue: state.dayStartHour)
        _endHour = State(initialValue: state.dayEndHour)
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            header
            dayWindowSection
            if let error {
                Text(error)
                    .font(Theme.Font.caption)
                    .foregroundStyle(Theme.Palette.secondary)
            }
            footer
        }
        .padding(28)
        .frame(width: 440)
        .background(Theme.Palette.surfaceContainerLowest)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Settings")
                .font(Theme.Font.tinyLabel)
                .tracking(1.5)
                .textCase(.uppercase)
                .foregroundStyle(Theme.Palette.primary)
            Text("Day Time Range")
                .font(Theme.Font.headlineMd)
                .foregroundStyle(Theme.Palette.onSurface)
            Text("Choose how early the schedule grid starts and how late it ends.")
                .font(Theme.Font.bodyMd)
                .foregroundStyle(Theme.Palette.onSurfaceVariant)
        }
    }

    private var dayWindowSection: some View {
        HStack(spacing: 16) {
            hourPicker(label: "Day starts at", selection: $startHour, range: 0...20)
            Image(systemName: "arrow.right")
                .font(.system(size: 13, weight: .regular))
                .foregroundStyle(Theme.Palette.onSurfaceVariant)
                .padding(.top, 20)
            hourPicker(label: "Day ends at", selection: $endHour, range: 4...24)
        }
    }

    private func hourPicker(label: String, selection: Binding<Int>, range: ClosedRange<Int>) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(Theme.Font.tinyLabel)
                .tracking(1.2)
                .foregroundStyle(Theme.Palette.onSurfaceVariant)
            Picker("", selection: selection) {
                ForEach(Array(range), id: \.self) { hour in
                    Text(displayHour(hour)).tag(hour)
                }
            }
            .labelsHidden()
            .pickerStyle(.menu)
            .frame(width: 140, alignment: .leading)
        }
    }

    private func displayHour(_ hour: Int) -> String {
        if hour == 24 { return "12:00 AM (next)" }
        let h = hour % 12 == 0 ? 12 : hour % 12
        let suffix = hour < 12 ? "AM" : "PM"
        return "\(h):00 \(suffix)"
    }

    private var footer: some View {
        HStack(spacing: 12) {
            Spacer()
            Button("Cancel", action: dismiss)
                .buttonStyle(.plain)
                .font(Theme.Font.labelMd)
                .padding(.horizontal, 18)
                .frame(height: 34)
                .foregroundStyle(Theme.Palette.primary)
                .overlay(Rectangle().strokeBorder(Theme.Palette.primary, lineWidth: 1))
                .keyboardShortcut(.cancelAction)
            Button("Save", action: save)
                .buttonStyle(.plain)
                .font(Theme.Font.labelMd)
                .padding(.horizontal, 18)
                .frame(height: 34)
                .foregroundStyle(Theme.Palette.onPrimary)
                .background(Theme.Palette.primary)
                .keyboardShortcut(.defaultAction)
        }
    }

    private func save() {
        if state.setDayBounds(startHour: startHour, endHour: endHour) {
            dismiss()
        } else {
            error = "Day must span at least 4 hours"
        }
    }
}
