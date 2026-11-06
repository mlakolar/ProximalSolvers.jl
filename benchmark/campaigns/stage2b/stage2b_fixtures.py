#!/usr/bin/env python3
"""Synthetic campaign roots for the migration comparator (MIGRATION_COMPARE_SPEC.md, sections 10-16).

    python3 -B stage2b_fixtures.py --check        (from benchmark/campaigns/stage2b)

Standard library only (Python 3.11 or later). The builder writes into a directory a complete, valid input set for
`migration_compare.py`:

    <dest>/campaign/
        roots/a, roots/b, roots/aa_a, roots/aa_b     one stack each: stack-identity.toml, julia-<MAJOR.MINOR>/
            (raw/ record files, Manifest.toml, Project.toml, environment-inventory.toml), fingerprints.tsv (a and b)
        case-mapping.toml          a copy of the real mapping (19 cases; P14 is the approved class B case)
        declared-differences.toml  derived from the stacks below
        receipt.jsonl              eight blocks per stratum for the A/B arm and the A/A arm, in the schedule order
        schedule.toml              a mutable copy of the real schedule
    <dest>/out-N/                  the output directories of Campaign.run (created by the tool)

The raw/ directories are accepted UNMODIFIED by `validate.validate(raw, expected=8, versions=[full version])`.
Every timing value is a finite positive integer of nanoseconds; each ok case has five samples, the minimum of
`validate.py`. Variants (the `variant` argument of `build_campaign`):

    "migration"  Stack B differs from Stack A in the ProximalSolvers commit, tree and package hash, in the
                 ProximalBase version, commit, tree and package hash, in the harness hash (the approved class B port
                 of P14) and in the [compat] entry of ProximalBase; all declared.
    "manifest"   "migration" plus a changed, an added (one stratum) and a removed dependency, all declared.
    "identical"  Stack B has the identity of Stack A and declares nothing.

The test helpers (`Campaign.run`, the edit helpers `toml_*`, `tsv_*`, `jsonl_*`, `Campaign.write_process`, ...) change
exactly one item of a built set; `Campaign.copy` copies a built set for one test.
"""

import argparse
import contextlib
import copy
import csv
import datetime
import hashlib
import importlib
import io
import json
import math
import os
import re
import shutil
import sys
import tempfile
import tomllib
import uuid
from pathlib import Path

HERE = Path(__file__).resolve().parent
BENCH = HERE.parents[1]
for _path in (str(BENCH), str(HERE)):
    if _path not in sys.path:
        sys.path.insert(0, _path)

import validate  # noqa: E402  (benchmark/validate.py, imported without modification)

LABELS = ("a", "b", "aa_a", "aa_b")
ROLE_LABELS = {"AB": {"A": "a", "B": "b"}, "AA": {"A": "aa_a", "B": "aa_b"}}
RECORD_KINDS = ("catalog", "errors", "metrics", "samples", "metadata", "metadata-start")
SESSION_ID = "session-0001"
PB_UUID = "0a755509-c5b1-5d6f-9b24-59bcda3c37a3"
PS_UUID = "fc4971f5-6616-4709-9bfc-89a819252f6b"
PS_A_PACKAGE_HASH = "f37fc61f300ad597a33c7ab5f448d38c865db854"
PB_A_PACKAGE_HASH = "d4747f2ab51212b20d9adcf70e21c2200b090b2a"
BLAS = "LBTConfig([ILP64] libopenblas64_.so)"
CERTIFICATES_HASH = hashlib.sha256(b"certificates.jl").hexdigest()
BANNED_WORDS = ("noninferior", "non-inferior", "no-regression", "significant", "equivalent")
CSV_COLUMNS = ("julia, id, role, phase, class, reason, repetitions, a_ns, b_ns, ratio, abs_diff_ns, geomean_ratio, "
               "ratio_min, ratio_max, measure, target, a_value, b_value, a_accuracy_fraction, b_accuracy_fraction, "
               "a_accuracy_band, b_accuracy_band, a_median_bytes, b_median_bytes, hardware, aa_ratio_min, "
               "aa_ratio_max, screen, mapping_class").split(", ")
LISTS_KEYS = ("not_ok", "invalid_certificates", "incomplete_paths", "errors_and_timeouts",
              "allocation_differences", "missing_diagnostics", "semantic_deviations", "not_comparable", "failed")
CLASS_ORDER = ("JULIA", "INPUTS", "TARGET", "CASE", "PHASE", "OPERATION", "THREADS", "MACHINE", "REPETITIONS",
               "MAPPING", "SCHEMA", "UNDECLARED", "SETTINGS", "STACK", "IDENTITY", "ORDER")
ERROR_TEXT = {
    "target_missed": "certificate value is above the target",
    "uncertifiable": "certificate value is not finite",
    "incomplete": "IncompletePath: the iterate has no working set",
    "timeout": "single call exceeds PS_CASE_SECONDS",
    "error": "ErrorException: synthetic failure",
}


# --------------------------------------------------------------------------------------------------------------
# TOML writer and in-place edit helpers
# --------------------------------------------------------------------------------------------------------------

def _key(key):
    return key if re.fullmatch(r"[A-Za-z0-9_-]+", key) else json.dumps(key, ensure_ascii=False)


def _value(value):
    if isinstance(value, bool):
        return "true" if value else "false"
    if isinstance(value, int):
        return str(value)
    if isinstance(value, float):
        return "nan" if math.isnan(value) else ("inf" if value > 0 else "-inf") if math.isinf(value) else repr(value)
    if isinstance(value, str):
        return json.dumps(value, ensure_ascii=False)
    if isinstance(value, (list, tuple)):
        return "[" + ", ".join(_value(item) for item in value) + "]"
    if isinstance(value, dict):
        return "{ " + ", ".join(f"{_key(k)} = {_value(v)}" for k, v in value.items()) + " }"
    raise TypeError(f"cannot write {value!r} as TOML")


def _is_table_array(value):
    return isinstance(value, list) and bool(value) and all(isinstance(item, dict) for item in value)


def toml_dumps(data, prefix=()):
    """Write a dict of scalars, scalar arrays, tables and arrays of tables as TOML (no comments)."""
    lines = [f"{_key(k)} = {_value(v)}" for k, v in data.items()
             if not isinstance(v, dict) and not _is_table_array(v)]
    chunks = ["\n".join(lines)] if lines else []
    for key, value in data.items():
        path = prefix + (key,)
        name = ".".join(_key(part) for part in path)
        if isinstance(value, dict):
            body = toml_dumps(value, path)
            chunks.append(f"[{name}]\n{body}" if body else f"[{name}]")
        elif _is_table_array(value):
            for item in value:
                body = toml_dumps(item, path)
                chunks.append(f"[[{name}]]\n{body}" if body else f"[[{name}]]")
    return "\n\n".join(chunks) + ("\n" if not prefix else "")


def break_link(path):
    """A file of a copy may be a link to the (read-only) file of the built set: make it a real file before a change."""
    path = Path(path)
    if path.is_symlink():
        data = path.read_bytes()
        path.unlink()
        path.write_bytes(data)


def write_file(path, text):
    """Write a text file; a linked file of a copy is replaced, never written through."""
    path = Path(path)
    if path.is_symlink():
        path.unlink()
    path.write_text(text, encoding="utf-8")


def toml_load(path):
    with Path(path).open("rb") as stream:
        return tomllib.load(stream)


def toml_write(path, data):
    text = toml_dumps(data)
    if tomllib.loads(text) != data:
        raise AssertionError(f"TOML round trip failed for {path}")
    write_file(path, text)


def toml_edit(path, function):
    """Load `path`, call `function(dict)` (which mutates it) and write it back (comments are not kept)."""
    data = toml_load(path)
    function(data)
    toml_write(path, data)
    return data


def _parent(data, keys):
    for key in keys[:-1]:
        data = data[key]
    return data, keys[-1]


def toml_set(path, keys, value):
    """Replace (or add) one value; `keys` is a tuple of dict keys and list indices."""
    def edit(data):
        parent, last = _parent(data, tuple(keys))
        parent[last] = value
    return toml_edit(path, edit)


def toml_del(path, keys):
    """Delete one key (or one list element when the last key is an index)."""
    def edit(data):
        parent, last = _parent(data, tuple(keys))
        del parent[last]
    return toml_edit(path, edit)


def toml_append(path, keys, value):
    """Append a row (a dict or a value) to the list at `keys`."""
    def edit(data):
        target = data
        for key in keys:
            target = target[key]
        target.append(value)
    return toml_edit(path, edit)


def text_replace(path, old, new, count=1):
    text = Path(path).read_text(encoding="utf-8")
    if text.count(old) < 1:
        raise AssertionError(f"{old!r} not found in {path}")
    write_file(path, text.replace(old, new, count))


# --------------------------------------------------------------------------------------------------------------
# TSV and JSON-lines helpers
# --------------------------------------------------------------------------------------------------------------

def tsv_read(path):
    lines = Path(path).read_text(encoding="utf-8").split("\n")
    if lines and lines[-1] == "":
        lines.pop()
    rows = [line.split("\t") for line in lines]
    return rows[0], rows[1:]


def tsv_write(path, header, rows):
    text = "".join("\t".join(str(field) for field in row) + "\n" for row in [header, *rows])
    write_file(path, text)


def _matches(header, row, match):
    return all(row[header.index(column)] == str(value) for column, value in match.items())


def tsv_edit(path, match, column, value):
    """Set `column` of every row whose columns equal `match`; at least one row must match."""
    header, rows = tsv_read(path)
    index, count = header.index(column), 0
    for row in rows:
        if _matches(header, row, match):
            row[index] = str(value)
            count += 1
    if not count:
        raise AssertionError(f"no row of {path} matches {match}")
    tsv_write(path, header, rows)
    return count


def tsv_drop(path, match):
    """Delete every row whose columns equal `match`; at least one row must match."""
    header, rows = tsv_read(path)
    kept = [row for row in rows if not _matches(header, row, match)]
    if len(kept) == len(rows):
        raise AssertionError(f"no row of {path} matches {match}")
    tsv_write(path, header, kept)
    return len(rows) - len(kept)


def tsv_append(path, row):
    break_link(path)
    with Path(path).open("a", encoding="utf-8") as stream:
        stream.write("\t".join(str(field) for field in row) + "\n")


def tsv_rename_column(path, old, new):
    header, rows = tsv_read(path)
    header[header.index(old)] = new
    tsv_write(path, header, rows)


def jsonl_read(path):
    return [json.loads(line) for line in Path(path).read_text(encoding="utf-8").splitlines() if line.strip()]


def jsonl_write(path, events):
    write_file(path, "".join(json.dumps(event, ensure_ascii=False) + "\n" for event in events))


def jsonl_edit(path, predicate, function):
    """Apply `function(event)` to every event with `predicate(event)`; at least one must match."""
    events, count = jsonl_read(path), 0
    for event in events:
        if predicate(event):
            function(event)
            count += 1
    if not count:
        raise AssertionError(f"no event of {path} matches")
    jsonl_write(path, events)
    return count


def jsonl_drop(path, predicate):
    events = jsonl_read(path)
    kept = [event for event in events if not predicate(event)]
    if len(kept) == len(events):
        raise AssertionError(f"no event of {path} matches")
    jsonl_write(path, kept)
    return len(events) - len(kept)


def jsonl_append(path, event):
    break_link(path)
    with Path(path).open("a", encoding="utf-8") as stream:
        stream.write(json.dumps(event, ensure_ascii=False) + "\n")


def process_event(role=None, arm="AB", julia=None, rep=None):
    """A predicate for the receipt events of one process (None matches any value)."""
    def predicate(event):
        return (event.get("event") == "process" and (role is None or event["role"] == role)
                and event["arm"] == arm and (julia is None or event["julia"] == julia)
                and (rep is None or event["rep"] == rep))
    return predicate


def sha256_text(*parts):
    return hashlib.sha256("|".join(str(part) for part in parts).encode()).hexdigest()


def sha1_text(*parts):
    return hashlib.sha1("|".join(str(part) for part in parts).encode()).hexdigest()


def tree_snapshot(path):
    """Relative path -> SHA-256 of every file below `path` (an empty dict when `path` does not exist)."""
    path = Path(path)
    if not path.exists():
        return {}
    return {str(item.relative_to(path)): hashlib.sha256(item.read_bytes()).hexdigest()
            for item in sorted(path.rglob("*")) if item.is_file()}


# --------------------------------------------------------------------------------------------------------------
# The real inputs the synthetic set is derived from
# --------------------------------------------------------------------------------------------------------------

def load_cases():
    """The 19 declared cases: ids and order of ../pre06/cases.txt, fields of ../pre06/campaign.toml [[case]]."""
    campaign = toml_load(HERE.parent / "pre06" / "campaign.toml")
    by_id = {entry["id"]: entry for entry in campaign["case"]}
    order = (HERE.parent / "pre06" / "cases.txt").read_text(encoding="utf-8").split()
    cases = []
    for index, case_id in enumerate(order):
        entry = by_id[case_id]
        group, problem, solver, variant, phase = case_id.split("/")
        assert phase == entry["phase"]
        cases.append(dict(id=case_id, group=group, problem=problem, solver=solver, variant=variant, phase=phase,
                          suite=entry["suite"], inputs=entry["inputs"], issue=entry["issue"],
                          measure=entry["measure"], target=float(entry["target"]), role=entry["role"],
                          label=entry["label"], index=index))
    return cases


def default_median(label, jkey, index, rep):
    """A deterministic median in nanoseconds. B differs from A by a few tenths of a percent, of both signs."""
    base = 20000 * (index + 2) * (1.0 if jkey == "1.10" else 1.25)
    shift = {"a": 0, "b": 2, "aa_a": 1, "aa_b": 3}[label]
    return int(round(base * (1 + 0.002 * ((rep * 3 + index * 5 + shift) % 7))))


def default_bytes(case):
    return {"call": 4096 * (case["index"] % 7 + 1), "workspace": 0, "setup": 8192}.get(case["phase"], 4096)


def data_hash(version, case_id, rep):
    return sha256_text("data", version, case_id, rep)


# --------------------------------------------------------------------------------------------------------------
# The stacks
# --------------------------------------------------------------------------------------------------------------

def _dep(name, version, compat, julia=None):
    return dict(uuid=str(uuid.uuid5(uuid.NAMESPACE_DNS, name)), version=version,
                tree=sha1_text("tree", name, version), compat=compat, julia=julia)


def stack_a(schedule, label, installation):
    """A Stack A installation: the identity of [stack_a] of the schedule."""
    ident = schedule["stack_a"]
    return dict(
        label=label, installation=installation, dirty=False, blas=BLAS,
        checkout=f"/opt/synthetic/{installation}/ProximalSolvers.jl", depot=f"/opt/synthetic/{installation}/depot",
        ps=dict(commit=ident["proximalsolvers"]["commit"], tree=ident["proximalsolvers"]["tree"],
                version=ident["proximalsolvers"]["version"], hash=PS_A_PACKAGE_HASH),
        pb=dict(dict(ident["proximalbase"]), hash=PB_A_PACKAGE_HASH),
        harness=ident["harness_hash"], pb_compat="0.5", loaded_tree=None,
        deps={"StatsBase": _dep("StatsBase", "1.9.0", "1"), "OldDep": _dep("OldDep", "0.2.0", "0.2")})


def stack_b(schedule, installation, variant):
    """A Stack B installation: a migration target with its own commits, trees and hashes."""
    stack = stack_a(schedule, "b", installation)
    if variant == "identical":
        return stack
    stack["ps"] = dict(commit=sha1_text("ps-commit"), tree=sha1_text("ps-tree"),
                       version=stack["ps"]["version"], hash=sha1_text("ps-hash"))
    stack["pb"] = dict(commit=sha1_text("pb-commit"), tree=sha1_text("pb-tree"), version="0.6.0",
                       hash=sha1_text("pb-hash"), release="development")
    stack["harness"] = sha1_text("harness-b")
    stack["pb_compat"] = "0.6"
    if variant == "manifest":
        stack["deps"] = {"StatsBase": _dep("StatsBase", "1.10.0", "1"),
                         "NewDep": _dep("NewDep", "1.0.0", "1", julia=["1.13"])}
    return stack


def dep_applies(dep, jkey):
    return dep["julia"] is None or jkey in dep["julia"]


def manifest_entries(stack, jkey):
    """name -> dict(uuid, version, tree) of the Manifest of one stratum."""
    entries = {"ProximalBase": dict(uuid=PB_UUID, version=stack["pb"]["version"], tree=stack["pb"]["tree"]),
               "ProximalSolvers": dict(uuid=PS_UUID, version=stack["ps"]["version"], tree="",
                                       path=stack["checkout"])}
    for name, dep in stack["deps"].items():
        if dep_applies(dep, jkey):
            entries[name] = dict(uuid=dep["uuid"], version=dep["version"], tree=dep["tree"])
    return entries


def project_dict(stack, jkey):
    deps = {"ProximalBase": PB_UUID, "ProximalSolvers": PS_UUID}
    compat = {"julia": "1.10", "ProximalBase": stack["pb_compat"]}
    for name, dep in stack["deps"].items():
        if dep_applies(dep, jkey):
            deps[name] = dep["uuid"]
            if dep["compat"]:
                compat[name] = dep["compat"]
    return {"name": "ProximalSolversBenchmark", "deps": deps, "compat": compat}


def identity_dict(stack, campaign_id, session_id=SESSION_ID):
    """stack-identity.toml: the root is bound to the campaign and the session of the receipt."""
    pb = {key: value for key, value in stack["pb"].items() if key != "hash"}
    ps = {key: value for key, value in stack["ps"].items() if key != "hash"}
    return {"schema": 1, "installation": stack["installation"], "campaign_id": campaign_id,
            "session_id": session_id, "proximalsolvers": ps, "proximalbase": pb}


def fixture_names(case):
    names = ["X", "y"]
    if "lasso" in case["problem"]:
        names.append("λ")
    if case["group"] == "paths":
        names.append("grid")
    return names


def fingerprint_rows(schedule, cases, reps):
    """The fingerprint rows of one stack: equal for equal workloads, whatever the stack."""
    rows = []
    for jkey, julia in schedule["julia"].items():
        version = julia["version"]
        for case in cases:
            for rep in reps:
                key = (version, case["id"], rep)
                for name in fixture_names(case):
                    rows.append((*key, "fixture", name, sha256_text("fixture", *key, name)))
                setup = case["phase"] == "setup"
                no_set = setup or case["group"] in ("admm", "newton", "primal_dual")
                rows.append((*key, "reset", "values", "none" if setup else sha256_text("reset", *key)))
                rows.append((*key, "reset", "active_ids", "none" if no_set else sha256_text("active", *key)))
                rows.append((*key, "config", "solver", sha256_text("solver", case["id"])))
                rows.append((*key, "config", "options", sha256_text("options", case["id"])))
                rows.append((*key, "file", "certificates.jl", CERTIFICATES_HASH))
    return rows


# --------------------------------------------------------------------------------------------------------------
# The campaign object
# --------------------------------------------------------------------------------------------------------------

class Result:
    """The outcome of one in-process run of the comparator."""

    def __init__(self, code, stdout, stderr, out, argv):
        self.code, self.stdout, self.stderr, self.out, self.argv = code, stdout, stderr, Path(out), argv
        self.files = sorted(item.name for item in self.out.iterdir()) if self.out.is_dir() else []
        self._json = {}

    def _read_json(self, name):
        if name not in self._json:
            path = self.out / name
            self._json[name] = json.loads(path.read_text(encoding="utf-8")) if path.is_file() else None
        return self._json[name]

    @property
    def refusals(self):
        document = self._read_json("refusals.json")
        return None if document is None else document["refusals"]

    @property
    def refusals_document(self):
        return self._read_json("refusals.json")

    @property
    def classes(self):
        return [item["class"] for item in self.refusals or []]

    @property
    def lines(self):
        """The parsed REFUSED lines of standard error: (class, field, detail)."""
        found = []
        for line in self.stderr.splitlines():
            match = re.fullmatch(r"REFUSED:([A-Z]+) ([A-Za-z_]+:[A-Za-z_]+): (.*)", line)
            if match:
                found.append(match.groups())
            elif line.startswith("REFUSED:"):
                found.append((line.split()[0][8:], None, line))
        return found

    def has(self, cls, field=None, text=None):
        for item in self.refusals or []:
            if (item["class"] == cls and (field is None or item["field"] == field)
                    and (text is None or text in item["detail"])):
                return True
        return False

    def fields(self, cls):
        return sorted(item["field"] for item in self.refusals or [] if item["class"] == cls)

    @property
    def lists(self):
        return self._read_json("lists.json")

    @property
    def report(self):
        path = self.out / "report.md"
        return path.read_text(encoding="utf-8") if path.is_file() else None

    @property
    def csv_text(self):
        path = self.out / "migration-comparison.csv"
        return path.read_text(encoding="utf-8") if path.is_file() else None

    @property
    def rows(self):
        text = self.csv_text
        if text is None:
            return None
        lines = text.split("\n")
        assert lines[-1] == "", "the CSV ends with a newline"
        reader = csv.DictReader(lines[:-1], lineterminator="\n")
        return list(reader)

    def row(self, case_id, jkey_or_version):
        version = jkey_or_version
        matches = [row for row in self.rows if row["id"] == case_id and row["julia"].startswith(version)]
        assert len(matches) == 1, f"{len(matches)} rows for {case_id} {version}"
        return matches[0]


def link_tree(source, dest, skip=()):
    """Copy a built set cheaply: directories are made, the top-level files and the stack-identity files are
    copied, every other file becomes a link to the file of the built set (which `freeze` made read-only; the
    helpers of this module replace a link before a change). `skip`: tuples of leading path parts to leave out."""
    source, dest = Path(source), Path(dest)
    skip = [tuple(part) for part in skip]

    def walk(directory, relative):
        dest.joinpath(*relative).mkdir(parents=True, exist_ok=True)
        with os.scandir(directory) as entries:
            for entry in sorted(entries, key=lambda e: e.name):
                child = relative + (entry.name,)
                if any(child[:len(part)] == part for part in skip):
                    continue
                if entry.is_dir(follow_symlinks=False):
                    walk(entry.path, child)
                elif len(child) == 1 or entry.name == "stack-identity.toml":
                    shutil.copyfile(entry.path, dest.joinpath(*child))
                else:
                    os.symlink(entry.path, dest.joinpath(*child))

    walk(source, ())


def freeze(path):
    """Make every file below `path` read-only: a change through a link then fails instead of spoiling the set."""
    for item in Path(path).rglob("*"):
        if item.is_file() and not item.is_symlink():
            item.chmod(0o444)


class Campaign:
    """A built synthetic input set and the helpers that mutate one item of it."""

    def __init__(self, base, model):
        self.base, self.model, self._runs = Path(base), model, 0

    # ---- paths ---------------------------------------------------------------------------------------------
    @property
    def work(self):
        return self.base.parent

    @property
    def schedule(self):
        return self.base / "schedule.toml"

    @property
    def mapping(self):
        return self.base / "case-mapping.toml"

    @property
    def declared(self):
        return self.base / "declared-differences.toml"

    @property
    def receipt(self):
        return self.base / "receipt.jsonl"

    def root(self, label):
        return self.base / "roots" / label

    def stratum(self, label, jkey):
        return self.root(label) / f"julia-{jkey}"

    def raw(self, label, jkey):
        return self.stratum(label, jkey) / "raw"

    def fingerprints(self, label):
        return self.root(label) / "fingerprints.tsv"

    def record(self, label, jkey, rep, kind):
        extension = "toml" if kind.startswith("metadata") else "tsv"
        return self.raw(label, jkey) / f"{self.prefix(jkey, rep)}-{kind}.{extension}"

    # ---- model ---------------------------------------------------------------------------------------------
    @property
    def sched(self):
        return self.model["schedule"]

    @property
    def jkeys(self):
        return list(self.sched["julia"])

    @property
    def reps(self):
        return list(self.sched["schedule"]["reps"])

    @property
    def cases(self):
        return self.model["cases"]

    @property
    def case_ids(self):
        return [case["id"] for case in self.cases]

    def version(self, jkey):
        return self.sched["julia"][jkey]["version"]

    def prefix(self, jkey, rep):
        return f"julia-{self.version(jkey)}-rep{rep:02d}"

    def stack(self, label):
        return self.model["stacks"][label]

    def case(self, case_id):
        return next(case for case in self.cases if case["id"] == case_id)

    def order(self, rep):
        return self.sched["schedule"]["orders"][str(rep)]

    # ---- copying -------------------------------------------------------------------------------------------
    def copy(self, work, with_aa=False):
        """A copy of the set in `work/campaign` (the A/A roots only on request)."""
        dest = Path(work) / "campaign"
        link_tree(self.base, dest, skip=() if with_aa else (("roots", "aa_a"), ("roots", "aa_b")))
        return Campaign(dest, copy.deepcopy(self.model))

    def attach_aa(self, source):
        for label in ("aa_a", "aa_b"):
            if not self.root(label).exists():
                link_tree(source.root(label), self.root(label))
        self.model["stacks"]["aa_a"] = copy.deepcopy(source.model["stacks"]["aa_a"])
        self.model["stacks"]["aa_b"] = copy.deepcopy(source.model["stacks"]["aa_b"])

    # ---- records -------------------------------------------------------------------------------------------
    def case_list(self, label, ov):
        """The case dicts of a process after the overrides `drop`, `rename`, `catalog`, `extra`."""
        dropped, renames = set(ov.get("drop", ())), ov.get("rename", {})
        cases = []
        for case in self.cases:
            if case["id"] in dropped:
                continue
            item = dict(case, orig=case["id"])
            if case["id"] in renames:
                new = renames[case["id"]]
                group, problem, solver, variant, phase = new.split("/")
                item.update(id=new, group=group, problem=problem, solver=solver, variant=variant, phase=phase)
            item.update(ov.get("catalog", {}).get(case["id"], {}))
            cases.append(item)
        for extra in ov.get("extra", ()):
            cases.append(dict(extra, orig=extra["id"]))
        return cases

    def process_tables(self, label, jkey, rep, ov):
        version = self.version(jkey)
        catalog, metrics, samples, errors, nonok = [], [], [], [], 0
        for case in self.case_list(label, ov):
            orig = case["orig"]
            status = ov.get("status", {}).get(orig, "ok")
            target = float(case["target"])
            median = ov.get("median", {}).get(orig, default_median(label, jkey, case["index"], rep))
            catalog.append([case[key] if key != "target" else repr(target) for key in validate.HEADERS["catalog"]])
            count = 0 if status == "error" else 5
            times = [median - 2, median - 1, median, median + 1, median + 2][:count]
            byte_count = ov.get("bytes", {}).get(orig, default_bytes(case))
            sizes = [byte_count] * count
            if orig in ov.get("max_bytes", {}) and count:
                sizes[-1] = ov["max_bytes"][orig]
            if status == "ok":
                worst = ov.get("value", {}).get(orig, 0.5 * target)
                if worst > target:
                    raise ValueError("an ok case needs a value at or below the target; use status target_missed")
                values = [worst / 2] * 4 + [worst]
            elif status == "target_missed":
                values = [ov.get("value", {}).get(orig, 2 * target)] * count
            else:
                values = [math.nan] * count
            rows = [dict(time_ns=str(t), gc_ns=str(t // 50), bytes=str(b)) for t, b in zip(times, sizes)]
            for index, (row, value) in enumerate(zip(rows, values), start=1):
                samples.append([case["id"], rep, index, row["time_ns"], row["gc_ns"], row["bytes"],
                                "" if math.isnan(value) else repr(float(value)), status])
            statistics_ = validate.sample_statistics(rows if status == "ok" else [])
            finite = [value for value in values if math.isfinite(value)]
            data = ov.get("data_hash", {}).get(orig, "" if status == "error" else data_hash(version, case["id"], rep))
            stats = ["" if math.isnan(statistics_[key]) else (repr(statistics_[key]) if key == "gc_share"
                                                           else str(round(statistics_[key])))
                     for key in validate.TIME_FIELDS]
            metrics.append([case["id"], case["group"], case["phase"], rep, status, count,
                            count if status == "ok" else 0, *stats, case["measure"], repr(target),
                            repr(max(finite)) if finite else "",
                            repr(sorted(finite)[len(finite) // 2]) if finite else "", data])
            if status != "ok":
                nonok += 1
                errors.append([case["id"], rep, status, ERROR_TEXT[status], ""])
        return catalog, metrics, samples, errors, nonok

    def metadata(self, label, jkey, rep, ov, cases, nonok):
        s, stack = self.sched["settings"], self.stack(label)
        start = {
            "julia": self.version(jkey), "rep": rep, "suite": s["suite"], "groups": s["groups"],
            "case_filter": s["case_filter"], "harness_hash": stack["harness"],
            "proximalsolvers_path": stack["checkout"], "proximalsolvers_sha": stack["ps"]["commit"],
            "proximalsolvers_dirty": stack["dirty"], "proximalsolvers_hash": stack["ps"]["hash"],
            "proximalbase_version": stack["pb"]["version"], "proximalbase_hash": stack["pb"]["hash"],
            "expected_package_root": stack["checkout"], "julia_threads": s["julia_threads"],
            "blas_threads": s["blas_threads"], "blas": stack["blas"], "cpu": self.sched["machine"]["cpu"][jkey],
            "cpu_model": self.sched["machine"]["cpu_model"], "samples_target": s["samples_target"],
            "seconds_limit": s["seconds_limit"], "case_seconds": s["case_seconds"],
            "profile_seconds": s["profile_seconds"], "seed_scheme": s["seed_scheme"], "job_id": "none"}
        start.update(ov.get("meta", {}))
        start.update(ov.get("start_meta", {}))
        final = dict(start)
        final.update(ov.get("meta", {}))
        final.update({"cases": cases, "ok_cases": cases - nonok, "nonok_cases": nonok,
                      "elapsed_s": ov.get("elapsed_s", 12.5), "maxrss_bytes": 400_000_000 + 1_000_000 * rep,
                      "finished": True})
        final.update(ov.get("final_meta", {}))
        return start, final

    def write_process(self, label, jkey, rep, **ov):
        """(Re)write the six record files of one process; `ov` are the overrides described in `process_tables`
        (`status`, `median`, `value`, `bytes`, `max_bytes`, `data_hash`, `drop`, `rename`, `catalog`, `extra`,
        `meta`, `start_meta`, `final_meta`, `elapsed_s`, all keyed by the original case id)."""
        catalog, metrics, samples, errors, nonok = self.process_tables(label, jkey, rep, ov)
        raw = self.raw(label, jkey)
        raw.mkdir(parents=True, exist_ok=True)
        tsv_write(self.record(label, jkey, rep, "catalog"), validate.HEADERS["catalog"], catalog)
        tsv_write(self.record(label, jkey, rep, "metrics"), validate.HEADERS["metrics"], metrics)
        tsv_write(self.record(label, jkey, rep, "samples"), validate.HEADERS["samples"], samples)
        tsv_write(self.record(label, jkey, rep, "errors"), validate.HEADERS["errors"], errors)
        start, final = self.metadata(label, jkey, rep, ov, len(catalog), nonok)
        toml_write(self.record(label, jkey, rep, "metadata-start"), start)
        toml_write(self.record(label, jkey, rep, "metadata"), final)

    def write_stratum(self, label, jkey, reps=None, **ov):
        for rep in (self.reps if reps is None else reps):
            self.write_process(label, jkey, rep, **ov)

    def write_records(self, label, jkeys=None, reps=None, **ov):
        for jkey in (self.jkeys if jkeys is None else jkeys):
            self.write_stratum(label, jkey, reps, **ov)

    def delete_process(self, label, jkey, rep):
        for kind in RECORD_KINDS:
            self.record(label, jkey, rep, kind).unlink()

    def retag_stratum(self, label, jkey, new_version):
        """Rewrite every record of a stratum as if it came from another Julia build (`new_version`)."""
        old = self.version(jkey)
        shutil.rmtree(self.raw(label, jkey))
        self.sched["julia"][jkey]["version"] = new_version
        try:
            self.write_records(label, [jkey])
        finally:
            self.sched["julia"][jkey]["version"] = old

    def set_meta(self, label, key, value, jkeys=None, reps=None, files=("metadata", "metadata-start")):
        """Set one metadata key in the given files of every process of the stratum (or of one repetition)."""
        for jkey in (self.jkeys if jkeys is None else jkeys):
            for rep in (self.reps if reps is None else reps):
                for kind in files:
                    toml_set(self.record(label, jkey, rep, kind), (key,), value)

    def del_meta(self, label, key, jkeys=None, reps=None, files=("metadata", "metadata-start")):
        for jkey in (self.jkeys if jkeys is None else jkeys):
            for rep in (self.reps if reps is None else reps):
                for kind in files:
                    toml_del(self.record(label, jkey, rep, kind), (key,))

    def set_status(self, label, jkey, case_id, status, reps=None, receipt=True, **ov):
        """Make `case_id` non-ok (or ok again) in the given repetitions, keep the receipt exit consistent."""
        for rep in (self.reps if reps is None else reps):
            self.write_process(label, jkey, rep, status={case_id: status}, **ov)
            if receipt and self.receipt.exists():
                arm = "AA" if label.startswith("aa") else "AB"
                role = "A" if label in ("a", "aa_a") else "B"
                jsonl_edit(self.receipt, process_event(role, arm, self.version(jkey), rep),
                           lambda event: event.update(exit=2 if status != "ok" else 0))

    def set_medians(self, case_id, jkey, **by_label):
        """`set_medians(id, "1.13", a=[...8], b=[...8], aa_a=[...8], aa_b=[...8])`: one median per repetition."""
        for label, values in by_label.items():
            for rep, value in zip(self.reps, values):
                header, rows = tsv_read(self.record(label, jkey, rep, "samples"))
                mine = [row for row in rows if row[0] == case_id]
                assert len(mine) == 5, "set_medians is for ok cases of five samples"
                for offset, row in zip((-2, -1, 0, 1, 2), mine):
                    row[3] = str(value + offset)
                    row[4] = str((value + offset) // 50)
                tsv_write(self.record(label, jkey, rep, "samples"), header, rows)
                stats = validate.sample_statistics([dict(time_ns=row[3], gc_ns=row[4], bytes=row[5])
                                                    for row in mine])
                for key in validate.TIME_FIELDS:
                    text = repr(stats[key]) if key == "gc_share" else str(round(stats[key]))
                    tsv_edit(self.record(label, jkey, rep, "metrics"), {"id": case_id}, key, text)

    def median(self, label, jkey, case_id, rep):
        header, rows = tsv_read(self.record(label, jkey, rep, "metrics"))
        row = next(row for row in rows if row[0] == case_id)
        return float(row[header.index("median_ns")])

    # ---- the root-level files ------------------------------------------------------------------------------
    def inventory_dict(self, label, jkey):
        stack = self.stack(label)
        inventory = {
            "julia": self.version(jkey), "commit": self.sched["julia"][jkey]["commit"],
            "cpu_model": self.sched["machine"]["cpu_model"], "blas": stack["blas"],
            "depot_path": [stack["depot"], "/opt/synthetic/julia/depot"],
            "proximalbase_version": stack["pb"]["version"],
            "proximalbase_loaded_tree": stack["loaded_tree"] or stack["pb"]["tree"],
            "proximalsolvers_dir": stack["checkout"], "threads": 1,
            "active_project": f"/opt/synthetic/{stack['installation']}/benchmark", "cpu_name":
            self.sched["machine"]["cpu"][jkey]}
        inventory["deps"] = {name: {"tree": entry["tree"], "uuid": entry["uuid"], "version": entry["version"]}
                             for name, entry in manifest_entries(stack, jkey).items() if entry["tree"]}
        return inventory

    def manifest_dict(self, label, jkey):
        deps = {}
        for name, entry in manifest_entries(self.stack(label), jkey).items():
            item = {"uuid": entry["uuid"], "version": entry["version"]}
            if entry["tree"]:
                item["git-tree-sha1"] = entry["tree"]
            if "path" in entry:
                item["path"] = entry["path"]
            deps[name] = [dict(sorted(item.items()))]
        return {"julia_version": self.version(jkey), "manifest_format": "2.0",
                "project_hash": sha1_text("project", label), "deps": deps}

    def write_environment(self, label, jkey):
        directory = self.stratum(label, jkey)
        toml_write(directory / "Manifest.toml", self.manifest_dict(label, jkey))
        toml_write(directory / "Project.toml", project_dict(self.stack(label), jkey))
        toml_write(directory / "environment-inventory.toml", self.inventory_dict(label, jkey))

    def write_fingerprints(self, label):
        header = ["julia", "id", "rep", "kind", "name", "value"]
        tsv_write(self.fingerprints(label), header, fingerprint_rows(self.sched, self.cases, self.reps))

    def write_root(self, label):
        root = self.root(label)
        if root.exists():
            shutil.rmtree(root)
        root.mkdir(parents=True)
        toml_write(root / "stack-identity.toml", identity_dict(self.stack(label), self.sched["schedule"]["campaign_id"]))
        for jkey in self.jkeys:
            self.write_records(label, [jkey])
            self.write_environment(label, jkey)
        if label in ("a", "b"):
            self.write_fingerprints(label)

    def rebuild_root(self, label):
        """Rewrite one root from the model (after a change of `self.stack(label)`)."""
        self.write_root(label)

    def mapping_dict(self):
        return toml_load(self.mapping)

    def write_declared(self):
        toml_write(self.declared, declared_differences(self))

    def write_receipt(self):
        jsonl_write(self.receipt, receipt_events(self))

    def write_inputs(self):
        for label in LABELS:
            self.write_root(label)
        self.write_receipt()
        self.write_declared()

    # ---- running the tool ----------------------------------------------------------------------------------
    def argv(self, a=None, b=None, mapping=None, declared=None, receipt=None, schedule=None, aa=False,
             fingerprints_a=None, fingerprints_b=None, out=None, extra=(), omit=()):
        args = []
        for flag, name, value in (("--a", "a", a or self.root("a")), ("--b", "b", b or self.root("b")),
                                  ("--mapping", "mapping", mapping or self.mapping),
                                  ("--declared-differences", "declared", declared or self.declared),
                                  ("--receipt", "receipt", receipt or self.receipt),
                                  ("--schedule", "schedule", schedule or self.schedule)):
            if name not in omit:
                args += [flag, str(value)]
        if aa is True:
            args += ["--aa", str(self.root("aa_a")), str(self.root("aa_b"))]
        elif aa:
            args += ["--aa", *map(str, aa)]
        for flag, value in (("--fingerprints-a", fingerprints_a), ("--fingerprints-b", fingerprints_b)):
            if value is not None:
                args += [flag, str(value)]
        if "out" not in omit:
            if out is None:
                self._runs += 1
                out = self.work / f"out-{self._runs}"
            args += ["--out", str(out)]
        return args + list(extra)

    def run(self, **overrides):
        """Call `migration_compare.main(argv)` in process; `overrides` are the arguments of `argv`."""
        args = self.argv(**overrides)
        out = args[args.index("--out") + 1] if "--out" in args else self.work / "no-out"
        return call_tool(args, out)


def load_tool():
    """Import migration_compare lazily (the tool may not exist while the fixtures are being written)."""
    return importlib.import_module("migration_compare")


def call_tool(args, out):
    tool = load_tool()
    stdout, stderr = io.StringIO(), io.StringIO()
    with contextlib.redirect_stdout(stdout), contextlib.redirect_stderr(stderr):
        try:
            code = tool.main(list(args))
        except SystemExit as error:
            code = error.code if isinstance(error.code, int) else (0 if error.code is None else 1)
    return Result(code, stdout.getvalue(), stderr.getvalue(), out, list(args))


# --------------------------------------------------------------------------------------------------------------
# Receipt and declared differences (derived from the model)
# --------------------------------------------------------------------------------------------------------------

def _utc(moment):
    return moment.strftime("%Y-%m-%dT%H:%M:%S.000+00:00")


def receipt_events(camp):
    """The receipt of one campaign: the A/A arm, then the A/B arm; per arm and stratum eight blocks in the
    order of the schedule, the second process of a block starting after the first has ended."""
    sched, machine = camp.sched, camp.sched["machine"]
    events = [{"event": "campaign", "campaign_id": sched["schedule"]["campaign_id"], "session_id": SESSION_ID,
               "schedule_id": sched["schedule"]["id"], "utc": "2026-12-01T08:00:00.000+00:00"}]
    moment = datetime.datetime(2026, 12, 1, 9, 0, 0, tzinfo=datetime.timezone.utc)
    step = datetime.timedelta
    for arm in ("AA", "AB"):
        for jkey in camp.jkeys:
            for rep in camp.reps:
                first, second = ("A", "B") if camp.order(rep) == "AB" else ("B", "A")
                for slot, role in enumerate((first, second)):
                    label = ROLE_LABELS[arm][role]
                    start = moment + step(seconds=35 * slot)
                    final = camp.record(label, jkey, rep, "metadata")
                    nonok = toml_load(final)["nonok_cases"] if final.exists() else 0
                    events.append({
                        "event": "process", "arm": arm, "role": role, "julia": camp.version(jkey), "rep": rep,
                        "block": rep, "installation": camp.stack(label)["installation"], "start_utc": _utc(start),
                        "end_utc": _utc(start + step(seconds=30)), "exit": 2 if nonok else 0, "complete": True,
                        "machine": {"cpu_model": machine["cpu_model"], "cpu": machine["cpu"][jkey],
                                    "logical_cpu": machine["logical_cpu"], "governor": machine["governor"],
                                    "epp": machine["epp"], "no_turbo": machine["no_turbo"],
                                    "smt_control": machine["smt_control"]}})
                moment += step(seconds=80)
    return events


def declared_differences(camp):
    """The declared-differences file that matches the two stacks of the model exactly."""
    a, b = camp.stack("a"), camp.stack("b")
    declared = {"schema": 1}
    if a["ps"]["commit"] != b["ps"]["commit"]:
        declared["proximalsolvers"] = dict(
            a_commit=a["ps"]["commit"], b_commit=b["ps"]["commit"], a_tree=a["ps"]["tree"], b_tree=b["ps"]["tree"],
            a_package_hash=a["ps"]["hash"], b_package_hash=b["ps"]["hash"])
    if a["pb"]["commit"] != b["pb"]["commit"]:
        declared["proximalbase"] = dict(
            a_version=a["pb"]["version"], b_version=b["pb"]["version"], a_commit=a["pb"]["commit"],
            b_commit=b["pb"]["commit"], a_tree=a["pb"]["tree"], b_tree=b["pb"]["tree"],
            a_package_hash=a["pb"]["hash"], b_package_hash=b["pb"]["hash"])
    entries, compat = {}, {}
    for jkey in camp.jkeys:
        left, right = manifest_entries(a, jkey), manifest_entries(b, jkey)
        for name in sorted(left.keys() | right.keys()):
            old, new = left.get(name), right.get(name)
            if old and new and (old["version"], old["tree"]) == (new["version"], new["tree"]):
                continue
            kind = "changed" if old and new else "added" if new else "removed"
            key = (name, (old or new)["uuid"], kind, old["version"] if old else "", new["version"] if new else "",
                   old["tree"] if old else "", new["tree"] if new else "")
            entries.setdefault(key, []).append(jkey)
        old_compat, new_compat = project_dict(a, jkey)["compat"], project_dict(b, jkey)["compat"]
        for name in sorted(old_compat.keys() | new_compat.keys()):
            if old_compat.get(name, "") != new_compat.get(name, ""):
                compat.setdefault((name, old_compat.get(name, ""), new_compat.get(name, "")), []).append(jkey)
    rows = []
    for (name, uid, kind, a_version, b_version, a_tree, b_tree), strata in sorted(entries.items()):
        row = dict(name=name, uuid=uid, kind=kind, a_version=a_version, b_version=b_version, a_tree=a_tree,
                   b_tree=b_tree, reason=f"synthetic {kind} dependency")
        if strata != camp.jkeys:
            row["julia"] = strata
        rows.append(row)
    if rows:
        declared["manifest"] = rows
    rows = []
    for (name, old, new), strata in sorted(compat.items()):
        row = dict(name=name, a=old, b=new, reason="the compat entry must admit the candidate")
        if strata != camp.jkeys:
            row["julia"] = strata
        rows.append(row)
    if rows:
        declared["compat"] = rows
    if a["harness"] != b["harness"]:
        mapping = camp.mapping_dict()["case"]
        class_b = [row for row in mapping if row["class"] == "B"]
        declared["harness"] = dict(
            a_hash=a["harness"], b_hash=b["harness"], port_commit=sha1_text("port-commit"),
            cases=[row["id"] for row in class_b],
            changed_lines=["-reset!() = (fill!(x, 0.0); reset_solver_rng!(method); nothing)",
                           "+reset!() = (dropzeros!(fill!(x, 0.0)); reset_solver_rng!(method); nothing)"],
            approval_url=class_b[0]["approval_url"])
    return declared


# --------------------------------------------------------------------------------------------------------------
# Building a set
# --------------------------------------------------------------------------------------------------------------

def build_campaign(dest, variant="migration", reps=None, schedule_edit=None):
    """Build a complete valid input set in `dest/campaign` and return its `Campaign`.

    `reps`: the number of repetition IDs (default: the schedule's eight; the schedule copy follows).
    `schedule_edit`: a function applied to the schedule dict before anything is built."""
    assert variant in ("migration", "manifest", "identical")
    base = Path(dest) / "campaign"
    base.mkdir(parents=True)
    shutil.copyfile(HERE / "schedule.toml", base / "schedule.toml")
    shutil.copyfile(HERE / "case-mapping.toml", base / "case-mapping.toml")
    schedule = toml_load(base / "schedule.toml")
    if reps is not None:
        schedule["schedule"]["reps"] = list(range(1, reps + 1))
        schedule["schedule"]["orders"] = {str(rep): schedule["schedule"]["orders"][str(rep)]
                                          for rep in range(1, reps + 1)}
    if schedule_edit is not None:
        schedule_edit(schedule)
    if reps is not None or schedule_edit is not None:
        toml_write(base / "schedule.toml", schedule)
    cases = load_cases()
    declared_ids = schedule["settings"]["case_filter"].split(",")
    assert declared_ids == [case["id"] for case in cases], "cases.txt and the schedule disagree"
    stacks = {"a": stack_a(schedule, "a", "inst-a1"), "b": stack_b(schedule, "inst-b1", variant),
              "aa_a": stack_a(schedule, "aa_a", "inst-aa1"), "aa_b": stack_a(schedule, "aa_b", "inst-aa2")}
    stacks["b"]["label"] = "b"
    camp = Campaign(base, {"schedule": schedule, "cases": cases, "stacks": stacks, "variant": variant})
    camp.write_inputs()
    return camp


def check_set(camp, verbose=False):
    """validate.validate on every stratum of every root; returns the totals."""
    totals = dict(roots=0, strata=0, processes=0, measurements=0, samples=0)
    for label in LABELS:
        totals["roots"] += 1
        for jkey in camp.jkeys:
            result = validate.validate(camp.raw(label, jkey), expected=len(camp.reps),
                                       versions=[camp.version(jkey)])
            if not result["valid"]:
                raise AssertionError(f"{label} {jkey}: {result['issues'][:3]}")
            totals["strata"] += 1
            totals["processes"] += result["counts"]["processes"]
            totals["measurements"] += result["counts"]["measurements"]
            totals["samples"] += result["counts"]["samples"]
    for path in (camp.schedule, camp.mapping, camp.declared):
        toml_load(path)
    events = jsonl_read(camp.receipt)
    assert sum(event["event"] == "process" for event in events) == 4 * len(camp.jkeys) * len(camp.reps)
    return totals


def main(argv=None):
    parser = argparse.ArgumentParser(description="Self-check of the synthetic campaign builder.")
    parser.add_argument("--check", action="store_true", help="build the sets and validate every stratum")
    args = parser.parse_args(argv)
    if not args.check:
        parser.error("nothing to do; use --check")
    for variant in ("migration", "manifest", "identical"):
        with tempfile.TemporaryDirectory() as work:
            camp = build_campaign(work, variant)
            totals = check_set(camp)
            print(f"{variant}: " + ", ".join(f"{key}={value}" for key, value in totals.items()))
    with tempfile.TemporaryDirectory() as work:
        camp = build_campaign(work, "migration", reps=7)
        totals = check_set(camp)
        print("migration, 7 repetition IDs: " + ", ".join(f"{key}={value}" for key, value in totals.items()))
    print("OK")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
