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
import unicodedata
from collections import Counter
from html.parser import HTMLParser
from pathlib import Path

from check_docs_layers import active_headings, active_sections, migration_example_scripts, source_code_sha256

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


def active_examples(text):
    """Yield executable fences, excluding literal outer fences and HTML comments."""
    fence, example, in_comment = None, [], False
    for line in text.splitlines(keepends=True):
        if fence is not None:
            if example:
                example.append(line)
            closing = FENCE.match(line)
            if (closing and closing[1][0] == fence[0]
                    and len(closing[1]) >= len(fence) and not closing[2].strip()):
                if example:
                    yield "".join(example).rstrip("\n")
                fence, example = None, []
            continue
        visible, position = [], 0
        while position < len(line):
            if in_comment:
                end = line.find("-->", position)
                if end < 0:
                    break
                in_comment, position = False, end + 3
            else:
                begin = line.find("<!--", position)
                if begin < 0:
                    visible.append(line[position:])
                    break
                visible.append(line[position:begin])
                in_comment, position = True, begin + 4
        content = "".join(visible)
        opening = FENCE.match(content)
        if opening:
            fence = opening[1]
            if re.match(r"@example(?:\s|$)", opening[2].strip()):
                example = [content]


def slug(label):
    explicit = re.search(r"\[.*?\]\(@id\s+([^\)]+)\)", label)
    if explicit:
        return explicit[1]
    label = re.sub(r"[`*_]", "", label.strip())
    label = re.sub(r"\[([^\]]+)\]\([^\)]+\)", r"\1", label)
    label = re.sub(r"\s+", "-", label).replace("&", "-and-")
    label = "".join(c for c in label if unicodedata.category(c)[0] in "LP" or c.isdigit() or c == "-")
    return re.sub(r"-+", "-", label).strip("-")


def _git_bytes(*args):
    """Read Git objects without newline conversion or worktree writes."""
    try:
        return subprocess.check_output(["git", *args], cwd=ROOT, stderr=subprocess.PIPE)
    except (OSError, subprocess.CalledProcessError) as exc:
        detail = getattr(exc, "stderr", b"")
        if isinstance(detail, bytes):
            detail = detail.decode("utf-8", errors="replace").strip()
        raise ValueError(f"Cannot read Git object ({' '.join(args)}): {detail or exc}") from exc


def _commit(ref):
    if not isinstance(ref, str) or not ref.strip():
        raise ValueError("A nonempty Git revision is required")
    try:
        return _git_bytes("rev-parse", "--verify", "--end-of-options", ref + "^{commit}").decode().strip()
    except ValueError as exc:
        raise ValueError(f"Cannot resolve revision {ref!r} to an available commit") from exc


def _implementation_fingerprints(revision):
    tree = _git_bytes("ls-tree", "-r", "--name-only", revision).decode("utf-8").splitlines()
    return {path: source_code_sha256(_git_bytes("show", f"{revision}:{path}"), path)
            for path in tree if path.startswith("src/") and path.endswith(".jl")}


def _example_fingerprints(revision):
    tree = _git_bytes("ls-tree", "-r", "--name-only", revision).decode("utf-8").splitlines()
    return {path: hashlib.sha256(_git_bytes("show", f"{revision}:{path}")).hexdigest()
            for path in tree if path.startswith("examples/") and path.endswith(".jl")}


def inventory(ref):
    """Reconstruct the immutable inventory from one commit, without writing it."""
    revision = _commit(ref)
    paths = ["README.md", "examples/README.md"] + ["docs/src/" + p for p in PAGES]
    tree = _git_bytes("ls-tree", "-r", "--name-only", revision).decode("utf-8").splitlines()
    paths += [p for p in tree if p.startswith("src/") and p.endswith(".jl")]
    entries, files, urls, source_fingerprints = [], {}, [], {}
    for path in paths:
        raw = _git_bytes("show", f"{revision}:{path}")
        text = raw.decode("utf-8")
        files[path] = hashlib.sha256(raw).hexdigest()
        if path.startswith("src/"):
            source_fingerprints[path] = source_code_sha256(raw, path)
        current = list(docstring_blocks(text, path) if path.startswith("src/") else blocks(text, path))
        entries += current
        if path.startswith("docs/src/"):
            for block in current:
                if block["kind"] == "heading":
                    label = re.sub(r"^\s*#+\s+", "", block["text"])
                    urls.append({"page": path.removeprefix("docs/src/").removesuffix(".md"),
                                 "fragment": slug(label), "heading": label})
    scripts = {p: hashlib.sha256(_git_bytes("show", f"{revision}:{p}")).hexdigest() for p in tree
               if p.startswith("examples/") and p.endswith(".jl")}
    return {"version": 1, "baseline": revision, "files": files, "blocks": entries,
            "example_scripts": scripts, "urls": urls, "source_code_sha256": source_fingerprints}


def extract(ref):
    manifest = inventory(ref)
    revision, entries = manifest["baseline"], manifest["blocks"]
    scripts, urls = manifest["example_scripts"], manifest["urls"]
    MIGRATION.mkdir(parents=True, exist_ok=True)
    (MIGRATION / "baseline.json").write_text(json.dumps(manifest, ensure_ascii=False, indent=2) + "\n")
    with (MIGRATION / "ledger.csv").open("w", newline="") as stream:
        writer = csv.DictWriter(stream, fieldnames=FIELDS, lineterminator="\n")
        writer.writeheader()
        for block in entries:
            writer.writerow({"block_id": block["id"], "sha256": block["sha256"],
                             "preview": " ".join(block["text"].split())[:80],
                             "audience": "use", "disposition": "example" if block["kind"] == "example" else "moved",
                             "destination": block["source"], "phase": "baseline",
                             "note": "Retained at baseline location."})
    print(f"Inventoried {len(entries)} blocks, {sum(b['kind'] == 'example' for b in entries)} inline examples, "
          f"{len(scripts)} scripts and {len(urls)} page fragments at {revision}.")


def _immutable_inventory(manifest):
    """Keep inventory data immutable while allowing explanatory provenance prose."""
    return {key: value for key, value in manifest.items()
            if key not in {"url_basis", "implementation_baseline_note"}}


def _validate_inventory(manifest, label):
    if not isinstance(manifest, dict) or manifest.get("version") != 1:
        raise ValueError(f"{label}: expected a version-1 inventory object")
    for field, kind in (("files", dict), ("blocks", list), ("example_scripts", dict),
                        ("urls", list), ("source_code_sha256", dict)):
        if not isinstance(manifest.get(field), kind) or not manifest[field]:
            raise ValueError(f"{label}: {field} must be a nonempty {kind.__name__}")
    if "implementation_example_scripts" in manifest:
        if not isinstance(manifest["implementation_example_scripts"], dict) or not manifest["implementation_example_scripts"]:
            raise ValueError(f"{label}: implementation_example_scripts must be a nonempty dict")
        if "implementation_baseline" not in manifest:
            raise ValueError(f"{label}: implementation_example_scripts requires implementation_baseline")
    for field in ("baseline", "implementation_baseline"):
        if field == "implementation_baseline" and field not in manifest:
            continue
        value = manifest.get(field)
        if not isinstance(value, str) or not re.fullmatch(r"(?:[0-9a-f]{40}|[0-9a-f]{64})", value):
            raise ValueError(f"{label}: {field} must be a full Git commit ID")


def _compare_inventory(current, expected, origin):
    actual, wanted = _immutable_inventory(current), _immutable_inventory(expected)
    missing = object()
    changed = sorted(key for key in actual.keys() | wanted.keys()
                     if actual.get(key, missing) != wanted.get(key, missing))
    if changed:
        raise ValueError(f"Immutable baseline inventory differs from {origin}: {', '.join(changed)}")


def verify_baseline(previous_ref):
    """Anchor the first inventory to Git; retain it on subsequent changes.

    A previous manifest was already anchored on introduction, so later checks
    need only that prior revision. Historical source commits need not remain in
    a shallow checkout once the inventory is published.
    """
    try:
        previous = _commit(previous_ref)
        manifest = json.loads((MIGRATION / "baseline.json").read_text(encoding="utf-8"))
        _validate_inventory(manifest, "Current baseline manifest")
        path = "docs/migration/baseline.json"
        present = _git_bytes("ls-tree", "--name-only", previous, "--", path).decode("utf-8").strip()
        if present:
            prior = json.loads(_git_bytes("show", f"{previous}:{path}").decode("utf-8"))
            _validate_inventory(prior, f"Baseline manifest at {previous_ref}")
            _compare_inventory(manifest, prior, f"previous revision {previous_ref}")
            print(f"Baseline verification: immutable inventory retained from {previous_ref}.")
            return 0

        expected = inventory(manifest["baseline"])
        implementation = manifest.get("implementation_baseline", manifest["baseline"])
        implementation_revision = _commit(implementation)
        if "implementation_baseline" in manifest:
            expected["implementation_baseline"] = implementation_revision
        if implementation_revision != expected["baseline"]:
            expected["source_code_sha256"] = _implementation_fingerprints(implementation_revision)
        if "implementation_example_scripts" in manifest:
            expected["implementation_example_scripts"] = _example_fingerprints(implementation_revision)
        _validate_inventory(expected, "Reconstructed Git inventory")
        _compare_inventory(manifest, expected, "recorded Git snapshots")
        event_base_sources = _implementation_fingerprints(previous)
        if manifest["source_code_sha256"] != event_base_sources:
            raise ValueError(f"source_code_sha256 differs from event base {previous_ref}; "
                             "the recorded implementation must match the event-base source code")
        event_base_examples = _example_fingerprints(previous)
        effective_examples = migration_example_scripts(manifest)
        if effective_examples != event_base_examples:
            raise ValueError(f"Integration example scripts differ from event base {previous_ref}; "
                             "the recorded example snapshot must match all event-base example paths and bytes")
        print(f"Baseline verification: {len(expected['blocks'])} blocks, "
              f"{len(expected['example_scripts'])} historical scripts, "
              f"{len(effective_examples)} integration scripts, {len(expected['urls'])} URL fragments "
              f"and {len(expected['source_code_sha256'])} implementation files anchored to Git "
              "and the event base.")
        return 0
    except (OSError, UnicodeError, ValueError, TypeError) as exc:
        print(f"Baseline verification failed: {exc}", file=sys.stderr)
        return 1


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
    return not anchor or any(anchor in h["ids"] or anchor == slug(h["title"])
                             for h in active_headings(file.read_text()))


def link_edit(value, old, new):
    """Permit a recorded link-target change, never arbitrary surrounding prose."""
    target = r'(?:\]\([^\n)]*\)|\(@ref [^\n)]*\))'
    if not all(isinstance(s, str) and re.fullmatch(target, s) for s in (old, new)) or old not in value:
        raise ValueError(f"invalid mechanical link edit {old!r}")
    return value.replace(old, new)


def source_ids(section):
    """Return exact IDs in Sources paragraphs, rather than substring matches."""
    result = set()
    for match in re.finditer(r"(?ms)^\s*\*\*Sources[.:]?\*\*[^\S\n]*(.*?)(?:\n\s*\n|\Z)", section):
        result.update(re.findall(r"`([^`\n]+:L\d+)`", match[1]))
    return result


def check(report_only=False, structural=False):
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
        if disposition in {"moved", "example"}:
            value = block["text"]
            try:
                edits = json.loads(row["link_edits"] or "[]")
                for old, new in edits:
                    value = link_edit(value, old, new)
                if block["kind"] == "example" and edits:
                    raise ValueError("original executable blocks cannot have link edits")
            except (ValueError, TypeError) as error:
                errors.append(f"{block['id']}: {error}")
            if not structural:
                if disposition == "example":
                    examples = list(active_examples(cache[destination]))
                    if value not in examples:
                        errors.append(f"{block['id']}: original active executable block not found in {destination}")
                elif value not in cache[destination]:
                    errors.append(f"{block['id']}: unchanged text not found in {destination}")
            if block["kind"] == "example" and disposition != "example":
                errors.append(f"{block['id']}: executable example needs example disposition")
        elif disposition in {"merged", "summarized"}:
            if not row["note"].strip():
                errors.append(f"{block['id']}: semantic mapping needs a review note")
            for target in destinations:
                path, anchor = destination_parts(target)
                if not anchor:
                    errors.append(f"{block['id']}: semantic mapping needs a destination anchor")
                section = active_sections((ROOT / path).read_text()).get(anchor, "")
                if path.startswith("docs/src/contracts/") and block["id"] not in source_ids(section):
                    errors.append(f"{block['id']}: destination clause {target} does not cite source block")
            if block["kind"] == "example":
                errors.append(f"{block['id']}: original executable blocks must retain their code")
        elif disposition == "superseded":
            if not row["note"].strip() or "https://github.com/" not in row["note"]:
                errors.append(f"{block['id']}: supersession needs the owner decision URL")
            if not structural and block["text"] not in cache[destination]:
                errors.append(f"{block['id']}: superseded wording must be preserved")
        else:
            errors.append(f"{block['id']}: unknown disposition {disposition!r}")
    if not structural:
        try:
            examples = migration_example_scripts(manifest)
        except ValueError as exc:
            errors.append(str(exc))
            examples = {}
        label = "Integration" if "implementation_example_scripts" in manifest else "Original"
        for path, digest in examples.items():
            if not (ROOT / path).is_file() or hashlib.sha256((ROOT / path).read_bytes()).hexdigest() != digest:
                errors.append(f"{label} example script changed or missing: {path}")
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
    verification = sub.add_parser("verify-baseline")
    verification.add_argument("--previous-ref", required=True, help="event base revision before this change")
    checking = sub.add_parser("check")
    checking.add_argument("--report-only", action="store_true")
    checking.add_argument("--structural", action="store_true", help="Check archival mappings without freezing future prose or examples")
    links = sub.add_parser("check-urls")
    links.add_argument("--build", type=Path, default=ROOT / "docs/build")
    args = parser.parse_args()
    if args.command == "extract":
        extract(args.ref)
        return 0
    if args.command == "verify-baseline":
        return verify_baseline(args.previous_ref)
    if args.command == "check":
        return check(args.report_only, args.structural)
    return check_urls(args.build)


if __name__ == "__main__":
    sys.exit(main())
