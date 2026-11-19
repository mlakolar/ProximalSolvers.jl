#!/usr/bin/env python3
"""Inventory and verify the one-time Learn / Use / Contracts migration.

The manifest records original text, not just vocabulary. Unchanged blocks are
checked mechanically; consolidated blocks require an explicit reviewed mapping.
The completed manifest is historical evidence, not a permanent freeze on prose.
"""
from __future__ import annotations

import argparse
import csv
import hashlib
import json
import re
import subprocess
import sys
from collections import Counter
from html.parser import HTMLParser
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
MIGRATION = ROOT / "docs/migration"
PAGES = ["index.md", "getting-started.md", "concepts.md", "sparsity-and-kkt.md",
         "choosing-solver.md", "numerics.md", "stopping-limits.md", "support.md",
         "working-with-results.md", "benchmarks.md", "glossary.md", "api.md",
         "internals.md", "developer/implementation-notes.md"]
FIELDS = ["block_id", "sha256", "preview", "audience", "disposition", "destination",
          "additional_destinations", "phase", "note", "link_edits"]
FENCE = re.compile(r"^\s{0,3}(`{3,}|~{3,})(.*)$")
HEADING = re.compile(r"^\s{0,3}#{1,6}\s+")
ITEM = re.compile(r"^\s{0,3}(?:[-+*]|\d+[.)])\s+")


def sha(text):
    return hashlib.sha256(text.encode()).hexdigest()


def git(*args):
    return subprocess.check_output(["git", *args], cwd=ROOT, text=True)


def blocks(text, source, first_line=1, prefix=""):
    """Partition nonblank Markdown into headings, rows, paragraphs and fences.

    Blank lines delimit prose paragraphs, including paragraphs within long list
    items. Fenced examples and indented admonitions remain indivisible. Every
    nonblank source line belongs to exactly one block.
    """
    lines = text.splitlines(keepends=True)
    i = 0
    while i < len(lines):
        if not lines[i].strip():
            i += 1
            continue
        start = i
        fence = FENCE.match(lines[i])
        if fence:
            marker = fence[1]
            kind = "example" if fence[2].strip().startswith("@example") else "code"
            i += 1
            while i < len(lines):
                closing = FENCE.match(lines[i])
                i += 1
                if closing and closing[1][0] == marker[0] and len(closing[1]) >= len(marker) and not closing[2].strip():
                    break
        elif HEADING.match(lines[i]):
            kind, i = "heading", i + 1
        elif lines[i].lstrip().startswith("|"):
            kind, i = "table", i + 1
        elif lines[i].lstrip().startswith("!!!"):
            kind, i = "admonition", i + 1
            while i < len(lines) and (not lines[i].strip() or lines[i].startswith("    ")):
                i += 1
        else:
            kind = "list" if ITEM.match(lines[i]) else "paragraph"
            i += 1
            while i < len(lines) and lines[i].strip():
                if FENCE.match(lines[i]) or HEADING.match(lines[i]) or ITEM.match(lines[i]) or lines[i].lstrip().startswith("|"):
                    break
                i += 1
        value = "".join(lines[start:i]).rstrip("\n")
        yield {"id": f"{prefix}{source}:L{first_line + start}", "source": source,
               "start_line": first_line + start, "end_line": first_line + i - 1,
               "kind": kind, "text": value, "sha256": sha(value)}


def docstring_blocks(text, source):
    lines = text.splitlines(keepends=True)
    delimiters = [i for i, line in enumerate(lines) if re.fullmatch(r'\s*(?:raw)?"""\s*', line)]
    if len(delimiters) % 2:
        raise ValueError(f"Unpaired standalone docstring delimiters in {source}")
    for start, end in zip(delimiters[::2], delimiters[1::2]):
        yield from blocks("".join(lines[start + 1:end]), source, start + 2, "docstring:")


def slug(label):
    explicit = re.search(r"\[.*?\]\(@id\s+([^\)]+)\)", label)
    if explicit:
        return explicit[1]
    label = re.sub(r"[`*_]", "", label.strip())
    label = re.sub(r"\[([^\]]+)\]\([^\)]+\)", r"\1", label)
    return re.sub(r"\s+", "-", label)


def extract(ref):
    revision = git("rev-parse", ref).strip()
    paths = ["README.md", "examples/README.md"] + ["docs/src/" + p for p in PAGES]
    tree = git("ls-tree", "-r", "--name-only", revision).splitlines()
    paths += [p for p in tree if p.startswith("src/") and p.endswith(".jl")]
    entries, files, urls = [], {}, []
    for path in paths:
        text = git("show", f"{revision}:{path}")
        files[path] = sha(text)
        current = list(docstring_blocks(text, path) if path.startswith("src/") else blocks(text, path))
        entries += current
        if path.startswith("docs/src/"):
            for block in current:
                if block["kind"] == "heading":
                    label = re.sub(r"^\s*#+\s+", "", block["text"])
                    urls.append({"page": path.removeprefix("docs/src/").removesuffix(".md"),
                                 "fragment": slug(label), "heading": label})
    scripts = {p: sha(git("show", f"{revision}:{p}")) for p in tree
               if p.startswith("examples/") and p.endswith(".jl")}
    manifest = {"version": 1, "baseline": revision, "files": files, "blocks": entries,
                "example_scripts": scripts, "urls": urls}
    MIGRATION.mkdir(parents=True, exist_ok=True)
    (MIGRATION / "baseline.json").write_text(json.dumps(manifest, ensure_ascii=False, indent=2) + "\n")
    with (MIGRATION / "ledger.csv").open("w", newline="") as stream:
        writer = csv.DictWriter(stream, fieldnames=FIELDS)
        writer.writeheader()
        for block in entries:
            writer.writerow({"block_id": block["id"], "sha256": block["sha256"],
                             "preview": " ".join(block["text"].split())[:80],
                             "audience": "use", "disposition": "example" if block["kind"] == "example" else "moved",
                             "destination": block["source"], "phase": "baseline",
                             "note": "Retained at baseline location."})
    print(f"Inventoried {len(entries)} blocks, {sum(b['kind'] == 'example' for b in entries)} inline examples, "
          f"{len(scripts)} scripts and {len(urls)} page fragments at {revision}.")


def source_text(path):
    text = (ROOT / path).read_text()
    if path.startswith("src/") and path.endswith(".jl"):
        return "\n\n".join(b["text"] for b in docstring_blocks(text, path))
    return text


def destination_parts(value):
    return value.split("#", 1) if "#" in value else (value, "")


def destination_exists(value):
    path, anchor = destination_parts(value)
    file = ROOT / path
    if not file.is_file():
        return False
    return not anchor or bool(re.search(r"\(@id\s+" + re.escape(anchor) + r"\)", file.read_text()))


def check(report_only=False):
    manifest = json.loads((MIGRATION / "baseline.json").read_text())
    with (MIGRATION / "ledger.csv").open(newline="") as stream:
        rows = list(csv.DictReader(stream))
    originals = {b["id"]: b for b in manifest["blocks"]}
    counts = Counter(r["block_id"] for r in rows)
    errors = [f"{bid}: expected one ledger row, found {counts[bid]}" for bid in originals if counts[bid] != 1]
    errors += [f"Unknown source block: {bid}" for bid in counts if bid not in originals]
    cache = {}
    for row in rows:
        block = originals.get(row["block_id"])
        if not block:
            continue
        if row["sha256"] != block["sha256"] or sha(block["text"]) != block["sha256"]:
            errors.append(f"{block['id']}: baseline hash changed")
        destinations = [row["destination"]] + [v for v in row["additional_destinations"].split(";") if v]
        if not all(destination_exists(d) for d in destinations):
            errors.append(f"{block['id']}: missing destination {destinations}")
            continue
        destination, _ = destination_parts(row["destination"])
        if destination not in cache:
            cache[destination] = source_text(destination)
        disposition = row["disposition"]
        if disposition in {"moved", "example", "linked"}:
            value = block["text"]
            edits = json.loads(row["link_edits"] or "[]")
            for old, new in edits:
                if old not in value or not (old.startswith("](") or old.startswith("(@ref ")):
                    errors.append(f"{block['id']}: invalid mechanical link edit {old!r}")
                value = value.replace(old, new)
            if value not in cache[destination]:
                errors.append(f"{block['id']}: unchanged text not found in {destination}")
            if block["kind"] == "example" and disposition != "example":
                errors.append(f"{block['id']}: executable example needs example disposition")
        elif disposition in {"merged", "summarized", "split"}:
            if not row["note"].strip():
                errors.append(f"{block['id']}: semantic mapping needs a review note")
            for target in destinations:
                path, anchor = destination_parts(target)
                if not anchor:
                    errors.append(f"{block['id']}: semantic mapping needs a destination anchor")
                if path.startswith("docs/src/contracts/") and block["id"] not in (ROOT / path).read_text():
                    errors.append(f"{block['id']}: contract destination does not cite source block")
            if block["kind"] == "example":
                errors.append(f"{block['id']}: original executable blocks must retain their code")
        elif disposition == "superseded":
            if not row["note"].strip() or "https://github.com/" not in row["note"]:
                errors.append(f"{block['id']}: supersession needs the owner decision URL")
            if block["text"] not in cache[destination]:
                errors.append(f"{block['id']}: superseded wording must be preserved")
        else:
            errors.append(f"{block['id']}: unknown disposition {disposition!r}")
    for path, digest in manifest["example_scripts"].items():
        if not (ROOT / path).is_file() or sha((ROOT / path).read_text()) != digest:
            errors.append(f"Original example script changed or missing: {path}")
    print(f"Ledger: {len(originals)} baseline blocks; {dict(Counter(r['disposition'] for r in rows))}; {len(errors)} errors.")
    for error in errors:
        print(error, file=sys.stderr)
    return 0 if report_only or not errors else 1


class HTMLIds(HTMLParser):
    def __init__(self):
        super().__init__()
        self.ids = set()

    def handle_starttag(self, tag, attrs):
        self.ids.update(v for k, v in attrs if k in {"id", "name"})


def check_urls(build):
    manifest = json.loads((MIGRATION / "baseline.json").read_text())
    errors, cache = [], {}
    for entry in manifest["urls"]:
        candidates = [build / entry["page"] / "index.html", build / (entry["page"] + ".html")]
        path = next((p for p in candidates if p.is_file()), None)
        if path is None:
            errors.append(f"Missing old page: {entry['page']}")
            continue
        if path not in cache:
            parser = HTMLIds()
            parser.feed(path.read_text())
            cache[path] = parser.ids
        if entry["fragment"] not in cache[path]:
            errors.append(f"Missing old fragment: {entry['page']}#{entry['fragment']}")
    print(f"URL compatibility: {len(manifest['urls'])} baseline fragments; {len(errors)} errors.")
    for error in errors:
        print(error, file=sys.stderr)
    return bool(errors)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    sub = parser.add_subparsers(dest="command", required=True)
    extraction = sub.add_parser("extract")
    extraction.add_argument("--ref", required=True)
    checking = sub.add_parser("check")
    checking.add_argument("--report-only", action="store_true")
    links = sub.add_parser("check-urls")
    links.add_argument("--build", type=Path, default=ROOT / "docs/build")
    args = parser.parse_args()
    if args.command == "extract":
        extract(args.ref)
        return 0
    if args.command == "check":
        return check(args.report_only)
    return check_urls(args.build)


if __name__ == "__main__":
    sys.exit(main())
