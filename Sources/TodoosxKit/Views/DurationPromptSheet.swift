import SwiftUI

public struct DurationPromptSheet: View {
    let startHour: Int
    let maxDuration: Int
    let onConfirm: (Int) -> Void
    let onCancel: () -> Void

    @State private var duration: Int = 1

    public init(
        startHour: Int,
        maxDuration: Int,
        onConfirm: @escaping (Int) -> Void,
        onCancel: @escaping () -> Void
    ) {
        self.startHour = startHour
        self.maxDuration = maxDuration
        self.onConfirm = onConfirm
        self.onCancel = onCancel
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("How long for this task?")
                .font(.headline)
            Text("Starting at \(formattedHour(startHour))")
                .foregroundStyle(.secondary)

            HStack {
                ForEach(1...min(4, maxDuration), id: \.self) { value in
                    Button("\(value)h") { duration = value }
                        .buttonStyle(.bordered)
                        .tint(duration == value ? .accentColor : .secondary)
                }
                Stepper(value: $duration, in: 1...maxDuration) {
                    Text("\(duration) hour\(duration == 1 ? "" : "s")")
                }
            }

            HStack {
                Spacer()
                Button("Cancel", action: onCancel)
                    .keyboardShortcut(.cancelAction)
                Button("Schedule") { onConfirm(duration) }
                    .keyboardShortcut(.defaultAction)
                    .buttonStyle(.borderedProminent)
            }
        }
        .padding(24)
        .frame(width: 380)
    }

    private func formattedHour(_ hour: Int) -> String {
        let h = hour % 12 == 0 ? 12 : hour % 12
        let suffix = hour < 12 ? "AM" : "PM"
        return "\(h) \(suffix)"
    }
}
