#!/usr/bin/env python3
"""Whole-stack migration comparison of two benchmark campaign roots (Stage 2B of #110).

Implements MIGRATION_COMPARE_SPEC.md (next to this file). It reads records only: it runs no Julia, needs no
network and writes only into a fresh output directory. Every refusal of section 4 is evaluated, and listed,
before any timing is read; a refused run writes `refusals.json` alone and exits with status 2. Otherwise it
writes `migration-comparison.csv`, `lists.json` and `report.md` and exits with 0 (all cases COMPARABLE) or 1.
Usage errors and unreadable argument files exit with status 3 and write nothing.

The unmodified `validate.py` and `summarize.py` of `benchmark/` are imported; no setting of theirs is changed.
The schedule, the settings, the machine policy, the Julia builds and the Stack A identity all come from
`schedule.toml`. The screens are descriptive investigation screens, not tests.
"""

import argparse
from collections import Counter, defaultdict
import csv
from datetime import datetime
import json
import math
from pathlib import Path
import posixpath
import re
import statistics
import sys
import tomllib

HERE = Path(__file__).resolve().parent
BENCH = HERE.parent.parent
if str(BENCH) not in sys.path:
    sys.path.insert(0, str(BENCH))
_write_bytecode, sys.dont_write_bytecode = sys.dont_write_bytecode, True     # write nothing next to the readers
import summarize  # noqa: E402
import validate  # noqa: E402
sys.dont_write_bytecode = _write_bytecode

# Refusal classes in the row order of section 4.
CLASSES = ("JULIA INPUTS TARGET CASE PHASE OPERATION THREADS MACHINE REPETITIONS MAPPING SCHEMA UNDECLARED "
           "SETTINGS STACK IDENTITY ORDER").split()
PRIMARY_CASES = 14          # section 2: the first 14 declared cases are primary, the rest diagnostic
PHASES = ("call", "workspace", "setup")
SETTING_KEYS = ("suite", "groups", "case_filter", "samples_target", "seconds_limit", "case_seconds",
                "profile_seconds")
MIXED_KEYS = ("proximalsolvers_sha", "proximalsolvers_hash", "proximalbase_version", "proximalbase_hash",
              "harness_hash")
META_START = tuple(validate.START_KEYS) + ("case_filter",)
META_FINAL = META_START + tuple(validate.FINAL_KEYS)
# The type of every metadata value the checks read: s string, b boolean, i integer, n number.
META_TYPES = {**dict.fromkeys(
    "julia suite groups case_filter harness_hash proximalsolvers_path proximalsolvers_sha proximalsolvers_hash "
    "proximalbase_version proximalbase_hash expected_package_root blas cpu cpu_model seed_scheme job_id".split(), "s"),
    **dict.fromkeys("proximalsolvers_dirty finished".split(), "b"),
    **dict.fromkeys("rep julia_threads blas_threads samples_target cases ok_cases nonok_cases "
                    "maxrss_bytes".split(), "i"),
    **dict.fromkeys("seconds_limit case_seconds profile_seconds elapsed_s".split(), "n")}
CATALOG_COLUMNS = ("problem", "solver", "variant", "suite", "inputs")
REQUIRED_ROWS = (("reset", "values"), ("reset", "active_ids"), ("config", "solver"), ("config", "options"),
                 ("file", "certificates.jl"))
FP_ALLOWED = {("reset", "values"), ("reset", "active_ids"), ("config", "solver"), ("config", "options"),
              ("file", "certificates.jl")}
FP_HEADER = "julia\tid\trep\tkind\tname\tvalue"
HEX40, HEX64 = re.compile(r"[0-9a-f]{40}"), re.compile(r"[0-9a-f]{64}")
TIME = re.compile(r"[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}(\.[0-9]+)?(Z|[+-][0-9]{2}:[0-9]{2})")
FIRST_LINE = ("This is a whole-stack migration comparison. Differences cannot be attributed solely to "
              "ProximalBase. The Stage 2A historical archive is descriptive context, not part of the "
              "contemporaneous paired ratios.")
DISCLAIMER = ("The screens are descriptive investigation screens, not tests: there is no significance level, "
              "no noninferiority claim and no no-regression claim, and A/A ranges are not calibrated "
              "confidence bounds.")
BANNED = re.compile(r"non-?inferior|no-regression|significant|equivalent", re.IGNORECASE)
HISTORICAL_TITLE = "Historical Stage 2A reference (descriptive; not part of any ratio)"
COLUMNS = ("julia id role phase class reason repetitions a_ns b_ns ratio abs_diff_ns geomean_ratio ratio_min "
           "ratio_max measure target a_value b_value a_accuracy_fraction b_accuracy_fraction a_accuracy_band "
           "b_accuracy_band a_median_bytes b_median_bytes hardware aa_ratio_min aa_ratio_max screen "
           "mapping_class").split()
# Section 4.1, rule R1: first matching message wins; (message, class, field suffix or full field).
R1 = (("process coverage", "REPETITIONS", "<root>:repetitions"),
      ("expected one Julia and one BLAS thread", "THREADS", "<root>:julia_threads"),
      ("process is not finished", "STACK", "<root>:unfinished"),
      ("interrupted process", "STACK", "<root>:unfinished"),
      ("loaded package root differs", "STACK", "<root>:loaded_tree"),
      ("series settings changed within a Julia version", "SETTINGS", "<root>:records"),
      ("catalog changed between repetitions", "OPERATION", "<pair>:catalog"),
      ("metric measure differs from catalog", "TARGET", "<pair>:target"),
      ("metric target differs from catalog", "TARGET", "<pair>:target"),
      ("metric phase differs from catalog", "PHASE", "<root>:phase"),
      ("unknown phase", "PHASE", "<root>:phase"))


class Usage(Exception):
    """A usage error or an unreadable argument file: exit status 3."""


# ----------------------------------------------------------------------------------------------- helpers

def refuse(ref, cls, field, detail):
    ref.append((CLASSES.index(cls) + 1, cls, field, str(detail).replace("\n", " ")))


def read_text(path, what):
    try:
        return Path(path).read_bytes().decode("utf-8")
    except (OSError, UnicodeDecodeError) as error:
        raise Usage(f"cannot read {what} {path}: {error}") from error


def read_toml(path, what):
    try:
        return tomllib.loads(read_text(path, what))
    except tomllib.TOMLDecodeError as error:
        raise Usage(f"{what} {path} is not valid TOML: {error}") from error


def try_toml(path):
    """Inside a root: (data, None) or (None, reason)."""
    try:
        return tomllib.loads(Path(path).read_bytes().decode("utf-8")), None
    except FileNotFoundError:
        return None, "missing"
    except (OSError, UnicodeDecodeError, tomllib.TOMLDecodeError) as error:
        return None, f"unreadable: {error}"


def is_int(value):
    return isinstance(value, int) and not isinstance(value, bool)


def is_num(value):
    return isinstance(value, (int, float)) and not isinstance(value, bool)


def is_str(value):
    return isinstance(value, str) and value != ""


def hex40(value):
    return isinstance(value, str) and bool(HEX40.fullmatch(value))


def same(left, right):
    """Equality with numbers compared as numbers and no bool/int confusion."""
    return left == right and isinstance(left, bool) == isinstance(right, bool)


def key_problems(data, required, optional=(), where="table"):
    """Messages for a table whose key set is not exactly required plus optional."""
    if not isinstance(data, dict):
        return [f"{where} is not a table"]
    out = [f"{where}: unknown key {key!r}" for key in sorted(data.keys() - set(required) - set(optional))]
    return out + [f"{where}: missing key {key!r}" for key in sorted(set(required) - data.keys())]


def num(value):
    return repr(float(value))


def jnum(value):
    return None if value is None or not math.isfinite(value) else value


def parse_time(text):
    if not isinstance(text, str) or not TIME.fullmatch(text):
        return None
    try:
        return datetime.fromisoformat(text)
    except ValueError:
        return None


def accuracy(status, value, target):
    """Section 16: (accuracy_fraction, band). The numerical outcome takes precedence."""
    usable = math.isfinite(value) and math.isfinite(target) and target > 0
    fraction = value / target if usable else math.nan
    if status != "ok" or not usable or value > target or value < 0:
        return fraction, "missed/invalid"
    return fraction, "near target" if fraction >= 0.9 else "margin"


# ------------------------------------------------------------------------------------------- the schedule

def load_schedule(path):
    """Section 16: the tool's own input; any violation is a usage error (exit 3)."""
    data = read_toml(path, "schedule")

    def need(ok, message):
        if not ok:
            raise Usage(f"schedule {path}: {message}")

    def tables(table, required, optional=(), where=""):
        problems = key_problems(table, required, optional, where or "schedule")
        need(not problems, "; ".join(problems))
        return table

    top = tables(data, ("schema", "schedule", "settings", "machine", "julia", "stack_a"))
    need(is_int(top["schema"]) and top["schema"] == 1, "schema must be 1")
    sch = tables(top["schedule"], ("id", "campaign_id", "reps", "arms", "orders"), where="[schedule]")
    need(is_str(sch["id"]) and is_str(sch["campaign_id"]), "id and campaign_id must be non-empty strings")
    reps = sch["reps"]
    need(isinstance(reps, list) and 1 <= len(reps) <= 10 and all(is_int(r) for r in reps)
         and reps == list(range(1, len(reps) + 1)), "reps must be the consecutive integers from 1, at most 10")
    need(isinstance(sch["arms"], list) and all(is_str(arm) for arm in sch["arms"]), "arms must be a string list")
    orders = sch["orders"]
    need(isinstance(orders, dict) and set(orders) == {str(r) for r in reps}
         and all(value in ("AB", "BA") for value in orders.values()),
         "orders must have exactly the keys of reps, each AB or BA")
    settings = tables(top["settings"], SETTING_KEYS + ("julia_threads", "blas_threads", "seed_scheme"),
                      where="[settings]")
    need(all(isinstance(settings[k], str) for k in ("suite", "groups", "case_filter", "seed_scheme")),
         "suite, groups, case_filter and seed_scheme must be strings")
    need(is_int(settings["samples_target"]) and is_int(settings["julia_threads"])
         and is_int(settings["blas_threads"]), "samples_target and the thread counts must be integers")
    need(all(is_num(settings[k]) for k in ("seconds_limit", "case_seconds", "profile_seconds")),
         "seconds_limit, case_seconds and profile_seconds must be numbers")
    cases = settings["case_filter"].split(",")
    need(all(cases) and len(set(cases)) == len(cases), "case_filter must list distinct non-empty case IDs")
    julia = top["julia"]
    need(isinstance(julia, dict) and julia, "[julia] needs at least one stratum")
    for mm, info in julia.items():
        need(re.fullmatch(r"[0-9]+\.[0-9]+", mm) is not None, f"stratum key {mm!r} is not MAJOR.MINOR")
        tables(info, ("version", "commit"), where=f"[julia.{mm}]")
        need(is_str(info["version"]) and info["version"].startswith(mm + ".") and is_str(info["commit"]),
             f"[julia.{mm}] version must extend {mm} and commit must be a string")
    machine = tables(top["machine"], ("cpu_model", "cpu", "logical_cpu", "smt_sibling", "governor", "epp",
                                      "no_turbo", "smt_control"), where="[machine]")
    need(is_str(machine["cpu_model"]) and is_int(machine["logical_cpu"]) and is_int(machine["smt_sibling"])
         and all(isinstance(machine[k], str) for k in ("governor", "epp", "no_turbo", "smt_control")),
         "[machine] values have the wrong type")
    need(isinstance(machine["cpu"], dict) and set(machine["cpu"]) == set(julia)
         and all(is_str(value) for value in machine["cpu"].values()), "[machine].cpu must map every stratum")
    stack = tables(top["stack_a"], ("harness_hash", "proximalsolvers", "proximalbase"), where="[stack_a]")
    need(hex40(stack["harness_hash"]), "[stack_a].harness_hash must be 40 lowercase hex")
    for table, keys in (("proximalsolvers", ("commit", "tree", "version")),
                        ("proximalbase", ("tag", "commit", "tree", "version", "release"))):
        tables(stack[table], keys, where=f"[stack_a.{table}]")
        need(all(is_str(stack[table][k]) for k in keys) and hex40(stack[table]["commit"])
             and hex40(stack[table]["tree"]), f"[stack_a.{table}] has an invalid value")
    return dict(id=sch["id"], campaign_id=sch["campaign_id"], reps=list(reps),
                orders={int(k): v for k, v in orders.items()}, settings=settings, machine=machine,
                strata=dict(julia), stack_a=stack, cases=cases)


# ------------------------------------------------------------------------------ root: files of one stratum

def parse_manifest(data):
    """Section 10: (parsed, problems). Entries are keyed by (name, uuid)."""
    problems, entries, by_name = [], {}, defaultdict(list)
    if not is_str(data.get("julia_version")):
        problems.append("julia_version missing")
    if data.get("manifest_format") not in ("2.0", "2.1"):
        problems.append("manifest_format is not 2.0 or 2.1")
    deps = data.get("deps", {})
    if not isinstance(deps, dict):
        return None, problems + ["deps is not a table"]
    for name, items in deps.items():
        for item in items if isinstance(items, list) else [None]:
            if (not isinstance(item, dict) or not is_str(item.get("uuid"))
                    or any(not isinstance(item.get(k, ""), str) for k in ("version", "git-tree-sha1", "path"))):
                problems.append(f"deps.{name} has a malformed entry")
                continue
            value = (item.get("version", ""), item.get("git-tree-sha1", ""))
            if (name, item["uuid"]) in entries:
                problems.append(f"deps.{name} {item['uuid']} appears twice")
            entries[(name, item["uuid"])] = value
            by_name[name].append(value)
    if problems:
        return None, problems
    return dict(julia_version=data["julia_version"], entries=entries, by_name=by_name), []


def parse_project(data):
    problems = []
    for table in ("deps", "compat"):
        value = data.get(table, {})
        if not isinstance(value, dict) or any(not isinstance(v, str) for v in value.values()):
            problems.append(f"{table} must be a table of strings")
    return (None, problems) if problems else (dict(deps=data.get("deps", {}), compat=data.get("compat", {})), [])


def parse_inventory(data):
    """Section 10: the keys the tool uses; other Stage 2A keys are allowed and ignored."""
    required = ("julia", "commit", "cpu_model", "cpu_name", "blas", "depot_path", "proximalbase_version",
                "proximalbase_loaded_tree", "proximalsolvers_dir", "threads")
    problems = [f"missing key {key!r}" for key in required if key not in data]
    if problems:
        return None, problems
    for key in required[:5] + required[6:9]:
        if not isinstance(data[key], str):
            problems.append(f"{key} must be a string")
    depot = data["depot_path"]
    if not (isinstance(depot, list) and depot and all(isinstance(d, str) for d in depot)):
        problems.append("depot_path must be a non-empty string array")
    if not is_int(data["threads"]):
        problems.append("threads must be an integer")
    if not isinstance(data.get("deps", {}), dict):
        problems.append("deps must be a table")
    return (None, problems) if problems else (data, [])


def typed_meta(meta):
    """The metadata values of known keys that have the type the checks read, and the keys that do not.

    Only these values are kept anywhere (no list or table is ever hashed or compared); a value of the wrong type
    is a SCHEMA refusal and is absent from every later check, which skips what it needs."""
    check = dict(s=lambda v: isinstance(v, str), b=lambda v: isinstance(v, bool), i=is_int, n=is_num)
    clean = {k: v for k, v in meta.items() if k in META_TYPES and check[META_TYPES[k]](v)}
    return clean, sorted(k for k in meta if k in META_TYPES and k not in clean)


def tables_problem(tables):
    """What the checks read of the tables of a process that validate.py may have stopped on before it got there."""
    for kind, rows in tables.items():
        if len({row["id"] for row in rows}) != len(rows):
            return f"duplicate id in the {kind} table"
    for row in tables["catalog"]:
        validate.number(row["target"])
    for row in tables["metrics"]:
        for key in validate.TIME_FIELDS + ("target", "worst_value"):
            validate.number(row[key])
    return None


def read_stratum(root, mm, info, sched, ref):
    """Read one stratum of one root; every unreadable item is a refusal, never a guess."""
    name, version, base = root["name"], info["version"], Path(root["path"]) / f"julia-{mm}"
    st = dict(mm=mm, version=version, procs={}, metas={}, cat=None, manifest=None, project=None, inv=None)
    where = f"julia {version}"
    for fname, parse, key in (("Manifest.toml", parse_manifest, "manifest"),
                              ("Project.toml", parse_project, "project"),
                              ("environment-inventory.toml", parse_inventory, "inv")):
        data, error = try_toml(base / fname)
        if error:
            parsed, problems = None, [f"{fname} {error}"]
        else:
            parsed, problems = parse(data)
            problems = [f"{fname}: {problem}" for problem in problems]
        for problem in problems:
            refuse(ref, "SCHEMA", f"{name}:files", f"{where}: {problem}")
        st[key] = parsed
    man, inv = st["manifest"], st["inv"]
    if man and man["julia_version"] != version:
        refuse(ref, "JULIA", f"{name}:julia", f"{where}: Manifest julia_version {man['julia_version']!r}, "
               f"expected {version!r}")
    if inv:
        for key, expected in (("julia", version), ("commit", info["commit"])):
            if inv[key] != expected:
                refuse(ref, "JULIA", f"{name}:julia", f"{where}: inventory {key} {inv[key]!r}, "
                       f"expected {expected!r}")
    raw = base / "raw"
    if not raw.is_dir():
        refuse(ref, "SCHEMA", f"{name}:files", f"{where}: raw/ missing")
        return st
    found = set()
    for path in sorted(raw.iterdir()):
        suffix = next((s for s in validate.SUFFIXES if path.name.endswith(s)), None)
        if not path.is_file() or suffix is None:
            refuse(ref, "SCHEMA", f"{name}:files", f"{where}: unrecognised entry raw/{path.name}")
            continue
        prefix = path.name.removesuffix(suffix)
        match = validate.PREFIX.fullmatch(prefix)
        if match and match[1] != version:
            refuse(ref, "JULIA", f"{name}:julia", f"{where}: record file {path.name} is for Julia {match[1]}")
        found.add(prefix)
    issues = validate.validate(raw, expected=len(sched["reps"]), versions=[version])["issues"]
    blocked = set()                  # processes whose records validate.py found schema-invalid
    for issue in issues:
        cls, field = next(((c, f) for text, c, f in R1 if text in issue), ("SCHEMA", "<root>:records"))
        if cls == "SCHEMA" and (match := re.match(r"(julia-.+-rep[0-9]{2}): ", issue)):
            blocked.add(match[1])
        scope = "aa" if name.startswith("aa") else "ab"
        refuse(ref, cls, field.replace("<root>", name).replace("<pair>", scope), f"{name} {where}: {issue}")
    for rep in sched["reps"]:
        prefix = f"julia-{version}-rep{rep:02d}"
        if prefix not in found:
            continue
        try:
            final = validate.metadata(raw / f"{prefix}-metadata.toml")
            start = validate.metadata(raw / f"{prefix}-metadata-start.toml")
        except (OSError, ValueError):
            continue
        final_raw = final
        final, wrong = typed_meta(final_raw)
        for key in wrong:
            refuse(ref, "SCHEMA", f"{name}:records", f"{name} {where} rep {rep}: metadata {key} has a value of "
                   "the wrong type")
        st["metas"][rep] = final
        for meta in (final_raw, start):
            if "julia" in meta and meta["julia"] != version:
                refuse(ref, "JULIA", f"{name}:julia", f"{name} {where} rep {rep}: julia {meta['julia']!r}, "
                       f"expected {version!r}")
        for label, meta, keys in (("final", final_raw, META_FINAL), ("start", start, META_START)):
            if set(meta) != set(keys):
                refuse(ref, "SCHEMA", f"{name}:metadata_keys",
                       f"{name} {where} rep {rep}: {label} metadata missing {sorted(set(keys) - set(meta))} "
                       f"unknown {sorted(set(meta) - set(keys))}")
        if prefix in blocked:
            continue
        try:
            tables = {kind: validate.records(raw / f"{prefix}-{kind}.tsv", kind)
                      for kind in ("catalog", "metrics", "errors")}
            problem = tables_problem(tables)
            if problem:
                raise ValueError(problem)
        except (OSError, ValueError, KeyError) as error:
            refuse(ref, "SCHEMA", f"{name}:records", f"{name} {where} rep {rep}: {error}")
            continue
        st["procs"][rep] = dict(meta=final, **{kind: {r["id"]: r for r in rows} for kind, rows in tables.items()})
    if st["procs"]:
        st["cat"] = st["procs"][min(st["procs"])]["catalog"]
    return st


def read_identity(root, ref):
    """Section 11: the identity file. Returns the parsed tables or None (refused)."""
    name = root["name"]
    data, error = try_toml(Path(root["path"]) / "stack-identity.toml")
    if error == "missing":
        refuse(ref, "IDENTITY", f"{name}:identity", "stack-identity.toml missing")
        return None
    if error:
        refuse(ref, "SCHEMA", f"{name}:files", f"stack-identity.toml {error}")
        return None
    schema, ident, tag = [], [], []
    found = key_problems(data, ("schema", "installation", "campaign_id", "session_id", "proximalsolvers",
                                "proximalbase"))
    schema += [p for p in found if "unknown" in p]
    ident += [p for p in found if "missing" in p]
    if "schema" in data and not (is_int(data["schema"]) and data["schema"] == 1):
        schema.append("schema is not 1")
    if "installation" in data and not (isinstance(data["installation"], str)
                                       and re.fullmatch(r"[A-Za-z0-9._-]+", data["installation"])):
        schema.append("installation must be a non-empty string of letters, digits, '.', '_' and '-'")
    for key in ("campaign_id", "session_id"):
        if key in data and not is_str(data[key]):
            schema.append(f"{key} must be a non-empty string")
    for table, keys, optional in (("proximalsolvers", ("commit", "tree", "version"), ()),
                                  ("proximalbase", ("commit", "tree", "version", "release"), ("tag",))):
        value = data.get(table)
        if value is None:
            continue
        found = key_problems(value, keys, optional, table)
        schema += [p for p in found if "unknown" in p or "not a table" in p]
        ident += [p for p in found if "missing" in p]
        if not isinstance(value, dict):
            continue
        for key in ("commit", "tree"):
            if key in value and not isinstance(value[key], str):
                schema.append(f"{table}.{key} must be a string")
            elif key in value and not hex40(value[key]):
                ident.append(f"{table}.{key} {value[key]!r} is not 40 lowercase hex")
        for key in ("version", "release", "tag"):
            if key in value and not is_str(value[key]):
                schema.append(f"{table}.{key} must be a non-empty string")
        if is_str(value.get("release")) and value["release"] not in ("registered", "development"):
            ident.append(f"{table}.release {value['release']!r} is neither registered nor development")
    base = data.get("proximalbase")
    if isinstance(base, dict) and not schema:
        if base.get("release") == "registered" and "tag" not in base:
            tag.append("release registered without a tag")
        if "tag" in base and not hex40(base.get("commit")):
            tag.append(f"tag {base['tag']!r} has no 40-hex commit")
    for cls, field, items in (("SCHEMA", "files", schema), ("IDENTITY", "identity", ident),
                              ("IDENTITY", "tag", tag)):
        for item in items:
            refuse(ref, cls, f"{name}:{field}", f"stack-identity.toml: {item}" if cls == "SCHEMA" else item)
    return None if schema or ident or tag else data


# ------------------------------------------------------------------------- root: record-level checks (sec 3)

def norm(path):
    """An archived path in normal form: no trailing slash, '.' or '..' segments (compared as text)."""
    return posixpath.normpath(path) if path else path


def procs(st):
    return sorted(st["procs"].items())


def trusted(root):
    """The identity of a root, or None when the root already has an identity refusal."""
    return root["ident"] if root["stack_ok"] else None


def check_records(root, st, sched, ref):
    """Section 3 table: the metadata keys against the schedule."""
    name, ver = root["name"], st["version"]
    settings, machine = sched["settings"], sched["machine"]
    for rep, proc in procs(st):
        meta, where = proc["meta"], f"{name} julia {ver} rep {rep}"

        def diff(cls, field, key, expected):
            if key in meta and not same(meta[key], expected):
                refuse(ref, cls, field, f"{where}: {key} {meta[key]!r}, expected {expected!r}")
        for key in SETTING_KEYS:
            diff("SETTINGS", f"{name}:{key}", key, settings[key])
        diff("INPUTS", f"{name}:seed_scheme", "seed_scheme", settings["seed_scheme"])
        for key in ("julia_threads", "blas_threads"):
            diff("THREADS", f"{name}:{key}", key, 1)
            diff("THREADS", f"{name}:{key}", key, settings[key])
        diff("MACHINE", f"{name}:cpu_model", "cpu_model", machine["cpu_model"])
        diff("MACHINE", f"{name}:cpu", "cpu", machine["cpu"][st["mm"]])
        if meta.get("proximalsolvers_dirty") is True:
            refuse(ref, "STACK", f"{name}:dirty", f"{where}: proximalsolvers_dirty is true")
        if meta.get("expected_package_root") == "":
            refuse(ref, "STACK", f"{name}:loaded_tree", f"{where}: expected_package_root is empty")
    for key, field, expected in (("cpu_model", "cpu_model", machine["cpu_model"]),
                                 ("cpu_name", "cpu", machine["cpu"][st["mm"]])):
        if st["inv"] and st["inv"][key] != expected:
            refuse(ref, "MACHINE", f"{name}:{field}", f"{name} julia {ver}: inventory {key} "
                   f"{st['inv'][key]!r}, expected {expected!r}")


def check_stack(root, st, ref):
    """Sections 3 and 11: loaded tree, versions and Manifest entries against stack-identity.toml."""
    name, ver, ident, inv, man = root["name"], st["version"], trusted(root), st["inv"], st["manifest"]
    where = f"{name} julia {ver}"

    def stack(field, detail):
        refuse(ref, "STACK", f"{name}:{field}", f"{where}: {detail}")
    if ident and inv:
        base = ident["proximalbase"]
        if inv["proximalbase_loaded_tree"] != base["tree"]:
            stack("loaded_tree", f"inventory proximalbase_loaded_tree {inv['proximalbase_loaded_tree']!r}, "
                  f"identity tree {base['tree']!r}")
        if inv["proximalbase_version"] != base["version"]:
            stack("loaded_tree", f"inventory proximalbase_version {inv['proximalbase_version']!r}, "
                  f"identity version {base['version']!r}")
    if ident and man:
        for package, key, with_tree in (("ProximalBase", "proximalbase", True),
                                        ("ProximalSolvers", "proximalsolvers", False)):
            found = man["by_name"].get(package, [])
            want = ident[key]
            if len(found) != 1:
                stack("loaded_tree", f"Manifest has {len(found)} entries for {package}, expected one")
            elif found[0][0] != want["version"] or (with_tree and found[0][1] != want["tree"]):
                stack("loaded_tree", f"Manifest {package} {found[0]} differs from identity "
                      f"({want['version']!r}, {want['tree']!r})")
    for rep, proc in procs(st):
        meta, at = proc["meta"], f"{where} rep {rep}"
        if ident and meta.get("proximalsolvers_sha", ident["proximalsolvers"]["commit"]) \
                != ident["proximalsolvers"]["commit"]:
            stack("loaded_tree", f"{at}: proximalsolvers_sha {meta['proximalsolvers_sha']!r}, identity "
                  f"{ident['proximalsolvers']['commit']!r}")
        if ident and meta.get("proximalbase_version", ident["proximalbase"]["version"]) \
                != ident["proximalbase"]["version"]:
            stack("loaded_tree", f"{at}: proximalbase_version {meta['proximalbase_version']!r}, identity "
                  f"{ident['proximalbase']['version']!r}")
        if inv and "proximalsolvers_path" in meta and norm(meta["proximalsolvers_path"]) != norm(
                inv["proximalsolvers_dir"]):
            stack("loaded_tree", f"{at}: proximalsolvers_path {meta['proximalsolvers_path']!r} differs from "
                  f"inventory proximalsolvers_dir {inv['proximalsolvers_dir']!r}")


def meta_values(root, key, usable=True):
    """The values of a metadata key over the processes of a root (all readable ones with usable=False)."""
    return {meta[key] for st in root["strata"].values()
            for meta in ([p["meta"] for p in st["procs"].values()] if usable else st["metas"].values())
            if key in meta}


def check_mixed(root, ref):
    for key in MIXED_KEYS:
        values = meta_values(root, key, usable=False)
        if len(values) > 1:
            refuse(ref, "STACK", f"{root['name']}:mixed", f"{key} differs between repetitions or strata: "
                   f"{sorted(map(str, values))}")


def check_stack_a(root, sched, ref):
    """Section 11 and the IDENTITY row: a Stack A root carries the [stack_a] identity and harness hash."""
    name, ident, want = root["name"], root["ident"], sched["stack_a"]
    for value in sorted(meta_values(root, "harness_hash")):
        if value != want["harness_hash"]:
            refuse(ref, "IDENTITY", f"{name}:stack_a", f"harness_hash {value!r}, [stack_a] has "
                   f"{want['harness_hash']!r}")
    if ident is None:
        return
    for table in ("proximalsolvers", "proximalbase"):
        for key, expected in want[table].items():
            if ident[table].get(key) != expected:
                refuse(ref, "IDENTITY", f"{name}:stack_a", f"{table}.{key} {ident[table].get(key)!r}, "
                       f"[stack_a] has {expected!r}")
    base = ident["proximalbase"]
    if base.get("tag") == want["proximalbase"]["tag"] and (
            base["commit"], base["tree"]) != (want["proximalbase"]["commit"], want["proximalbase"]["tree"]):
        refuse(ref, "IDENTITY", f"{name}:tag", f"tag {base['tag']!r} is accepted only as commit "
               f"{want['proximalbase']['commit']} with tree {want['proximalbase']['tree']}")


def read_root(name, path, sched, ref, stack_a):
    root = dict(name=name, path=Path(path), strata={}, ident=None, stack_ok=True)
    try:
        present = sorted(p.name for p in root["path"].iterdir() if p.is_dir() and p.name.startswith("julia-"))
    except OSError:
        present = []
    for entry in present:
        if entry.removeprefix("julia-") not in sched["strata"]:
            refuse(ref, "JULIA", f"{name}:stratum", f"directory {entry} is not a stratum of the schedule")
    for mm, info in sched["strata"].items():
        if f"julia-{mm}" not in present:
            refuse(ref, "JULIA", f"{name}:stratum", f"stratum julia-{mm} is missing")
        else:
            root["strata"][mm] = read_stratum(root, mm, info, sched, ref)
    root["ident"] = read_identity(root, ref)
    for st in root["strata"].values():
        check_records(root, st, sched, ref)
    check_mixed(root, ref)
    if stack_a:
        n = len(ref)
        check_stack_a(root, sched, ref)
        root["stack_ok"] = len(ref) == n         # a refused identity is not used by the checks below
    for st in root["strata"].values():
        check_stack(root, st, ref)
    return root


# ------------------------------------------------------------------------------ pair checks (a/b and aa)

def check_pair(scope, left, right, sched, ref):
    """Sections 4 rows 2, 3, 5, 6 and 7 between two roots; only record fields other than timings."""
    names = f"{left['name']} against {right['name']}"
    for mm, info in sched["strata"].items():
        sl, sr = left["strata"].get(mm), right["strata"].get(mm)
        if not sl or not sr:
            continue
        ver = info["version"]
        if sl["procs"] and sr["procs"]:
            blas_l = {p["meta"]["blas"] for _, p in procs(sl) if "blas" in p["meta"]}
            blas_r = {p["meta"]["blas"] for _, p in procs(sr) if "blas" in p["meta"]}
            if blas_l != blas_r:
                refuse(ref, "THREADS", f"{scope}:blas", f"julia {ver}: {names}: blas {sorted(blas_l)} against "
                       f"{sorted(blas_r)}")
        cl, cr = sl["cat"], sr["cat"]
        for cid in sorted(set(cl or {}) & set(cr or {})):
            at = f"julia {ver} case {cid}"
            for key, field, cls in (("measure", "measure", "TARGET"), ("phase", "phase", "PHASE")):
                if cl[cid][key] != cr[cid][key]:
                    refuse(ref, cls, f"{scope}:{field}", f"{at}: {names}: {key} {cl[cid][key]!r} against "
                           f"{cr[cid][key]!r}")
            if not validate.same_number(validate.number(cl[cid]["target"]), validate.number(cr[cid]["target"])):
                refuse(ref, "TARGET", f"{scope}:target", f"{at}: {names}: target {cl[cid]['target']!r} against "
                       f"{cr[cid]['target']!r}")
            for key in CATALOG_COLUMNS:
                if cl[cid][key] != cr[cid][key]:
                    refuse(ref, "OPERATION", f"{scope}:catalog", f"{at}: {names}: catalog column {key} "
                           f"{cl[cid][key]!r} against {cr[cid][key]!r}")
        for rep in sched["reps"]:
            pl, pr = sl["procs"].get(rep), sr["procs"].get(rep)
            if not pl or not pr:
                continue
            for cid in sorted(set(pl["metrics"]) & set(pr["metrics"])):
                a, b, at = pl["metrics"][cid], pr["metrics"][cid], f"julia {ver} case {cid} rep {rep}"
                if a["data_hash"] and b["data_hash"] and a["data_hash"] != b["data_hash"]:
                    refuse(ref, "INPUTS", f"{scope}:data_hash", f"{at}: {names}: {a['data_hash']} differs from "
                           f"{b['data_hash']}")
                if a["phase"] != b["phase"]:
                    refuse(ref, "PHASE", f"{scope}:phase", f"{at}: {names}: metrics phase {a['phase']!r} against "
                           f"{b['phase']!r}")


def check_cases(root, sched, ref):
    """Section 4 row 4: declared and catalog case sets, per root and stratum."""
    declared = set(sched["cases"])
    for mm, st in root["strata"].items():
        if st["cat"] is None:
            continue
        ver = st["version"]
        for cid in sched["cases"]:
            if cid not in st["cat"]:
                refuse(ref, "CASE", f"{root['name']}:case", f"julia {ver} case {cid}: declared but absent from "
                       f"the catalog")
        for cid in sorted(set(st["cat"]) - declared):
            refuse(ref, "CASE", f"{root['name']}:case", f"julia {ver} case {cid}: in the catalog but not declared")


# ----------------------------------------------------------------------------------------- the mapping file

def read_mapping(data, ref):
    """Section 4.1, rule R10: the rows of the mapping, or None after a SCHEMA refusal."""
    problems = []
    if not (is_int(data.get("schema")) and data["schema"] == 1):
        problems.append("schema is not 1")
    rows = data.get("case")
    if not isinstance(rows, list) or not all(isinstance(r, dict) for r in rows):
        problems.append("case must be an array of tables")
        rows = []
    for index, row in enumerate(rows, 1):
        for key in ("id", "role", "phase", "measure", "class"):
            if not isinstance(row.get(key), str):
                problems.append(f"case {index}: {key} missing or not a string")
        if not is_num(row.get("target")) and not isinstance(row.get("target"), str):
            problems.append(f"case {index}: target missing or of the wrong type")
        elif isinstance(row.get("target"), str):
            try:
                float(row["target"])
            except ValueError:
                problems.append(f"case {index}: target {row['target']!r} is not a number")
        if not isinstance(row.get("approved"), bool):
            problems.append(f"case {index}: approved missing or not a boolean")
        for key in ("approval_url", "approval_scope", "separate_mapping", "deviation"):
            if key in row and not isinstance(row[key], str):
                problems.append(f"case {index}: {key} must be a string")
    for problem in problems:
        refuse(ref, "SCHEMA", "mapping:schema", problem)
    return None if problems else rows


def check_mapping(rows, a_root, sched, ref):
    """Section 4.1 rule R10 and the MAPPING row."""
    declared, ids = sched["cases"], [row["id"] for row in rows]
    count = Counter(ids)
    for kind, items in (("missing", [c for c in declared if c not in count]),
                        ("not declared", [c for c in count if c not in declared]),
                        ("listed more than once", [c for c, n in count.items() if n > 1])):
        for cid in items:
            refuse(ref, "MAPPING", "mapping:case", f"case {cid}: {kind}")
    if sorted(ids) == sorted(declared) and ids != declared:
        refuse(ref, "MAPPING", "mapping:case", "cases are not in the declared order")
    for row in rows:
        cid = row["id"]
        index = declared.index(cid) if cid in declared else None
        if index is not None:
            role = "primary" if index < PRIMARY_CASES else "diagnostic"
            if row["role"] != role:
                refuse(ref, "MAPPING", "mapping:role", f"case {cid}: role {row['role']!r}, expected {role!r}")
        if row["phase"] not in PHASES:
            refuse(ref, "MAPPING", "mapping:phase", f"case {cid}: phase {row['phase']!r} is not a phase")
        for mm, st in a_root["strata"].items():
            entry = (st["cat"] or {}).get(cid)
            if entry is None:
                continue
            at = f"julia {st['version']} case {cid}"
            if row["phase"] != entry["phase"]:
                refuse(ref, "MAPPING", "mapping:phase", f"{at}: mapping phase {row['phase']!r}, catalog "
                       f"{entry['phase']!r}")
            if row["measure"].split(",")[0].strip() != entry["measure"]:
                refuse(ref, "TARGET", "mapping:measure", f"{at}: mapping {row['measure']!r}, catalog "
                       f"{entry['measure']!r}")
            if not validate.same_number(float(row["target"]), validate.number(entry["target"])):
                refuse(ref, "TARGET", "mapping:target", f"{at}: mapping {row['target']!r}, catalog "
                       f"{entry['target']!r}")
        approved = row["approved"] and is_str(row.get("approval_url"))
        if row["class"] not in ("A", "B", "C", "D"):
            refuse(ref, "MAPPING", "mapping:class", f"case {cid}: class {row['class']!r} is not A or B")
        elif row["class"] == "B" and not approved:
            refuse(ref, "MAPPING", "mapping:approval", f"case {cid}: class B needs approved = true and an "
                   "approval_url")
        elif row["class"] in ("C", "D") and not (approved and is_str(row.get("separate_mapping"))):
            refuse(ref, "MAPPING", "mapping:class", f"case {cid}: class {row['class']} needs a separate "
                   "approved mapping (approved, approval_url and separate_mapping)")
        if "deviation" in row and not approved:
            refuse(ref, "MAPPING", "mapping:approval", f"case {cid}: a deviation needs approved = true and an "
                   "approval_url")


# ------------------------------------------------------------------------- declared-differences file

DECLARED_HASHES = ("a_commit", "b_commit", "a_tree", "b_tree", "a_package_hash", "b_package_hash")


def read_declared(data, sched, ref):
    """Section 13: schema of the declared-differences file; returns the normalised content or None."""
    problems, strata = [], list(sched["strata"])
    if not isinstance(data, dict) or not is_int(data.get("schema")) or data.get("schema") != 1:
        problems.append("schema is not 1")
    problems += key_problems(data, ("schema",), ("proximalsolvers", "proximalbase", "manifest", "compat",
                                                 "harness"), "declared file")
    for table, extra in (("proximalsolvers", ()), ("proximalbase", ("a_version", "b_version"))):
        value = data.get(table)
        if value is None:
            continue
        found = key_problems(value, DECLARED_HASHES + extra, (), table)
        problems += found
        if not found:
            problems += [f"{table}.{k} must be 40 lowercase hex" for k in DECLARED_HASHES if not hex40(value[k])]
            problems += [f"{table}.{k} must be a non-empty string" for k in extra if not is_str(value[k])]
    seen = {"manifest": set(), "compat": set()}
    entries = {"manifest": [], "compat": []}
    specs = {"manifest": (("name", "uuid", "kind", "a_version", "b_version", "a_tree", "b_tree", "reason"),
                          ("name", "uuid", "kind", "a_version", "b_version", "a_tree", "b_tree")),
             "compat": (("name", "a", "b", "reason"), ("name", "a", "b"))}
    for table, (keys, tuple_keys) in specs.items():
        items = data.get(table, [])
        if not isinstance(items, list):
            problems.append(f"{table} must be an array of tables")
            continue
        for index, item in enumerate(items, 1):
            found = key_problems(item, keys, ("julia",), f"{table} {index}")
            problems += found
            if found:
                continue
            if any(not isinstance(item[k], str) for k in keys) or not item["reason"] or not item["name"]:
                problems.append(f"{table} {index}: values must be strings and name and reason non-empty")
                continue
            if table == "manifest" and (item["kind"] not in ("changed", "added", "removed")
                                        or any(item[k] and not hex40(item[k]) for k in ("a_tree", "b_tree"))):
                problems.append(f"manifest {index}: invalid kind or tree")
                continue
            julia = item.get("julia", strata)
            if not (isinstance(julia, list) and julia and all(j in strata for j in julia)):
                problems.append(f"{table} {index}: julia must list strata of the schedule")
                continue
            for mm in julia:
                key = (mm,) + ((item["name"], item["uuid"]) if table == "manifest" else (item["name"],))
                if key in seen[table]:
                    problems.append(f"{table} {index}: entry {key[1:]} declared twice for julia {mm}")
                seen[table].add(key)
                entries[table].append((mm, tuple(item[k] for k in tuple_keys)))
    harness = data.get("harness")
    if harness is not None:
        found = key_problems(harness, ("a_hash", "b_hash", "port_commit", "cases", "changed_lines",
                                       "approval_url"), (), "harness")
        problems += found
        if not found:
            problems += [f"harness.{k} must be 40 lowercase hex" for k in ("a_hash", "b_hash", "port_commit")
                         if not hex40(harness[k])]
            if not (isinstance(harness["cases"], list) and all(isinstance(c, str) for c in harness["cases"])
                    and isinstance(harness["changed_lines"], list)
                    and all(isinstance(c, str) for c in harness["changed_lines"])
                    and isinstance(harness["approval_url"], str)):
                problems.append("harness: cases and changed_lines must be string arrays, approval_url a string")
    for problem in problems:
        refuse(ref, "SCHEMA", "declared:schema", problem)
    if problems:
        return None
    return dict(proximalsolvers=data.get("proximalsolvers"), proximalbase=data.get("proximalbase"),
                manifest=entries["manifest"], compat=entries["compat"], harness=harness)


def manifest_diff(left, right):
    """Section 13: observed Manifest differences as (name, uuid, kind, a_version, b_version, a_tree, b_tree)."""
    out = set()
    for key in left.keys() | right.keys():
        a, b = left.get(key), right.get(key)
        if a != b:
            kind = "added" if a is None else "removed" if b is None else "changed"
            a, b = a or ("", ""), b or ("", "")
            out.add((key[0], key[1], kind, a[0], b[0], a[1], b[1]))
    return out


def compare_sets(ref, field, label, observed, declared):
    for item in sorted(observed - declared):
        refuse(ref, "UNDECLARED", field, f"{label}: observed difference not declared: {item}")
    for item in sorted(declared - observed):
        refuse(ref, "UNDECLARED", field, f"{label}: declared difference does not exist: {item}")


def check_declared(declared, left, right, mapping, sched, ref):
    """Section 13: the observed differences of section 3 must equal the declared set exactly."""
    for table, extra in (("proximalsolvers", ()), ("proximalbase", ("version",))):
        want, observed = declared[table], {}
        for side, root in (("a", left), ("b", right)):
            ident = trusted(root)
            sources = {"commit": [("identity commit", ident[table]["commit"] if ident else None)],
                       "tree": [("identity tree", ident[table]["tree"] if ident else None)],
                       "package_hash": [("metadata hash", meta_values(root, f"{table}_hash"))],
                       "version": [("identity version", ident[table]["version"] if ident else None),
                                   ("metadata version", meta_values(root, "proximalbase_version"))]}
            if table == "proximalsolvers":
                sources["commit"].append(("metadata sha", meta_values(root, "proximalsolvers_sha")))
            observed[side] = {k: [(label, [] if v is None else sorted(v) if isinstance(v, set) else [v])
                                  for label, v in items] for k, items in sources.items()}
        fields = ("commit", "tree", "package_hash") + extra
        pairs = [(x, y) for f in fields for (_, xs), (_, ys) in zip(observed["a"][f], observed["b"][f])
                 for x in xs for y in ys]
        if pairs and any(x != y for x, y in pairs) and want is None:
            refuse(ref, "UNDECLARED", f"declared:{table}", "the observed values differ between the roots and "
                   f"[{table}] is not declared")
        if want is None:
            continue
        if pairs and all(x == y for x, y in pairs):
            refuse(ref, "UNDECLARED", f"declared:{table}", f"[{table}] is declared but the observed values are "
                   "equal in both roots")
        for field in fields:
            for side in ("a", "b"):
                for label, values in observed[side][field]:
                    for value in values:
                        if value != want[f"{side}_{field}"]:
                            refuse(ref, "UNDECLARED", f"declared:{table}", f"{side}_{field} declared "
                                   f"{want[f'{side}_{field}']!r}, {side.upper()} {label} is {value!r}")
            if want[f"a_{field}"] == want[f"b_{field}"]:
                refuse(ref, "UNDECLARED", f"declared:{table}", f"{field}: declared difference does not exist "
                       f"({want[f'a_{field}']!r} on both sides)")
    for mm, info in sched["strata"].items():
        sl, sr = left["strata"].get(mm), right["strata"].get(mm)
        if not sl or not sr:
            continue
        label = f"julia {info['version']}"
        if sl["manifest"] and sr["manifest"]:
            diff = manifest_diff(sl["manifest"]["entries"], sr["manifest"]["entries"])
            compare_sets(ref, "declared:manifest", label, diff, {t for m, t in declared["manifest"] if m == mm})
        if sl["project"] and sr["project"]:
            exempt = {t[0] for m, t in declared["manifest"] if m == mm and t[2] in ("added", "removed")}
            dl, dr = sl["project"]["deps"], sr["project"]["deps"]
            for name in sorted(n for n in dl.keys() | dr.keys() if dl.get(n) != dr.get(n) and n not in exempt):
                refuse(ref, "UNDECLARED", "declared:compat", f"{label}: Project.toml [deps] entry {name} differs "
                       f"({dl.get(name, '')!r} against {dr.get(name, '')!r}) and is not declared added or removed")
            cl, cr = sl["project"]["compat"], sr["project"]["compat"]
            observed = {(n, cl.get(n, ""), cr.get(n, "")) for n in cl.keys() | cr.keys() if cl.get(n) != cr.get(n)}
            compare_sets(ref, "declared:compat", label, observed, {t for m, t in declared["compat"] if m == mm})
    check_harness(declared["harness"], left, right, mapping, ref)


def check_harness(harness, left, right, mapping, ref):
    observed = {}
    for side, root in (("a", left), ("b", right)):
        values = meta_values(root, "harness_hash")
        observed[side] = next(iter(values)) if len(values) == 1 else None
    if None in observed.values():
        return                                                          # mixed or unreadable: STACK
    differs = observed["a"] != observed["b"]
    cases = {r["id"]: r for r in mapping or []}
    if not differs:
        if harness is not None:
            refuse(ref, "UNDECLARED", "declared:harness", "[harness] is present but the harness hashes are equal")
        return
    approved = sorted(c for c, r in cases.items() if r["class"] == "B" and r["approved"]
                      and is_str(r.get("approval_url")))
    if harness is None:
        refuse(ref, "UNDECLARED", "ab:harness_hash", f"harness_hash differs ({observed['a']} against "
               f"{observed['b']}) and no [harness] is declared")
        return
    if not approved:
        refuse(ref, "UNDECLARED", "ab:harness_hash", "harness_hash differs and the mapping has no approved "
               "class B case")
    for side in ("a", "b"):
        if harness[f"{side}_hash"] != observed[side]:
            refuse(ref, "UNDECLARED", "declared:harness", f"{side}_hash declared {harness[f'{side}_hash']!r}, "
                   f"observed {observed[side]!r}")
    class_b = sorted(c for c, r in cases.items() if r["class"] == "B")
    if sorted(harness["cases"]) != class_b:
        refuse(ref, "UNDECLARED", "declared:harness", f"cases {sorted(harness['cases'])} differ from the class B "
               f"cases of the mapping {class_b}")
    for cid in harness["cases"]:
        row = cases.get(cid)
        if not (row and row["class"] == "B" and row["approved"]
                and row.get("approval_url") and row["approval_url"] == harness["approval_url"]):
            refuse(ref, "UNDECLARED", "declared:harness", f"case {cid} is not an approved class B case with the "
                   "approval_url of [harness]")
    if not harness["changed_lines"]:
        refuse(ref, "UNDECLARED", "declared:harness", "changed_lines is empty")


# ---------------------------------------------------------------------------------------- fingerprint files

def read_fingerprints(path, who, sched, phases, ref):
    """Section 14: ('missing' | 'bad' | 'ok', {(julia, id, rep): {(kind, name): value}}).

    `phases` maps (julia, id) to the catalog phase of root A; `none` is allowed for reset/active_ids always and for
    reset/values only in a setup case (a case whose phase is unknown is not judged)."""
    if not Path(path).exists():
        return "missing", {}
    text = read_text(path, "fingerprint file")
    lines = text.split("\n")
    if lines and lines[-1] == "":
        lines.pop()
    field, problems, data = f"fingerprints_{who.lower()}:schema", [], defaultdict(dict)
    if not lines or lines[0] != FP_HEADER:
        refuse(ref, "SCHEMA", field, "header is not exactly julia, id, rep, kind, name, value")
        return "bad", {}
    versions = {info["version"] for info in sched["strata"].values()}
    for number, line in enumerate(lines[1:], 2):
        cells = line.split("\t")
        if len(cells) != 6:
            problems.append(f"line {number}: {len(cells)} fields")
            continue
        julia, cid, rep, kind, name, value = cells
        if (julia not in versions or cid not in sched["cases"] or not re.fullmatch(r"[0-9]+", rep)
                or int(rep) not in sched["reps"]):
            problems.append(f"line {number}: undeclared Julia version, case or repetition")
            continue
        allowed = (kind, name) in FP_ALLOWED or (kind == "fixture" and name != "")
        none_ok = kind == "reset" and (name == "active_ids" or phases.get((julia, cid), "setup") == "setup")
        if not allowed or not (HEX64.fullmatch(value) or (value == "none" and none_ok)):
            problems.append(f"line {number}: invalid kind, name or value")
            continue
        key, triple = (kind, name), (julia, cid, int(rep))
        if key in data[triple]:
            problems.append(f"line {number}: duplicate row")
            continue
        data[triple][key] = value
    for problem in problems[:20]:
        refuse(ref, "SCHEMA", field, problem)
    if len(problems) > 20:
        refuse(ref, "SCHEMA", field, f"{len(problems) - 20} further invalid rows")
    return ("bad", {}) if problems else ("ok", data)


def check_fingerprints(fps, sched, ref):
    """Section 6: the global refusals; fixture rows are INPUTS, the certificate file is OPERATION."""
    (state_a, fa), (state_b, fb) = fps["A"], fps["B"]
    if state_a != "ok" or state_b != "ok":
        return
    for info in sched["strata"].values():
        for cid in sched["cases"]:
            for rep in sched["reps"]:
                triple = (info["version"], cid, rep)
                ra, rb, at = fa.get(triple, {}), fb.get(triple, {}), f"julia {info['version']} case {cid} rep {rep}"
                fixa = {k: v for k, v in ra.items() if k[0] == "fixture"}
                fixb = {k: v for k, v in rb.items() if k[0] == "fixture"}
                if fixa and fixb and fixa != fixb:
                    names = sorted(k[1] for k in fixa.keys() ^ fixb.keys()) + \
                        sorted(k[1] for k in fixa.keys() & fixb.keys() if fixa[k] != fixb[k])
                    refuse(ref, "INPUTS", "ab:fixture", f"{at}: fixture rows differ: {names}")
                key = ("file", "certificates.jl")
                if key in ra and key in rb and ra[key] != rb[key]:
                    refuse(ref, "OPERATION", "ab:certificates", f"{at}: certificates.jl {ra[key]} against "
                           f"{rb[key]}")


# ------------------------------------------------------------------------------------------- the receipt

def campaign_problem(event):
    problems = key_problems(event, ("event", "campaign_id", "session_id", "schedule_id", "utc"))
    if not problems and not (all(is_str(event[k]) for k in ("campaign_id", "session_id", "schedule_id"))
                             and parse_time(event["utc"])):
        problems.append("invalid value")
    return problems


def process_problem(event, versions):
    """Section 12: the schema of a process event; on success the parsed times are added to the event."""
    problems = key_problems(event, ("event", "arm", "role", "julia", "rep", "block", "installation", "start_utc",
                                    "end_utc", "exit", "complete", "machine"))
    if not problems:
        problems = key_problems(event["machine"], ("cpu_model", "cpu", "logical_cpu", "governor", "epp",
                                                   "no_turbo", "smt_control"), (), "machine")
    if problems:
        return problems
    machine = event["machine"]
    start, end = parse_time(event["start_utc"]), parse_time(event["end_utc"])
    valid = (event["arm"] in ("AB", "AA") and event["role"] in ("A", "B")
             and isinstance(event["julia"], str) and event["julia"] in versions
             and is_int(event["rep"]) and is_int(event["block"]) and event["block"] == event["rep"]
             and is_str(event["installation"]) and start is not None and end is not None
             and start.utcoffset() is not None and end.utcoffset() is not None and end > start
             and is_int(event["exit"]) and isinstance(event["complete"], bool)
             and is_int(machine["logical_cpu"])
             and all(isinstance(machine[k], str) for k in ("cpu_model", "cpu", "governor", "epp", "no_turbo",
                                                           "smt_control")))
    event.update(start=start, end=end)
    return [] if valid else ["invalid value"]


def read_receipt(text, sched, ref):
    """Section 12: parse the JSON lines; every unusable line is a SCHEMA refusal and only it is set aside.

    Returns the usable campaign and process events, the (arm, role, julia, rep) keys of process events that are
    identifiable but unusable, and how many lines may have been a process event that cannot be identified."""
    lines = text.split("\n")
    if lines and lines[-1] == "":
        lines.pop()
    versions = {info["version"] for info in sched["strata"].values()}
    campaigns, processes, schema, unusable, unidentified = [], [], [], set(), 0
    for number, line in enumerate(lines, 1):
        try:
            event = json.loads(line)
        except ValueError:
            schema.append(f"line {number}: not valid JSON")
            unidentified += 1
            continue
        kind = event.get("event") if isinstance(event, dict) else None
        if not isinstance(event, dict):
            schema.append(f"line {number}: not a JSON object")
            unidentified += 1
        elif kind not in ("campaign", "process"):
            schema.append(f"line {number}: unknown event {kind!r}")
            unidentified += not isinstance(kind, str)
        else:
            problems = campaign_problem(event) if kind == "campaign" else process_problem(event, versions)
            if problems:
                schema.append(f"line {number}: {problems[0]}")
            else:
                (campaigns if kind == "campaign" else processes).append(event)
            if problems and kind == "process":
                key = tuple(event.get(k) for k in ("arm", "role", "julia", "rep"))
                if (key[0] in ("AB", "AA") and key[1] in ("A", "B") and isinstance(key[2], str)
                        and key[2] in versions and is_int(key[3])):
                    unusable.add(key)
                else:
                    unidentified += 1
    distinct = {(c["campaign_id"], c["session_id"], c["schedule_id"]) for c in campaigns}
    if not campaigns:
        schema.append("no campaign event")
    elif len(campaigns) > 1 and len(distinct) == 1:
        schema.append("the campaign event occurs more than once")
    for problem in schema:
        refuse(ref, "SCHEMA", "receipt:schema", problem)
    return dict(campaigns=campaigns, procs=processes, unusable=unusable, unidentified=unidentified)


def check_receipt(receipt, roots, sched, with_aa, ref):
    """Section 12: campaign identity, machine, repetitions, block order, installations, process status."""
    machine, reps, procs_ = sched["machine"], sched["reps"], receipt["procs"]
    mm_of = {info["version"]: mm for mm, info in sched["strata"].items()}
    campaigns = receipt["campaigns"]
    distinct = {(c["campaign_id"], c["session_id"], c["schedule_id"]) for c in campaigns}
    if len(distinct) > 1:
        refuse(ref, "ORDER", "receipt:campaign", f"campaign events differ: {sorted(distinct)}")
    for c in campaigns[:1]:
        if c["campaign_id"] != sched["campaign_id"] or c["schedule_id"] != sched["id"]:
            refuse(ref, "ORDER", "receipt:campaign", f"campaign {c['campaign_id']!r} schedule "
                   f"{c['schedule_id']!r}, schedule.toml has {sched['campaign_id']!r} {sched['id']!r}")
    expected = campaigns[0] if campaigns else (roots["a"]["ident"] or {})
    for root in roots.values():
        ident = root["ident"]
        for key, field in (("campaign_id", "campaign"), ("session_id", "session")):
            if ident and key in expected and ident[key] != expected[key] and (campaigns or root["name"] != "a"):
                refuse(ref, "ORDER", f"{root['name']}:{field}", f"{key} {ident[key]!r} of the root differs from "
                       f"{'the receipt' if campaigns else 'root a'}: {expected[key]!r}")
    for key in ("cpu_model", "logical_cpu", "governor", "epp", "no_turbo", "smt_control"):
        values = {p["machine"][key] for p in procs_}
        if len(values) > 1:
            refuse(ref, "MACHINE", "receipt:machine", f"processes disagree on {key}: {sorted(map(str, values))}")
    for ver in sorted({p["julia"] for p in procs_}):
        values = {p["machine"]["cpu"] for p in procs_ if p["julia"] == ver}
        if len(values) > 1:
            refuse(ref, "MACHINE", "receipt:machine", f"julia {ver}: processes disagree on cpu: {sorted(values)}")
    for p in procs_:
        at = f"julia {p['julia']} rep {p['rep']}"
        for key, expected in (("cpu_model", machine["cpu_model"]), ("logical_cpu", machine["logical_cpu"]),
                              ("cpu", machine["cpu"][mm_of[p["julia"]]])):
            if p["machine"][key] != expected:
                refuse(ref, "MACHINE", "receipt:machine", f"julia {p['julia']}: {key} {p['machine'][key]!r}, "
                       f"expected {expected!r}")
        if p["rep"] not in reps:
            refuse(ref, "REPETITIONS", "receipt:repetitions", f"{at}: rep outside the declared set {reps}")
    by_key, count = {}, Counter((p["arm"], p["role"], p["julia"], p["rep"]) for p in procs_)
    for key, n in sorted(count.items()):
        if n > 1:
            refuse(ref, "REPETITIONS", "receipt:repetitions", f"arm {key[0]} role {key[1]} julia {key[2]} "
                   f"rep {key[3]}: {n} process events")
    for p in procs_:
        by_key.setdefault((p["arm"], p["role"], p["julia"], p["rep"]), p)
    arms = ("AB", "AA") if with_aa else ("AB",)
    roots_of = {("AB", "A"): "a", ("AB", "B"): "b", ("AA", "A"): "aa_a", ("AA", "B"): "aa_b"}
    for arm in arms:
        for info in sched["strata"].values():
            ver, previous = info["version"], None
            for rep in reps:
                pair = [by_key.get((arm, role, ver, rep)) for role in "AB"]
                for role, p in zip("AB", pair):
                    if p is None and not receipt["unidentified"] and (arm, role, ver, rep) not in receipt["unusable"]:
                        refuse(ref, "ORDER", "receipt:missing", f"arm {arm} role {role} julia {ver} rep {rep}: "
                               "no process event")
                if None in pair:
                    previous = None
                    continue
                first, second = sorted(pair, key=lambda p: p["start"])
                at = f"arm {arm} julia {ver} rep {rep}"
                if first["end"] >= second["start"]:
                    refuse(ref, "ORDER", "receipt:block", f"{at}: the two processes overlap or start together")
                else:
                    order = "AB" if first["role"] == "A" else "BA"
                    if order != sched["orders"][rep]:
                        refuse(ref, "ORDER", "receipt:block", f"{at}: order {order}, schedule has "
                               f"{sched['orders'][rep]}")
                if previous and min(p["start"] for p in pair) <= max(p["end"] for p in previous):
                    refuse(ref, "ORDER", "receipt:block", f"{at}: starts before the previous block ended")
                previous = pair
    for key, p in sorted(by_key.items(), key=lambda kv: (kv[0][0], kv[0][1], kv[0][2], kv[0][3])):
        arm, role, ver, rep = key
        if p["rep"] not in reps or (arm == "AA" and not with_aa):
            continue
        root = roots.get(roots_of[(arm, role)])
        at = f"arm {arm} role {role} julia {ver} rep {rep}"
        if root and root["ident"] and root["ident"]["installation"] != p["installation"]:
            refuse(ref, "ORDER", "receipt:installation", f"{at}: receipt installation {p['installation']!r}, "
                   f"root {root['ident']['installation']!r}")
        record = ((root or {}).get("strata", {}).get(mm_of[ver]) or {"procs": {}})["procs"].get(rep)
        meta = record["meta"] if record else {}
        if p["complete"] is not True or p["exit"] not in (0, 2):
            refuse(ref, "STACK", "receipt:process", f"{at}: complete {p['complete']}, exit {p['exit']}")
        nonok = meta.get("nonok_cases")
        if nonok is not None and ((p["exit"] == 0 and nonok > 0) or (p["exit"] == 2 and nonok == 0)):
            refuse(ref, "STACK", "receipt:process", f"{at}: exit {p['exit']} with nonok_cases {nonok}")
        seconds = (p["end"] - p["start"]).total_seconds()
        if meta.get("elapsed_s", 0) > seconds:
            refuse(ref, "ORDER", "receipt:elapsed", f"{at}: elapsed_s {meta['elapsed_s']} exceeds "
                   f"the receipt interval of {seconds} s")


def check_aa(roots, sched, ref):
    """Section 12, A/A pair: independent installations of an identical Stack A (paths in normal form)."""
    one, two, base = roots["aa_a"], roots["aa_b"], roots["a"]
    if one["ident"] and two["ident"] and one["ident"]["installation"] == two["ident"]["installation"]:
        refuse(ref, "ORDER", "aa:installation", f"both roots have installation {one['ident']['installation']!r}")

    def paths(st):
        found = {norm(p["meta"][key]) for _, p in procs(st) for key in ("proximalsolvers_path",
                                                                       "expected_package_root")
                 if p["meta"].get(key)}
        return found | ({norm(st["inv"]["proximalsolvers_dir"])} if st["inv"] else set())
    for mm, info in sched["strata"].items():
        s1, s2 = one["strata"].get(mm), two["strata"].get(mm)
        if not s1 or not s2:
            continue
        shared = paths(s1) & paths(s2)
        if shared:
            refuse(ref, "ORDER", "aa:installation", f"julia {info['version']}: both roots name the checkout "
                   f"{sorted(shared)}")
        if s1["inv"] and s2["inv"] and norm(s1["inv"]["depot_path"][0]) == norm(s2["inv"]["depot_path"][0]):
            refuse(ref, "ORDER", "aa:installation", f"julia {info['version']}: first depot entry "
                   f"{norm(s1['inv']['depot_path'][0])!r} is shared")
        for root in (one, two):
            st = root["strata"].get(mm)
            sb = base["strata"].get(mm)
            if st and sb and st["manifest"] and sb["manifest"] and \
                    manifest_diff(st["manifest"]["entries"], sb["manifest"]["entries"]):
                refuse(ref, "ORDER", "aa:identity", f"julia {info['version']}: Manifest of {root['name']} "
                       f"differs from Stack A")
    own = ("installation", "campaign_id", "session_id")
    for root in (one, two):
        if root["ident"] and base["ident"] and {k: v for k, v in root["ident"].items() if k not in own} \
                != {k: v for k, v in base["ident"].items() if k not in own}:
            refuse(ref, "ORDER", "aa:identity", f"identity of {root['name']} differs from Stack A")


# ---------------------------------------------------------------------------------------- per-case results

def screen_of(rhos, aa, sched):
    """Section 16: descriptive screens; never a test."""
    if aa is None:
        return "screen not evaluated"
    both = {sched["orders"][r] for r in sched["reps"]} == {"AB", "BA"}
    geo = math.exp(statistics.fmean(math.log(r) for r in rhos))
    if both and all(r > 1 for r in rhos) and geo > max(aa):
        return "screened slowdown"
    if both and all(r < 1 for r in rhos) and geo < min(aa):
        return "screened speedup"
    return "inconclusive"


def positive(row):
    median = validate.number(row["median_ns"])
    return math.isfinite(median) and median > 0


def good(row):
    """An ok row with a finite positive median_ns."""
    return row["status"] == "ok" and positive(row)


def classify(W, mm, cid):
    """Section 5: the class, reason and numbers of one case in one stratum."""
    sched, reps = W["sched"], W["sched"]["reps"]
    ver = sched["strata"][mm]["version"]
    rows = {side: [W["roots"][root]["strata"][mm]["procs"][rep]["metrics"][cid] for rep in reps]
            for side, root in (("A", "a"), ("B", "b"))}
    mapped, cat = W["mapping"][cid], W["roots"]["a"]["strata"][mm]["cat"][cid]
    out = dict(julia=ver, id=cid, role=mapped["role"], phase=cat["phase"], class_="", reason="",
               measure=cat["measure"], target=num(validate.number(cat["target"])), hardware=W["hardware"],
               mapping_class=mapped["class"])
    failed = [f"status: {side} rep{rep} {row['status']}" for side in "AB" for rep, row in zip(reps, rows[side])
              if row["status"] != "ok"]
    failed += [f"median_ns: {side} rep{rep} {row['median_ns'] or 'NaN'}" for side in "AB"
               for rep, row in zip(reps, rows[side]) if row["status"] == "ok" and not positive(row)]
    if failed:
        return dict(out, class_="FAILED", reason=" | ".join(failed))
    why = [f"fingerprint file missing: {side}" for side in "AB" if W["fps"][side][0] == "missing"]
    for rep in reps:
        present = {}
        for side in "AB":
            if W["fps"][side][0] == "ok":
                rowset = present[side] = W["fps"][side][1].get((ver, cid, rep), {})
                why += [f"fingerprint row missing: {kind}/{name} {side} rep {rep}"
                        for kind, name in REQUIRED_ROWS if (kind, name) not in rowset]
                if not any(k[0] == "fixture" for k in rowset):
                    why.append(f"fingerprint row missing: fixture/* {side} rep {rep}")
        if len(present) == 2:
            why += [f"fingerprint mismatch: {kind}/{name} rep {rep}" for kind, name in REQUIRED_ROWS
                    if kind in ("reset", "config") and (kind, name) in present["A"] and (kind, name) in present["B"]
                    and present["A"][(kind, name)] != present["B"][(kind, name)]]
    if mapped["class"] in ("C", "D"):
        why.append(f"mapping class {mapped['class']}")
    if "deviation" in mapped:
        why.append(f"semantic deviation: {mapped['deviation']}")
    if why:
        return dict(out, class_="NOT COMPARABLE", reason=" | ".join(why))
    a, b = [validate.number(r["median_ns"]) for r in rows["A"]], [validate.number(r["median_ns"]) for r in rows["B"]]
    rhos = [y / x for x, y in zip(a, b)]
    aa = None
    if W["aa"]:
        aa_rows = [(W["roots"]["aa_a"]["strata"][mm]["procs"][rep]["metrics"][cid],
                    W["roots"]["aa_b"]["strata"][mm]["procs"][rep]["metrics"][cid]) for rep in reps]
        if all(good(x) and good(y) for x, y in aa_rows):
            aa = [validate.number(y["median_ns"]) / validate.number(x["median_ns"]) for x, y in aa_rows]
    target = validate.number(cat["target"])
    acc = {side: [accuracy("ok", validate.number(r["worst_value"]), target) for r in rows[side]] for side in "AB"}
    join = lambda values: ";".join(values)  # noqa: E731
    return dict(
        out, class_="COMPARABLE", repetitions=join(str(r) for r in reps), a_ns=join(map(num, a)),
        b_ns=join(map(num, b)), ratio=join(map(num, rhos)), abs_diff_ns=join(num(y - x) for x, y in zip(a, b)),
        geomean_ratio=num(math.exp(statistics.fmean(math.log(r) for r in rhos))),
        ratio_min=num(min(rhos)), ratio_max=num(max(rhos)),
        a_value=join(num(validate.number(r["worst_value"])) for r in rows["A"]),
        b_value=join(num(validate.number(r["worst_value"])) for r in rows["B"]),
        a_accuracy_fraction=join(num(f) for f, _ in acc["A"]), b_accuracy_fraction=join(num(f) for f, _ in acc["B"]),
        a_accuracy_band=join(band for _, band in acc["A"]), b_accuracy_band=join(band for _, band in acc["B"]),
        a_median_bytes=join(num(validate.number(r["median_bytes"])) for r in rows["A"]),
        b_median_bytes=join(num(validate.number(r["median_bytes"])) for r in rows["B"]),
        aa_ratio_min=num(min(aa)) if aa else "", aa_ratio_max=num(max(aa)) if aa else "",
        screen=screen_of(rhos, aa, sched))


def build_lists(W, results):
    """Section 15: the nine visible lists, each sorted by (julia, id, rep, root)."""
    sched, reps = W["sched"], W["sched"]["reps"]
    sides = [("A", "a"), ("B", "b")] + ([("AA_A", "aa_a"), ("AA_B", "aa_b")] if W["aa"] else [])
    lists = {key: [] for key in ("not_ok", "invalid_certificates", "incomplete_paths", "errors_and_timeouts",
                                 "allocation_differences", "missing_diagnostics", "semantic_deviations",
                                 "not_comparable", "failed")}
    for mm, info in sched["strata"].items():
        for cid in sched["cases"]:
            for rep in reps:
                for label, root in sides:
                    proc = W["roots"][root]["strata"][mm]["procs"][rep]
                    row = proc["metrics"][cid]
                    value, target = validate.number(row["worst_value"]), validate.number(row["target"])
                    fraction, band = accuracy(row["status"], value, target)
                    if row["status"] != "ok":
                        lists["not_ok"].append(dict(
                            julia=info["version"], id=cid, rep=rep, root=label, status=row["status"],
                            detail=proc["errors"].get(cid, {}).get("exception", ""), worst_value=jnum(value),
                            target=jnum(target), accuracy_fraction=jnum(fraction), accuracy_band=band))
                    elif label.startswith("AA") and not good(row):
                        lists["missing_diagnostics"].append(dict(
                            what="aa", julia=info["version"], id=cid, rep=rep, root=label,
                            detail="non-positive or unavailable median_ns"))
                    if label.startswith("AA") and row["status"] != "ok":
                        lists["missing_diagnostics"].append(dict(
                            what="aa", julia=info["version"], id=cid, rep=rep, root=label,
                            detail=f"status {row['status']}"))
                ra = W["roots"]["a"]["strata"][mm]["procs"][rep]["metrics"][cid]
                rb = W["roots"]["b"]["strata"][mm]["procs"][rep]["metrics"][cid]
                if ra["status"] == rb["status"] == "ok" and (
                        validate.number(ra["median_bytes"]) != validate.number(rb["median_bytes"])
                        or validate.number(ra["max_bytes"]) != validate.number(rb["max_bytes"])):
                    lists["allocation_differences"].append(dict(
                        julia=info["version"], id=cid, rep=rep,
                        a_median_bytes=validate.number(ra["median_bytes"]),
                        b_median_bytes=validate.number(rb["median_bytes"]),
                        a_max_bytes=validate.number(ra["max_bytes"]), b_max_bytes=validate.number(rb["max_bytes"])))
            mapped = W["mapping"][cid]
            if "deviation" in mapped or mapped["class"] in ("C", "D"):
                lists["semantic_deviations"].append(dict(
                    julia=info["version"], id=cid, **{"class": mapped["class"]},
                    text=mapped.get("deviation", mapped.get("separate_mapping", "")),
                    approval_url=mapped.get("approval_url", "")))
        if not W["aa"]:
            lists["missing_diagnostics"].append(dict(what="aa", julia=info["version"],
                                                     detail="the A/A control (--aa) was not supplied"))
    for side in "AB":
        if W["fps"][side][0] == "missing":
            lists["missing_diagnostics"].append(dict(what="fingerprints", root=side,
                                                     detail=f"fingerprint file of stack {side} is missing"))
    for key, status in (("invalid_certificates", ("uncertifiable",)), ("incomplete_paths", ("incomplete",)),
                        ("errors_and_timeouts", ("error", "timeout"))):
        lists[key] = [row for row in lists["not_ok"] if row["status"] in status]
    for result in results:
        key = {"NOT COMPARABLE": "not_comparable", "FAILED": "failed"}.get(result["class_"])
        if key:
            lists[key].append(dict(julia=result["julia"], id=result["id"], reason=result["reason"]))
    order = lambda item: (item.get("julia") or "", item.get("id") or "", item.get("rep") or 0,  # noqa: E731
                          item.get("root") or "", item.get("what") or "")
    return {key: sorted(items, key=order) for key, items in lists.items()}


# -------------------------------------------------------------------------------------------------- report

def safe(value):
    """Free text from records and mappings, with the words the report must not use masked."""
    return summarize.markdown(BANNED.sub("[term]", str(value)))


def hardware_label(receipt, sched):
    policy = tuple(sched["machine"][k] for k in ("governor", "epp", "no_turbo", "smt_control"))
    seen = {tuple(p["machine"][k] for k in ("governor", "epp", "no_turbo", "smt_control")) for p in receipt["procs"]}
    if seen == {policy}:
        return "controlled"
    values = sorted(seen)[0] if seen else ("", "", "", "")
    return "observational: governor={}, epp={}, no_turbo={}, smt_control={}".format(*values)


def render_report(W, results, lists):
    sched, receipt = W["sched"], W["receipt"]
    campaign = receipt["campaigns"][0]
    lines = [FIRST_LINE, "",
             f"Campaign `{safe(campaign['campaign_id'])}`, schedule `{safe(campaign['schedule_id'])}`, session "
             f"`{safe(campaign['session_id'])}`.", "", f"Hardware: {safe(W['hardware'])}."]
    if W["hardware"] != "controlled":
        lines += ["", "This campaign is observational: the machine policy differs from the frozen policy of "
                  "`schedule.toml`, which does not change the exit status."]
    lines += ["", "## Visible lists", ""]
    titles = {"not_ok": "Cases that are not ok", "invalid_certificates": "Invalid certificates",
              "incomplete_paths": "Incomplete paths", "errors_and_timeouts": "Errors and timeouts",
              "allocation_differences": "Allocation differences (bytes per call, separately from timing)",
              "missing_diagnostics": "Missing diagnostics", "semantic_deviations": "Approved semantic deviations",
              "not_comparable": "Cases that are NOT COMPARABLE", "failed": "Cases that FAILED"}
    for key, title in titles.items():
        lines += [f"### {title} ({len(lists[key])})", ""]
        lines += ["- " + "; ".join(f"{k} {safe('null' if v is None else v)}" for k, v in item.items())
                  for item in lists[key]] or ["none"]
        lines.append("")
    lines += ["## Screens and ratios", "", DISCLAIMER, "",
              "A ratio is the process median of stack B over that of stack A for the same case and repetition; "
              "no ratio is formed for a FAILED or NOT COMPARABLE case, and Julia versions are never pooled.", ""]
    for mm, info in sched["strata"].items():
        ver = info["version"]
        lines += [f"### Julia {ver}", "", "| id | role | class | screen | geomean_ratio | ratio_min | ratio_max | "
                  "aa_ratio_min | aa_ratio_max | mapping_class |", "|---|---|---|---|---|---|---|---|---|---|"]
        for r in (r for r in results if r["julia"] == ver):
            lines.append("| " + " | ".join(safe(r.get(k, "")) for k in (
                "id", "role", "class_", "screen", "geomean_ratio", "ratio_min", "ratio_max", "aa_ratio_min",
                "aa_ratio_max", "mapping_class")) + " |")
        lines += ["", f"Process RSS of Julia {ver} (`maxrss_bytes` of the metadata, one value per process; heap "
                  "allocations above are a different quantity):", "", "| rep | A maxrss_bytes | B maxrss_bytes |",
                  "|---|---|---|"]
        for rep in sched["reps"]:
            a = W["roots"]["a"]["strata"][mm]["procs"][rep]["meta"]["maxrss_bytes"]
            b = W["roots"]["b"]["strata"][mm]["procs"][rep]["meta"]["maxrss_bytes"]
            lines.append(f"| {rep} | {a} | {b} |")
        lines.append("")
    lines += [f"## {HISTORICAL_TITLE}", "",
              "| julia | id | mean_of_medians_ns | median_bytes | worst_value_max | status |", "|---|---|---|---|---|---|"]
    for info in sched["strata"].values():
        for cid in sched["cases"]:
            row = W["hist"].get((info["version"], cid))
            if row:
                lines.append("| " + " | ".join(safe(row[k]) for k in (
                    "julia", "id", "mean_of_medians_ns", "median_bytes", "worst_value_max", "status")) + " |")
    return "\n".join(lines) + "\n"


def read_historical():
    """Section 2: historical-reference.tsv next to the tool; used only for the historical table."""
    text = read_text(HERE / "historical-reference.tsv", "historical reference")
    rows = list(csv.DictReader([l for l in text.split("\n") if l and not l.startswith("#")], delimiter="\t"))
    need = {"julia", "id", "mean_of_medians_ns", "median_bytes", "worst_value_max", "status"}
    if not rows or not need <= set(rows[0]):
        raise Usage("historical-reference.tsv lacks the expected columns")
    return {(r["julia"], r["id"]): r for r in rows}


# ------------------------------------------------------------------------------------------------- driver

class Parser(argparse.ArgumentParser):
    def error(self, message):
        raise Usage(message)


def parse_args(argv):
    parser = Parser(description=__doc__, allow_abbrev=False, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--a", required=True, metavar="ROOT_A")
    parser.add_argument("--b", required=True, metavar="ROOT_B")
    parser.add_argument("--mapping", required=True, metavar="case-mapping.toml")
    parser.add_argument("--declared-differences", required=True, metavar="FILE")
    parser.add_argument("--receipt", required=True, metavar="FILE")
    parser.add_argument("--aa", nargs=2, metavar=("ROOT_AA_A", "ROOT_AA_B"))
    parser.add_argument("--fingerprints-a", metavar="FILE")
    parser.add_argument("--fingerprints-b", metavar="FILE")
    parser.add_argument("--schedule", default=str(HERE / "schedule.toml"), metavar="FILE")
    parser.add_argument("--out", required=True, metavar="DIR")
    return parser.parse_args(argv)


def write_json(path, value):
    path.write_text(json.dumps(value, indent=2) + "\n", encoding="utf-8")


def make_scrub(paths):
    """A function that removes absolute paths from a message: known paths become labels, others their basename."""
    known = []
    for label, path in paths.items():
        for variant in {str(path), str(Path(path).resolve())} if path else ():
            if "/" in variant:
                known.append((variant.rstrip("/"), label))
    known.sort(key=lambda item: -len(item[0]))

    def scrub(text):
        text = str(text)
        for variant, label in known:
            text = re.sub(re.escape(variant) + r"(?![\w.-])", lambda _: f"<{label}>", text)
        return re.sub(r"(?<![\w.<>:/-])/(?:[^/\s'\"]+/)+([^/\s'\"]*)", r"\1", text)
    return scrub


def comparison_phase(W):
    """Sections 5, 15, 16: everything that uses a timing value of a comparison.

    The ratios, geometric means, screens, class table, lists and report live here and nowhere else. It is called
    only after every refusal has been evaluated and none was found; a refused input never reaches it."""
    scrub, sched = W["scrub"], W["sched"]
    results = [classify(W, mm, cid) for mm in sched["strata"] for cid in sched["cases"]]
    for result in results:
        result["reason"] = scrub(result["reason"])
    lists = build_lists(W, results)
    for items in lists.values():
        for item in items:
            for key in ("detail", "text", "reason"):
                if key in item:
                    item[key] = scrub(item[key])
    rows = [{**{k: r.get(k, "") for k in COLUMNS if k != "class"}, "class": r["class_"]} for r in results]
    return results, rows, lists, render_report(W, results, lists)


def run(argv):
    scrub = make_scrub({})
    try:
        args = parse_args(sys.argv[1:] if argv is None else argv)
        scrub = make_scrub(dict(a=args.a, b=args.b, **dict(zip(("aa_a", "aa_b"), args.aa or ())),
                                receipt=args.receipt, mapping=args.mapping, declared=args.declared_differences,
                                fingerprints_a=args.fingerprints_a or "", fingerprints_b=args.fingerprints_b or "",
                                schedule=args.schedule, out=args.out))
        out = Path(args.out)
        if out.exists() and (not out.is_dir() or any(out.iterdir())):
            raise Usage(f"--out {out} is not a fresh directory")
        sched = load_schedule(args.schedule)
        mapping_data = read_toml(args.mapping, "mapping")
        declared_data = read_toml(args.declared_differences, "declared-differences")
        receipt_text = read_text(args.receipt, "receipt")
        fp_paths = {"A": args.fingerprints_a or Path(args.a) / "fingerprints.tsv",
                    "B": args.fingerprints_b or Path(args.b) / "fingerprints.tsv"}
        for path in fp_paths.values():
            if Path(path).exists():
                read_text(path, "fingerprint file")
    except Usage as error:
        print(f"usage error: {scrub(error)}", file=sys.stderr)
        return 3
    except SystemExit as stop:
        return stop.code or 0

    ref = []
    names = (("a", args.a), ("b", args.b)) + (tuple(zip(("aa_a", "aa_b"), args.aa)) if args.aa else ())
    roots = {name: read_root(name, path, sched, ref, stack_a=name != "b") for name, path in names}
    for root in roots.values():
        check_cases(root, sched, ref)
    check_pair("ab", roots["a"], roots["b"], sched, ref)
    if args.aa:
        check_pair("aa", roots["aa_a"], roots["aa_b"], sched, ref)
    mapping_rows = read_mapping(mapping_data, ref)
    if mapping_rows is not None:
        check_mapping(mapping_rows, roots["a"], sched, ref)
    declared = read_declared(declared_data, sched, ref)
    if declared:
        check_declared(declared, roots["a"], roots["b"], mapping_rows, sched, ref)
    phases = {(st["version"], cid): row["phase"] for st in roots["a"]["strata"].values()
              for cid, row in (st["cat"] or {}).items()}
    fps = {side: read_fingerprints(fp_paths[side], side, sched, phases, ref) for side in "AB"}
    check_fingerprints(fps, sched, ref)
    receipt = read_receipt(receipt_text, sched, ref)
    check_receipt(receipt, roots, sched, bool(args.aa), ref)
    if args.aa:
        check_aa(roots, sched, ref)

    if ref:                                                       # the refusal decision
        entries = sorted(set((n, c, f, scrub(d)) for n, c, f, d in ref))
        for _, cls, field, detail in entries:
            print(f"REFUSED:{cls} {field}: {detail}", file=sys.stderr)
        try:
            validate.fresh_output(out)
            write_json(out / "refusals.json", dict(schema=1, count=len(entries), refusals=[
                dict(**{"class": cls}, field=field, detail=detail) for _, cls, field, detail in entries]))
        except (OSError, ValueError) as error:
            print(f"usage error: cannot write the output directory: {scrub(error)}", file=sys.stderr)
            return 3
        return 2

    try:
        hist = read_historical()                                  # only a written report needs it
    except Usage as error:
        print(f"usage error: {scrub(error)}", file=sys.stderr)
        return 3
    W = dict(sched=sched, roots=roots, mapping={r["id"]: r for r in mapping_rows}, fps=fps, receipt=receipt,
             aa=bool(args.aa), hist=hist, hardware=hardware_label(receipt, sched), scrub=scrub)
    results, rows, lists, report = comparison_phase(W)
    try:
        validate.fresh_output(out)
        summarize.write_csv(out / "migration-comparison.csv", COLUMNS, rows)
        write_json(out / "lists.json", lists)
        (out / "report.md").write_text(report, encoding="utf-8")
    except (OSError, ValueError) as error:
        print(f"usage error: cannot write the output directory: {scrub(error)}", file=sys.stderr)
        return 3
    counts = Counter(r["class_"] for r in results)
    print(f"migration comparison written: {counts['COMPARABLE']} COMPARABLE, {counts['NOT COMPARABLE']} "
          f"NOT COMPARABLE, {counts['FAILED']} FAILED")
    return 0 if counts["COMPARABLE"] == len(results) else 1


def main(argv=None):
    """Exit status: 0 or 1 a report was written, 2 refused, 3 usage error, unreadable input or internal error."""
    try:
        return run(argv)
    except Exception as error:                  # never the interpreter's default status 1
        print(f"INTERNAL ERROR: {type(error).__name__}", file=sys.stderr)
        return 3


if __name__ == "__main__":
    raise SystemExit(main())
