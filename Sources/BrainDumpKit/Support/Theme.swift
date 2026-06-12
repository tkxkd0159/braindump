import SwiftUI

public enum Theme {
    public enum Palette {
        public static let surface = Color(hex: 0xF8F9FF)
        public static let surfaceDim = Color(hex: 0xD0DBED)
        public static let surfaceBright = Color(hex: 0xF8F9FF)
        public static let surfaceContainerLowest = Color(hex: 0xFFFFFF)
        public static let surfaceContainerLow = Color(hex: 0xEFF4FF)
        public static let surfaceContainer = Color(hex: 0xE6EEFF)
        public static let surfaceContainerHigh = Color(hex: 0xDEE9FC)
        public static let surfaceContainerHighest = Color(hex: 0xD9E3F6)
        public static let onSurface = Color(hex: 0x121C2A)
        public static let onSurfaceVariant = Color(hex: 0x43474E)
        public static let outline = Color(hex: 0x74777F)
        public static let outlineVariant = Color(hex: 0xC4C6CF)
        public static let primary = Color(hex: 0x000613)
        public static let onPrimary = Color(hex: 0xFFFFFF)
        public static let primaryContainer = Color(hex: 0x001F3F)
        public static let onPrimaryContainer = Color(hex: 0x6F88AD)
        public static let secondary = Color(hex: 0xB22738)
        public static let inverseOnSurface = Color(hex: 0xEAF1FF)
    }

    /// Curated Neo-Academic schedule-block palette. Index 0 matches the
    /// historical "Deep Work" navy so existing entries render unchanged.
    public enum BlockPalette {
        public static let colors: [Color] = [
            Color(hex: 0x000613), // navy (default)
            Color(hex: 0xB22738), // crimson
            Color(hex: 0x2F4F4F), // slate
            Color(hex: 0x556B2F), // olive
            Color(hex: 0x5D3754), // plum
            Color(hex: 0xC2A77E), // sand
            Color(hex: 0x2F6F6F), // teal
            Color(hex: 0xA8553A)  // terracotta
        ]

        /// Foreground used on top of `colors[i]`. Sand uses dark text; the
        /// rest use white for legibility.
        public static let foregrounds: [Color] = [
            Color(hex: 0xFFFFFF),
            Color(hex: 0xFFFFFF),
            Color(hex: 0xFFFFFF),
            Color(hex: 0xFFFFFF),
            Color(hex: 0xFFFFFF),
            Color(hex: 0x2A1F12), // dark on sand
            Color(hex: 0xFFFFFF),
            Color(hex: 0xFFFFFF)
        ]

        public static func color(at index: Int) -> Color {
            let safeIndex = max(0, min(colors.count - 1, index))
            return colors[safeIndex]
        }

        public static func foreground(at index: Int) -> Color {
            let safeIndex = max(0, min(foregrounds.count - 1, index))
            return foregrounds[safeIndex]
        }
    }

    public enum Font {
        public static let displayLg = sans(size: 48, weight: .bold)
        public static let headlineLg = sans(size: 32, weight: .semibold)
        public static let headlineMd = sans(size: 24, weight: .medium)
        public static let headlineSmall = sans(size: 18, weight: .semibold)
        // Section header: 14px Hanken Grotesk medium uppercased (Top Priorities, Schedule).
        public static let sectionLabel = sans(size: 14, weight: .medium)
        // Brain Dump variant uses font-semibold per reference markup.
        public static let sectionLabelHeavy = sans(size: 14, weight: .semibold)
        public static let labelMd = sans(size: 14, weight: .semibold)
        // Sidebar navigation rows — a touch larger than labelMd for readability.
        public static let navLabel = sans(size: 15, weight: .semibold)
        public static let bodyLg = serif(size: 18, weight: .regular)
        public static let bodyLgSemibold = serif(size: 18, weight: .semibold)
        public static let bodyMd = serif(size: 16, weight: .regular)
        public static let bodyMdItalic = serifItalic(size: 16, weight: .regular)
        public static let caption = sans(size: 12, weight: .regular)
        public static let tinyLabel = sans(size: 10, weight: .semibold)
        public static let timeLabelHour = sans(size: 12, weight: .bold)
        public static let timeLabelHalf = sans(size: 12, weight: .semibold)

        public static func sans(size: CGFloat, weight: SwiftUI.Font.Weight) -> SwiftUI.Font {
            SwiftUI.Font.custom(Fonts.hankenGrotesk, size: size).weight(weight)
        }

        public static func serif(size: CGFloat, weight: SwiftUI.Font.Weight) -> SwiftUI.Font {
            SwiftUI.Font.custom(Fonts.sourceSerif, size: size).weight(weight)
        }

        public static func serifItalic(size: CGFloat, weight: SwiftUI.Font.Weight) -> SwiftUI.Font {
            SwiftUI.Font.custom(Fonts.sourceSerifItalic, size: size).weight(weight)
        }
    }
}

extension Color {
    init(hex: UInt32, opacity: Double = 1.0) {
        let r = Double((hex >> 16) & 0xFF) / 255.0
        let g = Double((hex >> 8) & 0xFF) / 255.0
        let b = Double(hex & 0xFF) / 255.0
        self.init(.sRGB, red: r, green: g, blue: b, opacity: opacity)
    }
}
