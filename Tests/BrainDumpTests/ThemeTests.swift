import SwiftUI
import Testing
@testable import BrainDumpKit

@MainActor
@Test func blockPaletteResolvesCustomHexOverIndex() {
    #expect(Theme.BlockPalette.color(at: 0, customHex: "#123456").hexString == "#123456")
    // nil custom -> palette color for the index
    #expect(Theme.BlockPalette.color(at: 1, customHex: nil).hexString
        == Theme.BlockPalette.color(at: 1).hexString)
    // unparseable custom -> falls back to the palette color
    #expect(Theme.BlockPalette.color(at: 1, customHex: "bogus").hexString
        == Theme.BlockPalette.color(at: 1).hexString)
}

@MainActor
@Test func blockPaletteForegroundForCustomUsesLuminance() {
    // Light custom color -> dark text; dark custom color -> white text.
    #expect(Theme.BlockPalette.foreground(at: 0, customHex: "#FFFFFF").hexString == "#2A1F12")
    #expect(Theme.BlockPalette.foreground(at: 0, customHex: "#000000").hexString == "#FFFFFF")
    // nil custom -> palette foreground for the index (index 0 is white)
    #expect(Theme.BlockPalette.foreground(at: 0, customHex: nil).hexString
        == Theme.BlockPalette.foreground(at: 0).hexString)
}
