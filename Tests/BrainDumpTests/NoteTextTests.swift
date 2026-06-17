import Foundation
import Testing

@testable import BrainDumpKit

struct NoteTextTests {
    /// Collects the plain text covered by `.link` runs, in order.
    private func linkedText(_ attributed: AttributedString) -> String {
        attributed.runs
            .filter { $0.link != nil }
            .map { String(attributed[$0.range].characters) }
            .joined(separator: "|")
    }

    /// Collects the URLs of `.link` runs, in order.
    private func linkedURLs(_ attributed: AttributedString) -> [URL] {
        attributed.runs.compactMap { $0.link }
    }

    @Test
    func schemedURLBecomesLink() {
        let result = NoteText.linkified("Spec at https://google.com today")
        #expect(linkedURLs(result) == [URL(string: "https://google.com")!])
        #expect(linkedText(result) == "https://google.com")
    }

    @Test
    func httpSchemeBecomesLink() {
        let result = NoteText.linkified("http://example.org")
        #expect(linkedURLs(result) == [URL(string: "http://example.org")!])
    }

    @Test
    func bareDomainStaysPlain() {
        let result = NoteText.linkified("visit google.com and www.apple.com")
        #expect(result.runs.allSatisfy { $0.link == nil })
    }

    @Test
    func emailStaysPlain() {
        let result = NoteText.linkified("ping jsl@linecorp.com please")
        #expect(result.runs.allSatisfy { $0.link == nil })
    }

    @Test
    func multipleSchemedURLs() {
        let result = NoteText.linkified("a https://a.com b http://b.org")
        #expect(linkedURLs(result) == [URL(string: "https://a.com")!, URL(string: "http://b.org")!])
    }

    @Test
    func trailingPunctuationExcluded() {
        let result = NoteText.linkified("See https://google.com.")
        #expect(linkedText(result) == "https://google.com")
    }

    @Test
    func plainTextHasNoLinks() {
        let result = NoteText.linkified("just some notes, nothing to click")
        #expect(result.runs.allSatisfy { $0.link == nil })
    }

    @Test
    func emptyStringIsEmpty() {
        let result = NoteText.linkified("")
        #expect(String(result.characters).isEmpty)
        #expect(result.runs.allSatisfy { $0.link == nil })
    }
}
