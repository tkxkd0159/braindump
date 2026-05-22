import Foundation
import CoreText

public enum Fonts {
    public static let hankenGrotesk = "HankenGrotesk-Regular"
    public static let hankenGroteskItalic = "HankenGrotesk-Italic"
    public static let sourceSerif = "SourceSerif4Variable-Roman"
    public static let sourceSerifItalic = "SourceSerif4Variable-Italic"

    private static let resources = [
        "HankenGrotesk-Variable",
        "HankenGrotesk-Italic-Variable",
        "SourceSerif4-Variable",
        "SourceSerif4-Italic-Variable",
    ]

    @MainActor private static var didRegister = false

    @MainActor
    public static func registerIfNeeded() {
        guard !didRegister else { return }
        didRegister = true
        for name in resources {
            guard let url = Bundle.module.url(forResource: name, withExtension: "ttf") else {
                continue
            }
            var error: Unmanaged<CFError>?
            CTFontManagerRegisterFontsForURL(url as CFURL, .process, &error)
        }
    }
}
