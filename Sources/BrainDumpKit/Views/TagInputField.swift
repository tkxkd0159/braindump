import SwiftUI

/// Reminders-style tag editor. Typing a tag and pressing space commits it.
/// All known tags (from `TaskService.allTags()`) are surfaced as suggestion
/// chips below the input; the suggestion list filters by the current draft.
struct TagInputField: View {
    @Binding var tags: [String]
    @Binding var draft: String
    let allKnownTags: [String]
    let placeholder: String
    let isCompact: Bool

    @FocusState private var focused: Bool

    init(
        tags: Binding<[String]>,
        draft: Binding<String>,
        allKnownTags: [String],
        placeholder: String = "Tag",
        isCompact: Bool = false
    ) {
        self._tags = tags
        self._draft = draft
        self.allKnownTags = allKnownTags
        self.placeholder = placeholder
        self.isCompact = isCompact
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if !tags.isEmpty {
                FlowLayout(spacing: 6) {
                    ForEach(tags, id: \.self) { tag in
                        selectedChip(tag)
                    }
                }
            }
            TextField(placeholder, text: $draft)
                .textFieldStyle(.plain)
                .font(isCompact ? Theme.Font.caption : Theme.Font.bodyMd)
                .padding(isCompact ? 6 : 8)
                .background(Theme.Palette.surfaceContainer)
                .overlay(
                    Rectangle().strokeBorder(
                        focused ? Theme.Palette.primary : Theme.Palette.outlineVariant,
                        lineWidth: 1
                    )
                )
                .focused($focused)
                .onChange(of: draft) { _, new in
                    if let committed = TagInputHelpers.extractCommitOnSpace(new) {
                        addTagIfNew(committed)
                        draft = ""
                    }
                }
                .onSubmit(commitDraft)
            let suggestions = TagInputHelpers.filterSuggestions(
                allKnownTags: allKnownTags,
                selectedTags: tags,
                draft: draft
            )
            if !suggestions.isEmpty {
                FlowLayout(spacing: 6) {
                    ForEach(suggestions, id: \.self) { tag in
                        suggestionChip(tag)
                    }
                }
            }
        }
    }

    private func commitDraft() {
        let trimmed = draft.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        draft = ""
        guard !trimmed.isEmpty else { return }
        addTagIfNew(trimmed)
    }

    private func addTagIfNew(_ tag: String) {
        guard !tags.contains(tag) else { return }
        tags.append(tag)
    }

    private func selectedChip(_ tag: String) -> some View {
        HStack(spacing: 4) {
            Text(tag)
                .font(Theme.Font.caption)
                .foregroundStyle(Theme.Palette.onSurface)
            Button(action: { tags.removeAll { $0 == tag } }) {
                Image(systemName: "xmark")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(Theme.Palette.onSurfaceVariant)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Theme.Palette.surfaceContainerHigh)
    }

    private func suggestionChip(_ tag: String) -> some View {
        Button(action: {
            addTagIfNew(tag)
            draft = ""
        }) {
            HStack(spacing: 4) {
                Image(systemName: "plus")
                    .font(.system(size: 8, weight: .semibold))
                Text(tag)
                    .font(Theme.Font.caption)
            }
            .foregroundStyle(Theme.Palette.primaryContainer)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .overlay(Rectangle().strokeBorder(Theme.Palette.outlineVariant, lineWidth: 1))
        }
        .buttonStyle(.plain)
    }
}

enum TagInputHelpers {
    /// Returns the tag to commit when the input ends with a space, otherwise nil.
    /// The committed value is trimmed + lowercased. Empty/whitespace-only input
    /// returns nil so a stray space doesn't add a blank tag.
    static func extractCommitOnSpace(_ input: String) -> String? {
        guard input.hasSuffix(" ") else { return nil }
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !trimmed.isEmpty else { return nil }
        return trimmed
    }

    /// Filters `allKnownTags`: removes any already in `selectedTags`, and if
    /// `draft` is non-empty, keeps only tags that start with the draft prefix.
    static func filterSuggestions(
        allKnownTags: [String],
        selectedTags: [String],
        draft: String
    ) -> [String] {
        let selected = Set(selectedTags.map { $0.lowercased() })
        let prefix = draft.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return allKnownTags.filter { tag in
            let lower = tag.lowercased()
            return !selected.contains(lower) && (prefix.isEmpty || lower.hasPrefix(prefix))
        }
    }
}
