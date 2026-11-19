"""Distinctive-token preservation for the one-time documentation migration.

This is a lexical safety net, not a claim that matching vocabulary proves the
same numerical rule. Whole inline code/math expressions retain their context;
bare numbers and one-letter variables are not independent evidence. The normal
ledger mappings and human review remain necessary.
"""
from __future__ import annotations

from bisect import bisect_right
from collections import defaultdict
import json
from pathlib import Path
import re

from check_docs_layers import _source_docstring_parts, active_headings


FENCE = re.compile(r"^\s{0,3}(`{3,}|~{3,})(.*)$")
HTML_COMMENT = re.compile(r"<!--.*?(?:-->|\Z)", re.S)
INLINE = re.compile(r"(?<!`)(`{1,2})(?!`)(.+?)(?<!`)\1(?!`)", re.S)
ISSUE = re.compile(r"(?<![\w/#])#[1-9][0-9]*(?![\w])")
IDENTIFIER = re.compile(
    r"(?<![\w])(?:[A-Za-z_]\w*!|_[A-Za-z_]\w*|[A-Za-z]\w*(?:_\w+)+)(?![\w])")
CALL = re.compile(r"(?<![\w])([A-Za-z_]\w*!?)\s*\(")
PATH = re.compile(r"(?<![\w./:-])(?:[A-Za-z0-9_.-]+/)*[A-Za-z0-9_.-]+\.(?:jl|py|m|sh|txt|toml|md|csv|json|ya?ml)(?![\w/-]|\.[\w])")
NUMBER = r"(?:\d+(?:\.\d*)?|\.\d+)"
EXPONENT = re.compile(rf"(?<![\w.])(?:{NUMBER}[eE][+-]?\d+|{NUMBER}\s*\^\s*[+-]?\d+|{NUMBER}[⁰¹²³⁴⁵⁶⁷⁸⁹⁺⁻]+)(?![\w]|\.\d)")
UNIT = re.compile(rf"(?<![\w.]){NUMBER}\s*(?:%|(?:ns|μs|µs|ms|s|seconds?|minutes?|hours?|bytes?|KiB|MiB|GiB|KB|MB|GB|ulps?)\b)")
SCALED_CALL = re.compile(rf"(?<![\w.]){NUMBER}(?:\s*\^\s*[+-]?\d+)?\s*(?:eps|floatmin|floatmax)\s*\([^()\n]+\)")
BOUND_CALL = re.compile(r"(?<![\w])(?:eps|floatmin|floatmax)\s*\([^()\n]+\)")
QUOTED = re.compile(r'"([^"\n]+)"|“([^”\n]+)”')
WAIVER_FIELDS = {"token", "blocks", "target", "replacement", "reason"}
EXCLUDED_PARTS = {"generated", "_generated", "build", "test", "tests", "fixtures", "migration"}


def normalized_token(text):
    """Normalize only wrapping and mechanical spacing, preserving case/symbols.

    No ASCII/Unicode variable, operator, exponent or spelling substitutions are
    implicit. Such translations need an individually reviewed waiver. Spaces
    inside words/quoted messages stay spaces; formatting around punctuation and
    between a numerical factor and eps/floatmin/floatmax may change.
    """
    text = " ".join(text.replace("`", "").split())
    text = re.sub(r"\s*([=<>≤≥+*/^:,(){}\[\];|‖−])\s*", r"\1", text)
    text = re.sub(r"\s*(-)\s*", r"\1", text)
    return re.sub(r"(?<=\d)\s+(?=(?:eps|floatmin|floatmax)\()", "", text).strip()


def visible_markdown(text):
    """Discard hidden HTML comments, while retaining displayed code/math.

    HTML-comment syntax inside a visible fence is literal displayed text,
    except in Documenter's @raw html blocks, where the browser hides it.
    Serialized baseline inventories are data, even inside a Markdown fence;
    their text must never satisfy preservation of authored documentation.
    """
    output, fenced = [], []
    fence, in_comment, raw_html = None, False, False
    for line in text.splitlines(keepends=True):
        if fence is not None:
            closing = FENCE.match(line)
            if (closing and closing[1][0] == fence[0]
                    and len(closing[1]) >= len(fence) and not closing[2].strip()):
                contents = "".join(fenced)
                if raw_html:
                    contents = HTML_COMMENT.sub("", contents)
                if not serialized_inventory(contents):
                    output.append(contents)
                output.append("\n")
                fenced, fence, raw_html = [], None, False
            else:
                fenced.append(line)
            continue
        visible, position = [], 0
        while position < len(line):
            if in_comment:
                end = line.find("-->", position)
                if end < 0:
                    break
                position, in_comment = end + 3, False
            else:
                begin = line.find("<!--", position)
                if begin < 0:
                    visible.append(line[position:])
                    break
                visible.append(line[position:begin])
                position, in_comment = begin + 4, True
        content = "".join(visible)
        opening = FENCE.match(content)
        if opening:
            fence = opening[1]
            raw_html = bool(re.fullmatch(r"@raw\s+html", opening[2].strip()))
            output.append("\n")
        else:
            output.append(content if content.endswith("\n") else content + "\n")
    if fenced:
        contents = "".join(fenced)
        if raw_html:
            contents = HTML_COMMENT.sub("", contents)
        if not serialized_inventory(contents):
            output.append(contents)
    return "".join(output)


def serialized_inventory(text):
    """Recognize baseline JSON dumps, including one inside a Markdown fence."""
    try:
        data = json.loads(text)
    except ValueError:
        return False
    return isinstance(data, dict) and "baseline" in data and isinstance(data.get("blocks"), list)


def distinctive_tokens(text):
    visible = visible_markdown(text)
    tokens = defaultdict(set)

    def add(value, kind):
        token = normalized_token(value)
        if token and not re.fullmatch(r"(?:[A-Za-zΑ-Ωα-ω]|[+-]?\d+(?:\.\d+)?)", token):
            tokens[token].add(kind)

    for match in INLINE.finditer(visible):
        add(match[2], "code/math span")
    for expression, kind in ((ISSUE, "issue"), (IDENTIFIER, "identifier"),
                             (PATH, "path"), (EXPONENT, "exponent"),
                             (UNIT, "number with unit"), (SCALED_CALL, "scaled bound"),
                             (BOUND_CALL, "floating-point bound")):
        for match in expression.finditer(visible):
            add(match[0], kind)
    for match in CALL.finditer(visible):
        # Function names in ordinary prose are captured only when distinctive;
        # whole inline calls above also retain their arguments and conditions.
        name = match[1]
        if "_" in name or name.endswith("!") or name in {"eps", "floatmin", "floatmax"}:
            add(name, "function identifier")
    for match in QUOTED.finditer(visible):
        message = match[1] or match[2]
        context = visible[max(0, match.start() - 100):match.end() + 40]
        if re.search(r"error|Error|warn|Warn|refus|message|throw", context):
            add(message, "message fragment")
    return tokens


def authored_documents(root):
    """Read maintained site prose and real help text, never migration metadata.

    The allowlist excludes tests, the ledger, waivers, build output, the
    Literate/gallery output in docs/src/examples, and JSON archives.
    Rendered historical evidence in docs/src/contracts/evidence is
    deliberately included: its historical qualification remains reviewable.
    """
    paths = [root / "README.md", root / "examples/README.md"]
    paths += sorted((root / "docs/src").rglob("*.md"))
    result = {}
    for path in paths:
        relative = path.relative_to(root).as_posix()
        if (not path.is_file() or relative.startswith("docs/src/examples/")
                or any(part in EXCLUDED_PARTS for part in path.relative_to(root).parts)):
            continue
        text = path.read_text(encoding="utf-8")
        if serialized_inventory(text):
            continue
        result[relative] = visible_markdown(text)
    for path in sorted((root / "src").rglob("*.jl")):
        relative = path.relative_to(root).as_posix()
        _, bodies = _source_docstring_parts(path.read_bytes(), relative)
        if bodies:
            result[relative] = "\n\n".join(visible_markdown(body) for _, body in bodies)
    return result


def contains_token(text, token):
    """Return a complete expression's offset, or None (never a prefix match)."""
    path = bool(PATH.fullmatch(token))
    before = token[0].isalnum() or token[0] == "_"
    after = token[-1].isalnum() or token[-1] in "_!"
    implicit_bound = bool(re.match(r"(?:eps|floatmin|floatmax)(?:\(|$)", token))
    def joined(character):
        return character.isalnum() or character == "_" or (path and character in "./-")
    offset = text.find(token)
    while offset >= 0:
        end = offset + len(token)
        joined_before = before and offset and joined(text[offset - 1])
        if implicit_bound and offset and text[offset - 1].isdigit():
            joined_before = False
        joined_after = after and end < len(text) and joined(text[end])
        if path and end < len(text) and text[end] == "." and (
                end + 1 == len(text) or not (text[end + 1].isalnum() or text[end + 1] == "_")):
            joined_after = False  # A sentence's final period is not a filename suffix.
        if not joined_before and not joined_after:
            return offset
        offset = text.find(token, offset + 1)
    return None


def target_section(root, target, documents):
    if not isinstance(target, str) or "#" not in target:
        raise ValueError("target must name an authored contract path and clause ID")
    path, anchor = target.split("#", 1)
    if path not in documents or not path.startswith("docs/src/contracts/") or not anchor:
        raise ValueError("target must name an authored contract path and clause ID")
    raw = (root / path).read_text(encoding="utf-8")
    headings = active_headings(raw)
    for index, heading in enumerate(headings):
        if anchor not in heading["ids"]:
            continue
        end = next((item["line"] - 1 for item in headings[index + 1:]
                    if item["level"] <= heading["level"]), len(raw.splitlines()))
        return normalized_token(visible_markdown("\n".join(raw.splitlines()[heading["line"] - 1:end])))
    raise ValueError(f"target clause does not exist: {target}")


def check_token_coverage(root, manifest, rows):
    """Return errors plus a deterministic, auditable report for every token."""
    requirements = defaultdict(lambda: {"kinds": set(), "blocks": []})
    destinations = {row["block_id"]: [row["destination"]] +
                    [part for part in row.get("additional_destinations", "").split(";") if part]
                    for row in rows}
    for block in manifest["blocks"]:
        for token, kinds in distinctive_tokens(block["text"]).items():
            requirements[token]["kinds"].update(kinds)
            requirements[token]["blocks"].append({"block_id": block["id"],
                "destinations": destinations.get(block["id"], [])})
    documents = authored_documents(root)
    corpus, offsets, paths = "", [], []
    for path, text in sorted(documents.items()):
        offsets.append(len(corpus))
        paths.append(path)
        corpus += normalized_token(text) + "\0"
    found = {}
    for token in requirements:
        match = contains_token(corpus, token)
        if match is not None:
            found[token] = paths[bisect_right(offsets, match) - 1]

    errors, waivers, seen = [], {}, set()
    waiver_path = root / "docs/migration/token-waivers.txt"
    if waiver_path.exists():
        for number, line in enumerate(waiver_path.read_text(encoding="utf-8").splitlines(), 1):
            if not line.strip() or line.lstrip().startswith("#"):
                continue
            label = f"token-waivers.txt:{number}"
            try:
                entry = json.loads(line)
                if not isinstance(entry, dict) or set(entry) != WAIVER_FIELDS:
                    raise ValueError("expected exactly token, blocks, target, replacement and reason")
                if not all(isinstance(entry[key], str) and entry[key].strip()
                           for key in ("token", "target", "replacement", "reason")):
                    raise ValueError("token, target, replacement and reason must be nonempty strings")
                token = normalized_token(entry["token"])
                if token != entry["token"]:
                    raise ValueError("token must use the report's exact normalized spelling")
                if token in seen:
                    raise ValueError(f"duplicate waiver for {token!r}")
                seen.add(token)
                if token not in requirements:
                    raise ValueError(f"unknown baseline token {token!r}")
                if token in found:
                    raise ValueError(f"stale waiver: {token!r} is present in {found[token]}")
                ids = [block["block_id"] for block in requirements[token]["blocks"]]
                if (not isinstance(entry["blocks"], list)
                        or not all(isinstance(ident, str) for ident in entry["blocks"])
                        or len(entry["blocks"]) != len(set(entry["blocks"]))
                        or set(entry["blocks"]) != set(ids)):
                    raise ValueError(f"blocks must list every originating block exactly once: {ids}")
                section = target_section(root, entry["target"], documents)
                replacement = normalized_token(entry["replacement"])
                if contains_token(section, replacement) is None:
                    raise ValueError(f"replacement is absent from target clause: {entry['target']}")
                waivers[token] = {**entry, "line": number}
            except (ValueError, TypeError) as exc:
                errors.append(f"{label}: {exc}")

    records = []
    for token, requirement in sorted(requirements.items()):
        record = {"token": token, "kinds": sorted(requirement["kinds"]),
                  "blocks": requirement["blocks"]}
        if token in found:
            record.update(status="retained", found_in=found[token])
        elif token in waivers:
            record.update(status="waived", waiver=waivers[token])
        else:
            record["status"] = "missing"
            for block in requirement["blocks"]:
                errors.append(f"{block['block_id']}: missing distinctive token {token!r}; "
                              f"mapped to {', '.join(block['destinations']) or '(no ledger destination)'}")
        records.append(record)
    summary = {status: sum(record["status"] == status for record in records)
               for status in ("retained", "waived", "missing")}
    return errors, {"version": 1, "baseline": manifest.get("baseline"),
                    "documents": sorted(documents), "summary": summary, "tokens": records}
