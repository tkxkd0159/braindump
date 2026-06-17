import Foundation
import SwiftUI

/// Converts a plain notes string into an `AttributedString` where **schemed**
/// URLs (matched text containing `"://"`) become crimson, underlined links.
/// Bare domains (`google.com`) and email addresses are intentionally left as
/// plain text — zero false positives.
public enum NoteText {
    private static let detector: NSDataDetector? = {
        try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue)
    }()

    public static func linkified(_ text: String) -> AttributedString {
        var attributed = AttributedString(text)
        guard !text.isEmpty, let detector else { return attributed }

        let fullRange = NSRange(text.startIndex..<text.endIndex, in: text)
        for match in detector.matches(in: text, options: [], range: fullRange) {
            guard let url = match.url,
                let stringRange = Range(match.range, in: text)
            else { continue }

            // Schemed URLs only: bare-domain and email matches have no "://".
            let matched = text[stringRange]
            guard matched.contains("://") else { continue }

            let lowerOffset = text.distance(from: text.startIndex, to: stringRange.lowerBound)
            let upperOffset = text.distance(from: text.startIndex, to: stringRange.upperBound)
            let lower = attributed.index(attributed.startIndex, offsetByCharacters: lowerOffset)
            let upper = attributed.index(attributed.startIndex, offsetByCharacters: upperOffset)

            attributed[lower..<upper].link = url
            attributed[lower..<upper].foregroundColor = Theme.Palette.secondary
            attributed[lower..<upper].underlineStyle = .single
        }
        return attributed
    }
}
