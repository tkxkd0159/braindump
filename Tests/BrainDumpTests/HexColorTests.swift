import SwiftUI
import Testing
@testable import BrainDumpKit

@Test func hexColorParsesSixDigitWithHash() {
    let rgb = HexColor.parse("#1A2B3C")
    #expect(rgb != nil)
    #expect(rgb!.r == 26.0 / 255.0)   // 0x1A
    #expect(rgb!.g == 43.0 / 255.0)   // 0x2B
    #expect(rgb!.b == 60.0 / 255.0)   // 0x3C
}

@Test func hexColorParsesWithoutHashAndLowercase() {
    let rgb = HexColor.parse("1a2b3c")
    #expect(rgb != nil)
    #expect(rgb!.r == 26.0 / 255.0)
    #expect(rgb!.b == 60.0 / 255.0)
}

@Test func hexColorParsesPureBlackAndWhite() {
    #expect(HexColor.parse("#000000")! == (0, 0, 0))
    let white = HexColor.parse("#FFFFFF")!
    #expect(white.r == 1 && white.g == 1 && white.b == 1)
}

@Test func hexColorRejectsMalformedInput() {
    #expect(HexColor.parse("") == nil)
    #expect(HexColor.parse("#12345") == nil)    // 5 digits
    #expect(HexColor.parse("#1234567") == nil)  // 7 digits
    #expect(HexColor.parse("GGGGGG") == nil)    // non-hex
    #expect(HexColor.parse("#12 34 56") == nil) // spaces
}

@Test func hexColorStringIsCanonicalUppercase() {
    #expect(HexColor.string(r: 1, g: 1, b: 1) == "#FFFFFF")
    #expect(HexColor.string(r: 0, g: 0, b: 0) == "#000000")
    #expect(HexColor.string(r: 26.0 / 255.0, g: 43.0 / 255.0, b: 60.0 / 255.0) == "#1A2B3C")
}

@Test func hexColorStringClampsOutOfRange() {
    #expect(HexColor.string(r: 1.5, g: -0.2, b: 0.5) == "#FF0080")
}

@Test func hexColorRoundTrips() {
    for hex in ["#000613", "#B22738", "#C2A77E", "#2F6F6F"] {
        let rgb = HexColor.parse(hex)!
        #expect(HexColor.string(r: rgb.r, g: rgb.g, b: rgb.b) == hex)
    }
}

@Test func hexColorIsLightDrivesForegroundChoice() {
    #expect(HexColor.isLight(r: 1, g: 1, b: 1) == true)    // white
    #expect(HexColor.isLight(r: 0, g: 0, b: 0) == false)   // black
    let sand = HexColor.parse("#C2A77E")!
    #expect(HexColor.isLight(r: sand.r, g: sand.g, b: sand.b) == true)   // palette uses dark text
    let navy = HexColor.parse("#000613")!
    #expect(HexColor.isLight(r: navy.r, g: navy.g, b: navy.b) == false)  // palette uses white text
    let crimson = HexColor.parse("#B22738")!
    #expect(HexColor.isLight(r: crimson.r, g: crimson.g, b: crimson.b) == false)
}

@MainActor
@Test func colorHexBridgeRoundTrips() {
    let color = Color(hexString: "#1A2B3C")
    #expect(color != nil)
    #expect(color?.hexString == "#1A2B3C")
}

@MainActor
@Test func colorHexBridgeRejectsBadInput() {
    #expect(Color(hexString: "nope") == nil)
}

