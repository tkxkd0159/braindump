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
import os
import sys
import xml.etree.ElementTree as ET
from email.utils import formatdate

REPO = "tkxkd0159/braindump"
SPARKLE = "http://www.andymatuschak.org/xml-namespaces/sparkle"
ET.register_namespace("sparkle", SPARKLE)


def sp(tag: str) -> str:
    return f"{{{SPARKLE}}}{tag}"


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
