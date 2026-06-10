import os
import subprocess
import sys
import tempfile
import types
import unittest
import xml.etree.ElementTree as ET
from datetime import datetime, timezone

from make_appcast import _parse_date, build_item, build_release_notes_html, sp

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


class BuildItemTests(unittest.TestCase):
    def _args(self):
        return types.SimpleNamespace(
            version="0.2.0", build="3", tag="v0.2.0",
            zip="/tmp/BrainDump.zip", signature="SIG", min_system="14.0",
        )

    def test_description_present_and_release_notes_link_absent(self):
        item = build_item(self._args(), 12345, "<h2>hi</h2>", DATE)
        self.assertIsNotNone(item.find("description"))
        self.assertEqual(item.find("description").text, "<h2>hi</h2>")
        self.assertIsNone(item.find(sp("releaseNotesLink")))

    def test_enclosure_url_and_signature(self):
        enc = build_item(self._args(), 12345, "x", DATE).find("enclosure")
        self.assertEqual(
            enc.get("url"),
            "https://github.com/tkxkd0159/braindump/releases/download/v0.2.0/BrainDump.zip",
        )
        self.assertEqual(enc.get(sp("edSignature")), "SIG")


class IdempotencyTests(unittest.TestCase):
    SCRIPT = os.path.join(os.path.dirname(__file__), "make_appcast.py")

    def test_rerun_same_build_replaces_item(self):
        with tempfile.TemporaryDirectory() as d:
            zip_path = os.path.join(d, "BrainDump.zip")
            with open(zip_path, "wb") as fh:
                fh.write(b"x" * 64)
            changes = os.path.join(d, "changes.txt")
            with open(changes, "w", encoding="utf-8") as fh:
                fh.write("feat: thing\n")
            base = [
                sys.executable, self.SCRIPT,
                "--version", "0.2.0", "--build", "3", "--tag", "v0.2.0",
                "--zip", zip_path, "--signature", "SIG",
                "--changes-file", changes, "--date", "2026-06-09",
            ]
            out1 = os.path.join(d, "a.xml")
            subprocess.run(base + ["--out", out1], check=True)
            out2 = os.path.join(d, "b.xml")
            subprocess.run(base + ["--prev", out1, "--out", out2], check=True)
            items = ET.parse(out2).getroot().find("channel").findall("item")
            self.assertEqual(len(items), 1)
            self.assertIsNotNone(items[0].find("description"))
            self.assertIsNone(items[0].find(sp("releaseNotesLink")))


class ParseDateTests(unittest.TestCase):
    def test_date_only_is_parsed_and_assumed_utc(self):
        dt = _parse_date("2026-06-09")
        self.assertEqual((dt.year, dt.month, dt.day), (2026, 6, 9))
        self.assertEqual(dt.tzinfo, timezone.utc)

    def test_empty_defaults_to_aware_utc_now(self):
        dt = _parse_date("")
        self.assertEqual(dt.tzinfo, timezone.utc)


if __name__ == "__main__":
    unittest.main()
