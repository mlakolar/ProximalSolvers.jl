#!/usr/bin/env python3
"""Check documentation structure, with optional one-time migration safeguards.

The permanent checks concern real Markdown headings, clause metadata, the Learn
chapters and retained IDs. --previous-ref compares the registry with a prior Git
revision so removing an ID from both the registry and the pages cannot hide it.
--migration additionally checks example bytes against the recorded integration
snapshot (or the historical example snapshot for older manifests) and source
bytes outside standalone docstring bodies against implementation_baseline. The
historical documentation snapshot remains separate when approved upstream work
precedes this migration.
Ordinary future code/documentation changes do not use that flag.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import re
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
FENCE = re.compile(r"^\s*(`{3,}|~{3,})(.*)$")
HEADING = re.compile(r"^ {0,3}(#{1,6})[ \t]+(.*?)[ \t]*#*[ \t]*$")
ANCHOR = re.compile(r"\(@id[ \t]+([^\s)]+)[ \t]*\)")
NUMBERED = re.compile(r"[A-Z][A-Z0-9]*(?:-[A-Z0-9]+)*-[0-9]+\Z", re.I)
FIELD = re.compile(r"^\s*\*\*(Statement|Applies to|Code|Tests|Sources)[.:]?\*\*", re.I | re.M)
INLINE_CODE = re.compile(r"(`+).*?\1")


def markdown_prose_lines(text):
    """Return line-aligned Markdown with fenced code and HTML comments blanked.

    Match the closing fence character and minimum opening length. Thus a Julia
    string containing three backticks does not close a four-backtick example.
    Unclosed fences extend to EOF, as in Markdown itself.
    """
    result = []
    fence = None
    in_comment = False
    for line in text.splitlines(keepends=True):
        if fence is not None:
            closing = FENCE.match(line)
            if (closing and closing[1][0] == fence[0]
                    and len(closing[1]) >= len(fence) and not closing[2].strip()):
                fence = None
            result.append("\n")
            continue
        visible = []
        position = 0
        while position < len(line):
            if in_comment:
                end = line.find("-->", position)
                if end < 0:
                    break
                in_comment = False
                position = end + 3
            else:
                begin = line.find("<!--", position)
                if begin < 0:
                    visible.append(line[position:])
                    break
                visible.append(line[position:begin])
                position = begin + 4
                in_comment = True
        content = "".join(visible)
        opening = FENCE.match(content)
        if opening and not (opening[1][0] == "`" and "`" in opening[2]):
            fence = opening[1]
            result.append("\n")
        else:
            result.append(content if content.endswith("\n") else content + "\n")
    return result


def active_headings(text):
    """Return dictionaries with line, level, title and ids for active headings."""
    headings = []
    for number, line in enumerate(markdown_prose_lines(text), 1):
        match = HEADING.match(line.rstrip("\r\n"))
        if match:
            title = match[2]
            headings.append({"line": number, "level": len(match[1]),
                             "title": title,
                             "ids": ANCHOR.findall(INLINE_CODE.sub("", title))})
    return headings


def active_sections(text):
    """Map each explicit heading ID to its active section text, including title.

    A section ends at the next heading at the same or a shallower level. Nested
    proof subsections remain part of their owning clause. Call active_headings
    separately when checking duplicates, because a dictionary cannot retain two
    definitions of the same ID.
    """
    lines = markdown_prose_lines(text)
    headings = active_headings(text)
    sections = {}
    for index, heading in enumerate(headings):
        end = next((other["line"] - 1 for other in headings[index + 1:]
                    if other["level"] <= heading["level"]), len(lines))
        content = "".join(lines[heading["line"] - 1:end])
        for anchor in heading["ids"]:
            sections[anchor] = content
    return sections


def _unescaped(text, position):
    previous = position - 1
    while previous >= 0 and text[previous] == "\\":
        previous -= 1
    return (position - previous - 1) % 2 == 0


def _scan_julia_line(line, block_depth, string):
    """Track comments/strings outside docstrings; preserve all their bytes."""
    index = 0
    while index < len(line):
        if block_depth:
            if line.startswith("#=", index):
                block_depth += 1
                index += 2
            elif line.startswith("=#", index):
                block_depth -= 1
                index += 2
            else:
                index += 1
        elif string:
            if line.startswith(string, index) and _unescaped(line, index):
                index += len(string)
                string = None
            else:
                index += 1
        elif line.startswith("#=", index):
            block_depth = 1
            index += 2
        elif line[index] == "#":
            break
        elif line.startswith('"""', index):
            string = '"""'
            index += 3
        elif line[index] in {'"', '`'}:
            string = line[index]
            index += 1
        elif line[index] == "'":
            # Distinguish a single character literal from Julia's adjoint syntax.
            character = re.match(r"'(?:\\.|[^'\\])'", line[index:])
            index += len(character[0]) if character else 1
        else:
            index += 1
    return block_depth, string


def _source_docstring_parts(raw, path="<source>"):
    """Return retained source bytes and (opening line, body) docstring pairs.

    Delimiter lines themselves are retained. Inline triple-quoted strings,
    strings in block comments and every other code/comment byte are retained.
    This is a checker for the repository's standalone-delimiter convention,
    not a general Julia parser. Unsupported closing placement fails explicitly.
    """
    try:
        text = raw.decode("utf-8")
    except UnicodeDecodeError as exc:
        raise ValueError(f"{path}: source is not UTF-8") from exc
    output = []
    docstrings = []
    body = []
    docstring = False
    opened = 0
    block_depth, string = 0, None
    for number, line in enumerate(text.splitlines(keepends=True), 1):
        delimiter = line.strip() in {'"""', 'raw"""'}
        if docstring:
            if line.strip() == '"""':
                output.append(line)
                docstrings.append((opened, "".join(body)))
                body = []
                docstring = False
            elif any(_unescaped(line, match.start()) for match in re.finditer('"""', line)):
                raise ValueError(f"{path}:{number}: docstring closing delimiter must stand alone")
            else:
                body.append(line)
            continue
        if delimiter and block_depth == 0 and string is None:
            output.append(line)
            docstring = True
            opened = number
        else:
            output.append(line)
            block_depth, string = _scan_julia_line(line, block_depth, string)
    if docstring:
        raise ValueError(f"{path}:{opened}: unclosed standalone docstring")
    return "".join(output).encode("utf-8"), docstrings


def source_without_docstrings(raw, path="<source>"):
    """Return original bytes except standalone docstring bodies; keep delimiters."""
    return _source_docstring_parts(raw, path)[0]


def source_code_sha256(raw, path="<source>"):
    """Hash raw source bytes after removing only standalone docstring bodies."""
    return hashlib.sha256(source_without_docstrings(raw, path)).hexdigest()


def _read_json(path, errors):
    try:
        return json.loads(path.read_text(encoding="utf-8"))
    except (OSError, ValueError) as exc:
        errors.append(f"Cannot read {path}: {exc}")
        return None


def _registry_ids(data, errors):
    if data is None:
        return []
    records = data.get("clause_ids", data.get("clauses")) if isinstance(data, dict) else data
    if isinstance(records, dict):
        records = list(records)
    if not isinstance(records, list):
        errors.append("clause-registry.json needs a clause_ids list (or clauses mapping)")
        return []
    ids = []
    for record in records:
        ident = record.get("id") if isinstance(record, dict) else record
        if not isinstance(ident, str) or not ident or re.search(r"\s", ident):
            errors.append(f"Invalid registry clause ID: {ident!r}")
        elif ident in ids:
            errors.append(f"Repeated registry clause ID: {ident}")
        else:
            ids.append(ident)
    if not ids:
        errors.append("clause-registry.json contains no clause IDs")
    return ids


def _previous_registry_ids(root, ref, errors):
    """Read the prior registry, accepting its absence only at a valid commit."""
    def git(*args):
        return subprocess.run(["git", "-C", str(root), *args], capture_output=True,
                              text=True, encoding="utf-8", errors="replace", timeout=10)

    try:
        resolved = git("rev-parse", "--verify", "--end-of-options", ref + "^{commit}")
        if resolved.returncode:
            errors.append(f"Cannot resolve --previous-ref {ref!r} to an available commit")
            return []
        commit = resolved.stdout.strip()
        path = "docs/migration/clause-registry.json"
        listing = git("ls-tree", "--name-only", "-z", commit, "--", path)
        if listing.returncode:
            errors.append(f"Cannot inspect the registry at --previous-ref {ref!r}")
            return []
        if path not in listing.stdout.split("\0"):
            return []  # The registry is being introduced for the first time.
        result = git("show", commit + ":" + path)
        if result.returncode:
            errors.append(f"Cannot read the registry at --previous-ref {ref!r}")
            return []
        try:
            data = json.loads(result.stdout)
        except ValueError as exc:
            errors.append(f"Invalid registry at --previous-ref {ref!r}: {exc}")
            return []
        registry_errors = []
        ids = _registry_ids(data, registry_errors)
        errors.extend(f"Registry at --previous-ref {ref!r}: {error}" for error in registry_errors)
        return ids
    except (OSError, subprocess.TimeoutExpired) as exc:
        errors.append(f"Cannot check --previous-ref {ref!r}: {exc}")
        return []


def prose_word_count(text):
    """Approximate prose words, excluding fenced code and HTML comments."""
    prose = "".join(markdown_prose_lines(text))
    prose = re.sub(r"(!?\[[^\]]*\])\([^)]*\)", r"\1", prose)
    return len(re.findall(r"\b\w+(?:['’-]\w+)*\b", prose))


def prose_paragraphs(text):
    """Yield prose paragraphs, keeping list items separate and omitting tables."""
    paragraph = []
    for line in markdown_prose_lines(text):
        boundary = not line.strip() or HEADING.match(line) or line.lstrip().startswith("|")
        new_item = re.match(r"^\s*(?:[-*+]|[0-9]+[.)])\s+", line)
        if boundary or new_item:
            if paragraph:
                yield "".join(paragraph)
                paragraph = []
            if boundary:
                continue
        paragraph.append(line)
    if paragraph:
        yield "".join(paragraph)


def _summary_length_advisories(root, advisories):
    readme = root / "README.md"
    if readme.exists():
        try:
            count = prose_word_count(readme.read_text(encoding="utf-8"))
            if count > 300:
                advisories.append(f"README.md: {count} prose words (review target 300)")
        except (OSError, UnicodeError) as exc:
            advisories.append(f"Cannot count README prose: {exc}")
    for path in sorted((root / "src").rglob("*.jl")):
        relative = path.relative_to(root).as_posix()
        try:
            _, docstrings = _source_docstring_parts(path.read_bytes(), relative)
        except (OSError, ValueError) as exc:
            advisories.append(f"Cannot count docstring prose in {relative}: {exc}")
            continue
        for opened, body in docstrings:
            extended = next((heading["line"] - 1 for heading in active_headings(body)
                             if heading["title"].strip().lower() == "extended help"), None)
            summary = "".join(body.splitlines(keepends=True)[:extended]) if extended is not None else body
            count = prose_word_count(summary)
            if count > 150:
                advisories.append(f"{relative}:{opened}: docstring summary has {count} prose words "
                                  "(review target 150 before '# Extended help')")


def _reference_ids(text):
    text = INLINE_CODE.sub("", text)
    result = set()
    for label, target in re.findall(r"\[([^\]]+)\]\(@ref(?:\s+([^)]*?))?\)", text):
        value = target.strip().strip('"') if target.strip() else label.strip()
        result.add(value)
    result.update(re.findall(r"\]\([^\s)]*#([^\s)]+)\)", text))
    return result


def migration_example_scripts(manifest):
    """Select integration examples without discarding the historical inventory."""
    historical = manifest.get("example_scripts")
    if not isinstance(historical, dict) or not historical:
        raise ValueError("Migration manifest lacks original example-script fingerprints")
    if "implementation_example_scripts" not in manifest:
        return historical
    integration = manifest["implementation_example_scripts"]
    if not isinstance(integration, dict) or not integration:
        raise ValueError("Migration manifest implementation_example_scripts must be a nonempty dict")
    if not manifest.get("implementation_baseline"):
        raise ValueError("Migration manifest implementation_example_scripts needs implementation_baseline")
    return integration


def _migration_checks(root, errors):
    manifest = _read_json(root / "docs/migration/baseline.json", errors)
    if not isinstance(manifest, dict):
        return
    files = manifest.get("files", {})
    sources = manifest.get("source_code_sha256")
    documented_sources = {path for path in files if path.startswith("src/") and path.endswith(".jl")}
    if not isinstance(sources, dict) or not sources:
        errors.append("Migration manifest lacks source_code_sha256 fingerprints")
    else:
        original_sources = set(sources)
        if manifest.get("implementation_baseline", manifest.get("baseline")) == manifest.get("baseline"):
            for path in sorted(documented_sources - original_sources):
                errors.append(f"Original source lacks a code fingerprint: {path}")
            for path in sorted(original_sources - documented_sources):
                errors.append(f"Source fingerprint is not in the baseline file inventory: {path}")
        current_sources = {path.relative_to(root).as_posix() for path in (root / "src").rglob("*.jl")}
        for path in sorted(current_sources - original_sources):
            errors.append(f"Source added during documentation-only migration: {path}")
        for path, expected in sorted(sources.items()):
            try:
                actual = source_code_sha256((root / path).read_bytes(), path)
            except (OSError, ValueError) as exc:
                errors.append(f"Cannot verify source {path}: {exc}")
                continue
            if actual != expected:
                errors.append(f"Source bytes outside docstring bodies changed: {path}")
    try:
        examples = migration_example_scripts(manifest)
    except ValueError as exc:
        errors.append(str(exc))
        return
    label = "Integration" if "implementation_example_scripts" in manifest else "Original"
    for path, expected in sorted(examples.items()):
        try:
            actual = hashlib.sha256((root / path).read_bytes()).hexdigest()
        except OSError as exc:
            errors.append(f"{label} example script missing or unreadable: {path}: {exc}")
            continue
        if actual != expected:
            errors.append(f"{label} example script bytes changed: {path}")


def run_checks(root=ROOT, migration=False, previous_ref=None):
    """Return (errors, advisories), without modifying the repository."""
    root = Path(root)
    errors, advisories = [], []
    definitions = {}
    documents = {}
    contract_dir = root / "docs/src/contracts"
    for path in sorted((root / "docs/src").rglob("*.md")):
        relative = path.relative_to(root).as_posix()
        try:
            text = path.read_text(encoding="utf-8")
        except (OSError, UnicodeError) as exc:
            errors.append(f"Cannot read {relative}: {exc}")
            continue
        headings = active_headings(text)
        sections = active_sections(text)
        documents[path] = (text, headings, sections)
        for heading in headings:
            for ident in heading["ids"]:
                location = f"{relative}:{heading['line']}"
                if ident in definitions:
                    errors.append(f"Duplicate explicit ID {ident}: {definitions[ident]} and {location}")
                else:
                    definitions[ident] = location

    registry = _read_json(root / "docs/migration/clause-registry.json", errors)
    registered_ids = set(_registry_ids(registry, errors))
    for ident in sorted(registered_ids):
        if ident not in definitions:
            errors.append(f"Registered clause ID disappeared: {ident}; retain its ID when retiring it")
    if previous_ref is not None:
        for ident in _previous_registry_ids(root, previous_ref, errors):
            if ident not in registered_ids:
                errors.append(f"Previously registered clause ID removed from registry: {ident}")
            if ident not in definitions and ident not in registered_ids:
                errors.append(f"Previously registered clause ID disappeared: {ident}; retain its ID when retiring it")

    for path, (text, headings, sections) in documents.items():
        relative = path.relative_to(root).as_posix()
        if contract_dir in path.parents:
            for heading in headings:
                for ident in heading["ids"]:
                    if not NUMBERED.fullmatch(ident):
                        continue
                    if ident not in registered_ids:
                        errors.append(f"{relative}:{heading['line']}: numbered contract ID is not registered: {ident}")
                    if "evidence" in path.relative_to(contract_dir).parts:
                        continue
                    body = sections[ident]
                    retired = bool(re.search(r"\bRetired\b", heading["title"], re.I))
                    retired |= bool(re.search(r"(?m)^\s*(?:\*\*)?Retired(?:[.:](?:\*\*)?|\*\*[.:]?)?\s", body, re.I))
                    if retired:
                        replacements = _reference_ids(body) - {ident}
                        if not replacements.intersection(definitions):
                            errors.append(f"{relative}:{heading['line']}: retired {ident} needs a link to an existing replacement ID")
                        continue
                    fields = {match[1].lower() for match in FIELD.finditer(body)}
                    for field in ("Statement", "Applies to", "Sources"):
                        if field.lower() not in fields:
                            errors.append(f"{relative}:{heading['line']}: {ident} lacks {field}")
                    for field in ("Code", "Tests"):
                        if field.lower() not in fields:
                            advisories.append(f"{relative}:{heading['line']}: {ident} has no {field} reference")

    learn = root / "docs/src/learn"
    for chapter in range(1, 9):
        candidates = sorted(learn.glob(f"{chapter:02d}-*.md"))
        if len(candidates) != 1:
            errors.append(f"Learn chapter {chapter:02d}: expected one {chapter:02d}-*.md file, found {len(candidates)}")
            continue
        path = candidates[0]
        if path not in documents:
            continue
        text, headings, _ = documents[path]
        exercise_heading = any(re.search(r"\bExercises\b", heading["title"], re.I)
                               for heading in headings)
        if not exercise_heading:
            errors.append(f"{path.relative_to(root)}: missing active Exercises heading")
        count = prose_word_count(text)
        if count > 1800:
            advisories.append(f"{path.relative_to(root)}: {count} prose words (review target 1800)")
        if chapter < 8:
            prose = "".join(markdown_prose_lines(text))
            if re.search(r"\b(?:floatmin|floatmax|subnormal)\b|eps\(T\)|(?<![\w])#\d+\b", prose):
                advisories.append(f"{path.relative_to(root)}: numerical boundary or issue detail may belong in chapter 08 or a contract")

    use_names = {"getting-started.md", "choosing-solver.md", "support.md",
                 "working-with-results.md", "benchmarks.md", "glossary.md"}
    for path, (text, _, _) in documents.items():
        if path.parent != root / "docs/src" or path.name not in use_names:
            continue
        prose = "".join(markdown_prose_lines(text))
        if re.search(r"(?<![\w])#\d+\b|\b[0-9a-f]{12,40}\b", prose):
            advisories.append(f"{path.relative_to(root)}: issue/commit detail may belong in evidence or history")
        paragraphs = list(prose_paragraphs(text))
        long_paragraphs = [count for count in map(prose_word_count, paragraphs) if count > 120]
        if long_paragraphs:
            advisories.append(f"{path.relative_to(root)}: {len(long_paragraphs)} Use paragraph(s) exceed "
                              f"120 prose words (longest {max(long_paragraphs)})")
        for paragraph in paragraphs:
            if (re.search(r"\bconverged\b", paragraph)
                    and not re.search(r"@ref\s+(?:STOP|RES)-|contracts/(?:pg-stopping|results-failures)\.md", paragraph)):
                advisories.append(f"{path.relative_to(root)}: a converged explanation has no direct STOP/RES clause link")
                break
    _summary_length_advisories(root, advisories)
    if migration:
        _migration_checks(root, errors)
    return errors, advisories


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--report-only", action="store_true", help="report findings but return success during bootstrap")
    parser.add_argument("--migration", action="store_true", help="also verify original source and example preservation")
    parser.add_argument("--previous-ref", metavar="REF", help="also retain every clause ID registered at this Git revision")
    args = parser.parse_args(argv)
    errors, advisories = run_checks(migration=args.migration, previous_ref=args.previous_ref)
    mode = "permanent structure and migration preservation" if args.migration else "permanent structure"
    print(f"Documentation layers ({mode}): {len(errors)} errors; {len(advisories)} advisories.")
    if args.previous_ref is not None:
        print(f"Registry retention compared with {args.previous_ref}.")
    if args.migration:
        try:
            manifest = json.loads((ROOT / "docs/migration/baseline.json").read_text(encoding="utf-8"))
            implementation = manifest.get("implementation_baseline", manifest.get("baseline", "missing"))
            examples = implementation if "implementation_example_scripts" in manifest else manifest.get("baseline", "missing")
            print("Preservation baselines: historical text/examples=" + str(manifest.get("baseline", "missing"))
                  + "; implementation=" + str(implementation) + "; current examples=" + str(examples) + ".")
        except (OSError, ValueError):
            pass  # The check already reported the missing or unreadable manifest.
    for error in errors:
        print("ERROR: " + error, file=sys.stderr)
    for advisory in advisories[:20]:
        print("ADVISORY: " + advisory)
    if len(advisories) > 20:
        print(f"ADVISORY: {len(advisories) - 20} further prose advisories omitted.")
    return 0 if args.report_only or not errors else 1


if __name__ == "__main__":
    sys.exit(main())
