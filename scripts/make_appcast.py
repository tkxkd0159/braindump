#!/usr/bin/env python3
"""Build or update the Sparkle appcast for a Brain Dump release.

Each GitHub release stores its zip as a per-tag asset, so a single shared
download-url-prefix (which Sparkle's `generate_appcast` assumes) cannot produce
correct URLs for older items. This script builds one <item> with the correct
per-tag enclosure URL and merges it (newest first) into the previous appcast,
preserving older items and their own per-tag URLs. Re-running for the same
build number is idempotent (the matching item is replaced).
"""
import argparse
import html
import os
import re
import sys
import xml.etree.ElementTree as ET
from email.utils import formatdate

REPO = "tkxkd0159/braindump"
SPARKLE = "http://www.andymatuschak.org/xml-namespaces/sparkle"
ET.register_namespace("sparkle", SPARKLE)

# Conventional-commit type -> release-notes section. Allowlist only: any type
# not listed here (and any unprefixed subject) is dropped from the user-facing
# notes, so chores/docs/ci can never leak in. The full list still lives on the
# GitHub release page.
SECTIONS = (
    ("Features", {"feat"}),
    ("Fixes", {"fix", "perf"}),
)
_PREFIX_RE = re.compile(r"^(?P<type>[a-z]+)(?:\([^)]*\))?!?:\s*(?P<desc>.+)$")
_TRAILING_PR_RE = re.compile(r"\s*\(#\d+\)\s*$")
# Locale-independent month names (strftime('%B') would localize on some runners).
_MONTHS = (
    "January", "February", "March", "April", "May", "June",
    "July", "August", "September", "October", "November", "December",
)


def sp(tag: str) -> str:
    return f"{{{SPARKLE}}}{tag}"


def _clean_description(desc: str) -> str:
    """Strip a trailing (#123) and upper-case the first character."""
    desc = _TRAILING_PR_RE.sub("", desc).strip()
    if desc:
        desc = desc[0].upper() + desc[1:]
    return desc


def build_release_notes_html(subjects, version, date, repo, tag) -> str:
    """Categorized, cleaned HTML release notes for the Sparkle update screen."""
    type_to_section = {t: name for name, types in SECTIONS for t in types}
    buckets = {name: [] for name, _ in SECTIONS}
    dropped = []
    for subject in subjects:
        subject = subject.strip()
        if not subject:
            continue
        match = _PREFIX_RE.match(subject)
        if match is None:
            dropped.append(subject)
            continue
        section = type_to_section.get(match.group("type"))
        if section is None:
            dropped.append(subject)
            continue
        buckets[section].append(_clean_description(match.group("desc")))

    if dropped:
        print(
            f"make_appcast: dropped {len(dropped)} non-user-facing commit(s) "
            f"from the in-app notes (still on the GitHub release page):",
            file=sys.stderr,
        )
        for line in dropped:
            print(f"  - {line}", file=sys.stderr)

    date_str = f"{_MONTHS[date.month - 1]} {date.day}, {date.year}"
    parts = [f"<h2>Brain Dump {html.escape(version)} — {date_str}</h2>"]

    if any(buckets[name] for name, _ in SECTIONS):
        for name, _ in SECTIONS:
            items = buckets[name]
            if not items:
                continue
            parts.append(f"<h3>{name}</h3>")
            parts.append("<ul>")
            parts.extend(f"<li>{html.escape(item)}</li>" for item in items)
            parts.append("</ul>")
    else:
        parts.append(
            "<p>This release includes maintenance and behind-the-scenes "
            "improvements.</p>"
        )

    notes_url = f"https://github.com/{repo}/releases/tag/{tag}"
    parts.append(
        f'<p><a href="{html.escape(notes_url)}">'
        f"Full release notes on GitHub →</a></p>"
    )
    return "\n".join(parts)


def build_item(args, length: int) -> ET.Element:
    item = ET.Element("item")
    ET.SubElement(item, "title").text = args.version
    ET.SubElement(item, "pubDate").text = formatdate(localtime=False)
    ET.SubElement(item, sp("version")).text = args.build
    ET.SubElement(item, sp("shortVersionString")).text = args.version
    ET.SubElement(item, sp("minimumSystemVersion")).text = args.min_system
    ET.SubElement(item, sp("releaseNotesLink")).text = (
        f"https://github.com/{REPO}/releases/tag/{args.tag}"
    )
    url = (
        f"https://github.com/{REPO}/releases/download/"
        f"{args.tag}/{os.path.basename(args.zip)}"
    )
    enc = ET.SubElement(item, "enclosure")
    enc.set("url", url)
    enc.set("type", "application/octet-stream")
    enc.set("length", str(length))
    enc.set(sp("edSignature"), args.signature)
    return item


def main() -> None:
    p = argparse.ArgumentParser()
    p.add_argument("--prev", default="")
    p.add_argument("--version", required=True)
    p.add_argument("--build", required=True)
    p.add_argument("--tag", required=True)
    p.add_argument("--zip", required=True)
    p.add_argument("--signature", required=True)
    p.add_argument("--min-system", default="14.0")
    p.add_argument("--out", required=True)
    args = p.parse_args()

    length = os.path.getsize(args.zip)

    if args.prev and os.path.exists(args.prev):
        tree = ET.parse(args.prev)
        root = tree.getroot()
        channel = root.find("channel")
        if channel is None:
            print("prev appcast is missing <channel>", file=sys.stderr)
            sys.exit(1)
        for it in list(channel.findall("item")):  # idempotent re-runs
            v = it.find(sp("version"))
            if v is not None and v.text == args.build:
                channel.remove(it)
    else:
        root = ET.Element("rss", {"version": "2.0"})
        channel = ET.SubElement(root, "channel")
        ET.SubElement(channel, "title").text = "Brain Dump"
        tree = ET.ElementTree(root)

    children = list(channel)
    first_item_idx = next(
        (i for i, c in enumerate(children) if c.tag == "item"), len(children)
    )
    channel.insert(first_item_idx, build_item(args, length))

    tree.write(args.out, encoding="utf-8", xml_declaration=True)


if __name__ == "__main__":
    main()
