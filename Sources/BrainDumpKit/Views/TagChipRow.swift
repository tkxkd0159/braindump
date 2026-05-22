import SwiftUI

/// Small wrapped row of tag chips, Reminders-style. Renders nothing when tags is empty.
public struct TagChipRow: View {
    let tags: [String]

    public init(tags: [String]) { self.tags = tags }

    public var body: some View {
        if tags.isEmpty {
            EmptyView()
        } else {
            FlowLayout(spacing: 6) {
                ForEach(tags, id: \.self) { tag in
                    Text("#\(tag)")
                        .font(Theme.Font.caption)
                        .foregroundStyle(Theme.Palette.onSurfaceVariant)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 2)
                        .background(Theme.Palette.surfaceContainerHigh)
                }
            }
        }
    }
}
