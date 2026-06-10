import unittest
from datetime import datetime, timezone

from make_appcast import build_release_notes_html

DATE = datetime(2026, 6, 9, tzinfo=timezone.utc)
REPO = "tkxkd0159/braindump"


def notes(subjects, version="0.2.0", tag="v0.2.0"):
    return build_release_notes_html(subjects, version, DATE, REPO, tag)


class ReleaseNotesHTMLTests(unittest.TestCase):
    def test_feat_to_features(self):
        out = notes(["feat: background auto-update via Sparkle"])
        self.assertIn("<h3>Features</h3>", out)
        self.assertIn("<li>Background auto-update via Sparkle</li>", out)
        self.assertNotIn("<h3>Fixes</h3>", out)

    def test_fix_and_perf_to_fixes(self):
        out = notes(["fix: roll-forward no longer drops tags", "perf: faster launch"])
        self.assertIn("<h3>Fixes</h3>", out)
        self.assertIn("<li>Roll-forward no longer drops tags</li>", out)
        self.assertIn("<li>Faster launch</li>", out)

    def test_chore_docs_ci_dropped(self):
        out = notes(["chore: bump deps", "docs: readme", "ci: tweak"])
        self.assertNotIn("<h3>Features</h3>", out)
        self.assertNotIn("<h3>Fixes</h3>", out)
        self.assertIn("maintenance and behind-the-scenes", out)

    def test_unprefixed_dropped(self):
        out = notes(["Update README", "feat: real feature"])
        self.assertNotIn("Update README", out)
        self.assertIn("<li>Real feature</li>", out)

    def test_pr_number_stripped(self):
        self.assertIn("<li>Add scroll layout</li>", notes(["feat: add scroll layout (#1)"]))

    def test_scope_and_bang(self):
        self.assertIn("<li>Redesign sheet</li>", notes(["feat(ui)!: redesign sheet"]))

    def test_header_format_is_locale_independent(self):
        self.assertIn("<h2>Brain Dump 0.2.0 — June 9, 2026</h2>", notes(["feat: x"]))

    def test_full_notes_link(self):
        self.assertIn(
            '<p><a href="https://github.com/tkxkd0159/braindump/releases/tag/v0.2.0">'
            'Full release notes on GitHub →</a></p>',
            notes(["feat: x"]),
        )

    def test_html_escaping(self):
        out = notes(['feat: A & B <x> "q"'])
        self.assertIn("<li>A &amp; B &lt;x&gt;", out)
        self.assertIn("&quot;q&quot;", out)
        self.assertNotIn("<x>", out)

    def test_empty_changelog_fallback(self):
        out = notes([])
        self.assertIn("maintenance and behind-the-scenes", out)
        self.assertNotIn("<ul>", out)

    def test_features_render_before_fixes(self):
        out = notes(["fix: a bug", "feat: a feature"])
        self.assertLess(out.index("Features"), out.index("Fixes"))


if __name__ == "__main__":
    unittest.main()
