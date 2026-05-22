import Foundation
import Testing
@testable import BrainDumpKit

@Test func extractCommitOnSpaceReturnsTagWhenInputEndsInSpace() {
    #expect(TagInputHelpers.extractCommitOnSpace("writing ") == "writing")
    #expect(TagInputHelpers.extractCommitOnSpace("Deep-Work ") == "deep-work")
}

@Test func extractCommitOnSpaceReturnsNilWithoutTrailingSpace() {
    #expect(TagInputHelpers.extractCommitOnSpace("writing") == nil)
    #expect(TagInputHelpers.extractCommitOnSpace("") == nil)
}

@Test func extractCommitOnSpaceIgnoresWhitespaceOnly() {
    #expect(TagInputHelpers.extractCommitOnSpace("   ") == nil)
    #expect(TagInputHelpers.extractCommitOnSpace(" ") == nil)
}

@Test func extractCommitOnSpaceTrimsLeadingWhitespace() {
    #expect(TagInputHelpers.extractCommitOnSpace("  research ") == "research")
}

@Test func filterSuggestionsExcludesAlreadySelected() {
    let suggestions = TagInputHelpers.filterSuggestions(
        allKnownTags: ["writing", "research", "deep-work"],
        selectedTags: ["research"],
        draft: ""
    )
    #expect(suggestions == ["writing", "deep-work"])
}

@Test func filterSuggestionsFiltersByPrefix() {
    let suggestions = TagInputHelpers.filterSuggestions(
        allKnownTags: ["writing", "research", "deep-work"],
        selectedTags: [],
        draft: "de"
    )
    #expect(suggestions == ["deep-work"])
}

@Test func filterSuggestionsIsCaseInsensitive() {
    let suggestions = TagInputHelpers.filterSuggestions(
        allKnownTags: ["Writing", "Research"],
        selectedTags: ["WRITING"],
        draft: "RE"
    )
    #expect(suggestions == ["Research"])
}

@Test func filterSuggestionsReturnsAllWhenDraftEmpty() {
    let suggestions = TagInputHelpers.filterSuggestions(
        allKnownTags: ["a", "b", "c"],
        selectedTags: [],
        draft: ""
    )
    #expect(suggestions == ["a", "b", "c"])
}

@Test func filterSuggestionsReturnsEmptyWhenNoMatchingPrefix() {
    let suggestions = TagInputHelpers.filterSuggestions(
        allKnownTags: ["writing", "research"],
        selectedTags: [],
        draft: "xyz"
    )
    #expect(suggestions.isEmpty)
}

@MainActor
@Test func taskDetailFocusDefaultsToEditMode() {
    let item = TaskItem(title: "T")
    let focus = TaskDetailFocus(item: item)
    #expect(focus.startInEditMode == true)
}

@MainActor
@Test func taskDetailFocusHonorsExplicitReadOnly() {
    let item = TaskItem(title: "T")
    let focus = TaskDetailFocus(item: item, startInEditMode: false)
    #expect(focus.startInEditMode == false)
}
