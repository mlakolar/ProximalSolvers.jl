#!/usr/bin/env python3
"""Stage 2B campaign driver (#110, #218): the Python core.

    python3 -B stage2b_campaign.py preflight --config FILE --base BASE [--official --freeze-sha SHA] [--arms AB,AA]
                                             [--julia MM=PATH ...]
    python3 -B stage2b_campaign.py prepare   --config FILE --base BASE --step fetch|finalize [--julia MM=PATH ...]
                                             [--archive FILE]
    python3 -B stage2b_campaign.py run       --config LOCK --base BASE --official --freeze-sha SHA [--julia MM=PATH ...]
    python3 -B stage2b_campaign.py pilot     --config PILOT --base BASE [--arms AB] [--julia MM=PATH ...]
    python3 -B stage2b_campaign.py verify    --base BASE --out FILE [--config PILOT_CONFIG]

Standard library only (Python 3.11 or later). The driver launches `benchmark/run.jl` of each role's checkout and
never measures anything itself. Everything that depends on Julia or on the host is injected: the pure functions
take observation dictionaries, and `execute` receives a hooks object (probe, command runner, clock, machine
sampler, depot-cache digest, data-hash check). `RealHooks` is the real implementation (subprocess runner, the
untimed environment probe, the depot digest, the data-hash check); `main(..., hooks=None)` builds it from the
configuration, tests pass mocks. `prepare --step fetch` clones, builds the environments and verifies the pinned
identities (network allowed); `prepare --step finalize` runs on the measurement node, offline, with the formal Julia
flags and environment.

Exit status: 0 success; 1 completed with non-ok cases (a process exit 2 or comparator exit 1; reported and
retained); 2 refused or stopped (official gate, preflight problem, infrastructure stop, comparator refusal,
failed verification); 3 usage or internal error.

BASE layout (one directory per campaign attempt; `installations`, `environments` and `depots` are private working
directories and are not evidence; everything else is evidence and is covered by `checksums.sha256`):

    roots/{ab-a,ab-b,aa-a,aa-b}/        comparator roots: stack-identity.toml, fingerprints.tsv and
                                        fingerprints.datahash.tsv (ab-a and ab-b only), julia-MM/{raw/,
                                        Project.toml, Manifest.toml, environment-inventory.toml}
    installations/<role>/ProximalSolvers.jl   the role's checkout (ProximalBase.jl next to it for stack B)
    environments/<role>/env-MM          the role's Julia environment per stratum
    depots/<role>                       the role's private depot (first JULIA_DEPOT_PATH entry)
    schedule.toml  case-mapping.toml    the copies this campaign used
    lock.toml | pilot-config.toml       the configuration of the mode: lock.toml official only, pilot-config.toml
                                        pilot only (the other one is forbidden)
    receipt.jsonl  declared-differences.toml
    logs/                               seals.jsonl commands.jsonl (personal environment values redacted)
                                        hardware.jsonl probes.jsonl (the untimed probes) campaign.json
                                        comparator.json, per-process stdout and stderr, STATE.json, completion.json;
                                        from prepare: session.json (the session minted by fetch),
                                        prepare-commands.jsonl, depot-baselines.json, finalize.json,
                                        pilot-overrides.json
    comparison/                         the output of migration_compare.py at run time
    checksums.sha256  verification.json (verification.json is written elsewhere, never into the evidence)

Roles and comparator root labels: ab-a=a, ab-b=b, aa-a=aa_a, aa-b=aa_b. Arm AB runs roles ab-a (role A) and ab-b
(role B), arm AA runs aa-a and aa-b. `run` is official (it needs the lock and the freeze SHA); `pilot` is not.
There is no other switch and no environment variable that changes the mode.
"""

import argparse
import contextlib
import copy
import csv
import dataclasses
import datetime
import hashlib
import importlib.util
import io
import json
import math
import os
import posixpath
import re
import secrets
import shutil
import stat
import subprocess
import sys
import tempfile
import time
import tomllib
from pathlib import Path

HERE = Path(__file__).resolve().parent
BENCH = HERE.parent.parent


def load_comparator():
    """migration_compare.py by explicit path (one module object per process, also for importers by name)."""
    name = "migration_compare"
    if name in sys.modules:
        return sys.modules[name]
    spec = importlib.util.spec_from_file_location(name, HERE / "migration_compare.py")
    module = importlib.util.module_from_spec(spec)
    sys.modules[name] = module
    try:
        spec.loader.exec_module(module)
    except BaseException:
        sys.modules.pop(name, None)
        raise
    return module


mc = load_comparator()
validate = mc.validate

HEX40 = re.compile(r"[0-9a-f]{40}")
HEX64 = re.compile(r"[0-9a-f]{64}")
INSTALLATION = re.compile(r"[A-Za-z0-9._-]+")
SESSION = re.compile(r"session-[0-9]{8}T[0-9]{6}Z-[0-9a-f]{4}")
APPROVAL_URL = re.compile(r"https://github\.com/mlakolar/ProximalSolvers\.jl/(issues|pull)/[0-9]+#issuecomment-[0-9]+")
GATES = tuple(f"G{n}" for n in range(1, 9))

ROLES = ("ab-a", "ab-b", "aa-a", "aa-b")
ROLE_LABEL = {"ab-a": "a", "ab-b": "b", "aa-a": "aa_a", "aa-b": "aa_b"}
ARM_ROLES = {"AB": {"A": "ab-a", "B": "ab-b"}, "AA": {"A": "aa-a", "B": "aa-b"}}
ARMS = ("AB", "AA")
PRIVATE_DIRECTORIES = ("installations", "environments", "depots")
RECORD_KINDS = ("catalog", "errors", "metrics", "samples", "metadata", "metadata-start")
PROFILES = "-profiles.txt"
ENV_PASSTHROUGH = ("PATH", "HOME", "USER", "LOGNAME", "LANG", "LC_ALL", "TMPDIR", "JULIA_PKG_SERVER")
# The scheduler job-ID variable that run.jl reads into the metadata key job_id (built from pieces: the files of this
# directory carry no scheduler strings, see test_stage2b_files.py).
JOB_ID_VARIABLES = ("SLU" + "RM_JOB_ID",)
REQUIRED_FP_ROWS = (("reset", "values"), ("reset", "active_ids"), ("config", "solver"), ("config", "options"),
                    ("file", "certificates.jl"))
MACHINE_KEYS = ("cpu_model", "cpu", "logical_cpu", "governor", "epp", "no_turbo", "smt_control")
SAMPLE_KEYS = ("cpu_model", "governor", "epp", "no_turbo", "smt_control")
POLICY_FIELDS = ("campaign", "stack_b", "declared", "harness", "approvals")
DATAHASH_HEADER = "julia\tid\trep\tdata_hash"
FP_NAME = "fingerprints.tsv"
DATAHASH_NAME = "fingerprints.datahash.tsv"


# ---------------------------------------------------------------------------------------------------- errors

class DriverError(Exception):
    """Base of the errors that end a command with exit status 2."""


class Refused(DriverError):
    """A refusal before anything was launched (gate, lock, preflight, existing evidence)."""

    def __init__(self, message, field=None, problems=()):
        super().__init__(message)
        self.field, self.problems = field, list(problems)


class LockRefusal(Refused):
    """A malformed lock or pilot configuration; `field` names the offending key."""

    def __init__(self, field, message):
        super().__init__(f"lock {field}: {message}", field=field)


class DeclaredRefusal(Refused):
    """A declared difference that cannot be written: missing reason, absent or unexpected difference."""


class Stopped(DriverError):
    """The attempt stopped after processes may have run; the evidence is kept and STATE.json says why."""


class UsageError(Exception):
    """A usage error or an internal error: exit status 3."""


# ------------------------------------------------------------------------------------------------- helpers

def utc_now():
    return datetime.datetime.now(datetime.timezone.utc)


def utc_text(moment):
    """ISO 8601 with a UTC offset and millisecond resolution (the receipt format)."""
    if moment.tzinfo is None or moment.utcoffset() is None:
        raise ValueError("a clock reading needs a UTC offset")
    return moment.astimezone(datetime.timezone.utc).isoformat(timespec="milliseconds")


def sha256_file(path):
    digest = hashlib.sha256()
    with Path(path).open("rb") as stream:
        for block in iter(lambda: stream.read(1 << 20), b""):
            digest.update(block)
    return digest.hexdigest()


def sha256_bytes(data):
    return hashlib.sha256(data).hexdigest()


def is_hex40(value):
    return isinstance(value, str) and bool(HEX40.fullmatch(value))


def is_text(value):
    return isinstance(value, str) and value != ""


def norm(path):
    return mc.norm(path)


def git(repo, *args, run=subprocess.run):
    """Output of `git -C repo args`; a failing git raises Refused (nothing is guessed)."""
    result = run(["git", "-C", str(repo), *args], capture_output=True, text=True)
    if result.returncode != 0:
        raise Refused(f"git {' '.join(args)} failed in {Path(repo).name}: {result.stderr.strip()}")
    return result.stdout.strip()


def git_clean(repo, run=subprocess.run):
    """Clean means no tracked change, no untracked file and no ignored file."""
    return git(repo, "status", "--porcelain", "--untracked-files=all", "--ignored", run=run) == ""


def mint_session_id(moment=None, used=()):
    """`session-<UTC compact>-<4 hex>`, minted once per attempt and never one of `used`."""
    moment = moment or utc_now()
    stamp = moment.astimezone(datetime.timezone.utc).strftime("%Y%m%dT%H%M%SZ")
    for _ in range(64):
        candidate = f"session-{stamp}-{secrets.token_hex(2)}"
        if candidate not in used:
            return candidate
    raise Refused("cannot mint an unused session id")


def append_jsonl(path, event):
    """Append one JSON line, flushed and synced; the file must exist (it is created exclusively at the start)."""
    with Path(path).open("a", encoding="utf-8") as stream:
        stream.write(json.dumps(event, ensure_ascii=False) + "\n")
        stream.flush()
        os.fsync(stream.fileno())


def create_exclusive(path, text=""):
    with Path(path).open("x", encoding="utf-8") as stream:
        stream.write(text)
        stream.flush()
        os.fsync(stream.fileno())


def replace_file(path, text):
    """Write a file in place of another one atomically (STATE.json only)."""
    temporary = Path(f"{path}.tmp")
    with temporary.open("w", encoding="utf-8") as stream:
        stream.write(text)
        stream.flush()
        os.fsync(stream.fileno())
    os.replace(temporary, path)


def read_jsonl(path):
    lines = Path(path).read_text(encoding="utf-8").split("\n")
    if lines and lines[-1] == "":
        lines.pop()
    return [json.loads(line) for line in lines]


def read_tsv(path):
    lines = Path(path).read_text(encoding="utf-8").split("\n")
    if lines and lines[-1] == "":
        lines.pop()
    return lines[0].split("\t") if lines else [], [line.split("\t") for line in lines[1:]]


# ------------------------------------------------------------------------------------------- TOML writer

def toml_key(key):
    return key if re.fullmatch(r"[A-Za-z0-9_-]+", key) else toml_string(key)


def toml_string(text):
    out = ['"']
    for char in text:
        code = ord(char)
        if char == '"':
            out.append('\\"')
        elif char == "\\":
            out.append("\\\\")
        elif char == "\n":
            out.append("\\n")
        elif char == "\t":
            out.append("\\t")
        elif char == "\r":
            out.append("\\r")
        elif char == "\b":
            out.append("\\b")
        elif char == "\f":
            out.append("\\f")
        elif code < 0x20 or code == 0x7F:
            out.append(f"\\u{code:04x}")
        else:
            out.append(char)
    out.append('"')
    return "".join(out)


def toml_value(value):
    if isinstance(value, bool):
        return "true" if value else "false"
    if isinstance(value, int):
        return str(value)
    if isinstance(value, float):
        if not math.isfinite(value):
            raise ValueError("a non-finite float is not written")
        return repr(value)
    if isinstance(value, str):
        return toml_string(value)
    if isinstance(value, (list, tuple)):
        return "[" + ", ".join(toml_value(item) for item in value) + "]"
    if isinstance(value, dict):
        return "{ " + ", ".join(f"{toml_key(k)} = {toml_value(v)}" for k, v in value.items()) + " }"
    raise TypeError(f"cannot write {type(value).__name__} as TOML")


def is_table_array(value):
    return isinstance(value, (list, tuple)) and bool(value) and all(isinstance(item, dict) for item in value)


def toml_dumps(data, prefix=()):
    """A dict of scalars, scalar arrays, tables and arrays of tables as TOML text: deterministic (the insertion
    order of the dictionaries), scalars before tables, no comments; `tomllib.loads` reads it back to `data`."""
    lines = [f"{toml_key(k)} = {toml_value(v)}" for k, v in data.items()
             if not isinstance(v, dict) and not is_table_array(v)]
    chunks = ["\n".join(lines)] if lines else []
    for key, value in data.items():
        path = prefix + (key,)
        name = ".".join(toml_key(part) for part in path)
        if isinstance(value, dict):
            body = toml_dumps(value, path)
            chunks.append(f"[{name}]\n{body}".rstrip("\n") if body else f"[{name}]")
        elif is_table_array(value):
            for item in value:
                body = toml_dumps(item, path)
                chunks.append(f"[[{name}]]\n{body}".rstrip("\n") if body else f"[[{name}]]")
    return "\n\n".join(chunks) + "\n"


def write_toml(path, data):
    """Exclusive create; the text is parsed back before it is kept."""
    text = toml_dumps(data)
    if tomllib.loads(text) != data:
        raise ValueError(f"{path}: the TOML text does not round-trip")
    create_exclusive(path, text)


# --------------------------------------------------------------------------- fingerprints of the sources

def fingerprint(root, files):
    """benchmark/run.jl `fingerprint`: SHA-1 over, per file in sorted order, the path relative to `root`, NUL,
    the bytes, NUL."""
    root = Path(root)
    entries = sorted((Path(f).relative_to(root).as_posix(), Path(f)) for f in files)
    digest = hashlib.sha1()
    for relative, path in entries:
        digest.update(relative.encode() + b"\0" + path.read_bytes() + b"\0")
    return digest.hexdigest()


def harness_hash(directory):
    """benchmark/run.jl `harness_hash`: the four harness files of the directory of run.jl."""
    directory = Path(directory)
    return fingerprint(directory, [directory / name for name in
                                   ("problems.jl", "certificates.jl", "cases.jl", "run.jl")])


def package_fingerprint(root):
    """benchmark/run.jl `package_fingerprint`: Project.toml and every `*.jl` below src/ and ext/."""
    root = Path(root)
    files = [root / "Project.toml"]
    for name in ("src", "ext"):
        directory = root / name
        if not directory.is_dir():
            continue
        for folder, _, names in os.walk(directory):
            files += [Path(folder) / n for n in names if n.endswith(".jl")]
    return fingerprint(root, files)


# --------------------------------------------------------------------------------------------- the lock

DECLARED_COMMON = ("kind", "name", "reason", "approval_url")


def _table(data, required, optional, where):
    if not isinstance(data, dict):
        raise LockRefusal(where, "is not a table")
    for key in sorted(data.keys() - set(required) - set(optional)):
        raise LockRefusal(f"{where}.{key}", "unknown key")
    for key in required:
        if key not in data:
            raise LockRefusal(f"{where}.{key}", "missing key")
    return data


def _text(data, key, where):
    if not is_text(data[key]):
        raise LockRefusal(f"{where}.{key}", "must be a non-empty string")


def _hex40(data, key, where):
    if not is_hex40(data[key]):
        raise LockRefusal(f"{where}.{key}", f"must be 40 lowercase hex characters, not {data[key]!r}")


def parse_lock(data, strata=None):
    """Validate a lock (schema 1) and return it unchanged; a violation raises LockRefusal naming the field.

    [campaign] id and session_id (optional); [stack_b] (the migrated stack, optional until the candidate is frozen:
    the official gate refuses a lock without it) with proximalsolvers, proximalbase, harness_hash and one
    environment per stratum; [[declared]] reasons and approval URLs of the manifest and compat differences;
    [harness] port commit, changed lines and approval URL; [approvals] G1..G8 and the case-mapping URLs."""
    _table(data, ("schema", "campaign"), ("stack_b", "declared", "harness", "approvals"), "lock")
    if not (isinstance(data["schema"], int) and not isinstance(data["schema"], bool) and data["schema"] == 1):
        raise LockRefusal("schema", "must be 1")
    campaign = _table(data["campaign"], ("id",), ("session_id",), "campaign")
    _text(campaign, "id", "campaign")
    if "session_id" in campaign and not SESSION.fullmatch(str(campaign["session_id"])):
        raise LockRefusal("campaign.session_id", "must look like session-<UTC compact>-<4 hex>")
    if "stack_b" in data:
        stack = _table(data["stack_b"], ("proximalsolvers", "proximalbase", "harness_hash", "environments"), (),
                       "stack_b")
        _hex40(stack, "harness_hash", "stack_b")
        ps = _table(stack["proximalsolvers"], ("commit", "tree", "version", "package_hash", "source"), (),
                    "stack_b.proximalsolvers")
        pb = _table(stack["proximalbase"], ("commit", "tree", "version", "package_hash", "source", "release"),
                    ("tag",), "stack_b.proximalbase")
        for table, where in ((ps, "stack_b.proximalsolvers"), (pb, "stack_b.proximalbase")):
            for key in ("commit", "tree", "package_hash"):
                _hex40(table, key, where)
            for key in ("version", "source"):
                _text(table, key, where)
            if re.search(r"\s", table["source"]):
                raise LockRefusal(f"{where}.source", "must be one locator without white space")
        if pb["release"] not in ("registered", "development"):
            raise LockRefusal("stack_b.proximalbase.release", "must be registered or development")
        if "tag" in pb:
            _text(pb, "tag", "stack_b.proximalbase")
        if pb["release"] == "registered" and "tag" not in pb:
            raise LockRefusal("stack_b.proximalbase.tag", "a registered release needs its tag")
        environments = stack["environments"]
        if not isinstance(environments, dict) or not environments:
            raise LockRefusal("stack_b.environments", "needs one table per stratum")
        if strata is not None and set(environments) != set(strata):
            raise LockRefusal("stack_b.environments", f"strata {sorted(environments)} differ from the "
                              f"schedule's {sorted(strata)}")
        for mm, env in environments.items():
            where = f"stack_b.environments.{mm}"
            _table(env, ("project", "project_sha256", "manifest", "manifest_sha256"), (), where)
            for key in ("project", "manifest"):
                _text(env, key, where)
                path = posixpath.normpath(env[key])
                if path.startswith("/") or path.startswith("..") or "\\" in env[key]:
                    raise LockRefusal(f"{where}.{key}", "must be a relative path inside the repository")
            for key in ("project_sha256", "manifest_sha256"):
                if not (isinstance(env[key], str) and HEX64.fullmatch(env[key])):
                    raise LockRefusal(f"{where}.{key}", "must be 64 lowercase hex characters")
    declared = data.get("declared", [])
    if not isinstance(declared, list):
        raise LockRefusal("declared", "must be an array of tables")
    for index, entry in enumerate(declared, 1):
        where = f"declared[{index}]"
        kind = entry.get("kind") if isinstance(entry, dict) else None
        if kind == "manifest":
            _table(entry, DECLARED_COMMON + ("uuid", "change"), ("julia",), where)
            if entry["change"] not in ("changed", "added", "removed"):
                raise LockRefusal(f"{where}.change", "must be changed, added or removed")
            _text(entry, "uuid", where)
        elif kind == "compat":
            _table(entry, DECLARED_COMMON, ("julia",), where)
        else:
            raise LockRefusal(f"{where}.kind", "must be manifest or compat")
        for key in ("name", "reason", "approval_url"):
            _text(entry, key, where)
        if "julia" in entry and not (isinstance(entry["julia"], list) and entry["julia"]
                                     and all(is_text(j) for j in entry["julia"])):
            raise LockRefusal(f"{where}.julia", "must be a non-empty list of strata")
        if "julia" in entry:
            if len(set(entry["julia"])) != len(entry["julia"]):
                raise LockRefusal(f"{where}.julia", "names a stratum twice")
            if strata is not None and not set(entry["julia"]) <= set(strata):
                raise LockRefusal(f"{where}.julia", f"{sorted(set(entry['julia']) - set(strata))} are not strata "
                                  f"of the schedule {sorted(strata)}")
    if "harness" in data:
        harness = _table(data["harness"], ("port_commit", "changed_lines", "approval_url"), (), "harness")
        _hex40(harness, "port_commit", "harness")
        _text(harness, "approval_url", "harness")
        if not (isinstance(harness["changed_lines"], list) and harness["changed_lines"]
                and all(isinstance(line, str) for line in harness["changed_lines"])):
            raise LockRefusal("harness.changed_lines", "must be a non-empty list of strings")
    if "approvals" in data:
        approvals = _table(data["approvals"], GATES + ("case_mapping",), (), "approvals")
        for gate in GATES:
            if not isinstance(approvals[gate], str):
                raise LockRefusal(f"approvals.{gate}", "must be a string")
        urls = approvals["case_mapping"]
        if not (isinstance(urls, list) and all(isinstance(u, str) for u in urls)):
            raise LockRefusal("approvals.case_mapping", "must be a list of strings")
    return data


def load_lock(path, strata=None):
    """Read and validate a lock file; no real candidate lock is committed anywhere."""
    try:
        data = tomllib.loads(Path(path).read_bytes().decode("utf-8"))
    except (OSError, UnicodeDecodeError, tomllib.TOMLDecodeError) as error:
        raise LockRefusal("file", f"cannot read {Path(path).name}: {error}") from error
    return parse_lock(data, strata)


# ---------------------------------------------------------------------------------------- official gate

def official_gate(lock, repo_facts, freeze_sha):
    """The unmet gates of an official run (an empty list means it may proceed), pure over `repo_facts`:

        head              the SHA the driver checkout is at
        clean             true only if the checkout has no tracked change, no untracked and no ignored file
        lock_tracked      the lock file is tracked at that commit
        strata            the strata of the schedule
        manifest_sha256   {stratum: SHA-256 of the Manifest.toml of root ab-b}
        checkouts         {"ps_b" | "pb_b": {"commit", "tree", "package_hash"}} observed in the fetched checkouts
        mapping_rows      the rows of case-mapping.toml ({"id", "class", "approved"})

    Nothing is read from the environment and no local approval flag exists. Each entry is `<CODE>: <detail>`."""
    unmet = []

    def need(ok, code, detail):
        if not ok:
            unmet.append(f"{code}: {detail}")

    facts = repo_facts or {}
    need(is_hex40(freeze_sha), "FREEZE_SHA", "--freeze-sha must be a full 40-hex commit SHA")
    need(is_hex40(freeze_sha) and facts.get("head") == freeze_sha, "HEAD",
         f"HEAD {facts.get('head')!r} is not the freeze commit {freeze_sha!r}")
    need(facts.get("clean") is True, "CLEAN", "the checkout is not clean (tracked, untracked or ignored files)")
    need(facts.get("lock_tracked") is True, "LOCK_TRACKED", "the lock is not tracked at the freeze commit")
    stack = (lock or {}).get("stack_b")
    if not isinstance(stack, dict):
        need(False, "STACK_B", "the lock has no [stack_b] candidate")
    else:
        for key, name in (("proximalsolvers", "ps_b"), ("proximalbase", "pb_b")):
            table, seen = stack.get(key) or {}, (facts.get("checkouts") or {}).get(name) or {}
            for field in ("commit", "tree", "package_hash"):
                value = table.get(field)
                code = f"{name.upper()}_{field.upper()}"
                if not is_hex40(value):
                    need(False, code, f"{key}.{field} is {value!r}, not a 40-hex value (no branch, no short SHA)")
                elif seen.get(field) != value:
                    need(False, code, f"{key}.{field} {value} differs from the observed {seen.get(field)!r}")
        need(is_hex40(stack.get("harness_hash")), "HARNESS_HASH", "[stack_b].harness_hash is not explicit 40-hex")
        environments = stack.get("environments") or {}
        need(set(environments) == set(facts.get("strata") or ()) and bool(environments), "ENVIRONMENTS",
             "the lock's environments are not the strata of the schedule")
        for mm, env in sorted(environments.items()):
            wanted = (facts.get("manifest_sha256") or {}).get(mm)
            need(isinstance(env, dict) and HEX64.fullmatch(str(env.get("manifest_sha256", "")))
                 and env.get("manifest_sha256") == wanted, "MANIFEST_SHA256",
                 f"julia {mm}: Manifest SHA-256 {wanted!r} differs from the lock")
    if isinstance(stack, dict):
        for code, detail in static_candidate_problems(stack):
            need(False, code, detail)
    rows = facts.get("mapping_rows") or []
    need(bool(rows), "MAPPING", "no case-mapping rows were observed")
    for row in rows:
        if row.get("class") in ("B", "C", "D"):
            need(row.get("approved") is True, "MAPPING", f"case {row.get('id')}: class {row.get('class')} "
                 "is not approved")
    for entry in approval_problems(lock or {}):
        unmet.append(entry)
    return unmet


def static_candidate_problems(stack):
    """(code, detail) of the static checks of a stack B candidate: ProximalBase is a 0.6 release and nothing
    equals the historical stack A. Used by the gate and again where `verify` reads an archived lock (a
    verification-consistency check only: it does not replace the gate or the external F1-B approval)."""
    historical = mc.load_schedule(HERE / "schedule.toml")["stack_a"]
    found = []
    table = stack.get("proximalbase") or {}
    if not (isinstance(table.get("version"), str) and re.match(r"0\.6\.", table["version"])):
        found.append(("PB_B_VERSION", f"ProximalBase version {table.get('version')!r} is not a 0.6 candidate"))
    for key, fields in (("proximalsolvers", ("commit", "tree")), ("proximalbase", ("commit", "tree", "package_hash"))):
        for field in fields:
            if (stack.get(key) or {}).get(field) == historical[key][field]:
                found.append((f"HISTORICAL_{key.upper()}_{field.upper()}",
                              f"stack_b {key}.{field} equals the historical stack A value"))
    if stack.get("harness_hash") == historical["harness_hash"]:
        found.append(("HISTORICAL_HARNESS_HASH", "stack_b harness_hash equals the historical stack A value"))
    return found


def approval_problems(lock):
    """`<CODE>: <detail>` for each of G1..G8 and the case-mapping approvals that is not a maintainer comment URL
    of this repository."""
    approvals = lock.get("approvals")
    if not isinstance(approvals, dict):
        return ["APPROVALS: the lock has no [approvals] table"]
    found = []
    for gate in GATES:
        value = approvals.get(gate)
        if not (isinstance(value, str) and APPROVAL_URL.fullmatch(value)):
            found.append(f"APPROVAL_{gate}: {gate} needs a maintainer comment URL of this repository, "
                         f"not {value!r}")
    urls = approvals.get("case_mapping")
    if not (isinstance(urls, list) and urls and all(isinstance(u, str) and APPROVAL_URL.fullmatch(u) for u in urls)):
        found.append("APPROVAL_CASE_MAPPING: the case-mapping approvals need maintainer comment URLs of this "
                     "repository")
    return found


def collect_repo_facts(repo, lock_path, base, schedule_path, mapping_path, run=subprocess.run):
    """The `repo_facts` of `official_gate` read from git and from BASE (the only part that runs git)."""
    repo, base = Path(repo), Path(base)
    facts = {"head": git(repo, "rev-parse", "HEAD", run=run), "clean": git_clean(repo, run=run)}
    try:
        relative = Path(lock_path).resolve().relative_to(repo.resolve()).as_posix()
        tracked = run(["git", "-C", str(repo), "cat-file", "-e", f"HEAD:{relative}"], capture_output=True,
                      text=True)
        facts["lock_tracked"] = tracked.returncode == 0
    except ValueError:                               # a lock outside the repository is not tracked in it
        facts["lock_tracked"] = False
    sched = mc.load_schedule(schedule_path)
    facts["strata"] = list(sched["strata"])
    facts["manifest_sha256"] = {}
    for mm in sched["strata"]:
        path = base / "roots" / "ab-b" / f"julia-{mm}" / "Manifest.toml"
        if path.is_file():
            facts["manifest_sha256"][mm] = sha256_file(path)
    facts["checkouts"] = {}
    for name, directory in (("ps_b", "ProximalSolvers.jl"), ("pb_b", "ProximalBase.jl")):
        checkout = base / "installations" / "ab-b" / directory
        if checkout.is_dir():
            facts["checkouts"][name] = {"commit": git(checkout, "rev-parse", "HEAD", run=run),
                                        "tree": git(checkout, "rev-parse", "HEAD^{tree}", run=run),
                                        "package_hash": package_fingerprint(checkout)}
    rows = tomllib.loads(Path(mapping_path).read_text(encoding="utf-8")).get("case", [])
    facts["mapping_rows"] = [{"id": r.get("id"), "class": r.get("class"), "approved": r.get("approved")}
                             for r in rows]
    return facts


# --------------------------------------------------------------------------------- pilot configuration

PILOT_TOP = ("schema", "campaign", "schedule", "pilot")
PILOT_OPTIONAL_TOP = ("julia", "source", "archive", "resources")
PILOT_SAMPLING = ("samples_target", "seconds_limit", "case_seconds")
STRATUM_KEY = re.compile(r"[0-9]+\.[0-9]+")


EXACT_FLOAT_INTEGER = 2 ** 53          # every integer up to this converts to a float exactly


def positive_number(value, integer=False, exact_float=False):
    """A positive number: an int (also a float unless `integer`), never a bool, NaN or infinity. The range of an int
    is checked before anything converts it: an int beyond the float range (about 1.8e308) is refused, never passed to
    `math.isfinite` (which raises OverflowError for it); with `exact_float` (a value the driver later converts with
    `float()`, the durations) an int must also be at most 2**53, so that the conversion never rounds it."""
    if isinstance(value, bool) or not isinstance(value, int if integer else (int, float)):
        return False
    if isinstance(value, int):           # int and float compare exactly in Python, with no conversion
        return 0 < value <= (EXACT_FLOAT_INTEGER if exact_float else sys.float_info.max)
    return math.isfinite(value) and value > 0


def _number(table, key, where, integer=False, exact_float=False):
    if not positive_number(table[key], integer, exact_float):
        limit = "at most 2**53" if exact_float else "within the float range"
        raise LockRefusal(f"{where}.{key}", f"must be a positive {'integer' if integer else 'number'} (an integer "
                          f"{limit})")


def parse_pilot(data, official_sched):
    """Validate a pilot configuration against the official schedule; any refusal is a Refused.

    The pilot has its own campaign and schedule ids (both contain `-pilot` and differ from the official ones)
    and no [stack_b] table: its stack B is a second independent installation of stack A. Besides the identities
    and the arms (`[pilot]`), the configuration may carry what `prepare` and the real hooks need, with strict keys:
    the reduced sampling values (`samples_target`, `seconds_limit`, `case_seconds` of `[pilot]`), `[julia]` (one
    binary per stratum), `[source]` (`repository` of ProximalSolvers, optional `proximalbase`), `[archive]`
    (`path` of the Stage 2A archive) and `[resources]` (`min_cpus`)."""
    if isinstance(data, dict) and "stack_b" in data:
        raise LockRefusal("stack_b", "a pilot has no [stack_b] table")
    _table(data, PILOT_TOP, PILOT_OPTIONAL_TOP, "pilot")
    if data["schema"] != 1 or isinstance(data["schema"], bool):
        raise LockRefusal("schema", "must be 1")
    campaign = _table(data["campaign"], ("id",), ("session_id",), "campaign")
    schedule = _table(data["schedule"], ("id",), (), "schedule")
    pilot = _table(data["pilot"], ("arms",), PILOT_SAMPLING, "pilot")
    for table, key, official, where in ((campaign, "id", official_sched["campaign_id"], "campaign.id"),
                                        (schedule, "id", official_sched["id"], "schedule.id")):
        _text(table, key, where.split(".")[0])
        if table[key] == official:
            raise LockRefusal(where, f"{table[key]!r} is the official identity")
        if "-pilot" not in table[key]:
            raise LockRefusal(where, f"{table[key]!r} lacks -pilot")
    if "session_id" in campaign and not SESSION.fullmatch(str(campaign["session_id"])):
        raise LockRefusal("campaign.session_id", "must look like session-<UTC compact>-<4 hex>")
    arms = pilot["arms"]
    if not (isinstance(arms, list) and arms and all(a in ARMS for a in arms) and len(set(arms)) == len(arms)):
        raise LockRefusal("pilot.arms", "must be a non-empty list of AB and AA")
    for key in PILOT_SAMPLING:
        if key in pilot:
            _number(pilot, key, "pilot", integer=key == "samples_target", exact_float=key != "samples_target")
    if "julia" in data:
        julia = data["julia"]
        if not isinstance(julia, dict) or not julia:
            raise LockRefusal("julia", "must map strata to Julia binaries")
        for mm, path in julia.items():
            if not STRATUM_KEY.fullmatch(mm):
                raise LockRefusal(f"julia.{mm}", "the key is not a MAJOR.MINOR stratum")
            if not (is_text(path) and path.startswith("/")):
                raise LockRefusal(f"julia.{mm}", "must be an absolute path")
    if "source" in data:
        source = _table(data["source"], ("repository",), ("proximalbase",), "source")
        for key in source:
            _text(source, key, "source")
            if re.search(r"\s", source[key]):
                raise LockRefusal(f"source.{key}", "must be one locator without white space")
    if "archive" in data:
        _text(_table(data["archive"], ("path",), (), "archive"), "path", "archive")
    if "resources" in data:
        resources = _table(data["resources"], (), ("min_cpus",), "resources")
        if "min_cpus" in resources:
            _number(resources, "min_cpus", "resources", integer=True)
            if resources["min_cpus"] < 2:
                raise LockRefusal("resources.min_cpus", "the driver needs at least two CPUs: the measured one and "
                                  "one for itself")
    return data


def pilot_schedule_problems(config, schedule, official, arms=None):
    """The one check of a pilot schedule against the held configuration and the committed official schedule,
    used before launch (`plan_from_pilot`, on the schedule the processes will use) and by `verify` (on the archived
    schedule). `schedule` and `official` are loaded schedules (`mc.load_schedule`), `arms` the arms of the
    schedule file.

    samples_target, seconds_limit and case_seconds must equal the value of `[pilot]` of the configuration when it
    names one and the OFFICIAL value otherwise (numbers compared as numbers, no booleans); every other [settings]
    value must equal the official one byte for byte; the repetition IDs must be a non-empty prefix of the official
    ones with the official AB/BA order; the arms must be those of the configuration."""
    problems = []
    if schedule["id"] != config["schedule"]["id"] or schedule["campaign_id"] != config["campaign"]["id"]:
        problems.append("the schedule ids differ from the pilot configuration's")
    pilot, settings, wanted = config["pilot"], schedule["settings"], official["settings"]
    for key in PILOT_SAMPLING:
        effective = pilot.get(key, wanted[key])
        value = settings.get(key)
        if not positive_number(value, exact_float=key != "samples_target"):    # range first: no OverflowError
            problems.append(f"settings.{key} is {value!r}, not a positive number in range")
        elif not mc.same(value, effective):                  # exact: no float coercion (integers beyond 2**53)
            origin = "the pilot configuration" if key in pilot else "the official schedule"
            problems.append(f"settings.{key} is {value!r}, {origin} has {effective!r}")
    for key in sorted((settings.keys() | wanted.keys()) - set(PILOT_SAMPLING)):
        if key not in settings or key not in wanted or not mc.same(settings[key], wanted[key]):
            problems.append(f"settings.{key} is {settings.get(key)!r}, the official schedule has {wanted.get(key)!r}")
    if schedule["strata"] != official["strata"]:
        problems.append("the Julia strata (versions and commits) differ from the official schedule's")
    if schedule["stack_a"] != official["stack_a"]:
        problems.append("[stack_a] differs from the official schedule's")
    reps, official_reps = list(schedule["reps"]), list(official["reps"])
    if not reps or reps != official_reps[:len(reps)]:
        problems.append(f"reps {reps} are not a non-empty prefix of the official {official_reps}")
    for rep in reps:
        if schedule["orders"].get(rep) != official["orders"].get(rep):
            problems.append(f"the order of repetition {rep} is {schedule['orders'].get(rep)!r}, the official one is "
                            f"{official['orders'].get(rep)!r}")
    if arms is not None and tuple(a for a in ARMS if a in arms) != tuple(a for a in ARMS if a in pilot["arms"]):
        problems.append(f"the arms {list(arms)} are not the configuration's {pilot['arms']}")
    return problems


def load_pilot(path, official_sched):
    try:
        data = tomllib.loads(Path(path).read_bytes().decode("utf-8"))
    except (OSError, UnicodeDecodeError, tomllib.TOMLDecodeError) as error:
        raise LockRefusal("file", f"cannot read {Path(path).name}: {error}") from error
    return parse_pilot(data, official_sched)


def load_config(path, official_sched):
    """A lock or a pilot configuration (a pilot has a [pilot] table); returns (kind, data)."""
    try:
        data = tomllib.loads(Path(path).read_bytes().decode("utf-8"))
    except (OSError, UnicodeDecodeError, tomllib.TOMLDecodeError) as error:
        raise LockRefusal("file", f"cannot read {Path(path).name}: {error}") from error
    if isinstance(data, dict) and "pilot" in data:
        return "pilot", parse_pilot(data, official_sched)
    return "lock", parse_lock(data, strata=list(official_sched["strata"]))


# ------------------------------------------------------------------------------------- plan and layout

@dataclasses.dataclass
class RoleSpec:
    name: str
    installation: str
    checkout: Path
    depot: Path
    environments: dict          # stratum -> environment directory
    julia: dict                 # stratum -> julia binary
    bundled_depot: object       # the Julia installation's own depots, appended after the private one: "" (none), a
                                # string for every stratum, or {stratum: string} (one installation per stratum)
    expected: dict              # see expected_identity()

    @property
    def label(self):
        return ROLE_LABEL[self.name]


@dataclasses.dataclass
class Plan:
    base: Path
    sched: dict
    official: bool
    campaign_id: str
    session_id: str
    arms: tuple
    roles: dict
    cpu: int
    case_filter: str
    parent_env: dict
    lock: dict = None
    freeze_sha: str = None

    def root(self, role):
        return self.base / "roots" / role

    def raw(self, role, mm):
        return self.root(role) / f"julia-{mm}" / "raw"

    def stem(self, mm, rep):
        return f"julia-{self.sched['strata'][mm]['version']}-rep{rep:02d}"

    def role_names(self):
        return [ARM_ROLES[arm][letter] for arm in self.arms for letter in "AB"]


@dataclasses.dataclass(frozen=True)
class Key:
    arm: str
    role: str                   # ab-a, ab-b, aa-a, aa-b
    mm: str
    rep: int

    @property
    def letter(self):
        return "A" if self.role.endswith("-a") else "B"

    @property
    def name(self):
        return f"{self.arm}-{self.letter}-{self.mm}-rep{self.rep:02d}"


def expected_identity(sched, stack, lock=None):
    """What a role's checkout must be: stack A is [stack_a] of the schedule, stack B is the lock."""
    if stack == "A":
        a = sched["stack_a"]
        return {"ps": {k: a["proximalsolvers"][k] for k in ("commit", "tree", "version", "package_hash")},
                "pb": {k: a["proximalbase"][k] for k in ("commit", "tree", "version", "package_hash")},
                "harness_hash": a["harness_hash"], "manifest_sha256": {}, "project_sha256": {}}
    b = lock["stack_b"]
    return {"ps": {k: b["proximalsolvers"][k] for k in ("commit", "tree", "version", "package_hash")},
            "pb": {k: b["proximalbase"][k] for k in ("commit", "tree", "version", "package_hash")},
            "harness_hash": b["harness_hash"],
            "manifest_sha256": {mm: env["manifest_sha256"] for mm, env in b["environments"].items()},
            "project_sha256": {mm: env["project_sha256"] for mm, env in b["environments"].items()}}


def read_identity_file(base, role):
    path = Path(base) / "roots" / role / "stack-identity.toml"
    try:
        return tomllib.loads(path.read_text(encoding="utf-8"))
    except (OSError, UnicodeDecodeError, tomllib.TOMLDecodeError) as error:
        raise Refused(f"cannot read the identity of {role}: {error}") from error


def schedule_arms(base):
    """The arms of the archived schedule copy (the comparator's loader does not return them)."""
    declared = tomllib.loads((Path(base) / "schedule.toml").read_text(encoding="utf-8"))["schedule"]["arms"]
    return tuple(arm for arm in ARMS if arm in declared)


SESSION_RECORD = "logs/session.json"
SESSION_RECORD_KEYS = ("schema", "session_id", "campaign_id", "minted_utc", "configuration", "configuration_sha256")


def configuration_name(official):
    return "lock.toml" if official else "pilot-config.toml"


def write_session_record(base, campaign_id, official, moment=None):
    """logs/session.json: the session of this base, minted once by `prepare --step fetch` (never one fixed in a
    configuration, which every attempt from that configuration would share). Exclusive: a base has one session."""
    base = Path(base)
    name = configuration_name(official)
    record = {"schema": 1, "session_id": mint_session_id(moment), "campaign_id": campaign_id,
              "minted_utc": utc_text(moment or utc_now()), "configuration": name,
              "configuration_sha256": sha256_file(base / name)}
    try:
        create_exclusive(base / SESSION_RECORD, json.dumps(record, indent=2) + "\n")
    except FileExistsError:
        raise Refused(f"{SESSION_RECORD} exists in {base.name}: prepare --step fetch ran on this base already, and a "
                      "base has one session", field="session") from None
    return record


def session_record_problems(base, official, campaign_id):
    """(record or None, problems) of logs/session.json against the base's configuration copy and campaign id."""
    base = Path(base)
    record = read_json_file(base / SESSION_RECORD)
    if record is None:
        return None, [f"{SESSION_RECORD} is missing or not a JSON object"]
    problems = []
    if tuple(sorted(record)) != tuple(sorted(SESSION_RECORD_KEYS)) or record.get("schema") != 1:
        problems.append(f"{SESSION_RECORD}: the keys are not exactly {list(SESSION_RECORD_KEYS)} with schema 1")
    if not (isinstance(record.get("session_id"), str) and SESSION.fullmatch(record["session_id"])):
        problems.append(f"{SESSION_RECORD}: session_id {record.get('session_id')!r} does not look like "
                        "session-<UTC compact>-<4 hex>")
    if record.get("campaign_id") != campaign_id:
        problems.append(f"{SESSION_RECORD}: campaign_id {record.get('campaign_id')!r} is not {campaign_id!r}")
    name = configuration_name(official)
    if record.get("configuration") != name:
        problems.append(f"{SESSION_RECORD}: configuration {record.get('configuration')!r} is not {name!r}")
    elif not (base / name).is_file() or record.get("configuration_sha256") != sha256_file(base / name):
        problems.append(f"{SESSION_RECORD}: configuration_sha256 is not the digest of {name}")
    return record, problems


def session_from_base(base, roles, official=False, campaign_id=None):
    """The session of an attempt whose configuration names none: the one `prepare --step fetch` minted for this base
    (logs/session.json), which the identity files of the roles must carry (finalize writes it into them). A base
    without the record (prepared before the session was minted per base) takes the session the identity files
    agree on; a session is minted only where neither exists, and then the identity check of the engine still binds
    the files to it."""
    sessions = set()
    for role in roles:
        path = Path(base) / "roots" / role / "stack-identity.toml"
        if path.is_file():
            sessions.add(read_identity_file(base, role).get("session_id"))
    if len(sessions) > 1 or None in sessions:
        raise Refused(f"the identity files of the roles carry different or no session ids: {sorted(map(str, sessions))}",
                      field="session_id")
    if (Path(base) / SESSION_RECORD).exists():
        record, problems = session_record_problems(base, official, campaign_id)
        if problems:
            raise Refused("the session record of the base is not valid: " + "; ".join(problems), field="session",
                          problems=problems)
        if sessions and sessions != {record["session_id"]}:
            raise Refused(f"the identity files carry the session {sorted(sessions)}, {SESSION_RECORD} "
                          f"{record['session_id']!r}", field="session_id")
        return record["session_id"]
    return next(iter(sessions)) if sessions else mint_session_id()


def plan_session(configured, base, roles, official, campaign_id):
    """The one session of an attempt: a session_id of the configuration (an attempt prepared before sessions were
    minted per base; such a base has no session record), else the base's own (`session_from_base`)."""
    if configured:
        if (Path(base) / SESSION_RECORD).exists():
            raise Refused(f"the configuration names campaign.session_id {configured!r} but the base has its own "
                          f"session in {SESSION_RECORD}: remove session_id from the configuration",
                          field="campaign.session_id")
        return configured
    return session_from_base(base, roles, official, campaign_id)


def build_roles(sched, base, arms, stack_b, lock, julia_bins, bundled_depot=""):
    """The RoleSpecs of the roles in use; the installation id of each is the one of its stack-identity.toml."""
    roles = {}
    for arm in arms:
        for letter, role in ARM_ROLES[arm].items():
            stack = "B" if (role == "ab-b" and stack_b) else "A"
            ident = read_identity_file(base, role)
            installation = ident.get("installation")
            if not (isinstance(installation, str) and INSTALLATION.fullmatch(installation)):
                raise Refused(f"identity of {role}: installation {installation!r} is not valid")
            roles[role] = RoleSpec(
                name=role, installation=installation,
                checkout=base / "installations" / role / "ProximalSolvers.jl", depot=base / "depots" / role,
                environments={mm: base / "environments" / role / f"env-{mm}" for mm in sched["strata"]},
                julia={mm: Path(julia_bins[mm]) for mm in sched["strata"]}, bundled_depot=bundled_depot,
                expected=expected_identity(sched, stack, lock))
    ids = [spec.installation for spec in roles.values()]
    if len(set(ids)) != len(ids):
        raise Refused(f"two roles share an installation id: {sorted(ids)}")
    return roles


def plan_from_lock(lock, base, julia_bins, parent_env, freeze_sha, bundled_depot=""):
    """The plan of an official run. `base/schedule.toml` is the copy the campaign uses."""
    base = Path(base)
    for name in ("schedule.toml", "case-mapping.toml"):
        if not (base / name).is_file() or sha256_file(base / name) != sha256_file(HERE / name):
            raise Refused(f"{name} of the base is not the committed file", field=name)
    sched = mc.load_schedule(base / "schedule.toml")
    lock = parse_lock(copy.deepcopy(lock), strata=list(sched["strata"]))
    if "stack_b" not in lock:
        raise Refused("the lock has no [stack_b] candidate", field="stack_b")
    if lock["campaign"]["id"] != sched["campaign_id"]:
        raise Refused(f"lock campaign {lock['campaign']['id']!r} is not the schedule's {sched['campaign_id']!r}",
                      field="campaign.id")
    arms = schedule_arms(base)
    roles = build_roles(sched, base, arms, True, lock, julia_bins, bundled_depot)
    session = plan_session(lock["campaign"].get("session_id"), base, roles, True, sched["campaign_id"])
    return Plan(base=base, sched=sched, official=True, campaign_id=sched["campaign_id"], session_id=session,
                arms=arms, roles=roles, cpu=sched["machine"]["logical_cpu"],
                case_filter=sched["settings"]["case_filter"], parent_env=dict(parent_env), lock=lock,
                freeze_sha=freeze_sha)


def plan_from_pilot(config, base, julia_bins, parent_env, arms=None, bundled_depot=""):
    """The plan of a pilot: stack B is a second independent installation of stack A; never official."""
    base = Path(base)
    if "pilot" not in base.name:
        raise LockRefusal("base", f"the base directory name {base.name!r} lacks pilot")
    if not (base / "case-mapping.toml").is_file() or sha256_file(base / "case-mapping.toml") != sha256_file(
            HERE / "case-mapping.toml"):
        raise Refused("case-mapping.toml of the base is not the committed file", field="case-mapping.toml")
    sched = mc.load_schedule(base / "schedule.toml")
    official = mc.load_schedule(HERE / "schedule.toml")
    config = parse_pilot(copy.deepcopy(config), official)
    if sched["id"] != config["schedule"]["id"] or sched["id"] == official["id"] or "-pilot" not in sched["id"]:
        raise LockRefusal("schedule.id", f"the schedule copy {sched['id']!r} is not the pilot schedule "
                          f"{config['schedule']['id']!r}")
    if sched["campaign_id"] != config["campaign"]["id"] or sched["campaign_id"] == official["campaign_id"]:
        raise LockRefusal("campaign.id", f"the schedule copy's campaign {sched['campaign_id']!r} is not the pilot's "
                          f"{config['campaign']['id']!r}")
    chosen = tuple(a for a in ARMS if a in (arms or config["pilot"]["arms"]))
    if not chosen or not set(chosen) <= set(config["pilot"]["arms"]):
        raise LockRefusal("pilot.arms", f"arms {chosen} are not among the configured {config['pilot']['arms']}")
    if chosen != schedule_arms(base):
        raise LockRefusal("pilot.arms", f"arms {chosen} differ from the arms {schedule_arms(base)} of the "
                          "schedule copy")
    problems = pilot_schedule_problems(config, sched, official, schedule_arms(base))
    if problems:
        raise Refused("the pilot schedule does not match the pilot configuration: " + "; ".join(problems),
                      field="pilot.schedule", problems=problems)
    roles = build_roles(sched, base, chosen, False, None, julia_bins, bundled_depot)
    session = plan_session(config["campaign"].get("session_id"), base, roles, False, sched["campaign_id"])
    return Plan(base=base, sched=sched, official=False, campaign_id=sched["campaign_id"], session_id=session,
                arms=chosen, roles=roles, cpu=sched["machine"]["logical_cpu"],
                case_filter=sched["settings"]["case_filter"], parent_env=dict(parent_env))


def process_order(plan):
    """Every process in the order it runs: per stratum in schedule order, per arm (AB then AA), per repetition,
    per block the roles in orders[rep] (AB: role A first)."""
    keys = []
    for mm in plan.sched["strata"]:
        for arm in plan.arms:
            for rep in plan.sched["reps"]:
                letters = "AB" if plan.sched["orders"][rep] == "AB" else "BA"
                keys += [Key(arm, ARM_ROLES[arm][letter], mm, rep) for letter in letters]
    return keys


def bundled_of(spec, mm):
    """The bundled depot entries of the Julia installation of stratum `mm`."""
    bundled = spec.bundled_depot
    return bundled.get(mm, "") if isinstance(bundled, dict) else bundled


def launch_env(plan, spec, mm, rep):
    """The measurement environment: a whitelist, never the parent environment."""
    env = {name: plan.parent_env[name] for name in ENV_PASSTHROUGH if name in plan.parent_env}
    env.update({name: plan.parent_env[name] for name in JOB_ID_VARIABLES if name in plan.parent_env})
    s = plan.sched["settings"]
    bundled = bundled_of(spec, mm)
    depots = str(spec.depot) + (f":{bundled}" if bundled else "")
    env.update({
        "JULIA_NUM_THREADS": "1", "OPENBLAS_NUM_THREADS": "1", "JULIA_LOAD_PATH": "@:@stdlib",
        "JULIA_DEPOT_PATH": depots, "JULIA_PKG_OFFLINE": "true",
        "PS_SUITE": s["suite"], "PS_GROUPS": s["groups"], "PS_SAMPLES": str(s["samples_target"]),
        "PS_SECONDS": repr(float(s["seconds_limit"])), "PS_CASE_SECONDS": repr(float(s["case_seconds"])),
        "PS_PROFILE_SECONDS": repr(float(s["profile_seconds"])), "PS_CASES": plan.case_filter,
        "PS_REPETITION": str(rep), "PS_OUTPUT": str(plan.raw(spec.name, mm)),
        "PS_EXPECTED_PACKAGE_ROOT": str(spec.checkout)})
    return env


REDACTED_ENV = ("HOME", "USER", "LOGNAME", "TMPDIR")


def redacted_env(env):
    """The environment as the evidence records it: personal values are replaced, the process gets the real ones."""
    return {k: ("<redacted>" if k in REDACTED_ENV else v) for k, v in env.items()}


def launch_argv(plan, spec, mm):
    return ["taskset", "-c", str(plan.cpu), str(spec.julia[mm]), "--startup-file=no", "--history-file=no",
            f"--project={spec.environments[mm]}", f"{spec.checkout}/benchmark/run.jl"]


# --------------------------------------------------------------------------------------- hooks, machine

@dataclasses.dataclass
class RunResult:
    exit: int
    stdout: bytes = b""
    stderr: bytes = b""


@dataclasses.dataclass
class Hooks:
    """Everything the engine takes from Julia or the host.

    probe(spec, mm) -> observation dictionary (keys documented at `preflight_checks`)
    runner(argv, env, cwd, cpu) -> RunResult (a negative exit means killed by a signal)
    clock() -> timezone-aware datetime, read immediately before and after the runner call
    sampler() -> {"cpu_model", "governor", "epp", "no_turbo", "smt_control"} (absent sysfs files "unavailable")
    julia_bins: {stratum: path of the exact Julia binary}
    datahash_ok(role, stratum, rep) -> bool: the exporter's data_hash sidecar equals the process's metrics.tsv
    depot_digest(spec) -> a digest of the depot's compiled/ directory; any change between processes stops the run
    probe_log() -> the commands the probe ran since the last call, each {"kind", "argv", "exit", "start_utc",
        "end_utc"} (PROBE_COMMAND_KEYS), and forgets them; the engine writes them into logs/probes.jsonl. Hooks
        without it leave `commands` null in the record, which `verify` rejects.
    export: used by prepare (the fingerprint exporter), not by the engine"""
    probe: object
    runner: object
    clock: object = utc_now
    sampler: object = None
    julia_bins: dict = dataclasses.field(default_factory=dict)
    datahash_ok: object = None
    depot_digest: object = None
    probe_log: object = None
    export: object = None


def sample_machine(cpu, root="/"):
    """The machine values of this host; a file that does not exist is recorded as "unavailable"."""
    root = Path(root)

    def read(relative):
        try:
            return (root / relative).read_text(encoding="utf-8").strip() or "unavailable"
        except OSError:
            return "unavailable"
    model = "unavailable"
    try:
        for line in (root / "proc/cpuinfo").read_text(encoding="utf-8").splitlines():
            if line.startswith("model name"):
                model = line.partition(":")[2].strip()
                break
    except OSError:
        pass
    freq = f"sys/devices/system/cpu/cpu{cpu}/cpufreq"
    return {"cpu_model": model, "governor": read(f"{freq}/scaling_governor"),
            "epp": read(f"{freq}/energy_performance_preference"),
            "no_turbo": read("sys/devices/system/cpu/intel_pstate/no_turbo"),
            "smt_control": read("sys/devices/system/cpu/smt/control")}


def check_machine_object(machine):
    """The checks the receipt applies to a process event's `machine` object; ValueError when they fail."""
    if not (isinstance(machine, dict) and tuple(machine) == MACHINE_KEYS
            and isinstance(machine["logical_cpu"], int) and not isinstance(machine["logical_cpu"], bool)
            and all(isinstance(machine[k], str) for k in MACHINE_KEYS if k != "logical_cpu")):
        raise ValueError(f"machine must have exactly the keys {MACHINE_KEYS}, strings except logical_cpu "
                         f"(an integer): {machine!r}")


def machine_record(sample, cpu_name, logical_cpu):
    """The `machine` object of a receipt process event (cpu is Sys.CPU_NAME from the probe). The same checks as
    the receipt's run here, so that an invalid sample is found before a process is launched."""
    missing = [k for k in SAMPLE_KEYS if k not in sample]
    if missing:
        raise ValueError(f"the machine sample lacks {missing}")
    record = {"cpu_model": sample["cpu_model"], "cpu": cpu_name, "logical_cpu": logical_cpu,
              "governor": sample["governor"], "epp": sample["epp"], "no_turbo": sample["no_turbo"],
              "smt_control": sample["smt_control"]}
    check_machine_object(record)
    return record


# --------------------------------------------------------------------------------------- preflight

def _dig(observation, path):
    value = observation
    for part in path.split("."):
        if not isinstance(value, dict) or part not in value:
            return None
        value = value[part]
    return value


OBSERVATION_SCHEMA = {
    "julia": {"version": str, "commit": str, "cpu_name": str},
    "ps": {"commit": str, "tree": str, "version": str, "dirty": bool, "loaded_realpath": str, "package_hash": str},
    "pb": {"loaded_tree": str, "manifest_tree": str, "version": str, "package_hash": str},
    "checkout_realpath": str, "depot_realpath": str,
    "environment": {"dir": str, "realpath": str, "project_exists": bool, "manifest_exists": bool},
    "manifest_sha256": str, "project_sha256": str, "harness_hash": str, "affinity_cpus": list,
    "machine": {"cpu_model": str, "cpu": str, "logical_cpu": int}}
ABSOLUTE_KEYS = ("ps.loaded_realpath", "checkout_realpath", "depot_realpath", "environment.dir",
                 "environment.realpath")


def validate_observation(observation, where):
    """Problems of one observation against OBSERVATION_SCHEMA: every key required and typed, paths absolute and
    non-empty, the two digests 64 lowercase hex, the affinity a list of integers."""
    problems = []

    def walk(schema, value, prefix):
        for key, kind in schema.items():
            path = f"{prefix}{key}"
            if not isinstance(value, dict) or key not in value:
                problems.append(f"OBSERVATION: {where}: {path} is missing")
            elif isinstance(kind, dict):
                walk(kind, value[key], path + ".")
            elif not isinstance(value[key], kind) or (kind is int and isinstance(value[key], bool)) or (
                    kind is str and value[key] == ""):
                problems.append(f"OBSERVATION: {where}: {path} has the wrong type or is empty")
    walk(OBSERVATION_SCHEMA, observation, "")
    for path in ABSOLUTE_KEYS:
        value = _dig(observation, path)
        if isinstance(value, str) and not value.startswith("/"):
            problems.append(f"OBSERVATION: {where}: {path} is not an absolute path")
    for path in ("manifest_sha256", "project_sha256"):
        value = _dig(observation, path)
        if isinstance(value, str) and not HEX64.fullmatch(value):
            problems.append(f"OBSERVATION: {where}: {path} is not 64 lowercase hex")
    cpus = _dig(observation, "affinity_cpus")
    if isinstance(cpus, list) and not all(isinstance(c, int) and not isinstance(c, bool) for c in cpus):
        problems.append(f"OBSERVATION: {where}: affinity_cpus must be a list of integers")
    return problems


def pseudo_root(spec, observation):
    """A root dictionary of the shape `migration_compare.check_independent` reads, built from an observation."""
    strata, inv, procs = {}, {}, {}
    for mm, obs in observation.items():
        def text(path, fallback):               # an absent field never skips the comparison: the plan's value stands in
            value = _dig(obs, path)
            return value if isinstance(value, str) and value.startswith("/") else str(fallback)
        env = text("environment.dir", spec.environments[mm])
        checkout, depot = text("checkout_realpath", spec.checkout), text("depot_realpath", spec.depot)
        env_real = text("environment.realpath", env)
        strata[mm] = {"inv": {"depot_path": [str(spec.depot)], "depot_realpath": norm(depot),
                              "active_project": f"{env}/Project.toml",
                              "active_project_realpath": f"{norm(env_real)}/Project.toml",
                              "proximalsolvers_dir": norm(checkout)},
                      "procs": {0: {"meta": {"proximalsolvers_path": str(spec.checkout),
                                             "expected_package_root": str(spec.checkout)}}}}
        if bundled_of(spec, mm):
            strata[mm]["inv"]["depot_path"].append(bundled_of(spec, mm))
    return {"name": ROLE_LABEL[spec.name], "ident": {"installation": spec.installation}, "strata": strata}


def preflight_checks(plan, observations):
    """Every problem of the observations against the plan, never only the first (an empty list: ready).

    `observations` maps (role, stratum) to a dictionary:

        julia           {version, commit, cpu_name}        the binary that will run
        ps              {commit, tree, version, dirty, loaded_realpath, package_hash}
        pb              {loaded_tree, manifest_tree, version, package_hash}
        checkout_realpath, depot_realpath                  realpaths of the role's checkout and first depot
        environment     {dir, realpath, project_exists, manifest_exists}
        manifest_sha256, project_sha256, harness_hash     (both digests: 64 lowercase hex, required)
        affinity_cpus   the CPUs the pinned launch is restricted to (a list of integers)
        machine         {cpu_model, cpu, logical_cpu}

    Each problem is `<CODE>: <role> <stratum>: <detail>`; the codes are JULIA_VERSION, JULIA_COMMIT, PS_VERSION,
    PB_VERSION, PS_COMMIT, PS_TREE, DIRTY, PB_TREE, PS_PATH, MANIFEST_SHA256, ENV_MISSING, AFFINITY, CASE_FILTER,
    HARNESS_HASH, PACKAGE_HASH, MACHINE, SHARED and OBSERVATION (a key that is absent or of the wrong type).
    The policy values (governor, epp, no_turbo, smt_control) are labelled, not refused."""
    problems, sched = [], plan.sched
    wanted = {(role, mm) for role in plan.role_names() for mm in sched["strata"]}
    for role, mm in sorted(wanted - set(observations)):
        problems.append(f"OBSERVATION: {role} {mm}: no observation")
    for role, mm in sorted(set(observations) - wanted):
        problems.append(f"OBSERVATION: {role} {mm}: not a role or stratum of the plan")
    observations = {k: v for k, v in observations.items() if k in wanted}
    for (role, mm), obs in sorted(observations.items()):
        problems += validate_observation(obs, f"{role} {mm}")
    if plan.case_filter != sched["settings"]["case_filter"]:
        problems.append("CASE_FILTER: the case filter of the plan is not the schedule's case_filter byte for byte")
    for (role, mm), obs in sorted(observations.items()):
        spec = plan.roles[role]
        where = f"{role} {mm}"
        want, version = spec.expected, sched["strata"][mm]

        def need(code, path, expected, label=None):
            seen = _dig(obs, path)
            if seen is None:
                problems.append(f"OBSERVATION: {where}: {path} is missing")
            elif seen != expected:
                problems.append(f"{code}: {where}: {label or path} is {seen!r}, expected {expected!r}")
            return seen
        need("JULIA_VERSION", "julia.version", version["version"])
        need("JULIA_COMMIT", "julia.commit", version["commit"])
        need("PS_VERSION", "ps.version", want["ps"]["version"])
        need("PB_VERSION", "pb.version", want["pb"]["version"])
        need("PS_COMMIT", "ps.commit", want["ps"]["commit"])
        need("PS_TREE", "ps.tree", want["ps"]["tree"])
        need("DIRTY", "ps.dirty", False, "dirty (tracked, untracked or ignored files)")
        for path in ("pb.loaded_tree", "pb.manifest_tree"):
            need("PB_TREE", path, want["pb"]["tree"])
        checkout = _dig(obs, "checkout_realpath")
        if checkout is None:
            problems.append(f"OBSERVATION: {where}: checkout_realpath is missing")
        else:
            need("PS_PATH", "ps.loaded_realpath", checkout, "loaded ProximalSolvers realpath")
        if mm in want["manifest_sha256"]:
            need("MANIFEST_SHA256", "manifest_sha256", want["manifest_sha256"][mm])
        if mm in want["project_sha256"]:
            need("PROJECT_SHA256", "project_sha256", want["project_sha256"][mm])
        need("HARNESS_HASH", "harness_hash", want["harness_hash"])
        need("PACKAGE_HASH", "ps.package_hash", want["ps"]["package_hash"], "ProximalSolvers package hash")
        need("PACKAGE_HASH", "pb.package_hash", want["pb"]["package_hash"], "ProximalBase package hash")
        need("AFFINITY", "affinity_cpus", [plan.cpu])
        for path in ("environment.project_exists", "environment.manifest_exists"):
            if _dig(obs, path) is False:
                problems.append(f"ENV_MISSING: {where}: {path.split('.')[1]} is missing")
            elif not isinstance(_dig(obs, path), bool):
                problems.append(f"OBSERVATION: {where}: {path} is missing")
        machine = sched["machine"]
        need("MACHINE", "machine.cpu_model", machine["cpu_model"])
        need("MACHINE", "machine.cpu", machine["cpu"][mm])
        need("MACHINE", "machine.logical_cpu", plan.cpu)
    by_role = {}
    for (role, mm), obs in observations.items():
        by_role.setdefault(role, {})[mm] = obs
    names = sorted(by_role)
    for index, first in enumerate(names):
        for second in names[index + 1:]:
            ref = []
            one, two = pseudo_root(plan.roles[first], by_role[first]), pseudo_root(plan.roles[second], by_role[second])
            mc.check_independent("ab", one, two, sched, ref, named=True)
            for _, _, _, detail in sorted(set(ref)):
                problems.append(f"SHARED: {first} and {second}: {detail}")
    return list(dict.fromkeys(problems))


# ------------------------------------------------------------------------------------- identity writer

def write_identity(base, role, installation, campaign_id, session_id, ps, pb):
    """roots/<role>/stack-identity.toml (spec section 11, exact keys); never overwrites."""
    if role not in ROLES:
        raise ValueError(f"unknown role {role!r}")
    if not (isinstance(installation, str) and INSTALLATION.fullmatch(installation)):
        raise ValueError(f"installation {installation!r} must match [A-Za-z0-9._-]+")
    for value in (campaign_id, session_id):
        if not is_text(value):
            raise ValueError("campaign_id and session_id must be non-empty strings")
    for name, table, keys in (("proximalsolvers", ps, ("commit", "tree", "version")),
                              ("proximalbase", pb, ("commit", "tree", "version", "release"))):
        extra = set(table) - set(keys) - ({"tag"} if name == "proximalbase" else set())
        if extra or set(keys) - set(table):
            raise ValueError(f"{name}: keys must be {keys}")
        for key in ("commit", "tree"):
            if not is_hex40(table[key]):
                raise ValueError(f"{name}.{key} must be 40 lowercase hex characters")
        if not all(is_text(table[k]) for k in table):
            raise ValueError(f"{name}: values must be non-empty strings")
    if pb["release"] not in ("registered", "development"):
        raise ValueError("release must be registered or development")
    if pb["release"] == "registered" and "tag" not in pb:
        raise ValueError("a registered release needs its tag")
    data = {"schema": 1, "installation": installation, "campaign_id": campaign_id, "session_id": session_id,
            "proximalsolvers": dict(ps), "proximalbase": dict(pb)}
    directory = Path(base) / "roots" / role
    directory.mkdir(parents=True, exist_ok=True)
    path = directory / "stack-identity.toml"
    write_toml(path, data)
    return path


# ------------------------------------------------------------------------------------------- receipt

PROCESS_KEYS = ("event", "arm", "role", "julia", "rep", "block", "installation", "start_utc", "end_utc", "exit",
                "complete", "machine")
CAMPAIGN_KEYS = ("event", "campaign_id", "session_id", "schedule_id", "utc")
TIME_TEXT = re.compile(r"[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}\.[0-9]{3}[+-][0-9]{2}:[0-9]{2}")


class Receipt:
    """receipt.jsonl: exclusive create, append only, each line flushed and synced.

    One `campaign` event first, then exactly one `process` event for every launched process, including those that
    failed (exit other than 0 or 2, complete false). No other event type. A reading of the clock is recorded as it
    was taken: if the end collides with the start the comparator refuses, the driver does not adjust it."""

    def __init__(self, path):
        self.path = Path(path)
        create_exclusive(self.path)
        self.campaign_done = False

    def campaign(self, campaign_id, session_id, schedule_id, moment):
        if self.campaign_done:
            raise RuntimeError("the campaign event is written once")
        for value in (campaign_id, session_id, schedule_id):
            if not is_text(value):
                raise ValueError("campaign_id, session_id and schedule_id must be non-empty strings")
        append_jsonl(self.path, {"event": "campaign", "campaign_id": campaign_id, "session_id": session_id,
                                 "schedule_id": schedule_id, "utc": utc_text(moment)})
        self.campaign_done = True

    def process(self, arm, role, julia, rep, installation, start, end, exit, complete, machine):
        if not self.campaign_done:
            raise RuntimeError("the campaign event comes first")
        if arm not in ARMS or role not in ("A", "B"):
            raise ValueError("arm must be AB or AA and role A or B")
        if not (isinstance(exit, int) and not isinstance(exit, bool) and isinstance(complete, bool)
                and isinstance(rep, int) and not isinstance(rep, bool) and is_text(julia)
                and is_text(installation)):
            raise ValueError("a process event has wrong types")
        check_machine_object(machine)
        append_jsonl(self.path, {"event": "process", "arm": arm, "role": role, "julia": julia, "rep": rep,
                                 "block": rep, "installation": installation, "start_utc": utc_text(start),
                                 "end_utc": utc_text(end), "exit": exit, "complete": complete,
                                 "machine": dict(machine)})


# --------------------------------------------------------------------------------- evidence and checksums

def evidence_paths(base):
    """Every file of BASE that is evidence, as sorted POSIX paths relative to BASE: everything except the private
    installations, environments and depots, the checksum listing itself and verification.json."""
    base = Path(base)
    found = []
    for folder, directories, names in os.walk(base):
        relative = Path(folder).relative_to(base)
        if relative == Path("."):
            directories[:] = [d for d in directories if d not in PRIVATE_DIRECTORIES]
        for name in names:
            path = (relative / name).as_posix() if relative != Path(".") else name
            if path in ("checksums.sha256", "verification.json"):
                continue
            found.append(path)
    return sorted(found)


def checksum_text(base):
    return "".join(f"{sha256_file(Path(base) / p)}  {p}\n" for p in evidence_paths(base))


def write_checksums(base):
    path = Path(base) / "checksums.sha256"
    if path.exists():
        path.chmod(0o644)
        path.unlink()
    path.write_text(checksum_text(base), encoding="utf-8")
    path.chmod(0o444)


def read_checksums(path):
    entries = {}
    for number, line in enumerate(Path(path).read_text(encoding="utf-8").splitlines(), 1):
        match = re.fullmatch(r"([0-9a-f]{64})  (.+)", line)
        if not match:
            raise ValueError(f"checksums.sha256 line {number} is malformed")
        entries[match[2]] = match[1]
    return entries


# ------------------------------------------------------------------------------------------ sealing

class SealProblem(Exception):
    """A process left records that cannot be sealed: the attempt stops."""


def stem_files(stem):
    return {f"{stem}-{kind}.{'toml' if kind.startswith('metadata') else 'tsv'}" for kind in RECORD_KINDS}


def read_seals(base):
    path = Path(base) / "logs" / "seals.jsonl"
    return read_jsonl(path) if path.exists() else []


def verify_seals(base, check_mode=True):
    """Problems with the sealed files: one that is missing, changed or not read-only."""
    problems = []
    for seal in read_seals(base):
        path = Path(base) / seal["file"]
        if not path.is_file():
            problems.append(f"sealed file {seal['file']} is missing")
        elif sha256_file(path) != seal["sha256"]:
            problems.append(f"sealed file {seal['file']} changed")
        elif check_mode and stat.S_IMODE(path.stat().st_mode) != 0o444:
            problems.append(f"sealed file {seal['file']} is not read-only (mode "
                            f"{stat.S_IMODE(path.stat().st_mode):04o})")
    return problems


def prefix_files(raw, stem):
    raw = Path(raw)
    return sorted(p.name for p in raw.iterdir() if p.name.startswith(stem + "-")) if raw.is_dir() else []


def seal_process(plan, key, exit_code, seconds):
    """After a process: exactly the six record files (and an allowed -profiles.txt) for its stem and nothing
    else new in raw/; exit 0 or 2 consistent with the final metadata; digests into logs/seals.jsonl; mode 0444.

    Returns the failed case ids of the process (exit 2: kept, reported, never retried). Anything else raises
    SealProblem and the attempt stops with everything preserved."""
    raw, stem = plan.raw(key.role, key.mm), plan.stem(key.mm, key.rep)
    if exit_code not in (0, 2):
        raise SealProblem(f"{key.name} exited with {exit_code}")
    present, wanted = set(prefix_files(raw, stem)), stem_files(stem)
    if not wanted <= present or present - wanted - {f"{stem}{PROFILES}"}:
        raise SealProblem(f"{key.name}: raw/ files {sorted(present ^ wanted)} differ from the six record files")
    sealed = {s["file"] for s in read_seals(plan.base)}
    known = {Path(f).name for f in sealed}
    others = {p.name for p in raw.iterdir()} - present - known
    if others:
        raise SealProblem(f"{key.name}: unexpected entries in raw/: {sorted(others)}")
    try:
        meta = tomllib.loads((raw / f"{stem}-metadata.toml").read_text(encoding="utf-8"))
    except (OSError, UnicodeDecodeError, tomllib.TOMLDecodeError) as error:
        raise SealProblem(f"{key.name}: the final metadata is unreadable: {error}") from error
    nonok, elapsed = meta.get("nonok_cases"), meta.get("elapsed_s")
    if meta.get("finished") is not True:
        raise SealProblem(f"{key.name}: the final metadata says the process did not finish")
    if not (isinstance(nonok, int) and not isinstance(nonok, bool) and nonok >= 0):
        raise SealProblem(f"{key.name}: nonok_cases is {nonok!r}")
    if (exit_code == 0) != (nonok == 0):
        raise SealProblem(f"{key.name}: exit {exit_code} with nonok_cases {nonok}")
    if not (isinstance(elapsed, (int, float)) and not isinstance(elapsed, bool) and math.isfinite(elapsed)
            and 0 <= elapsed <= seconds):
        raise SealProblem(f"{key.name}: elapsed_s {elapsed!r} is not within the receipt interval of {seconds} s")
    failed = []
    if exit_code == 2:
        header, rows = read_tsv(raw / f"{stem}-metrics.tsv")
        failed = [row[header.index("id")] for row in rows if row[header.index("status")] != "ok"]
    log = plan.base / "logs" / "seals.jsonl"
    for name in sorted(present):
        path = raw / name
        digest = sha256_file(path)
        path.chmod(0o444)
        append_jsonl(log, {"file": path.relative_to(plan.base).as_posix(), "sha256": digest,
                           "size": path.stat().st_size, "process": key.name})
    return failed


def seal_file(base, relative, process):
    """Seal one more file (completion.json): digest into seals.jsonl, mode 0444."""
    path = Path(base) / relative
    digest = sha256_file(path)
    path.chmod(0o444)
    append_jsonl(Path(base) / "logs" / "seals.jsonl", {"file": relative, "sha256": digest,
                                                       "size": path.stat().st_size, "process": process})


# ------------------------------------------------------------------------------- declared differences

def _mapping_rows(base):
    data = tomllib.loads((Path(base) / "case-mapping.toml").read_text(encoding="utf-8"))
    return data.get("case", [])


def _single(root, key, label, problems):
    values = mc.meta_values(root, key, usable=False)
    if len(values) != 1:
        problems.append(f"{label}: metadata {key} has {len(values)} distinct values")
        return None
    return next(iter(values))


def declared_differences(base, lock):
    """The declared-differences file of BASE as a dict.

    The OBSERVED differences come from the comparator's own readers (`read_root`, `manifest_diff`) applied to the
    roots ab-a and ab-b; every reason, approval URL, port commit and changed-lines entry comes from the lock. A
    difference without a declaration, a declaration of a difference that is not observed, a missing reason, and a
    pair that cannot be declared (the commits differ but the trees do not) raise DeclaredRefusal; nothing is
    invented and nothing is approved here. No difference at all gives {"schema": 1}. Without a lock (a pilot)
    any observed difference is a refusal."""
    base = Path(base)
    sched = mc.load_schedule(base / "schedule.toml")
    ref = []
    roots = {name: mc.read_root(name, base / "roots" / role, sched, ref, stack_a=name != "b")
             for name, role in (("a", "ab-a"), ("b", "ab-b"))}
    if ref:
        raise DeclaredRefusal("the roots cannot be read: " + "; ".join(f"{c} {f}: {d}" for _, c, f, d in ref[:5]),
                              field="roots", problems=[f"{c} {f}: {d}" for _, c, f, d in ref])
    problems, declared = [], {"schema": 1}
    lock = lock or {}
    stack_b = lock.get("stack_b")
    observed = {}
    for table in ("proximalsolvers", "proximalbase"):
        sides = {}
        for side, root in roots.items():
            ident = root["ident"]
            package = _single(root, f"{table}_hash", f"{table} root {side}", problems)
            sides[side] = {"commit": ident[table]["commit"], "tree": ident[table]["tree"], "package_hash": package}
            if table == "proximalbase":
                sides[side]["version"] = ident[table]["version"]
                for meta_version in mc.meta_values(root, "proximalbase_version", usable=False):
                    if meta_version != ident[table]["version"]:
                        problems.append(f"{table} root {side}: metadata version {meta_version!r} differs from the "
                                        "identity")
            else:
                for sha in mc.meta_values(root, "proximalsolvers_sha", usable=False):
                    if sha != ident[table]["commit"]:
                        problems.append(f"{table} root {side}: metadata sha differs from the identity commit")
        observed[table] = sides
        fields = list(sides["a"])
        differing = [f for f in fields if sides["a"][f] != sides["b"][f]]
        if stack_b is not None:
            for f in fields:
                if sides["b"][f] != stack_b[table][f]:
                    problems.append(f"{table}: root b {f} {sides['b'][f]!r} differs from the lock "
                                    f"{stack_b[table][f]!r}")
        if not differing:
            continue
        if len(differing) != len(fields):
            problems.append(f"{table}: {sorted(set(fields) - set(differing))} are equal in both roots while "
                            f"{differing} differ; such a pair cannot be declared")
            continue
        keys = (["a_version", "b_version"] if table == "proximalbase" else []) + [
            "a_commit", "b_commit", "a_tree", "b_tree", "a_package_hash", "b_package_hash"]
        declared[table] = {k: sides[k[0]][k[2:]] for k in keys}
    strata = list(sched["strata"])
    lock_entries = lock.get("declared", [])
    parse_lock({"schema": 1, "campaign": {"id": "scope-check"}, "declared": lock_entries}, strata=strata)
    used = set()

    def match(kind, name, uuid=None, change=None):
        for index, entry in enumerate(lock_entries):
            if entry["kind"] == kind and entry["name"] == name and (kind == "compat" or (
                    entry["uuid"] == uuid and entry["change"] == change)):
                yield index, entry
    def associate(label, observed, find, make_row):
        """Match the lock's declarations with the observed differences PER STRATUM. A declaration's `julia` scope
        selects the strata it covers (unscoped: all). Every observed (key, stratum) needs exactly one covering
        declaration; a declaration for a stratum where the key is not observed is a refusal. A declaration whose
        scope spans strata with different observed values becomes one row per value group."""
        rows = []
        for key in sorted({k for per in observed.values() for k in per}):
            covering = {mm: [] for mm in strata}
            for index, entry in find(key):
                used.add(index)
                by_value = {}
                for mm in entry.get("julia", strata):
                    value = observed[mm].get(key)
                    if value is None:
                        problems.append(f"{label} {key[0]}: declared for julia {mm}, where it is not observed")
                        continue
                    covering[mm].append(index)
                    by_value.setdefault(value, []).append(mm)
                for value, scope in sorted(by_value.items()):
                    rows.append((key, value, make_row(key, value, entry, scope)))
            for mm in strata:
                if key in observed[mm] and not covering[mm]:
                    problems.append(f"{label} {key[0]} julia {mm}: observed, but the lock has no reason for it")
                if len(covering[mm]) > 1:
                    problems.append(f"{label} {key[0]} julia {mm}: declared twice for julia {mm}")
        return [row for _, _, row in sorted(rows, key=lambda r: (r[0], r[1], r[2].get("julia", [])))]

    def scoped(row, scope):
        if sorted(scope) != sorted(strata):
            row["julia"] = list(scope)
        return row
    observed_manifest, observed_compat, exempt = {}, {}, {}
    for mm in strata:
        sa, sb = roots["a"]["strata"][mm], roots["b"]["strata"][mm]
        diff = mc.manifest_diff(sa["manifest"]["entries"], sb["manifest"]["entries"])
        observed_manifest[mm] = {(n, u, k): (av, bv, at, bt) for n, u, k, av, bv, at, bt in diff}
        exempt[mm] = {n for n, _, k, *_ in diff if k in ("added", "removed")}
        pa, pb_ = sa["project"], sb["project"]
        ca, cb = pa["compat"], pb_["compat"]
        observed_compat[mm] = {(n,): (ca.get(n, ""), cb.get(n, "")) for n in ca.keys() | cb.keys()
                               if ca.get(n) != cb.get(n)}
        da, db = pa["deps"], pb_["deps"]
        for name in sorted(n for n in da.keys() | db.keys() if da.get(n) != db.get(n) and n not in exempt[mm]):
            problems.append(f"Project.toml [deps] {name} differs in julia {mm} without an added or removed "
                            "Manifest difference")
    manifest_rows = associate(
        "manifest", observed_manifest, lambda key: match("manifest", key[0], key[1], key[2]),
        lambda key, value, entry, scope: scoped(
            {"name": key[0], "uuid": key[1], "kind": key[2], "a_version": value[0], "b_version": value[1],
             "a_tree": value[2], "b_tree": value[3], "reason": entry["reason"]}, scope))
    compat_rows = associate(
        "compat", observed_compat, lambda key: match("compat", key[0]),
        lambda key, value, entry, scope: scoped(
            {"name": key[0], "a": value[0], "b": value[1], "reason": entry["reason"]}, scope))
    for index, entry in enumerate(lock_entries):
        if index not in used:
            problems.append(f"declared {entry['kind']} {entry['name']}: declared in the lock but not observed")
    if manifest_rows:
        declared["manifest"] = manifest_rows
    if compat_rows:
        declared["compat"] = compat_rows
    hashes = {}
    for side, root in roots.items():
        hashes[side] = _single(root, "harness_hash", f"harness root {side}", problems)
    harness = lock.get("harness")
    if None not in hashes.values() and hashes["a"] != hashes["b"]:
        rows = _mapping_rows(base)
        class_b = [r for r in rows if r.get("class") == "B"]
        if harness is None:
            problems.append("the harness hash differs and the lock has no [harness]")
        else:
            for r in class_b:
                if not (r.get("approved") is True and r.get("approval_url") == harness["approval_url"]):
                    problems.append(f"harness case {r.get('id')}: its mapping approval is not the lock's "
                                    "[harness] approval_url")
            if stack_b is not None and hashes["b"] != stack_b["harness_hash"]:
                problems.append("the harness hash of root b differs from the lock")
            declared["harness"] = {"a_hash": hashes["a"], "b_hash": hashes["b"],
                                   "port_commit": harness["port_commit"], "cases": [r["id"] for r in class_b],
                                   "changed_lines": list(harness["changed_lines"]),
                                   "approval_url": harness["approval_url"]}
    elif harness is not None and None not in hashes.values():
        problems.append("the lock declares a harness difference but the harness hashes are equal")
    if problems:
        raise DeclaredRefusal("declared differences: " + "; ".join(problems[:5]), field="declared",
                              problems=problems)
    return declared


def write_declared_differences(base, lock):
    declared = declared_differences(base, lock)
    path = Path(base) / "declared-differences.toml"
    write_toml(path, declared)
    return declared


# ------------------------------------------------------------------------------------- the comparator

def comparator_argv(base, out):
    base = Path(base)
    argv = ["--a", str(base / "roots" / "ab-a"), "--b", str(base / "roots" / "ab-b"),
            "--mapping", str(base / "case-mapping.toml"),
            "--declared-differences", str(base / "declared-differences.toml"),
            "--receipt", str(base / "receipt.jsonl"), "--schedule", str(base / "schedule.toml")]
    if "AA" in schedule_arms(base):
        argv += ["--aa", str(base / "roots" / "aa-a"), str(base / "roots" / "aa-b")]
    return argv + ["--out", str(out)]


def run_comparator(base, out):
    """migration_compare.py (the only ratio code) on BASE's own copies, always with --schedule and --aa when the
    A/A roots exist. Returns (exit status, standard error text)."""
    stdout, stderr = io.StringIO(), io.StringIO()
    with contextlib.redirect_stdout(stdout), contextlib.redirect_stderr(stderr):
        try:
            code = mc.main(comparator_argv(base, out))
        except SystemExit as stop:
            code = stop.code if isinstance(stop.code, int) else 3
    return code, stderr.getvalue()


LABEL_TOKEN = re.compile(r"<(?:a|b|aa_a|aa_b|receipt|mapping|declared|schedule|out|fingerprints_[ab])>")
TAG_TOKEN = re.compile(r"[^\s/<>'\"]+#[0-9a-f]{8,64}")


def _strip_paths(text):
    return TAG_TOKEN.sub("<path>", LABEL_TOKEN.sub("<path>", text))


def _normalised(value):
    """A JSON value with the path labels removed from every string."""
    if isinstance(value, str):
        return _strip_paths(value)
    if isinstance(value, list):
        return [_normalised(v) for v in value]
    if isinstance(value, dict):
        return {k: _normalised(v) for k, v in value.items()}
    return value


def comparison_summary(out):
    """What two runs of the comparator must agree on: the refusal (class, field) pairs and the CSV rows with
    the path labels removed (the scrub prints a root path as `<a>` or as `basename#tag`)."""
    out = Path(out)
    summary = {"refusals": None, "triples": None, "rows": None, "counts": None, "report": None, "lists": None}
    if (out / "refusals.json").is_file():
        document = json.loads((out / "refusals.json").read_text(encoding="utf-8"))
        summary["refusals"] = sorted((r["class"], r["field"]) for r in document["refusals"])
        summary["triples"] = sorted((r["class"], r["field"], _strip_paths(r["detail"]))
                                    for r in document["refusals"])
    if (out / "report.md").is_file():
        summary["report"] = _strip_paths((out / "report.md").read_text(encoding="utf-8"))
    if (out / "lists.json").is_file():
        summary["lists"] = _normalised(json.loads((out / "lists.json").read_text(encoding="utf-8")))
    if (out / "migration-comparison.csv").is_file():
        table = list(csv.reader(io.StringIO((out / "migration-comparison.csv").read_text(encoding="utf-8"))))
        summary["rows"] = [[_strip_paths(cell) for cell in row] for row in table]
        counts = {}
        if table and "class" in table[0]:
            column = table[0].index("class")
            for row in table[1:]:
                counts[row[column]] = counts.get(row[column], 0) + 1
        summary["counts"] = counts
    return summary


# ------------------------------------------------------------------------------------------- the engine

@dataclasses.dataclass
class Outcome:
    exit_code: int
    state: str
    processes: int = 0
    nonok: list = dataclasses.field(default_factory=list)       # [{"process": name, "failed_cases": [...]}]
    comparator_exit: int = None


def state_text(state, **info):
    return json.dumps({"schema": 1, "state": state, **info}, indent=2) + "\n"


def check_prepared(plan):
    """No formal process without a finished `prepare --step finalize`: logs/finalize.json says `finalized` with no
    problems, and logs/depot-baselines.json holds a digest for every role of the plan."""
    logs = plan.base / "logs"
    marker = read_json_file(logs / "finalize.json")
    if marker is None or marker.get("state") != "finalized" or marker.get("problems") != []:
        state = None if marker is None else (marker.get("state"), marker.get("problems"))
        raise Refused(f"{plan.base.name} is not prepared: logs/finalize.json must say finalized with no problems "
                      f"(found {state!r}); run prepare --step finalize", field="prepare")
    baselines = read_json_file(logs / "depot-baselines.json")
    missing = [r for r in plan.role_names() if not isinstance((baselines or {}).get(r), str) or not baselines[r]]
    if baselines is None or missing:
        raise Refused(f"logs/depot-baselines.json must hold a digest for every role (missing {missing or 'file'})",
                      field="prepare")


def check_fresh(plan):
    """No STATE, receipt, evidence log or raw record may exist: a root, a prefix or a stopped state is refused."""
    base = plan.base
    state = base / "logs" / "STATE.json"
    if state.exists():
        try:
            previous = json.loads(state.read_text(encoding="utf-8")).get("state")
        except (OSError, ValueError):
            previous = "unreadable"
        raise Refused(f"{base.name} already holds a campaign state ({previous}); a BASE is used for one attempt "
                      "and a stopped one is never resumed", field="state")
    stray = ("pilot-config.toml", "logs/pilot-config.toml") if plan.official else ("lock.toml", "logs/lock.toml")
    for relative in stray:
        if (base / relative).exists():
            raise Refused(f"{relative} exists in {'an official' if plan.official else 'a pilot'} base: the "
                          "configuration of the other mode must not be present", field=relative)
    for relative in ("receipt.jsonl", "declared-differences.toml", "comparison", "checksums.sha256",
                     "logs/seals.jsonl", "logs/commands.jsonl", "logs/hardware.jsonl", PROBE_LOG, "logs/campaign.json",
                     "logs/completion.json", "logs/comparator.json"):
        if (base / relative).exists():
            raise Refused(f"{relative} already exists in {base.name}", field=relative)
    for role in plan.role_names():
        for mm in plan.sched["strata"]:
            raw = plan.raw(role, mm)
            leftovers = sorted(p.name for p in raw.iterdir()) if raw.is_dir() else []
            if leftovers:
                raise Refused(f"{role} julia {mm}: raw/ already holds {leftovers[:3]}; an existing prefix is "
                              "never overwritten, deleted or retried", field="raw")


def check_identity_files(plan):
    """Each role's stack-identity.toml binds it to this campaign, session and installation."""
    for role in plan.role_names():
        spec = plan.roles[role]
        ident = read_identity_file(plan.base, role)
        problems = []
        if ident.get("installation") != spec.installation:
            problems.append(f"installation {ident.get('installation')!r}, plan {spec.installation!r}")
        for key, want in (("campaign_id", plan.campaign_id), ("session_id", plan.session_id)):
            if ident.get(key) != want:
                problems.append(f"{key} {ident.get(key)!r}, plan {want!r}")
        for table, key in (("proximalsolvers", "ps"), ("proximalbase", "pb")):
            for field in ("commit", "tree", "version"):
                if (ident.get(table) or {}).get(field) != spec.expected[key][field]:
                    problems.append(f"{table}.{field} differs from the expected identity")
        if problems:
            raise Refused(f"identity of {role}: " + "; ".join(problems), field=f"{role}:identity",
                          problems=problems)


PROBE_LOG = "logs/probes.jsonl"
PROBE_KEYS = ("record", "timed", "phase", "campaign_id", "session_id", "schedule_id", "process", "arm", "role",
              "installation", "julia", "rep", "logical_cpu", "outcome", "error", "machine", "commands")
PROBE_COMMAND_KEYS = ("kind", "argv", "exit", "start_utc", "end_utc")
PROBE_MACHINE_KEYS = ("cpu_model", "cpu_name", "affinity_cpus")


def probe_record(plan, hooks, spec, mm, phase, key=None, observation=None, error=None):
    """The audit record of one untimed probe (an `environment_probe.jl` process and the pinned affinity command
    before a formal process, or before the attempt in the preflight phase). It goes to logs/probes.jsonl, never to
    the receipt: `record` is "probe" and `timed` is false, and nothing of it is a measurement. `commands` are the
    hook's own readings of each command (argv, exit, times); the engine reads no clock for it, so the timing
    boundaries of the formal processes do not move."""
    take = getattr(hooks, "probe_log", None)
    commands = None
    if take is not None:
        try:
            commands = [{k: c.get(k) for k in PROBE_COMMAND_KEYS} for c in take()]
        except Exception as problem:                # a broken journal is recorded as missing, not fatal here
            error = error or f"probe journal: {type(problem).__name__}: {problem}"
    arm, letter = next((arm, letter) for arm in ARMS for letter, role in ARM_ROLES[arm].items() if role == spec.name)
    machine = None
    if observation is not None:
        machine = {"cpu_model": _dig(observation, "machine.cpu_model"), "cpu_name": _dig(observation, "julia.cpu_name"),
                   "affinity_cpus": observation.get("affinity_cpus")}
    return {"record": "probe", "timed": False, "phase": phase, "campaign_id": plan.campaign_id,
            "session_id": plan.session_id, "schedule_id": plan.sched["id"], "process": key.name if key else None,
            "arm": key.arm if key else arm, "role": key.letter if key else letter, "installation": spec.installation,
            "julia": plan.sched["strata"][mm]["version"], "rep": key.rep if key else None, "logical_cpu": plan.cpu,
            "outcome": "failed" if error is not None else "ok",
            "error": None if error is None else f"{type(error).__name__}: {error}" if isinstance(error, BaseException)
            else str(error), "machine": machine, "commands": commands}


def run_probe(plan, hooks, spec, mm, phase, key=None, sink=None):
    """hooks.probe(spec, mm) with its audit record handed to `sink`, also when the probe fails (then the error
    propagates after the record is written)."""
    try:
        observation = hooks.probe(spec, mm)
    except BaseException as error:
        if sink is not None:
            sink(probe_record(plan, hooks, spec, mm, phase, key, error=error))
        raise
    if sink is not None:
        sink(probe_record(plan, hooks, spec, mm, phase, key, observation=observation))
    return observation


def sample_differences(first, other):
    return {k: [first.get(k), other.get(k)] for k in SAMPLE_KEYS if first.get(k) != other.get(k)}


class Attempt:
    """The records of one attempt: STATE, receipt, sidecar logs. Created exclusively at the start."""

    def __init__(self, plan, hooks):
        self.plan, self.hooks, self.finished = plan, hooks, False
        # The last depot-cache digest read per installation (role); prepare may record a baseline per role in
        # logs/depot-baselines.json, which then also binds the first launch of that role.
        baselines = read_json_file(plan.base / "logs" / "depot-baselines.json") or {}
        self.depot_last = {role: str(value) for role, value in baselines.items()}
        logs = plan.base / "logs"
        logs.mkdir(parents=True, exist_ok=True)
        create_exclusive(logs / "STATE.json", state_text("running", campaign_id=plan.campaign_id,
                                                         session_id=plan.session_id))
        for name in ("seals.jsonl", "commands.jsonl", "hardware.jsonl", Path(PROBE_LOG).name):
            create_exclusive(logs / name)
        self.receipt = Receipt(plan.base / "receipt.jsonl")
        start = hooks.clock()
        self.receipt.campaign(plan.campaign_id, plan.session_id, plan.sched["id"], start)
        create_exclusive(logs / "campaign.json", json.dumps({
            "schema": 1, "campaign_id": plan.campaign_id, "session_id": plan.session_id,
            "schedule_id": plan.sched["id"], "official": plan.official, "freeze_sha": plan.freeze_sha,
            "arms": list(plan.arms), "started_utc": utc_text(start),
            "schedule_sha256": sha256_file(plan.base / "schedule.toml"),
            "case_mapping_sha256": sha256_file(plan.base / "case-mapping.toml"),
            "lock_sha256": sha256_file(plan.base / "lock.toml") if (plan.base / "lock.toml").is_file() else None,
            "pilot_config_sha256": (sha256_file(plan.base / "pilot-config.toml")
                                    if (plan.base / "pilot-config.toml").is_file() else None),
            # Where this attempt recorded its session and its untimed probes (absent in evidence made before these
            # records existed; `verify` then requires neither).
            "session_record": SESSION_RECORD if (plan.base / SESSION_RECORD).is_file() else None,
            "probe_record": PROBE_LOG}, indent=2) + "\n")

    def probe(self, record):
        """One line of logs/probes.jsonl (an untimed probe; never a receipt event)."""
        append_jsonl(self.plan.base / PROBE_LOG, record)

    def finish(self, state, **info):
        """STATE.json, then the checksums of the whole evidence (best effort: the attempt is over either way)."""
        logs = self.plan.base / "logs"
        replace_file(logs / "STATE.json", state_text(state, campaign_id=self.plan.campaign_id,
                                                      session_id=self.plan.session_id,
                                                      schedule_id=self.plan.sched["id"], **info))
        write_checksums(self.plan.base)
        self.finished = True

    def stop(self, reason, key=None, **info):
        self.finish("stopped", reason=reason, process=key.name if key else None, **info)
        raise Stopped(reason)


def execute(plan, hooks):
    """Run a campaign (or a pilot) in `plan.base`: the one engine behind `run` and `pilot`.

    Raises Refused before anything is launched (existing evidence, identity files, preflight problems) and
    Stopped after an infrastructure failure (evidence kept, STATE.json says why, nothing resumed). Returns an
    Outcome when every process ran; exit_code is 0, 1 (a process exit 2 or comparator exit 1) or 2 (the comparator
    refused)."""
    missing = [name for name in ("sampler", "depot_digest", "datahash_ok") if getattr(hooks, name, None) is None]
    if missing:
        raise Refused(f"the hooks {missing} are mandatory: an official or pilot run needs the depot-cache digest "
                      "and the data_hash check", field="hooks")
    check_prepared(plan)
    check_fresh(plan)
    check_identity_files(plan)
    order = process_order(plan)
    observations, preflight_probes = {}, []
    for role in plan.role_names():                 # a refusal here leaves the base fresh: no attempt, no record
        for mm in plan.sched["strata"]:
            observations[(role, mm)] = run_probe(plan, hooks, plan.roles[role], mm, "preflight",
                                                 sink=preflight_probes.append)
    problems = preflight_checks(plan, observations)
    if problems:
        raise Refused("preflight found problems: " + "; ".join(problems[:5]), field="preflight",
                      problems=problems)
    attempt = Attempt(plan, hooks)
    nonok = []
    try:
        for record in preflight_probes:
            attempt.probe(record)
        first = hooks.sampler()
        try:
            machine_record(first, "first-sample", plan.cpu)
        except ValueError as error:
            attempt.stop(f"the first machine sample is invalid: {error}")
        for key in order:
            run_one(plan, hooks, attempt, key, observations, first, nonok)
        return finalize(plan, hooks, attempt, len(order), nonok)
    except Stopped:
        raise
    except Refused as error:                        # a refusal after the attempt began still ends it cleanly
        if not attempt.finished:
            with contextlib.suppress(Exception):
                attempt.finish("stopped", reason=f"refused: {error}")
        raise
    except BaseException as error:                  # a bug, an interrupt: the evidence is still kept
        if not attempt.finished:
            with contextlib.suppress(Exception):
                attempt.finish("stopped", reason=f"internal error: {type(error).__name__}: {error}")
        raise


def run_one(plan, hooks, attempt, key, observations, first, nonok):
    spec = plan.roles[key.role]
    logs, raw = plan.base / "logs", plan.raw(key.role, key.mm)
    stem = plan.stem(key.mm, key.rep)
    previous = observations.get((key.role, key.mm)) or {}
    observations[(key.role, key.mm)] = obs = run_probe(plan, hooks, spec, key.mm, "launch", key, attempt.probe)
    problems = preflight_checks(plan, observations)
    for name in ("manifest_sha256", "project_sha256"):
        if name in previous and _dig(obs, name) != previous[name]:
            problems.append(f"ENV_CHANGED: {key.role} {key.mm}: {name} changed since the first observation")
    if problems:
        attempt.stop("preflight: " + "; ".join(problems[:5]), key, problems=problems)
    problems = verify_seals(plan.base)
    if problems:
        attempt.stop("sealed files changed: " + "; ".join(problems[:5]), key, problems=problems)
    if prefix_files(raw, stem):
        attempt.stop(f"raw/ already holds records of {stem}", key)
    digest_before = str(hooks.depot_digest(spec))
    expected_digest = attempt.depot_last.get(key.role)
    if expected_digest is not None and digest_before != expected_digest:
        append_jsonl(logs / "commands.jsonl", {
            "process": key.name, "launched": False, "depot_digest_expected": expected_digest,
            "depot_digest_before": digest_before, "depot_digest_continuous": False})
        attempt.stop("the compiled-cache digest of the depot changed between processes", key)
    before = hooks.sampler()
    if sample_differences(first, before):
        append_jsonl(logs / "hardware.jsonl", {"process": key.name, "moment": "before", "sample": before,
                                               "disagrees": sample_differences(first, before)})
        attempt.stop("the machine values differ from the first sample", key)
    try:
        machine = machine_record(before, _dig(obs, "julia.cpu_name"), plan.cpu)
    except ValueError as error:                     # found before the launch, not after it
        attempt.stop(f"the machine record is invalid: {error}", key)
    raw.mkdir(parents=True, exist_ok=True)
    argv, env = launch_argv(plan, spec, key.mm), launch_env(plan, spec, key.mm, key.rep)
    version = plan.sched["strata"][key.mm]["version"]
    launched = {"start": hooks.clock(), "end": None, "result": None, "event": False}

    def record(complete):
        """The one process event of this launch: the real exit when known, else -1; never twice."""
        if launched["event"]:
            return
        end = launched["end"]
        if end is None:
            try:
                end = hooks.clock()
            except Exception:
                end = utc_now()
        code = launched["result"].exit if launched["result"] is not None else -1
        attempt.receipt.process(key.arm, key.letter, version, key.rep, spec.installation, launched["start"], end,
                                code, complete, machine)
        launched["event"] = True
    try:
        try:
            launched["result"] = hooks.runner(argv, env, str(spec.checkout), plan.cpu)
        except Exception as error:                  # a launch that failed is still one honest process event
            launched["result"] = RunResult(-1, b"", f"runner failed: {type(error).__name__}: {error}".encode())
        result = launched["result"]
        launched["end"] = end = hooks.clock()
        after = hooks.sampler()
        for suffix, data in (("stdout", result.stdout), ("stderr", result.stderr)):
            (logs / f"{key.name}.{suffix}").write_bytes(data or b"")
        digest_after = str(hooks.depot_digest(spec))
        seal_error, failed = None, []
        try:
            failed = seal_process(plan, key, result.exit, (end - launched["start"]).total_seconds())
        except SealProblem as error:
            seal_error = error
        record(seal_error is None)
        append_jsonl(logs / "commands.jsonl", {
            "process": key.name, "argv": argv, "cwd": str(spec.checkout), "env": redacted_env(env),
            "start_utc": utc_text(launched["start"]), "end_utc": utc_text(end), "exit": result.exit,
            "stdout": f"logs/{key.name}.stdout", "stderr": f"logs/{key.name}.stderr", "machine_before": before,
            "machine_after": after, "depot_digest_before": digest_before, "depot_digest_after": digest_after,
            "depot_digest_expected": expected_digest, "depot_digest_continuous": True})
        attempt.depot_last[key.role] = digest_after
        append_jsonl(logs / "hardware.jsonl", {"process": key.name, "moment": "after", "sample": after,
                                               "disagrees": sample_differences(first, after)})
        if seal_error is not None:
            attempt.stop(str(seal_error), key)
        if result.exit == 2:
            nonok.append({"process": key.name, "failed_cases": failed})
        if sample_differences(first, after):
            attempt.stop("the machine values changed during the process", key)
        if digest_after != digest_before:
            attempt.stop("the compiled-cache digest of the depot changed during the process", key)
        if not hooks.datahash_ok(key.role, key.mm, key.rep):
            attempt.stop("the data_hash sidecar differs from metrics.tsv", key)
    except Stopped:
        raise
    except BaseException as error:                  # after the launch an event exists whatever happens
        with contextlib.suppress(Exception):
            record(False)
        with contextlib.suppress(Exception):
            attempt.finish("stopped", reason=f"{type(error).__name__}: {error}", process=key.name)
        raise


def finalize(plan, hooks, attempt, count, nonok):
    """After the last process: declared differences, the comparator, the sealed completion record, checksums."""
    base = plan.base
    try:
        write_declared_differences(base, plan.lock)
    except DeclaredRefusal as error:
        attempt.finish("refused", reason=str(error), problems=error.problems[:50])
        raise
    out = base / "comparison"
    code, stderr = run_comparator(base, out)
    create_exclusive(base / "logs" / "comparator.json", json.dumps({"schema": 1, "exit": code,
                                                                     "stderr": stderr[-4000:]}, indent=2) + "\n")
    if code not in (0, 1):
        attempt.finish("refused" if code == 2 else "stopped", reason=f"the comparator exited with {code}",
                       comparator_exit=code)
        return Outcome(2, "refused" if code == 2 else "stopped", count, nonok, code)
    completion = base / "logs" / "completion.json"
    create_exclusive(completion, json.dumps({
        "schema": 1, "campaign_id": plan.campaign_id, "session_id": plan.session_id,
        "schedule_id": plan.sched["id"], "processes": count, "receipt_sha256": sha256_file(base / "receipt.jsonl"),
        "comparator_exit": code, "outcome": "comparable" if code == 0 and not nonok else "non_ok",
        "nonok_processes": nonok, "schedule_sha256": sha256_file(base / "schedule.toml"),
        "case_mapping_sha256": sha256_file(base / "case-mapping.toml"),
        "campaign_sha256": sha256_file(base / "logs" / "campaign.json"),
        **({"lock_sha256": sha256_file(base / "lock.toml")} if plan.official else
           {"pilot_config_sha256": (sha256_file(base / "pilot-config.toml")
                                    if (base / "pilot-config.toml").is_file() else None)})}, indent=2) + "\n")
    seal_file(base, "logs/completion.json", "completion")
    problems = verify_seals(base)
    if problems:
        attempt.stop("sealed files changed at the end: " + "; ".join(problems[:5]))
    attempt.finish("completed", comparator_exit=code)
    return Outcome(0 if code == 0 and not nonok else 1, "completed", count, nonok, code)


# ------------------------------------------------------------------------------------------- verify

def _parse_time(text):
    if not isinstance(text, str) or not TIME_TEXT.fullmatch(text):
        return None
    try:
        return datetime.datetime.fromisoformat(text)
    except ValueError:
        return None


def check_receipt_text(base, sched, aa, problems, complete=True):
    """The receipt parsed again from the file alone: one campaign event first, one process event per
    (arm, role, julia, rep), the block order re-derived from the timestamps, no overlap, blocks in time order."""
    path = Path(base) / "receipt.jsonl"
    try:
        events = read_jsonl(path)
    except (OSError, ValueError) as error:
        problems.append(f"receipt: unreadable: {error}")
        return {}
    if not events or events[0].get("event") != "campaign" or tuple(events[0]) != CAMPAIGN_KEYS:
        problems.append("receipt: the first event is not a campaign event with the exact keys")
        return {}
    campaign = events[0]
    if any(e.get("event") == "campaign" for e in events[1:]):
        problems.append("receipt: more than one campaign event")
    if campaign["campaign_id"] != sched["campaign_id"] or campaign["schedule_id"] != sched["id"]:
        problems.append("receipt: the campaign or schedule id differs from schedule.toml")
    versions = {info["version"]: mm for mm, info in sched["strata"].items()}
    arms = ("AB", "AA") if aa else ("AB",)
    seen, procs = {}, []
    for number, event in enumerate(events[1:], 2):
        if event.get("event") != "process" or tuple(event) != PROCESS_KEYS:
            problems.append(f"receipt line {number}: not a process event with the exact keys")
            continue
        machine = event["machine"]
        start, end = _parse_time(event["start_utc"]), _parse_time(event["end_utc"])
        valid = (event["arm"] in ARMS and event["role"] in ("A", "B") and event["julia"] in versions
                 and isinstance(event["rep"], int) and not isinstance(event["rep"], bool)
                 and event["block"] == event["rep"] and start is not None and end is not None
                 and start.utcoffset() is not None and end.utcoffset() is not None and end > start
                 and isinstance(event["exit"], int) and not isinstance(event["exit"], bool)
                 and isinstance(event["complete"], bool) and isinstance(machine, dict)
                 and tuple(machine) == MACHINE_KEYS)
        if not valid:
            problems.append(f"receipt line {number}: invalid values")
            continue
        key = (event["arm"], event["role"], event["julia"], event["rep"])
        if key in seen:
            problems.append(f"receipt line {number}: process {key} occurs twice")
            continue
        if event["arm"] not in arms:
            problems.append(f"receipt line {number}: arm {event['arm']} has no roots")
            continue
        seen[key] = dict(event, start=start, end=end)
        procs.append(seen[key])
    for arm in arms:
        for version in versions:
            previous = None
            for rep in sched["reps"]:
                pair = [seen.get((arm, role, version, rep)) for role in "AB"]
                if None in pair:
                    if complete:
                        problems.append(f"receipt: arm {arm} julia {version} rep {rep}: a process event is missing")
                    previous = None
                    continue
                first, second = sorted(pair, key=lambda p: p["start"])
                order = "AB" if first["role"] == "A" else "BA"
                if first["end"] >= second["start"]:
                    problems.append(f"receipt: arm {arm} julia {version} rep {rep}: the processes overlap")
                if order != sched["orders"][rep]:
                    problems.append(f"receipt: arm {arm} julia {version} rep {rep}: order {order}, schedule "
                                    f"{sched['orders'][rep]}")
                if previous and min(p["start"] for p in pair) <= max(p["end"] for p in previous):
                    problems.append(f"receipt: arm {arm} julia {version} rep {rep}: not after the previous block")
                previous = pair
    ordered = sorted(procs, key=lambda p: p["start"])
    for left, right in zip(ordered, ordered[1:]):
        if left["end"] >= right["start"]:
            problems.append(f"receipt: processes {left['arm']}/{left['role']}/{left['julia']}/{left['rep']} and "
                            f"{right['arm']}/{right['role']}/{right['julia']}/{right['rep']} overlap")
    return seen


def role_names_of(arms):
    return [ARM_ROLES[arm][letter] for arm in arms for letter in "AB"]


def required_keys(sched, arms):
    """Every (arm, role letter, stratum, repetition) the schedule requires, in run order."""
    return [(arm, letter, mm, rep) for mm in sched["strata"] for arm in arms for rep in sched["reps"]
            for letter in "AB"]


def raw_relative(role, mm, name):
    return f"roots/{role}/julia-{mm}/raw/{name}"


def process_name(arm, letter, mm, rep):
    return f"{arm}-{letter}-{mm}-rep{rep:02d}"


def check_roots(base, sched, receipt, arms, problems):
    """Per required root and stratum: the six files of every repetition, coverage of every case, the identity
    file, the receipt facts, and for the A/B roots the fingerprint files and the data_hash sidecars."""
    cases = sched["settings"]["case_filter"].split(",")
    arm_of = {role: (arm, letter) for arm in ARMS for letter, role in ARM_ROLES[arm].items()}
    for role in role_names_of(arms):
        root = Path(base) / "roots" / role
        if not root.is_dir():
            problems.append(f"{role}: the root is missing")
            continue
        try:
            ident = tomllib.loads((root / "stack-identity.toml").read_text(encoding="utf-8"))
        except (OSError, tomllib.TOMLDecodeError, UnicodeDecodeError):
            problems.append(f"{role}: stack-identity.toml is missing or unreadable")
            ident = {}
        for mm, info in sched["strata"].items():
            where = f"{role} julia {mm}"
            raw = root / f"julia-{mm}" / "raw"
            for name in ("Project.toml", "Manifest.toml", "environment-inventory.toml"):
                if not (root / f"julia-{mm}" / name).is_file():
                    problems.append(f"{where}: {name} is missing")
            names = {p.name for p in raw.iterdir()} if raw.is_dir() else set()
            expected = set()
            for rep in sched["reps"]:
                stem = f"julia-{info['version']}-rep{rep:02d}"
                files = stem_files(stem)
                expected |= files | ({f"{stem}{PROFILES}"} if f"{stem}{PROFILES}" in names else set())
                for missing in sorted(files - names):
                    problems.append(f"{where}: {missing} is missing")
                metrics = raw / f"{stem}-metrics.tsv"
                if metrics.is_file():
                    header, rows = read_tsv(metrics)
                    ids = [r[header.index("id")] for r in rows] if "id" in header else []
                    reps = {r[header.index("rep")] for r in rows} if "rep" in header else set()
                    if sorted(ids) != sorted(cases) or reps != {str(rep)}:
                        problems.append(f"{where} rep {rep}: metrics.tsv does not cover every declared case "
                                        "exactly once")
                process = (receipt or {}).get((arm_of[role][0], arm_of[role][1], info["version"], rep))
                if process is not None:
                    if ident.get("installation") != process["installation"]:
                        problems.append(f"{where} rep {rep}: receipt installation differs from the identity file")
                    if process["exit"] not in (0, 2) or process["complete"] is not True:
                        problems.append(f"{where} rep {rep}: receipt exit {process['exit']} complete "
                                        f"{process['complete']}")
                    meta_path = raw / f"{stem}-metadata.toml"
                    if meta_path.is_file():
                        try:
                            meta = tomllib.loads(meta_path.read_text(encoding="utf-8"))
                        except (tomllib.TOMLDecodeError, UnicodeDecodeError):
                            meta = {}
                        nonok = meta.get("nonok_cases")
                        if isinstance(nonok, int) and ((process["exit"] == 0 and nonok > 0)
                                                       or (process["exit"] == 2 and nonok == 0)):
                            problems.append(f"{where} rep {rep}: exit {process['exit']} with nonok_cases {nonok}")
                        seconds = (process["end"] - process["start"]).total_seconds()
                        if not isinstance(meta.get("elapsed_s"), (int, float)) or meta["elapsed_s"] > seconds:
                            problems.append(f"{where} rep {rep}: elapsed_s exceeds the receipt interval")
            for extra in sorted(names - expected):
                problems.append(f"{where}: unexpected entry raw/{extra}")
        if role in ("ab-a", "ab-b"):
            check_fingerprints(root, sched, role, problems)


def parse_strict_tsv(path, header, width, what, problems):
    """(rows) of a TSV with the exact header; every malformed line is a problem."""
    if not path.is_file():
        problems.append(f"{what} is missing")
        return None
    lines = path.read_text(encoding="utf-8").split("\n")
    if lines and lines[-1] == "":
        lines.pop()
    if not lines or lines[0] != header:
        problems.append(f"{what} has a wrong header")
        return None
    rows = []
    for number, line in enumerate(lines[1:], 2):
        cells = line.split("\t")
        if len(cells) != width:
            problems.append(f"{what} line {number} has {len(cells)} fields")
        else:
            rows.append(cells)
    return rows


def check_fingerprints(root, sched, role, problems):
    """Unconditional coverage: every expected (julia, id, rep) must be present, also when the file is empty; a
    malformed, duplicate or extra row is a problem."""
    cases = sched["settings"]["case_filter"].split(",")
    expected = {(info["version"], case, str(rep)) for info in sched["strata"].values() for case in cases
                for rep in sched["reps"]}
    what = f"{role}: {FP_NAME}"
    rows = parse_strict_tsv(root / FP_NAME, mc.FP_HEADER, 6, what, problems)
    if rows is not None:
        present, seen = {}, set()
        for julia, case, rep, kind, name, value in rows:
            key = (julia, case, rep)
            if key not in expected:
                problems.append(f"{what}: row for {key} is not a declared (julia, id, rep)")
                continue
            if (kind, name) not in mc.FP_ALLOWED and not (kind == "fixture" and name):
                problems.append(f"{what}: {kind}/{name} is not an allowed row")
            if value != "none" and not HEX64.fullmatch(value):
                problems.append(f"{what}: the value of {key} {kind}/{name} is neither 64 hex nor none")
            if (key, kind, name) in seen:
                problems.append(f"{what}: duplicate row {key} {kind}/{name}")
            seen.add((key, kind, name))
            present.setdefault(key, set()).add((kind, name))
        for key in sorted(expected):
            have = present.get(key, set())
            missing = [f"{k}/{n}" for k, n in REQUIRED_FP_ROWS if (k, n) not in have]
            if not any(k == "fixture" for k, _ in have):
                missing.append("fixture")
            if missing:
                problems.append(f"{what} lacks {missing} for {key}")
    what = f"{role}: {DATAHASH_NAME}"
    rows = parse_strict_tsv(root / DATAHASH_NAME, DATAHASH_HEADER, 4, what, problems)
    if rows is None:
        return
    hashes = {}
    for julia, case, rep, value in rows:
        key = (julia, case, rep)
        if key not in expected:
            problems.append(f"{what}: row for {key} is not a declared (julia, id, rep)")
        elif key in hashes:
            problems.append(f"{what}: duplicate row {key}")
        hashes[key] = value
    versions = {info["version"]: mm for mm, info in sched["strata"].items()}
    for key in sorted(expected):
        if key not in hashes:
            problems.append(f"{what} has no row for {key}")
            continue
        julia, case, rep = key
        metrics = root / f"julia-{versions[julia]}" / "raw" / f"julia-{julia}-rep{int(rep):02d}-metrics.tsv"
        if metrics.is_file():
            header, body = read_tsv(metrics)
            if "id" in header and "data_hash" in header:
                found = {r[header.index("id")]: r[header.index("data_hash")] for r in body if len(r) == len(header)}
                if case in found and found[case] != hashes[key]:
                    problems.append(f"{role}: data_hash sidecar differs from metrics.tsv for {key}")


def symlink_problems(base):
    """A symbolic link anywhere in the evidence (files, directories at any depth, BASE itself and the private
    top-level entries themselves); the content of installations, environments and depots is not evidence."""
    base = str(base)
    problems = []
    if os.path.islink(base):
        problems.append("the base directory is a symbolic link")
    for name in PRIVATE_DIRECTORIES:                 # the entry itself must not be a link; its content is not evidence
        if os.path.islink(os.path.join(base, name)):
            problems.append(f"{name} is a symbolic link")
    for folder, directories, names in os.walk(base):
        if os.path.abspath(folder) == os.path.abspath(base):
            directories[:] = [d for d in directories if d not in PRIVATE_DIRECTORIES]
        for name in directories + names:
            path = os.path.join(folder, name)
            if os.path.islink(path):
                problems.append(f"{os.path.relpath(path, base)} is a symbolic link")
    return problems


def check_seal_coverage(base, sched, arms, receipt, state, problems):
    """Exactly one valid seal per required raw file, bound to its process, mode 0444 on disk, plus the completion
    seal when the attempt completed; extra or duplicate seals are problems."""
    finished = state in ("completed", "refused")
    if finished:
        keys = required_keys(sched, arms)
    else:
        keys = [k for k, e in (receipt or {}).items() if e["complete"] is True and e["exit"] in (0, 2)]
    mm_of = {info["version"]: mm for mm, info in sched["strata"].items()}
    expected = {}
    for arm, letter, mm_or_version, rep in keys:
        mm = mm_of.get(mm_or_version, mm_or_version)
        version = sched["strata"][mm]["version"]
        role, stem = ARM_ROLES[arm][letter], f"julia-{version}-rep{rep:02d}"
        names = set(stem_files(stem))
        if (Path(base) / raw_relative(role, mm, f"{stem}{PROFILES}")).is_file():
            names.add(f"{stem}{PROFILES}")
        for name in names:
            expected[raw_relative(role, mm, name)] = process_name(arm, letter, mm, rep)
    if finished and state == "completed":
        expected["logs/completion.json"] = "completion"
    seals = read_seals(base)
    counts = {}
    for seal in seals:
        counts.setdefault(seal.get("file"), []).append(seal)
    for relative, process in sorted(expected.items()):
        found = counts.get(relative, [])
        if not found:
            problems.append(f"seal coverage: {relative} has no seal")
        else:
            if len(found) > 1:
                problems.append(f"seal coverage: {relative} has {len(found)} seals")
            if found[0].get("process") != process:
                problems.append(f"seal coverage: {relative} is sealed for {found[0].get('process')!r}, "
                                f"not {process!r}")
        path = Path(base) / relative
        if path.is_file() and not path.is_symlink() and stat.S_IMODE(os.lstat(path).st_mode) != 0o444:
            problems.append(f"seal coverage: {relative} is not mode 0444")
    for relative in sorted(set(counts) - set(expected)):
        problems.append(f"seal coverage: {relative} is sealed but not a required file")
    return expected


def read_json_file(path):
    try:
        data = json.loads(Path(path).read_text(encoding="utf-8"))
    except (OSError, ValueError):
        return None
    return data if isinstance(data, dict) else None


def check_identifiers(base, sched, arms, state, completion, problems):
    """schema, campaign id, session id and schedule id agree across campaign.json, STATE.json, the receipt's
    campaign event, the roots' stack-identity.toml and completion.json."""
    campaign = read_json_file(Path(base) / "logs" / "campaign.json") or {}
    if campaign.get("schema") != 1:
        problems.append("logs/campaign.json: schema is not 1")
    ids = {k: campaign.get(k) for k in ("campaign_id", "session_id", "schedule_id")}
    if ids["campaign_id"] != sched["campaign_id"] or ids["schedule_id"] != sched["id"]:
        problems.append("logs/campaign.json: the campaign or schedule id differs from schedule.toml")
    if not is_text(ids["session_id"]):
        problems.append("logs/campaign.json: no session id")
    if campaign.get("arms") != list(arms):
        problems.append(f"logs/campaign.json: arms {campaign.get('arms')!r} differ from the schedule's {list(arms)}")
    others = {"logs/STATE.json": state, "logs/completion.json": completion}
    for name, document in others.items():
        if document is None:
            continue
        if document.get("schema") != 1:
            problems.append(f"{name}: schema is not 1")
        for key, value in ids.items():
            if document.get(key) != value:
                problems.append(f"{name}: {key} {document.get(key)!r} differs from logs/campaign.json")
    try:
        first = read_jsonl(Path(base) / "receipt.jsonl")[0]
    except (OSError, ValueError, IndexError):
        first = {}
    for key, value in ids.items():
        if first.get(key) != value:
            problems.append(f"receipt.jsonl: {key} of the campaign event differs from logs/campaign.json")
    for role in role_names_of(arms):
        try:
            ident = tomllib.loads((Path(base) / "roots" / role / "stack-identity.toml").read_text(encoding="utf-8"))
        except (OSError, tomllib.TOMLDecodeError, UnicodeDecodeError):
            continue
        for key in ("campaign_id", "session_id"):
            if ident.get(key) != ids[key]:
                problems.append(f"roots/{role}/stack-identity.toml: {key} differs from logs/campaign.json")
    return campaign


def check_session_source(base, mode, campaign, problems):
    """The session of an attempt has exactly one source. Current evidence (`session_record` in campaign.json) names
    logs/session.json, the session `prepare --step fetch` minted for the base: it must be valid, bound to the
    configuration copy, equal to the session of campaign.json (and through `check_identifiers` to the identity files,
    the receipt, STATE.json and completion.json), and the configuration must not fix another one. With
    `session_record` null the session came from the configuration (a base prepared before sessions were minted per
    base). Evidence made before the key existed carries neither the key nor the record."""
    base = Path(base)
    exists = (base / SESSION_RECORD).exists()
    try:
        data = tomllib.loads((base / configuration_name(mode == "official")).read_text(encoding="utf-8"))
        configured = (data.get("campaign") or {}).get("session_id")
    except (OSError, UnicodeDecodeError, tomllib.TOMLDecodeError, AttributeError):
        configured = None                           # reported by the binding checks of the mode
    if "session_record" not in campaign:
        if exists:
            problems.append(f"{SESSION_RECORD} exists but logs/campaign.json does not name it")
        return
    marker = campaign["session_record"]
    if marker is None:
        if exists:
            problems.append(f"{SESSION_RECORD} exists but logs/campaign.json says the attempt has no session record")
        if not configured:
            problems.append("the attempt has no session source: neither a session record nor a session_id of the "
                            "configuration")
        return
    if marker != SESSION_RECORD:
        problems.append(f"logs/campaign.json: session_record {marker!r} is not {SESSION_RECORD!r}")
        return
    if configured:
        problems.append(f"the configuration names campaign.session_id {configured!r} although the base has its own "
                        f"session in {SESSION_RECORD}")
    record, found = session_record_problems(base, mode == "official", campaign.get("campaign_id"))
    problems += found
    if record is not None and record.get("session_id") != campaign.get("session_id"):
        problems.append(f"{SESSION_RECORD}: session_id {record.get('session_id')!r} differs from logs/campaign.json")


def _probe_command_problem(command):
    """Why one command of a probe record is malformed (None when it is well formed); also its (start, end)."""
    if not isinstance(command, dict) or tuple(command) != PROBE_COMMAND_KEYS:
        return f"a command does not have exactly the keys {list(PROBE_COMMAND_KEYS)}", None
    argv, code = command["argv"], command["exit"]
    if not (isinstance(argv, list) and argv and all(is_text(a) for a in argv)):
        return "a command has no argv", None
    if not is_text(command["kind"]) or not (isinstance(code, int) and not isinstance(code, bool)):
        return "a command has no kind or no integer exit status", None
    start, end = _parse_time(command["start_utc"]), _parse_time(command["end_utc"])
    if start is None or end is None or end < start:
        return "a command has no valid start and completion times", None
    return None, (start, end)


def check_probe_records(base, sched, arms, receipt, kind, campaign, problems):
    """logs/probes.jsonl, the untimed probes of current evidence (`probe_record` in campaign.json): one valid record
    per role and stratum in the preflight phase (before the campaign started) and one per launched process in the
    launch phase, each finished before its process started and overlapping no formal process, bound to the attempt's
    ids, the process's installation and the measured CPU. Only a stopped attempt may end with a record that has no
    process event (the probe that failed, or whose checks stopped the attempt), and only there may a probe have
    failed. Probe records are never receipt events (`check_receipt_text` rejects any other event)."""
    base, path = Path(base), Path(base) / PROBE_LOG
    if "probe_record" not in campaign:
        if path.exists():
            problems.append(f"{PROBE_LOG} exists but logs/campaign.json does not name it")
        return
    if campaign["probe_record"] != PROBE_LOG:
        problems.append(f"logs/campaign.json: probe_record {campaign['probe_record']!r} is not {PROBE_LOG!r}")
        return
    try:
        records = read_jsonl(path)
    except (OSError, ValueError) as error:
        problems.append(f"{PROBE_LOG}: missing or unreadable: {error}")
        return
    mm_of = {info["version"]: mm for mm, info in sched["strata"].items()}
    started = _parse_time(campaign.get("started_utc"))
    installation = {}
    for role in role_names_of(arms):
        try:
            ident = tomllib.loads((base / "roots" / role / "stack-identity.toml").read_text(encoding="utf-8"))
            installation[role] = ident.get("installation")
        except (OSError, tomllib.TOMLDecodeError, UnicodeDecodeError):
            installation[role] = None
    preflight, launches, intervals, launch_seen = {}, {}, [], False
    for number, record in enumerate(records, 1):
        where = f"{PROBE_LOG} line {number}"
        if not isinstance(record, dict) or tuple(record) != PROBE_KEYS:
            problems.append(f"{where}: not a probe record with the exact keys")
            continue
        if record["record"] != "probe" or record["timed"] is not False:
            problems.append(f"{where}: not an untimed probe record (record {record['record']!r}, timed "
                            f"{record['timed']!r})")
            continue
        for name in ("campaign_id", "session_id", "schedule_id"):
            if record[name] != campaign.get(name):
                problems.append(f"{where}: {name} {record[name]!r} differs from logs/campaign.json")
        if record["logical_cpu"] != sched["machine"]["logical_cpu"]:
            problems.append(f"{where}: logical_cpu {record['logical_cpu']!r} is not the measured CPU")
        arm, letter, version = record["arm"], record["role"], record["julia"]
        if arm not in arms or letter not in ("A", "B") or version not in mm_of:
            problems.append(f"{where}: arm {arm!r}, role {letter!r} or julia {version!r} is not of this attempt")
            continue
        role = ARM_ROLES[arm][letter]
        spans = []
        if not isinstance(record["commands"], list) or not record["commands"]:
            problems.append(f"{where}: the probe's commands are not recorded")
        else:
            for command in record["commands"]:
                problem, span = _probe_command_problem(command)
                if problem:
                    problems.append(f"{where}: {problem}")
                else:
                    spans.append(span)
        intervals += spans
        if record["outcome"] == "ok":
            probes = [c for c in record["commands"] or [] if isinstance(c, dict) and c.get("kind") == "environment-probe"]
            if record["error"] is not None or len(probes) != 1 or probes[0].get("exit") != 0:
                problems.append(f"{where}: outcome ok without exactly one environment-probe command that exited 0")
            if not (isinstance(record["machine"], dict) and tuple(record["machine"]) == PROBE_MACHINE_KEYS):
                problems.append(f"{where}: outcome ok without the observed machine values")
        elif record["outcome"] == "failed":
            if not is_text(record["error"]):
                problems.append(f"{where}: a failed probe without its error")
            if kind != "stopped" or number != len(records):
                problems.append(f"{where}: a failed probe that is not the last record of a stopped attempt")
        else:
            problems.append(f"{where}: outcome {record['outcome']!r} is neither ok nor failed")
        if record["phase"] == "preflight":
            if launch_seen:
                problems.append(f"{where}: a preflight probe after a launch probe")
            if record["process"] is not None or record["rep"] is not None:
                problems.append(f"{where}: a preflight probe names a process or a repetition")
            if record["installation"] != installation.get(role):
                problems.append(f"{where}: installation {record['installation']!r} is not that of {role}")
            if started is not None and any(end > started for _, end in spans):
                problems.append(f"{where}: a preflight probe ends after the campaign started")
            if (arm, letter, version) in preflight:
                problems.append(f"{where}: a second preflight probe of {arm}/{letter}/{version}")
            preflight[(arm, letter, version)] = record
        elif record["phase"] == "launch":
            launch_seen = True
            rep = record["rep"]
            if not (isinstance(rep, int) and not isinstance(rep, bool) and rep in sched["reps"]):
                problems.append(f"{where}: repetition {rep!r} is not of the schedule")
                continue
            if record["process"] != process_name(arm, letter, mm_of[version], rep):
                problems.append(f"{where}: process {record['process']!r} does not match its arm, role, julia and "
                                "repetition")
            key = (arm, letter, version, rep)
            if key in launches:
                problems.append(f"{where}: a second launch probe of {record['process']}")
            launches[key] = (number, record, spans)
        else:
            problems.append(f"{where}: phase {record['phase']!r} is neither preflight nor launch")
    for arm in arms:
        for letter in "AB":
            for version in mm_of:
                if (arm, letter, version) not in preflight:
                    problems.append(f"{PROBE_LOG}: no preflight probe of {arm}/{letter}/{version}")
    for key, event in sorted((receipt or {}).items(), key=lambda item: item[1]["start"]):
        name = process_name(key[0], key[1], mm_of.get(key[2], key[2]), key[3])
        if key not in launches:
            problems.append(f"{PROBE_LOG}: process {name} has no launch probe record")
            continue
        _, record, spans = launches[key]
        if record["outcome"] != "ok":
            problems.append(f"{PROBE_LOG}: the launch probe of {name} failed, yet the process ran")
        if record["installation"] != event["installation"]:
            problems.append(f"{PROBE_LOG}: the installation of the probe of {name} differs from the receipt")
        if any(end > event["start"] for _, end in spans):
            problems.append(f"{PROBE_LOG}: the probe of {name} did not finish before the process started")
    for key, (number, record, _) in launches.items():
        if key not in (receipt or {}) and not (kind == "stopped" and number == len(records)):
            problems.append(f"{PROBE_LOG} line {number}: the probe of {record['process']} has no process event and "
                            "is not the last record of a stopped attempt")
    for start, end in intervals:
        for event in (receipt or {}).values():
            if start < event["end"] and end > event["start"]:
                problems.append(f"{PROBE_LOG}: a probe command overlaps the formal process "
                                f"{event['arm']}/{event['role']}/{event['julia']}/{event['rep']}")


def classify_mode(verifier, pairs):
    """('official' | 'pilot' | None, problems) from the recorded (campaign id, schedule id) pairs and the
    VERIFIER's own official identity. Official iff an id equals the official one; pilot iff both ids contain
    `-pilot` and differ from the official ones; anything else, or a mix, is a problem."""
    modes, problems = set(), []
    for campaign_id, schedule_id in pairs:
        official = campaign_id == verifier["campaign_id"] or schedule_id == verifier["id"]
        pilot_names = all(isinstance(i, str) and "-pilot" in i for i in (campaign_id, schedule_id))
        if official and any(isinstance(i, str) and "-pilot" in i for i in (campaign_id, schedule_id)):
            problems.append(f"identity {campaign_id!r}/{schedule_id!r} mixes the official and the pilot names")
            modes.add(None)
        elif official:
            modes.add("official")
        elif pilot_names:
            modes.add("pilot")
        else:
            problems.append(f"identity {campaign_id!r}/{schedule_id!r} is neither official nor a pilot")
            modes.add(None)
    if len(modes) != 1 or None in modes:
        if len(modes) > 1 and None not in modes:
            problems.append("the recorded identities disagree on the mode")
        return None, problems
    return next(iter(modes)), problems


POLICY_FILES = ("schedule.toml", "case-mapping.toml")


def verifier_schedule_problems(run=subprocess.run):
    """The verifier's trusted policy inputs, schedule.toml and case-mapping.toml, are the development reference:
    each must be tracked and unmodified in its repository (a clean checkout at a recorded freeze commit is required
    for official use, not claimed here)."""
    repo = HERE.parents[2]
    problems = []
    for name in POLICY_FILES:
        relative = (HERE / name).relative_to(repo).as_posix()
        for argv, text in ((["ls-files", "--error-unmatch", "--", relative], "is not tracked"),
                           (["diff", "--quiet", "HEAD", "--", relative], "is modified")):
            try:
                result = run(["git", "-C", str(repo), *argv], capture_output=True, text=True)
                failed = result.returncode != 0
            except OSError:
                failed = True
            if failed:
                problems.append(f"the verifier's {name} {text} (or git cannot say)")
    return problems


def check_policy_copy(base, campaign, problems):
    """The archived case-mapping.toml equals the verifier's and campaign.json records its digest (checked before
    anything is derived from the mapping)."""
    trusted = (HERE / "case-mapping.toml").read_bytes()
    path = Path(base) / "case-mapping.toml"
    if not path.is_file() or path.read_bytes() != trusted:
        problems.append("case-mapping.toml of the archive differs from the verifier's case-mapping.toml")
    if campaign.get("case_mapping_sha256") != sha256_bytes(trusted):
        problems.append("logs/campaign.json: case_mapping_sha256 is missing or not the digest of the verifier's "
                        "case-mapping.toml")


def top_level_problems(base, mode):
    """The top-level entries of the archive against the documented producer layout, with the mode-specific
    configuration file: lock.toml for an official attempt only, pilot-config.toml for a pilot only."""
    allowed = {"roots", "logs", "comparison", "schedule.toml", "case-mapping.toml", "receipt.jsonl",
               "declared-differences.toml", "checksums.sha256", *PRIVATE_DIRECTORIES,
               "lock.toml" if mode == "official" else "pilot-config.toml"}
    forbidden = "pilot-config.toml" if mode == "official" else "lock.toml"
    problems = []
    for entry in sorted(p.name for p in Path(base).iterdir()):
        if entry == forbidden:
            problems.append(f"{entry} is forbidden in {'an official' if mode == 'official' else 'a pilot'} attempt")
        elif entry not in allowed:
            problems.append(f"{entry} is not an entry of the documented layout")
    for entry in ("logs/pilot-config.toml",) if mode == "official" else ("logs/lock.toml",):
        if (Path(base) / entry).exists():
            problems.append(f"{entry} is forbidden in {'an official' if mode == 'official' else 'a pilot'} attempt")
    return problems


def check_pilot_binding(base, sched, campaign, config_path, problems):
    """A pilot is bound to the configuration the verifier holds (--config): the archived pilot-config.toml is
    byte-equal to it, valid, and the archived schedule and the recorded ids agree with it."""
    base = Path(base)
    archived = base / "pilot-config.toml"
    if not archived.is_file():
        problems.append("pilot-config.toml is missing from the tree of a pilot attempt")
        return
    if config_path is None:
        problems.append("a pilot needs --config: the pilot configuration the verifier holds")
        return
    try:
        held = Path(config_path).read_bytes()
    except OSError as error:
        problems.append(f"--config cannot be read: {error}")
        return
    if archived.read_bytes() != held:
        problems.append("pilot-config.toml differs from the configuration supplied with --config")
    try:
        config = parse_pilot(tomllib.loads(held.decode("utf-8")), mc.load_schedule(HERE / "schedule.toml"))
    except (Refused, tomllib.TOMLDecodeError, UnicodeDecodeError, mc.Usage) as error:
        problems.append(f"pilot configuration: {error}")
        return
    if config["campaign"]["id"] != campaign.get("campaign_id") or sched["campaign_id"] != campaign.get("campaign_id"):
        problems.append("pilot configuration: the ids differ from the attempt and its schedule")
    if "session_id" in config["campaign"] and config["campaign"]["session_id"] != campaign.get("session_id"):
        problems.append("pilot configuration: the session id differs from the attempt")
    problems += [f"pilot configuration: {p}" for p in pilot_schedule_problems(
        config, sched, mc.load_schedule(HERE / "schedule.toml"), schedule_arms(base))]
    if campaign.get("pilot_config_sha256") != sha256_file(archived):
        problems.append("pilot-config.toml differs from the digest recorded in logs/campaign.json")
    declared_path = base / "declared-differences.toml"
    if declared_path.is_file():
        try:
            declared = tomllib.loads(declared_path.read_text(encoding="utf-8"))
        except (tomllib.TOMLDecodeError, UnicodeDecodeError):
            declared = None
        if declared != {"schema": 1}:
            problems.append("declared-differences.toml of a pilot is not the minimal `schema = 1`")


def check_completion_binding(base, mode, campaign, completion, problems):
    """completion.json carries the SHA-256 of schedule.toml, logs/campaign.json and the lock (official) or the
    pilot configuration (pilot); each must be the digest of the file in the tree. An internal consistency control,
    not an authenticity signature."""
    base = Path(base)
    wanted = {"schedule_sha256": base / "schedule.toml", "case_mapping_sha256": base / "case-mapping.toml",
              "campaign_sha256": base / "logs" / "campaign.json"}
    wanted["lock_sha256" if mode == "official" else "pilot_config_sha256"] = (
        base / ("lock.toml" if mode == "official" else "pilot-config.toml"))
    other = "pilot_config_sha256" if mode == "official" else "lock_sha256"
    if other in completion:
        problems.append(f"logs/completion.json: {other} does not apply to this attempt")
    for key, path in wanted.items():
        if not path.is_file() or completion.get(key) != sha256_file(path):
            problems.append(f"logs/completion.json: {key} is not the digest of {path.relative_to(base).as_posix()}")
    for key in ("schedule_sha256", "case_mapping_sha256"):
        if campaign.get(key) is None or campaign.get(key) != completion.get(key):
            problems.append(f"logs/completion.json and logs/campaign.json record different {key} values")


def check_lock_binding(base, sched, campaign, problems, deep=True):
    """An official attempt is bound to its lock: the lock validates, and the archived stack B (identity,
    metadata, Manifest and Project digests) is the one the lock names."""
    base = Path(base)
    if (base / "pilot-config.toml").exists():
        problems.append("pilot-config.toml exists in the tree of an official attempt")
    path = base / "lock.toml"
    if not path.is_file():
        problems.append("lock.toml is missing from the tree of an official attempt")
        return
    try:
        lock = load_lock(path, strata=list(sched["strata"]))
    except Refused as error:
        problems.append(f"lock.toml: {error}")
        return
    if "stack_b" not in lock:
        problems.append("lock.toml has no [stack_b]")
        return
    if campaign.get("lock_sha256") != sha256_file(path):
        problems.append("lock.toml differs from the digest recorded in logs/campaign.json")
    if (base / "logs" / "lock.toml").is_file() and (base / "logs" / "lock.toml").read_bytes() != path.read_bytes():
        problems.append("logs/lock.toml differs from lock.toml")
    if lock["campaign"]["id"] != campaign.get("campaign_id"):
        problems.append("lock.toml: the campaign id differs from the attempt")
    if "session_id" in lock["campaign"] and lock["campaign"]["session_id"] != campaign.get("session_id"):
        problems.append("lock.toml: the session id differs from the attempt")
    problems += [f"lock.toml: {p}" for p in approval_problems(lock)]
    problems += [f"lock.toml: {code}: {detail}" for code, detail in static_candidate_problems(lock["stack_b"])]
    # The freeze SHA recorded by the run is a record, not an authentication anchor: the anchor is the independently
    # chosen verifier checkout. It must still be a full SHA.
    if not is_hex40(campaign.get("freeze_sha")):
        problems.append("logs/campaign.json: freeze_sha is not a full 40-hex SHA")
    declared_path = base / "declared-differences.toml"
    if deep and declared_path.is_file():
        try:
            expected = declared_differences(base, lock)
        except Refused as error:
            problems.append(f"declared-differences.toml cannot be recomputed from the roots and the lock: {error}")
        else:
            try:
                archived = tomllib.loads(declared_path.read_text(encoding="utf-8"))
            except (tomllib.TOMLDecodeError, UnicodeDecodeError):
                archived = None
            if archived != expected:
                problems.append("declared-differences.toml differs from the declaration recomputed from the "
                                "archived roots and the lock (reasons and approvals included)")
    b = lock["stack_b"]
    try:
        ident = tomllib.loads((base / "roots" / "ab-b" / "stack-identity.toml").read_text(encoding="utf-8"))
    except (OSError, tomllib.TOMLDecodeError, UnicodeDecodeError):
        ident = {}
    for table, key in (("proximalsolvers", "proximalsolvers"), ("proximalbase", "proximalbase")):
        for field in ("commit", "tree", "version"):
            if (ident.get(table) or {}).get(field) != b[key][field]:
                problems.append(f"roots/ab-b/stack-identity.toml: {table}.{field} differs from the lock")
    pb_ident = ident.get("proximalbase") or {}
    if pb_ident.get("release") != b["proximalbase"]["release"] or pb_ident.get("tag") != b["proximalbase"].get("tag"):
        problems.append("roots/ab-b/stack-identity.toml: the ProximalBase release or tag differs from the lock")
    wanted = {"proximalsolvers_sha": b["proximalsolvers"]["commit"],
              "proximalsolvers_hash": b["proximalsolvers"]["package_hash"],
              "proximalbase_version": b["proximalbase"]["version"],
              "proximalbase_hash": b["proximalbase"]["package_hash"], "harness_hash": b["harness_hash"]}
    for mm, info in sched["strata"].items():
        env = b["environments"][mm]
        for name, digest in (("Manifest.toml", env["manifest_sha256"]), ("Project.toml", env["project_sha256"])):
            target = base / "roots" / "ab-b" / f"julia-{mm}" / name
            if not target.is_file() or sha256_file(target) != digest:
                problems.append(f"roots/ab-b/julia-{mm}/{name} differs from the lock's SHA-256")
        for rep in sched["reps"]:
            meta_path = base / raw_relative("ab-b", mm, f"julia-{info['version']}-rep{rep:02d}-metadata.toml")
            try:
                meta = tomllib.loads(meta_path.read_text(encoding="utf-8"))
            except (OSError, tomllib.TOMLDecodeError, UnicodeDecodeError):
                continue
            for field, value in wanted.items():
                if meta.get(field) != value:
                    problems.append(f"ab-b julia {mm} rep {rep}: metadata {field} differs from the lock")


def verify(base, out, replay=True, config=None, run=subprocess.run):
    """Read-only check of a BASE (no Julia, no original paths, works on a copied tree) and the verification
    record `out`, a fresh path outside BASE. Returns (document, exit status).

    What is required (arms, roots, processes, seals) comes from the archived schedule.toml and
    logs/campaign.json, never from which files happen to exist. Only a sealed logs/completion.json that is
    consistent with everything else verifies as a success. A stopped attempt, a missing completion record or a
    reproduced comparator refusal never does; a reproduced refusal is `refused` ("verified: refused")."""
    base, out = Path(base), Path(out)
    if out.exists():
        raise UsageError(f"{out} exists: the verification record is written to a fresh path")
    if base.resolve() in out.resolve().parents or out.resolve() == base.resolve():
        raise UsageError("the verification record must not be written into the evidence")
    problems = []
    document = {"schema": 1, "problems": problems}
    sched, arms, reference = None, ("AB",), base
    verifier = mc.load_schedule(HERE / "schedule.toml")
    campaign = read_json_file(base / "logs" / "campaign.json") or {}
    pairs = [(campaign.get("campaign_id"), campaign.get("schedule_id"))]
    try:
        archived = tomllib.loads((base / "schedule.toml").read_text(encoding="utf-8"))["schedule"]
        pairs.append((archived.get("campaign_id"), archived.get("id")))
    except (OSError, KeyError, tomllib.TOMLDecodeError, UnicodeDecodeError):
        problems.append("schedule.toml is missing or unreadable")
    mode, mode_problems = classify_mode(verifier, pairs)
    problems += mode_problems
    document["mode"] = {"official": "OFFICIAL", "pilot": "PILOT / NON-OFFICIAL", None: None}[mode]
    if mode is not None and campaign.get("official") is not (mode == "official"):
        problems.append(f"logs/campaign.json: official is {campaign.get('official')!r}, but the identity is "
                        f"{'official' if mode == 'official' else 'a pilot'}")
    if mode is not None:
        other = "pilot_config_sha256" if mode == "official" else "lock_sha256"
        if campaign.get(other) is not None:
            problems.append(f"logs/campaign.json: {other} is set in {'an official' if mode == 'official' else 'a pilot'} "
                            "attempt")
    if mode == "official":
        # The reference for an official attempt is the verifier's own tracked, unmodified schedule.toml, never
        # the archive: arms, roots, blocks and counts derive from it.
        reference = HERE
        problems += verifier_schedule_problems(run)
        trusted = (HERE / "schedule.toml").read_bytes()
        if not (base / "schedule.toml").is_file() or (base / "schedule.toml").read_bytes() != trusted:
            problems.append("schedule.toml of the archive differs from the verifier's schedule.toml")
        if campaign.get("schedule_sha256") != sha256_bytes(trusted):
            problems.append("logs/campaign.json: schedule_sha256 is not the digest of the verifier's schedule.toml")
        sched = verifier
    if mode is not None:
        check_policy_copy(base, campaign, problems)
        problems += top_level_problems(base, mode)
    try:
        if sched is None:
            sched = mc.load_schedule(base / "schedule.toml")
        arms = schedule_arms(reference)
    except (mc.Usage, OSError, KeyError, ValueError) as error:
        problems.append(f"schedule.toml: {error}")
    if mode == "pilot" and sched is not None:
        if campaign.get("schedule_sha256") != sha256_file(base / "schedule.toml"):
            problems.append("logs/campaign.json: schedule_sha256 is not the digest of the archived schedule.toml")
    if "AB" not in arms:
        problems.append("the schedule does not list the AB arm")
    aa = "AA" in arms
    state = read_json_file(base / "logs" / "STATE.json") or {}
    kind = state.get("state")
    required = ["schedule.toml", "case-mapping.toml", "receipt.jsonl", "logs/seals.jsonl", "logs/commands.jsonl",
                "logs/hardware.jsonl", "logs/STATE.json", "logs/campaign.json"]
    if campaign.get("probe_record") == PROBE_LOG:
        required.append(PROBE_LOG)
    if campaign.get("session_record") == SESSION_RECORD:
        required.append(SESSION_RECORD)
    if kind == "completed":
        required += ["declared-differences.toml", "logs/comparator.json", "logs/completion.json"]
    for relative in required + ["checksums.sha256"]:
        if not (base / relative).is_file():
            problems.append(f"{relative} is missing")
    problems += symlink_problems(base)
    listed = {}
    try:
        listed = read_checksums(base / "checksums.sha256")
        actual = evidence_paths(base)
        for relative in sorted(set(listed) - set(actual)):
            problems.append(f"checksums: {relative} is listed but missing")
        for relative in sorted(set(actual) - set(listed)):
            problems.append(f"checksums: {relative} is evidence but not listed")
        for relative in sorted(set(listed) & set(actual)):
            if sha256_file(base / relative) != listed[relative]:
                problems.append(f"checksums: {relative} differs from its digest")
    except (OSError, ValueError) as error:
        problems.append(f"checksums.sha256: {error}")
    for relative in required:
        if (base / relative).is_file() and relative not in listed:
            problems.append(f"checksums: the mandatory file {relative} is not in the inventory")
    problems += verify_seals(base) if (base / "logs" / "seals.jsonl").is_file() else []
    document["campaign_state"] = kind
    completion = None
    if (base / "logs" / "completion.json").is_file():
        completion = read_json_file(base / "logs" / "completion.json")
        if completion is None:
            problems.append("logs/completion.json is not a valid JSON object")
    receipt, campaign = {}, {}
    if sched is not None:
        receipt = check_receipt_text(base, sched, aa, problems, complete=kind != "stopped")
        campaign = check_identifiers(base, sched, arms, state, completion, problems)
        if completion is not None and kind == "completed" and mode is not None:
            check_completion_binding(base, mode, campaign, completion, problems)
        if kind in ("completed", "refused"):
            check_roots(base, sched, receipt, arms, problems)
        expected = check_seal_coverage(base, sched, arms, receipt, kind, problems)
        for relative in sorted(expected):
            if relative not in listed and (base / relative).is_file():
                problems.append(f"checksums: the mandatory file {relative} is not in the inventory")
        check_probe_records(base, sched, arms, receipt, kind, campaign, problems)
        if mode is not None:
            check_session_source(base, mode, campaign, problems)
        if mode == "official":
            check_lock_binding(base, sched, campaign, problems, deep=replay)
        elif mode == "pilot":
            check_pilot_binding(base, sched, campaign, config, problems)
    expected_count = 0 if sched is None else len(sched["strata"]) * len(sched["reps"]) * 2 * len(arms)
    document["campaign_outcome"] = None
    if kind == "completed":
        if completion is None:
            problems.append("the state is completed but logs/completion.json is missing")
        else:
            if completion.get("processes") != expected_count:
                problems.append(f"completion.json counts {completion.get('processes')} processes, expected "
                                f"{expected_count}")
            if (base / "receipt.jsonl").is_file() and completion.get("receipt_sha256") != sha256_file(
                    base / "receipt.jsonl"):
                problems.append("completion.json: the receipt digest differs")
            document["campaign_outcome"] = completion.get("outcome")
    elif completion is not None:
        problems.append("logs/completion.json exists but the state is not completed")
    comparator = read_json_file(base / "logs" / "comparator.json") or {}
    stored_exit = comparator.get("exit")
    if kind == "completed" and stored_exit is None:
        problems.append("logs/comparator.json is missing")
    if completion is not None and stored_exit is not None and completion.get("comparator_exit") != stored_exit:
        problems.append("completion.json and logs/comparator.json disagree on the comparator exit")
    document["comparator_exit"] = None
    document["classification"] = None
    if replay and sched is not None and (base / "comparison").is_dir() and kind != "stopped":
        scratch = Path(tempfile.mkdtemp(prefix="stage2b-verify-"))
        try:
            code, _ = run_comparator(base, scratch / "replay")
            document["comparator_exit"] = code
            again, stored = comparison_summary(scratch / "replay"), comparison_summary(base / "comparison")
            document["classification"] = again["counts"] if again["counts"] is not None else [
                list(pair) for pair in again["refusals"] or []]
            if stored_exit is not None and code != stored_exit:
                problems.append(f"the replay exits with {code}, the campaign recorded {stored_exit}")
            if again["refusals"] != stored["refusals"] or again["triples"] != stored["triples"]:
                problems.append("the refusals of the replay differ from the stored comparison")
            if again["rows"] != stored["rows"]:
                problems.append("the comparison rows of the replay differ from the stored comparison")
            if stored["refusals"] is None and (stored["report"] is None or stored["lists"] is None):
                problems.append("comparison/ lacks report.md or lists.json")
            if again["report"] != stored["report"]:
                problems.append("report.md of the replay differs from the stored comparison")
            if again["lists"] != stored["lists"]:
                problems.append("lists.json of the replay differs from the stored comparison")
        finally:
            shutil.rmtree(scratch, ignore_errors=True)
    elif kind == "completed" and not (base / "comparison").is_dir():
        problems.append("comparison/ is missing")
    if problems:
        document["state"], status = "failed", 2
    elif kind == "completed" and completion is not None:
        success = document["campaign_outcome"] == "comparable" and document["comparator_exit"] in (0, None)
        label = "verified" if mode == "official" else "pilot_verified"
        document["state"], status = (label, 0) if success else (label + "_non_ok", 1)
    elif kind == "refused":
        document["state"], status = "refused", 2
    elif kind == "stopped":
        document["state"], status = "stopped", 2
    else:
        document["state"], status = "no_success_record", 2
    document["problems"] = list(problems)
    out.parent.mkdir(parents=True, exist_ok=True)
    create_exclusive(out, json.dumps(document, indent=2) + "\n")
    return document, status


# ------------------------------------------------------------------------------ real hooks: host and Julia

STAGE2A_ARCHIVE_SHA256 = "1edd64330606d739acf1d7b4ba0643a4fb6a1366bad4c82393e2ba1ffdcc723e"
STAGE2A_CAMPAIGN = BENCH / "campaigns" / "pre06" / "campaign.toml"
JULIA_FLAGS = ("--startup-file=no", "--history-file=no")
STALE_MANIFEST = "since the manifest was last resolved"
GIT_THREADS = ("-c", "pack.threads=1", "-c", "index.threads=1")
MAX_MEMBER_BYTES = 16 << 20
PILOT_SCHEDULE_CHANGES = (
    "schedule.id", "schedule.campaign_id", "schedule.reps", "schedule.orders", "schedule.arms",
    "settings.samples_target", "settings.seconds_limit", "settings.case_seconds",
    "machine.cpu_model", "machine.cpu", "machine.logical_cpu", "machine.smt_sibling", "machine.governor",
    "machine.epp", "machine.no_turbo", "machine.smt_control")


def run_process(run, argv, env=None, cwd=None):
    """One command without a shell: a RunResult (a negative exit means killed by a signal)."""
    result = (run or subprocess.run)(list(argv), env=env, cwd=None if cwd is None else str(cwd),
                                     capture_output=True, shell=False)
    return RunResult(result.returncode, result.stdout or b"", result.stderr or b"")


def tail(data, size=600):
    text = data.decode("utf-8", "replace") if isinstance(data, bytes) else str(data)
    return text[-size:].strip()


def run_git(run, *args):
    """`git args` outside any repository (clone, ls-remote); a failure raises Refused."""
    result = (run or subprocess.run)(["git", *args], capture_output=True, text=True)
    if result.returncode != 0:
        raise Refused(f"git {args[0] if args[0] != '-c' else 'clone'} failed: {tail(result.stderr)}")
    return result.stdout.strip()


def parse_cpu_list(text):
    """`Cpus_allowed_list` text such as `0-2,5` as a sorted list of integers."""
    cpus = []
    for part in text.strip().split(","):
        low, _, high = part.partition("-")
        cpus += range(int(low), int(high or low) + 1)
    return sorted(set(cpus))


def depot_digest(depot):
    """SHA-256 over the sorted listing of every file inside every `compiled/` directory of a depot: (relative
    path, size, mtime_ns), except for a `.ji` file, which is listed with its content digest instead of its mtime
    because Julia touches a `.ji` file each time it loads the package. A rebuilt package image changes the digest
    (its `.so` file is new and its `.ji` content differs); an unchanged cache does not, however often it is loaded."""
    depot, entries = Path(depot), []
    for folder, _, names in os.walk(depot):
        relative = Path(folder).relative_to(depot)
        if "compiled" not in relative.parts:
            continue
        for name in names:
            path = Path(folder) / name
            info = os.lstat(path)
            stamp = sha256_file(path) if name.endswith(".ji") else str(info.st_mtime_ns)
            entries.append((relative.joinpath(name).as_posix(), info.st_size, stamp))
    digest = hashlib.sha256()
    for path, size, stamp in sorted(entries):
        digest.update(f"{path}\0{size}\0{stamp}\n".encode())
    return digest.hexdigest()


def depot_entries(spec):
    """Every effective JULIA_DEPOT_PATH entry of a role: its private depot and the bundled depots of every stratum
    it runs (the same entries `launch_env` puts into JULIA_DEPOT_PATH), each once, in a fixed order."""
    entries = [str(spec.depot)]
    for mm in spec.environments:
        entries += [e for e in bundled_of(spec, mm).split(":") if e]
    return list(dict.fromkeys(entries))


def effective_depot_digest(spec):
    """One digest over `depot_digest` of every effective depot entry of the role (also the bundled Julia depots)."""
    digest = hashlib.sha256()
    for entry in depot_entries(spec):
        digest.update(f"{entry}\0{depot_digest(entry)}\n".encode())
    return digest.hexdigest()


def bundled_depots(julia_bins):
    """{stratum: the two depot entries that belong to the Julia installation of that stratum}."""
    return {mm: f"{Path(binary).parent.parent}/local/share/julia:{Path(binary).parent.parent}/share/julia"
            for mm, binary in julia_bins.items()}


def keep_off_cpu(cpu, getaffinity=None, setaffinity=None):
    """Restrict the driver to the allowed CPUs except the measured one. Refuses when the measured CPU is not
    allowed or no other CPU remains."""
    allowed = set((getaffinity or os.sched_getaffinity)(0))
    if cpu not in allowed:
        raise Refused(f"the measured CPU {cpu} is not among the allowed CPUs {sorted(allowed)}")
    rest = allowed - {cpu}
    if not rest:
        raise Refused(f"only CPU {cpu} is allowed: the driver needs a second CPU to stay off the measured one")
    (setaffinity or os.sched_setaffinity)(0, rest)
    return sorted(rest)


def julia_command(plan, spec, mm, tail_argv, pinned=True):
    """The formal Julia command line (`launch_argv` is its run.jl instance) with other arguments after the flags."""
    head = ["taskset", "-c", str(plan.cpu)] if pinned else []
    return head + [str(spec.julia[mm]), *JULIA_FLAGS, f"--project={spec.environments[mm]}", *tail_argv]


def datahash_matches(base, sched, role, mm, rep):
    """The exporter's data_hash rows of (julia, rep) equal the data_hash column of the process's metrics.tsv, row
    for row. The A/A roots have no sidecar: their data are those of the stack A root ab-a."""
    base = Path(base)
    source = role if role in ("ab-a", "ab-b") else "ab-a"
    version = sched["strata"][mm]["version"]
    stem = f"julia-{version}-rep{rep:02d}"
    try:
        _, rows = read_tsv(base / "roots" / source / DATAHASH_NAME)
        header, body = read_tsv(base / "roots" / role / f"julia-{mm}" / "raw" / f"{stem}-metrics.tsv")
        ids, hashes = header.index("id"), header.index("data_hash")
    except (OSError, ValueError, UnicodeDecodeError):
        return False
    sidecar, listed = {}, [r for r in rows if len(r) == 4 and r[0] == version and r[2] == str(rep)]
    for _, case, _, value in listed:
        sidecar[case] = value
    metrics = {r[ids]: r[hashes] for r in body if len(r) == len(header)}
    return bool(metrics) and len(listed) == len(sidecar) and len(body) == len(metrics) and sidecar == metrics


def build_observation(data, facts):
    """The observation dictionary of one (role, stratum) from the probe's TOML (`data`) and the facts the driver
    read itself (`facts`): see `preflight_checks` for the keys."""
    deps = data.get("deps") or {}
    return {
        "julia": {"version": data["julia"], "commit": data["commit"], "cpu_name": data["cpu_name"]},
        "ps": {"commit": facts["ps_commit"], "tree": facts["ps_tree"], "version": facts["ps_version"],
               "dirty": facts["dirty"], "loaded_realpath": data["proximalsolvers_dir"],
               "package_hash": facts["ps_package_hash"]},
        "pb": {"loaded_tree": data["proximalbase_loaded_tree"],
               "manifest_tree": (deps.get("ProximalBase") or {}).get("tree", ""),
               "version": data["proximalbase_version"], "package_hash": facts["pb_package_hash"]},
        "checkout_realpath": facts["checkout_realpath"], "depot_realpath": data["depot_realpath"],
        "environment": {"dir": facts["environment_dir"], "realpath": facts["environment_realpath"],
                        "project_exists": facts["project_exists"], "manifest_exists": facts["manifest_exists"]},
        "manifest_sha256": facts["manifest_sha256"], "project_sha256": facts["project_sha256"],
        "harness_hash": facts["harness_hash"], "affinity_cpus": facts["affinity_cpus"],
        "machine": {"cpu_model": data["cpu_model"], "cpu": data["cpu_name"], "logical_cpu": facts["logical_cpu"]}}


def python_facts(spec, mm, data, affinity, run=None):
    """What the driver reads without Julia: git facts of the checkout, the Python replicas of the two source
    fingerprints of the loaded roots and of the harness, the digests of the environment files."""
    run = run or subprocess.run
    checkout, env = spec.checkout, spec.environments[mm]
    ps_dir, pb_dir = Path(data["proximalsolvers_dir"]), Path(data["proximalbase_dir"])
    version = tomllib.loads((ps_dir / "Project.toml").read_text(encoding="utf-8")).get("version", "")
    files = {name: env / name for name in ("Project.toml", "Manifest.toml")}
    return {
        "ps_commit": git(checkout, "rev-parse", "HEAD", run=run), "ps_tree": git(checkout, "rev-parse", "HEAD^{tree}",
                                                                              run=run),
        "dirty": not git_clean(checkout, run=run), "ps_version": version,
        "ps_package_hash": package_fingerprint(ps_dir), "pb_package_hash": package_fingerprint(pb_dir),
        "harness_hash": harness_hash(checkout / "benchmark"),
        "checkout_realpath": os.path.realpath(checkout), "environment_dir": str(env),
        "environment_realpath": os.path.realpath(env),
        "project_exists": files["Project.toml"].is_file(), "manifest_exists": files["Manifest.toml"].is_file(),
        "project_sha256": sha256_file(files["Project.toml"]) if files["Project.toml"].is_file() else "",
        "manifest_sha256": sha256_file(files["Manifest.toml"]) if files["Manifest.toml"].is_file() else "",
        "affinity_cpus": affinity,
        "logical_cpu": affinity[0] if len(affinity) == 1 else -1}


class RealHooks:
    """The real hooks of the engine and of `prepare --step finalize`: commands run through `subprocess` (no shell),
    the probe is the untimed `environment_probe.jl` in the role's environment under the formal Julia flags and
    environment. `bind(plan)` supplies the plan (schedule, measured CPU) and keeps the driver off the measured CPU."""

    def __init__(self, julia_bins, parent_env, run=None, getaffinity=None, setaffinity=None):
        self.julia_bins = {mm: str(path) for mm, path in julia_bins.items()}
        self.bundled_depot = bundled_depots(self.julia_bins)
        self.parent_env, self.run, self.plan = dict(parent_env), run, None
        self.getaffinity, self.setaffinity = getaffinity, setaffinity
        self.journal = []

    def probe_log(self):
        """The probe commands run since the last call (see Hooks.probe_log), forgotten once returned."""
        taken, self.journal = self.journal, []
        return taken

    def _probe_command(self, kind, argv, env, cwd):
        """run_process with the command's own record in the journal (also when it cannot start: exit -1)."""
        entry = {"kind": kind, "argv": [str(a) for a in argv], "exit": None, "start_utc": utc_text(utc_now()),
                 "end_utc": None}
        self.journal.append(entry)
        try:
            result = run_process(self.run, argv, env, cwd)
        except BaseException:
            entry.update(exit=-1, end_utc=utc_text(utc_now()))
            raise
        entry.update(exit=result.exit, end_utc=utc_text(utc_now()))
        return result

    def bind(self, plan, keep_off=True):
        self.plan = plan
        if keep_off:
            keep_off_cpu(plan.cpu, self.getaffinity, self.setaffinity)

    def clock(self):
        return utc_now()

    def sampler(self):
        return sample_machine(self.plan.cpu)

    def depot_digest(self, spec):
        return effective_depot_digest(spec)

    def datahash_ok(self, role, mm, rep):
        return datahash_matches(self.plan.base, self.plan.sched, role, mm, rep)

    def runner(self, argv, env, cwd, cpu):
        return run_process(self.run, argv, env, cwd)

    def _step(self, name, spec, mm, argv, env):
        """A prepare step with its output kept in logs/ (names are unique: a log is never overwritten)."""
        result = run_process(self.run, argv, env, spec.checkout)
        logs = self.plan.base / "logs"
        create_exclusive(logs / f"{name}.out", result.stdout.decode("utf-8", "replace"))
        create_exclusive(logs / f"{name}.err", result.stderr.decode("utf-8", "replace"))
        (logs / "prepare-commands.jsonl").touch()
        append_jsonl(logs / "prepare-commands.jsonl", {"step": name, "argv": argv, "cwd": str(spec.checkout),
                                                       "env": redacted_env(env), "exit": result.exit})
        return result

    def precompile(self, spec, mm):
        argv = julia_command(self.plan, spec, mm, ["-e", "using Pkg; Pkg.precompile()"], pinned=False)
        return self._step(f"finalize-{spec.name}-{mm}-precompile", spec, mm, argv,
                          launch_env(self.plan, spec, mm, 1))

    def warmup(self, spec, mm, number):
        """An untimed PS_LIST=true run of the role's run.jl: it imports everything and writes nothing."""
        env = dict(launch_env(self.plan, spec, mm, 1), PS_LIST="true")
        return self._step(f"finalize-{spec.name}-{mm}-warmup{number}", spec, mm, launch_argv(self.plan, spec, mm),
                          env)

    def export(self, spec, mm, reps, out):
        argv = julia_command(self.plan, spec, mm, [
            str(HERE / "export_fingerprints.jl"), "--harness", f"{spec.checkout}/benchmark",
            "--expected-package-root", str(spec.checkout), "--schedule", str(HERE / "schedule.toml"),
            "--reps", ",".join(str(r) for r in reps), "--expected-harness-hash", spec.expected["harness_hash"],
            "--out", str(out)])
        return self._step(f"finalize-{spec.name}-{mm}-export", spec, mm, argv, launch_env(self.plan, spec, mm, 1))

    def affinity(self, spec, mm):
        """The CPUs a pinned launch is allowed on, observed by a tiny command under the same `taskset` argv."""
        argv = ["taskset", "-c", str(self.plan.cpu), "grep", "Cpus_allowed_list:", "/proc/self/status"]
        result = self._probe_command("affinity", argv, launch_env(self.plan, spec, mm, 1), spec.checkout)
        try:
            return parse_cpu_list(result.stdout.decode().partition(":")[2]) if result.exit == 0 else []
        except ValueError:
            return []

    def probe_raw(self, spec, mm):
        """(observation, the probe's TOML text) of one role and stratum; the probe is untimed."""
        argv = julia_command(self.plan, spec, mm, [str(HERE / "environment_probe.jl")])
        result = self._probe_command("environment-probe", argv, launch_env(self.plan, spec, mm, 1), spec.checkout)
        where = f"{spec.name} julia {mm}"
        if result.exit != 0:
            raise Refused(f"the environment probe of {where} exited with {result.exit}: {tail(result.stderr)}")
        text = result.stdout.decode("utf-8", "replace")
        try:
            data = tomllib.loads(text)
            if data["threads"] != 1:
                raise Refused(f"the environment probe of {where} reports {data['threads']} Julia threads")
            facts = python_facts(spec, mm, data, self.affinity(spec, mm), self.run)
            return build_observation(data, facts), text
        except (KeyError, TypeError, OSError, ValueError) as error:       # includes tomllib.TOMLDecodeError
            raise Refused(f"the environment probe of {where} is unusable: {type(error).__name__}: {error}") from error

    def probe(self, spec, mm):
        return self.probe_raw(spec, mm)[0]


# ------------------------------------------------------------------------------------ prepare: documents

def rewrite_manifest_path(text, checkout):
    """The `path` line of the ProximalSolvers entry of a Manifest, rewritten to `checkout` (text level, line
    exact, nothing else touched); not found exactly once is a refusal."""
    check_toml_path(checkout)
    lines = text.split("\n")
    starts = [i for i, line in enumerate(lines) if line == "[[deps.ProximalSolvers]]"]
    if len(starts) != 1:
        raise Refused(f"the Manifest has {len(starts)} [[deps.ProximalSolvers]] tables, expected exactly one")
    end = next((j for j in range(starts[0] + 1, len(lines)) if lines[j].startswith("[")), len(lines))
    hits = [j for j in range(starts[0] + 1, end) if re.fullmatch(r'path = "[^"]*"', lines[j])]
    if len(hits) != 1:
        raise Refused(f"the ProximalSolvers entry of the Manifest has {len(hits)} path lines, expected exactly one")
    lines[hits[0]] = f'path = "{checkout}"'
    return "\n".join(lines)


SOURCES_LINE = re.compile(r'ProximalSolvers = \{path = "[^"]*"\}')


def rewrite_project_sources(text, checkout):
    """(text, rewritten): the ProximalSolvers line of `[sources]` (Julia 1.13) rewritten to `checkout`. A Project
    without `[sources]` and without such a line is returned unchanged; any other count is a refusal."""
    check_toml_path(checkout)
    lines = text.split("\n")
    hits = [i for i, line in enumerate(lines) if SOURCES_LINE.fullmatch(line)]
    headers = [i for i, line in enumerate(lines) if line == "[sources]"]
    if not hits and not headers:
        return text, False
    if len(hits) != 1 or len(headers) != 1 or hits[0] < headers[0] or any(
            line.startswith("[") for line in lines[headers[0] + 1:hits[0]]):
        raise Refused(f"the Project has {len(hits)} ProximalSolvers path lines in {len(headers)} [sources] tables, "
                      "expected exactly one in exactly one")
    lines[hits[0]] = f'ProximalSolvers = {{path = "{checkout}"}}'
    return "\n".join(lines), True


def check_toml_path(path):
    if not (isinstance(path, str) and path.startswith("/")) or any(c in path for c in '"\\\n\r\t'):
        raise Refused(f"the path {path!r} cannot be written into a TOML line")


def manifest_entries(text):
    """Sorted (name, uuid, version, git-tree-sha1) of every dependency entry of a Manifest ("" when absent)."""
    data = tomllib.loads(text)
    return sorted((name, item["uuid"], item.get("version", ""), item.get("git-tree-sha1", ""))
                  for name, items in (data.get("deps") or {}).items() for item in items)


def lock_entries(campaign, mm):
    """The same tuples from the `lock` array of `[julia."MM"]` of the Stage 2A campaign definition."""
    entry = ((campaign.get("julia") or {}).get(mm) or {}).get("lock")
    if not isinstance(entry, list):
        raise Refused(f"the Stage 2A campaign definition has no lock for julia {mm}")
    return sorted((item["name"], item["uuid"], item["version"], item["tree"]) for item in entry)


def unified(old, new, old_name, new_name):
    import difflib
    return "".join(difflib.unified_diff(old.splitlines(keepends=True), new.splitlines(keepends=True), old_name,
                                        new_name, n=0))


def foreign_changes(old, new):
    """The changed lines (with their sign) that are neither a `path = ` nor a `project_hash = ` line."""
    import difflib
    changed = [line for line in difflib.unified_diff(old.splitlines(), new.splitlines(), lineterm="", n=0)
               if line[:1] in "+-" and not line.startswith(("+++", "---"))]
    return [line for line in changed if not re.match(r'[+-](path|project_hash) = "', line)]


def check_archive_digest(archive, expected=None):
    expected = expected or STAGE2A_ARCHIVE_SHA256
    try:
        digest = sha256_file(archive)
    except OSError as error:
        raise Refused(f"cannot read the Stage 2A archive: {error}") from error
    if digest != expected:
        raise Refused(f"the Stage 2A archive has SHA-256 {digest}, expected {expected}")


def extract_archive(archive, destination, strata, root, expected=None):
    """Verify the archive's SHA-256 and extract only `julia-MM/{Project,Manifest}.toml` into a fresh directory.

    `root` is the archive's top directory (`[archive] name` of the Stage 2A campaign definition). The extractor never executes or unpacks anything else: a member with an absolute name, a `..` component or a
    backslash anywhere in the archive refuses it; a wanted member must be a regular file, found exactly once, and
    is read with a size limit and written under a fixed name. Returns the directory."""
    import tarfile
    archive, destination = Path(archive), Path(destination)
    check_archive_digest(archive, expected)
    wanted = {f"{root}/julia-{mm}/{name}": f"julia-{mm}/{name}" for mm in strata
              for name in ("Project.toml", "Manifest.toml")}
    found = {}
    try:
        with tarfile.open(archive, "r:gz") as tar:
            for member in tar:
                parts = member.name.split("/")
                if member.name.startswith("/") or ".." in parts or "\\" in member.name:
                    raise Refused(f"the archive has an unsafe member {member.name!r}")
                if member.name in wanted:
                    if not member.isreg() or member.size > MAX_MEMBER_BYTES or member.name in found:
                        raise Refused(f"the archive member {member.name!r} is not a single regular file of "
                                      "acceptable size")
                    found[member.name] = tar.extractfile(member).read()
    except (tarfile.TarError, OSError, EOFError) as error:
        raise Refused(f"cannot read the Stage 2A archive: {error}") from error
    missing = sorted(set(wanted) - set(found))
    if missing:
        raise Refused(f"the archive lacks {missing}")
    destination.mkdir(parents=True, exist_ok=False)
    for name, relative in wanted.items():
        (destination / relative).parent.mkdir(exist_ok=True)
        (destination / relative).write_bytes(found[name])
    return destination


def registry_tree(depot, uuid, version):
    """git-tree-sha1 of a package version in the registry copy of a depot (a directory or a tarball); None if
    the depot has no registry that lists it."""
    import tarfile
    registries = Path(depot) / "registries"
    if not registries.is_dir():
        return None
    for entry in sorted(registries.iterdir()):
        try:
            if entry.is_dir():
                def read(name, entry=entry):
                    return (entry / name).read_text(encoding="utf-8")
            elif entry.name.endswith((".tar.gz", ".tar")):
                tar = tarfile.open(entry, "r:*")

                def read(name, tar=tar):
                    for candidate in (name, "./" + name):
                        with contextlib.suppress(KeyError):
                            return tar.extractfile(candidate).read().decode("utf-8")
                    raise KeyError(name)
            else:
                continue
            info = tomllib.loads(read("Registry.toml"))["packages"].get(uuid)
            if info is not None:
                return tomllib.loads(read(f"{info['path']}/Versions.toml"))[version]["git-tree-sha1"]
        except (KeyError, OSError, tarfile.TarError, tomllib.TOMLDecodeError, UnicodeDecodeError):
            continue
    return None


# ------------------------------------------------------------------------------------------ prepare: fetch

@dataclasses.dataclass
class Prepare:
    """What `prepare` works on: the configuration (a pilot configuration or an official lock), the committed
    official schedule, the Julia binaries and the host-specific source locators."""
    kind: str                       # "pilot" or "official"
    config: dict
    config_path: Path
    base: Path
    sched: dict                     # the committed official schedule (strata, stack_a, machine, ...)
    arms: tuple
    julia_bins: dict
    parent_env: dict
    source: str = None              # repository of ProximalSolvers (stack A and stack B)
    pb_source: str = None           # optional repository of ProximalBase (tag check; stack B development)
    archive: str = None             # the Stage 2A archive
    lock: dict = None
    min_cpus: int = 2
    repo: Path = None               # the driver checkout (the lock's frozen files are read from it)
    run: object = None

    def roles(self):
        return [ARM_ROLES[arm][letter] for arm in self.arms for letter in "AB"]

    def stack_of(self, role):
        return "B" if (self.kind == "official" and role == "ab-b") else "A"

    def campaign_id(self):
        return self.config["campaign"]["id"]

    def refuse_fixed_session(self):
        """A configuration that fixes campaign.session_id would give every attempt prepared from it one session."""
        if "session_id" in self.config["campaign"]:
            raise Refused("the configuration names campaign.session_id: prepare --step fetch mints a fresh session "
                          "for every base, so that independent attempts never share one; remove session_id "
                          "(it is accepted only when verifying evidence prepared before that)",
                          field="campaign.session_id")

    def session_id(self):
        """The session `prepare --step fetch` minted for this base (logs/session.json)."""
        self.refuse_fixed_session()
        record, problems = session_record_problems(self.base, self.kind == "official", self.campaign_id())
        if problems:
            raise Refused("the base has no valid session record (run prepare --step fetch first): " + "; ".join(
                problems), field="session", problems=problems)
        return record["session_id"]

    def expected(self, role):
        return expected_identity(self.sched, self.stack_of(role), self.lock)


def prepare_settings(args, kind, config, base, official_sched, environ, bins=None):
    """The Prepare of a `prepare` command; refusals before anything is created."""
    base = Path(base)
    strata = list(official_sched["strata"])
    if kind == "pilot":
        if "pilot" not in base.name:
            raise LockRefusal("base", f"the base directory name {base.name!r} lacks pilot")
        source = (config.get("source") or {})
        arms = tuple(a for a in ARMS if a in config["pilot"]["arms"])
        repository, pb_source = source.get("repository"), source.get("proximalbase")
        archive = getattr(args, "archive", None) or (config.get("archive") or {}).get("path")
        min_cpus = (config.get("resources") or {}).get("min_cpus", 2)
        lock = None
    else:
        if "stack_b" not in config:
            raise Refused("the lock has no [stack_b] candidate", field="stack_b")
        arms = schedule_arms(HERE)
        repository = config["stack_b"]["proximalsolvers"]["source"]
        pb_source = config["stack_b"]["proximalbase"]["source"]
        archive, min_cpus, lock = getattr(args, "archive", None), 2, config
    if bins is None:
        bins = julia_binaries(getattr(args, "julia", None), config, strata)
    if args.step == "fetch" and not repository:
        raise Refused("prepare --step fetch needs the ProximalSolvers repository locator ([source] repository of "
                      "the pilot configuration)", field="source.repository")
    return Prepare(kind=kind, config=config, config_path=Path(args.config), base=base, sched=official_sched,
                   arms=arms, julia_bins=bins, parent_env=dict(environ), source=repository, pb_source=pb_source,
                   archive=archive, lock=lock, min_cpus=min_cpus, repo=HERE.parents[2])


def julia_binaries(options, config, strata):
    """{stratum: absolute path of the Julia binary} from `[julia]` of a pilot configuration and `--julia MM=PATH`
    options (the options win); every stratum of the schedule needs one."""
    bins = dict((config or {}).get("julia") or {})
    for item in options or []:
        mm, separator, path = item.partition("=")
        if not (separator and STRATUM_KEY.fullmatch(mm) and path.startswith("/")):
            raise UsageError(f"--julia expects MAJOR.MINOR=ABSOLUTE_PATH, not {item!r}")
        bins[mm] = path
    missing, extra = [mm for mm in strata if mm not in bins], sorted(set(bins) - set(strata))
    if missing or extra:
        raise Refused(f"the Julia binaries {sorted(bins)} are not the strata {list(strata)} of the schedule "
                      "(use [julia] of the pilot configuration or --julia MAJOR.MINOR=PATH)", field="julia")
    return {mm: bins[mm] for mm in strata}


def fetch_env(parent_env, depot, bundled):
    """The environment of a network step (instantiate, resolve): the whitelist, a private depot, no offline flag."""
    env = {name: parent_env[name] for name in ENV_PASSTHROUGH if name in parent_env}
    env.update({"JULIA_NUM_THREADS": "1", "OPENBLAS_NUM_THREADS": "1", "JULIA_LOAD_PATH": "@:@stdlib",
                "JULIA_DEPOT_PATH": f"{depot}:{bundled}" if bundled else str(depot),
                "JULIA_PKG_PRECOMPILE_AUTO": "0"})
    return env


def clone_checkout(source, destination, commit, run):
    """An independent clone (no shared objects) checked out detached at the pinned commit."""
    run_git(run, *GIT_THREADS, "clone", "--quiet", "--no-hardlinks", "--", str(source), str(destination))
    git(destination, "checkout", "--quiet", "--detach", commit, run=run or subprocess.run)


def verify_checkout(checkout, pinned, harness, run):
    """Facts of a fresh checkout; Refused unless it is the pinned commit and tree, clean (untracked and ignored
    files included), with the Python fingerprints of the package (and of the harness) equal to the pins."""
    run = run or subprocess.run
    problems = []
    seen = {"commit": git(checkout, "rev-parse", "HEAD", run=run), "tree": git(checkout, "rev-parse", "HEAD^{tree}",
                                                                             run=run)}
    for key in ("commit", "tree"):
        if seen[key] != pinned[key]:
            problems.append(f"{key} {seen[key]} is not the pinned {pinned[key]}")
    if not git_clean(checkout, run=run):
        problems.append("the checkout is not clean (tracked, untracked or ignored files)")
    seen["package_hash"] = package_fingerprint(checkout)
    if seen["package_hash"] != pinned["package_hash"]:
        problems.append(f"the package fingerprint {seen['package_hash']} is not the pinned {pinned['package_hash']}")
    if harness is not None:
        try:
            seen["harness_hash"] = harness_hash(Path(checkout) / "benchmark")
        except OSError as error:
            seen["harness_hash"] = None
            problems.append(f"the harness cannot be read: {error}")
        if seen["harness_hash"] != harness:
            problems.append(f"the harness fingerprint {seen['harness_hash']} is not the pinned {harness}")
    if problems:
        raise Refused(f"{Path(checkout).parent.name}: " + "; ".join(problems), problems=problems)
    return seen


PKG_ATTEMPTS = 3


def julia_step(st, role, mm, name, code, env_dir, pause=5.0):
    """One Julia step of prepare in the role's environment: output kept in logs/ (one log pair per attempt), a
    failing step is retried (a network step is idempotent; at most PKG_ATTEMPTS attempts) and then refused.
    Returns whether Pkg warned that the Manifest is out of sync with the Project."""
    bundled = bundled_depots(st.julia_bins)[mm]
    argv = [str(st.julia_bins[mm]), *JULIA_FLAGS, f"--project={env_dir}", "-e", code]
    env = fetch_env(st.parent_env, st.base / "depots" / role, bundled)
    logs = st.base / "logs"
    for attempt in range(1, PKG_ATTEMPTS + 1):
        label = name if attempt == 1 else f"{name}-attempt{attempt}"
        result = run_process(st.run, argv, env, env_dir)
        create_exclusive(logs / f"prepare-{role}-{mm}-{label}.out", result.stdout.decode("utf-8", "replace"))
        create_exclusive(logs / f"prepare-{role}-{mm}-{label}.err", result.stderr.decode("utf-8", "replace"))
        (logs / "prepare-commands.jsonl").touch()
        append_jsonl(logs / "prepare-commands.jsonl", {"step": f"{role}-{mm}-{label}", "argv": argv,
                                                       "env": redacted_env(env),
                                                       "cwd": str(env_dir), "exit": result.exit})
        if result.exit == 0:
            return STALE_MANIFEST in (result.stdout + result.stderr).decode("utf-8", "replace")
        if attempt < PKG_ATTEMPTS and pause:
            time.sleep(pause)
    raise Refused(f"{role} julia {mm}: Pkg step {name} exited with {result.exit} in {PKG_ATTEMPTS} attempts: "
                  f"{tail(result.stderr)}")


def prepare_environment_a(st, role, mm, archive_dir, checkout_real, campaign):
    """The Stage 2A environment of one role and stratum: the archived Project and Manifest with only the
    ProximalSolvers path lines rewritten to the role's checkout, instantiated; the entries must stay identical."""
    env = st.base / "environments" / role / f"env-{mm}"
    env.mkdir(parents=True)
    old_manifest = (archive_dir / f"julia-{mm}" / "Manifest.toml").read_bytes().decode("utf-8")
    old_project = (archive_dir / f"julia-{mm}" / "Project.toml").read_bytes().decode("utf-8")
    manifest = rewrite_manifest_path(old_manifest, checkout_real)
    project, _ = rewrite_project_sources(old_project, checkout_real)
    create_exclusive(env / "Manifest.toml", manifest)
    create_exclusive(env / "Project.toml", project)
    record = {"stale_warning": julia_step(st, role, mm, "instantiate", "using Pkg; Pkg.instantiate()", env)}
    record["resolved"] = record["stale_warning"]
    if record["stale_warning"]:
        julia_step(st, role, mm, "resolve", "using Pkg; Pkg.resolve()", env)
    new_manifest = (env / "Manifest.toml").read_bytes().decode("utf-8")
    new_project = (env / "Project.toml").read_bytes().decode("utf-8")
    logs = st.base / "logs"
    create_exclusive(logs / f"prepare-{role}-{mm}-manifest.diff", unified(
        old_manifest, new_manifest, "archive/Manifest.toml", f"{role}/env-{mm}/Manifest.toml"))
    create_exclusive(logs / f"prepare-{role}-{mm}-project.diff", unified(
        old_project, new_project, "archive/Project.toml", f"{role}/env-{mm}/Project.toml"))
    problems = []
    if new_project != project:
        problems.append("Project.toml changed during instantiate or resolve")
    if manifest_entries(new_manifest) != manifest_entries(old_manifest):
        problems.append("the (name, uuid, version, git-tree-sha1) entries differ from the archived Manifest")
    if manifest_entries(new_manifest) != lock_entries(campaign, mm):
        problems.append("the entries differ from the lock of the Stage 2A campaign definition")
    foreign = foreign_changes(old_manifest, new_manifest)
    if foreign:
        problems.append(f"Manifest lines other than the path and project_hash changed: {foreign[:4]}")
    if problems:
        raise Refused(f"{role} julia {mm}: no fresh resolution and no new historical baseline: " + "; ".join(problems),
                      problems=problems)
    return env, record


def prepare_environment_b(st, role, mm):
    """The frozen Project and Manifest of the lock (SHA-256 checked), instantiated; they must stay unchanged."""
    spec = st.lock["stack_b"]["environments"][mm]
    env = st.base / "environments" / role / f"env-{mm}"
    env.mkdir(parents=True)
    repo = os.path.realpath(st.repo)
    for key, name in (("project", "Project.toml"), ("manifest", "Manifest.toml")):
        source = os.path.realpath(Path(st.repo) / spec[key])
        if not source.startswith(repo + os.sep) or not os.path.isfile(source):
            raise Refused(f"stack B julia {mm}: {spec[key]} is not a file of the driver repository")
        if sha256_file(source) != spec[f"{key}_sha256"]:
            raise Refused(f"stack B julia {mm}: {spec[key]} differs from the SHA-256 of the lock")
        shutil.copyfile(source, env / name)
    stale = julia_step(st, role, mm, "instantiate", "using Pkg; Pkg.instantiate()", env)
    if stale:
        raise Refused(f"stack B julia {mm}: Pkg reports that the frozen Manifest is out of sync with the Project")
    for key, name in (("project", "Project.toml"), ("manifest", "Manifest.toml")):
        if sha256_file(env / name) != spec[f"{key}_sha256"]:
            raise Refused(f"stack B julia {mm}: {name} changed during instantiate")
    return env, {"stale_warning": False, "resolved": False}


def snapshot_environment(st, role, mm, env):
    target = st.base / "roots" / role / f"julia-{mm}"
    target.mkdir(parents=True)
    for name in ("Project.toml", "Manifest.toml"):
        shutil.copyfile(env / name, target / name)
        (target / name).chmod(0o444)


DEFAULT_PB_SOURCE = "https://github.com/mlakolar/ProximalBase.jl"


def check_pb_tag(st, depot):
    """The ProximalBase tag of stack A resolves to the pinned commit AND tree. It is always checked, never
    skipped: from the configured locator (`[source] proximalbase` of the pilot configuration, the lock's source) or,
    when none is configured, from DEFAULT_PB_SOURCE. A failing clone or git, another commit or another tree is a
    refusal. A registry copy of the instantiated depot is a second witness for the tree only: its absence is
    acceptable (the tag check is what must succeed), a different tree is a refusal, and a matching registry tree
    alone proves nothing."""
    pb = st.sched["stack_a"]["proximalbase"]
    uuid = stage2a_campaign()["proximalbase"]["uuid"]
    source = st.pb_source or DEFAULT_PB_SOURCE
    record = {"tag": pb["tag"], "registry_tree": registry_tree(depot, uuid, pb["version"]),
              "source": source, "source_kind": "configured locator" if st.pb_source else "default repository"}
    if record["registry_tree"] not in (None, pb["tree"]):
        raise Refused(f"the registry lists ProximalBase {pb['version']} with tree {record['registry_tree']}, "
                      f"expected {pb['tree']}")
    scratch = Path(tempfile.mkdtemp(prefix="stage2b-pb-"))
    try:
        run_git(st.run, *GIT_THREADS, "clone", "--quiet", "--bare", "--no-hardlinks", "--", source,
                str(scratch / "pb.git"))
        run = st.run or subprocess.run
        for key, spec in (("commit", f"refs/tags/{pb['tag']}^{{commit}}"), ("tree", f"refs/tags/{pb['tag']}^{{tree}}")):
            record[f"clone_{key}"] = git(scratch / "pb.git", "rev-parse", spec, run=run)
            if record[f"clone_{key}"] != pb[key]:
                raise Refused(f"the tag {pb['tag']} of the ProximalBase clone has {key} "
                              f"{record[f'clone_{key}']}, expected {pb[key]}")
    finally:
        shutil.rmtree(scratch, ignore_errors=True)
    return record


def stage2a_campaign():
    try:
        return tomllib.loads(STAGE2A_CAMPAIGN.read_text(encoding="utf-8"))
    except (OSError, UnicodeDecodeError, tomllib.TOMLDecodeError) as error:
        raise Refused(f"cannot read the Stage 2A campaign definition: {error}") from error


def write_base_files(st):
    """The copies the campaign uses: schedule.toml (for a pilot the committed one, provisional until finalize
    replaces it), case-mapping.toml and the configuration."""
    st.base.mkdir(parents=True, exist_ok=True)
    configuration = "pilot-config.toml" if st.kind == "pilot" else "lock.toml"
    for name, source in (("schedule.toml", HERE / "schedule.toml"), ("case-mapping.toml", HERE / "case-mapping.toml"),
                         (configuration, st.config_path)):
        target = st.base / name
        if target.exists():
            if target.read_bytes() != Path(source).read_bytes():
                raise Refused(f"{name} of the base differs from the file this command is given", field=name)
        else:
            shutil.copyfile(source, target)


def prepare_fetch(st):
    """prepare --step fetch (network allowed, any host): per role an independent clone at the pinned commit, the
    private depot and the environments, the pinned identities verified. Nothing existing is reused or deleted."""
    roles, strata = st.roles(), list(st.sched["strata"])
    st.refuse_fixed_session()
    if (st.base / SESSION_RECORD).exists():
        raise Refused(f"{SESSION_RECORD} exists in {st.base.name}: prepare --step fetch ran on this base already",
                      field="session")
    for role in roles:
        for directory in ("installations", "environments", "depots", "roots"):
            if (st.base / directory / role).exists():
                raise Refused(f"{directory}/{role} already exists in {st.base.name}: nothing is reused or deleted",
                              field=f"{directory}/{role}")
    needs_archive = any(st.stack_of(role) == "A" for role in roles)
    if needs_archive and not st.archive:
        raise Refused("the Stage 2A archive is needed for stack A (--archive or [archive] path)", field="archive")
    if needs_archive:
        check_archive_digest(st.archive)
    campaign, archive_dir, summary = stage2a_campaign(), None, {"schema": 1, "roles": {}}
    write_base_files(st)
    (st.base / "logs").mkdir(exist_ok=True)
    session = write_session_record(st.base, st.campaign_id(), st.kind == "official")["session_id"]
    summary["session_id"] = session
    if needs_archive:
        archive_dir = extract_archive(st.archive, st.base / "environments" / "_archive", strata,
                                      campaign["archive"]["name"])
    first_a = None
    for role in roles:
        stack, pinned = st.stack_of(role), st.expected(role)
        checkout = st.base / "installations" / role / "ProximalSolvers.jl"
        clone_checkout(st.source, checkout, pinned["ps"]["commit"], st.run)
        facts = verify_checkout(checkout, pinned["ps"], pinned["harness_hash"], st.run)
        info = {"stack": stack, "checkout": facts, "environments": {}}
        if stack == "B":                              # registered and development alike: the pinned identity checkout
            pb_checkout = st.base / "installations" / role / "ProximalBase.jl"
            clone_checkout(st.pb_source or DEFAULT_PB_SOURCE, pb_checkout, pinned["pb"]["commit"], st.run)
            info["proximalbase"] = verify_checkout(pb_checkout, pinned["pb"], None, st.run)
        (st.base / "depots" / role).mkdir(parents=True)
        real = os.path.realpath(checkout)
        for mm in strata:
            if stack == "A":
                env, record = prepare_environment_a(st, role, mm, archive_dir, real, campaign)
            else:
                env, record = prepare_environment_b(st, role, mm)
            snapshot_environment(st, role, mm, env)
            info["environments"][mm] = dict(record, manifest_sha256=sha256_file(env / "Manifest.toml"),
                                            project_sha256=sha256_file(env / "Project.toml"))
        summary["roles"][role] = info
        first_a = first_a or (role if stack == "A" else None)
    provenance = {"schema": 1, "pb_tag_check": "not applicable: no stack A role"}
    if first_a is not None:
        summary["proximalbase_tag"] = check_pb_tag(st, st.base / "depots" / first_a)
        provenance = {"schema": 1, "pb_tag_check": f"verified: {summary['proximalbase_tag']['source_kind']}",
                      "record": summary["proximalbase_tag"]}
    create_exclusive(st.base / "logs" / "provenance.json", json.dumps(provenance, indent=2) + "\n")
    create_exclusive(st.base / "logs" / "prepare-fetch.json", json.dumps(summary, indent=2) + "\n")
    print(f"prepare fetch: {len(roles)} roles in {st.base.name}, {session}: " + ", ".join(
        f"{role} {summary['roles'][role]['checkout']['commit'][:12]}" for role in roles))
    return 0


# ---------------------------------------------------------------------------------------- prepare: finalize

def flatten(table, prefix=""):
    items = {}
    for key, value in table.items():
        path = f"{prefix}{key}"
        if isinstance(value, dict):
            items.update(flatten(value, path + "."))
        else:
            items[path] = value
    return items


def pilot_sampling(config):
    """The reduced sampling values of a pilot configuration (all three are required for finalize)."""
    pilot = config["pilot"]
    missing = [key for key in PILOT_SAMPLING if key not in pilot]
    if missing:
        raise Refused(f"the pilot configuration lacks the reduced sampling values {missing}", field="pilot")
    return {key: pilot[key] for key in PILOT_SAMPLING}  # as validated: no coercion, the checks compare exactly


def derive_pilot_schedule(official, config, machine, arms):
    """The pilot schedule: the committed official schedule (parsed) with ONLY the keys of
    PILOT_SCHEDULE_CHANGES changed. Returns (schedule, {key: [old, new]}); any other change is an error."""
    new = copy.deepcopy(official)
    new["schedule"].update({"id": config["schedule"]["id"], "campaign_id": config["campaign"]["id"], "reps": [1],
                            "orders": {"1": "AB"}, "arms": list(arms)})
    new["settings"].update(pilot_sampling(config))
    new["machine"].update(machine)
    before, after = flatten(official), flatten(new)
    changes = {key: [before.get(key), after.get(key)] for key in sorted(before.keys() | after.keys())
               if before.get(key) != after.get(key)}
    stray = [key for key in changes if not any(key == allowed or key.startswith(allowed + ".")
                                                for allowed in PILOT_SCHEDULE_CHANGES)]
    if stray:
        raise Refused(f"the pilot schedule would change keys outside the whitelist: {stray}")
    return new, changes


def pilot_machine(observations, strata, roles, sample, cpu):
    """The [machine] values of a pilot schedule from what this node reported."""
    models = {obs["machine"]["cpu_model"] for obs in observations.values()}
    if len(models) != 1 or sample["cpu_model"] not in models:
        raise Refused(f"the CPU model differs between Julia {sorted(models)} and the host {sample['cpu_model']!r}")
    names = {}
    for mm in strata:
        found = {observations[(role, mm)]["machine"]["cpu"] for role in roles}
        if len(found) != 1:
            raise Refused(f"julia {mm}: the roles report different Sys.CPU_NAME values {sorted(found)}")
        names[mm] = next(iter(found))
    return {"cpu_model": next(iter(models)), "cpu": names, "logical_cpu": cpu, "smt_sibling": -1,
            "governor": sample["governor"], "epp": sample["epp"], "no_turbo": sample["no_turbo"],
            "smt_control": sample["smt_control"]}


def write_pilot_schedule(st, machine):
    """Replace the provisional schedule.toml of a pilot base by the derived one (once) and record both digests."""
    base = st.base
    official_text = (HERE / "schedule.toml").read_bytes()
    current = base / "schedule.toml"
    if current.read_bytes() != official_text:
        raise Refused("schedule.toml of the base is not the provisional copy of the committed schedule")
    new, changes = derive_pilot_schedule(tomllib.loads(official_text.decode("utf-8")), st.config, machine, st.arms)
    text = toml_dumps(new)
    if tomllib.loads(text) != new:
        raise Refused("the pilot schedule does not round-trip as TOML")
    temporary = base / "schedule.toml.new"
    create_exclusive(temporary, text)
    try:
        derived = mc.load_schedule(temporary)
    except mc.Usage as error:
        temporary.unlink()
        raise Refused(f"the pilot schedule is not accepted by the comparator's loader: {error}") from error
    os.replace(temporary, current)
    create_exclusive(base / "logs" / "pilot-overrides.json", json.dumps({
        "schema": 1, "official_schedule_sha256": sha256_bytes(official_text),
        "provisional_sha256": sha256_bytes(official_text), "final_sha256": sha256_bytes(text.encode("utf-8")),
        "pilot_config_sha256": sha256_file(st.config_path), "changes": changes}, indent=2) + "\n")
    return derived


def mint_installation(role, checkout, depot):
    """An installation id minted from the role name and bound to the realpaths of its checkout and depot."""
    digest = sha256_bytes(f"{role}\0{os.path.realpath(checkout)}\0{os.path.realpath(depot)}".encode())[:12]
    return f"{role}-{digest}"


def identity_parts(st, role):
    pinned = st.expected(role)
    ps = {k: pinned["ps"][k] for k in ("commit", "tree", "version")}
    pb = {k: pinned["pb"][k] for k in ("commit", "tree", "version")}
    if st.stack_of(role) == "A":
        a = st.sched["stack_a"]["proximalbase"]
        pb.update(release=a["release"], tag=a["tag"])
    else:
        b = st.lock["stack_b"]["proximalbase"]
        pb["release"] = b["release"]
        if "tag" in b:
            pb["tag"] = b["tag"]
    return ps, pb


def concatenate_fingerprints(st, role, strata):
    """roots/<role>/fingerprints.tsv and fingerprints.datahash.tsv from the per-stratum exporter files, in
    stratum order, with one header each."""
    for suffix, name, header in (("", FP_NAME, mc.FP_HEADER), (".datahash.tsv", DATAHASH_NAME, DATAHASH_HEADER)):
        lines = [header]
        for mm in strata:
            path = st.base / "logs" / f"fingerprints-{role}-{mm}.tsv{suffix}"
            text = path.read_text(encoding="utf-8").split("\n")
            if text[-1] == "":
                text.pop()
            if not text or text[0] != header:
                raise Refused(f"{path.name} has a wrong header")
            lines += text[1:]
        create_exclusive(st.base / "roots" / role / name, "\n".join(lines) + "\n")


def prepare_finalize(st, hooks, getaffinity=None, setaffinity=None, say=None):
    """prepare --step finalize: on the measurement node, offline, with the formal Julia flags and environment.

    Per role and stratum: Pkg.precompile(), two untimed PS_LIST=true warm-up runs of the role's run.jl (the second
    must not precompile), the exporter (roles ab-a and ab-b: one fresh process per role and stratum), the probe
    (written as roots/<role>/julia-MM/environment-inventory.toml). Then the identity files, the fingerprint files,
    for a pilot the pilot schedule, the depot baselines; finally the checks of `preflight` on what was observed.
    It refuses to run twice on one base: the marker logs/finalize.json is created before anything else."""
    say = say or (lambda message: print(message, flush=True))
    base, roles, strata = st.base, st.roles(), list(st.sched["strata"])
    for role in roles:
        for mm in strata:
            for name in ("Project.toml", "Manifest.toml"):
                if not (base / "roots" / role / f"julia-{mm}" / name).is_file():
                    raise Refused(f"{role} julia {mm}: {name} is not in the base; run prepare --step fetch first")
        if (base / "roots" / role / "stack-identity.toml").exists():
            raise Refused(f"{role} has an identity file: finalize ran on this base already")
    sampling = pilot_sampling(st.config) if st.kind == "pilot" else None
    campaign_id, session_id = st.campaign_id(), st.session_id()
    marker = base / "logs" / "finalize.json"
    if marker.exists():
        raise Refused("finalize ran on this base already: a base is finalized once", field="finalize")
    allowed = sorted((getaffinity or os.sched_getaffinity)(0))
    if len(allowed) < max(2, st.min_cpus):
        raise Refused(f"{len(allowed)} CPUs are allowed ({allowed}); finalize needs at least {max(2, st.min_cpus)}: "
                      "one for the measured process and the others for the driver")
    cpu = st.sched["machine"]["logical_cpu"] if st.kind == "official" else max(allowed)
    if cpu not in allowed:
        raise Refused(f"the measured CPU {cpu} is not among the allowed CPUs {allowed}")
    marker.parent.mkdir(exist_ok=True)
    create_exclusive(marker, json.dumps({"schema": 1, "state": "started"}) + "\n")
    keep_off_cpu(cpu, lambda _: set(allowed), setaffinity)
    for role in roles:
        ps, pb = identity_parts(st, role)
        checkout, depot = base / "installations" / role / "ProximalSolvers.jl", base / "depots" / role
        write_identity(base, role, mint_installation(role, checkout, depot), campaign_id, session_id, ps, pb)
    bundled = getattr(hooks, "bundled_depot", "")
    if st.kind == "official":
        plan = plan_from_lock(st.lock, base, st.julia_bins, st.parent_env, None, bundled)
    else:
        draft = copy.deepcopy(st.sched)
        draft["settings"].update(sampling)
        draft["machine"]["logical_cpu"] = cpu
        roles_ = build_roles(draft, base, st.arms, False, None, st.julia_bins, bundled)
        plan = Plan(base=base, sched=draft, official=False, campaign_id=campaign_id, session_id=session_id,
                    arms=st.arms, roles=roles_, cpu=cpu, case_filter=draft["settings"]["case_filter"],
                    parent_env=dict(st.parent_env))
    hooks.bind(plan, keep_off=False)
    cases = sorted(plan.sched["settings"]["case_filter"].split(","))
    reps = list(plan.sched["reps"]) if st.kind == "official" else [1]
    observations = {}
    for mm in strata:
        for role in roles:
            spec = plan.roles[role]
            where = f"{role} julia {mm}"

            def step(name, result):
                if result.exit != 0:
                    raise Refused(f"{where}: {name} exited with {result.exit}: {tail(result.stderr)}")
                say(f"finalize {where}: {name} ok")
                return result
            step("precompile", hooks.precompile(spec, mm))
            step("warm-up 1", hooks.warmup(spec, mm, 1))
            warm = hooks.depot_digest(spec)
            second = step("warm-up 2", hooks.warmup(spec, mm, 2))
            output = (second.stdout + second.stderr).decode("utf-8", "replace")
            if "precompiling" in output.lower():
                raise Refused(f"{where}: the second warm-up precompiled again")
            listed = sorted(line.split("\t")[0] for line in second.stdout.decode("utf-8", "replace").splitlines()
                            if line.strip())
            if listed != cases:
                raise Refused(f"{where}: the warm-up listed {len(listed)} cases, not the schedule's {len(cases)}")
            if plan.raw(role, mm).exists() and any(plan.raw(role, mm).iterdir()):
                raise Refused(f"{where}: the warm-up wrote records")
            if role in ("ab-a", "ab-b"):
                step("export", hooks.export(spec, mm, reps, base / "logs" / f"fingerprints-{role}-{mm}.tsv"))
            observation, text = hooks.probe_raw(spec, mm)
            create_exclusive(base / "roots" / role / f"julia-{mm}" / "environment-inventory.toml", text)
            observations[(role, mm)] = observation
            if hooks.depot_digest(spec) != warm:
                raise Refused(f"{where}: the compiled-cache digest of the depot changed after the first warm-up")
            for name in ("Project.toml", "Manifest.toml"):
                if sha256_file(spec.environments[mm] / name) != sha256_file(base / "roots" / role / f"julia-{mm}" / name):
                    raise Refused(f"{where}: {name} of the environment differs from the snapshot in the root")
    for role in roles:
        if role in ("ab-a", "ab-b"):
            concatenate_fingerprints(st, role, strata)
    if st.kind == "pilot":
        write_pilot_schedule(st, pilot_machine(observations, strata, roles, hooks.sampler(), cpu))
        final = plan_from_pilot(st.config, base, st.julia_bins, st.parent_env, None, bundled)
    else:
        final = plan
    problems = preflight_checks(final, observations)
    for role in roles:
        if role in ("ab-a", "ab-b"):
            check_fingerprints(base / "roots" / role, final.sched, role, problems)
    for problem in problems:
        report(problem)
    say(f"finalize: {len(roles)} roles, {len(strata)} strata, measured CPU {cpu}, {len(problems)} problems")
    if problems:                                     # a failed finalize leaves its problems and no baseline
        replace_file(marker, json.dumps({"schema": 1, "state": "failed", "cpu": cpu, "problems": problems},
                                        indent=2) + "\n")
        raise Refused("finalize found problems: " + "; ".join(problems[:5]), problems=problems)
    baselines = {role: str(hooks.depot_digest(final.roles[role])) for role in roles}
    create_exclusive(base / "logs" / "depot-baselines.json", json.dumps(baselines, indent=2) + "\n")
    replace_file(marker, json.dumps({"schema": 1, "state": "finalized", "cpu": cpu, "problems": []}, indent=2)
                 + "\n")
    return 0


# ----------------------------------------------------------------------------------------------- CLI

class Parser(argparse.ArgumentParser):
    def error(self, message):
        raise UsageError(message)


def build_parser():
    parser = Parser(description=__doc__, allow_abbrev=False, formatter_class=argparse.RawDescriptionHelpFormatter)
    commands = parser.add_subparsers(dest="command", required=True, parser_class=Parser)
    for name in ("preflight", "prepare", "run", "pilot"):
        sub = commands.add_parser(name, allow_abbrev=False)
        sub.add_argument("--config", required=True)
        sub.add_argument("--base", required=True)
        if name in ("preflight", "run"):
            sub.add_argument("--official", action="store_true")
            sub.add_argument("--freeze-sha")
        if name in ("preflight", "pilot"):
            sub.add_argument("--arms")
        sub.add_argument("--julia", action="append", metavar="MM=PATH",
                         help="the Julia binary of a stratum (repeatable; wins over [julia] of a pilot configuration)")
        if name == "prepare":
            sub.add_argument("--step", required=True, choices=("fetch", "finalize"))
            sub.add_argument("--archive", help="the Stage 2A archive (default: [archive] path of a pilot "
                                               "configuration)")
    verify_parser = commands.add_parser("verify", allow_abbrev=False)
    verify_parser.add_argument("--base", required=True)
    verify_parser.add_argument("--out", required=True)
    verify_parser.add_argument("--config", help="the pilot configuration the verifier holds (a pilot needs it; "
                                                "ignored for an official attempt)")
    return parser


def parse_arms(text):
    arms = [a.strip() for a in text.split(",")] if text else []
    if not arms or any(a not in ARMS for a in arms) or len(set(arms)) != len(arms):
        raise UsageError(f"--arms must list AB and/or AA, not {text!r}")
    return tuple(a for a in ARMS if a in arms)


def report(message, stream=None):
    print(message, file=stream or sys.stderr)


def main(argv=None, hooks=None, facts=collect_repo_facts, environ=None):
    """The command line. `hooks` (a Hooks) is how tests, and later the real Julia hooks, reach the engine;
    `facts` reads the repository facts of the official gate. The mode comes from the subcommand only."""
    environ = os.environ if environ is None else environ
    try:
        args = build_parser().parse_args(sys.argv[1:] if argv is None else argv)
        return dispatch(args, hooks, facts, environ)
    except (UsageError, mc.Usage) as error:
        report(f"usage error: {error}")
        return 3
    except SystemExit as stop:
        return stop.code if isinstance(stop.code, int) else 3
    except DriverError as error:
        report(f"REFUSED: {error}")
        for problem in getattr(error, "problems", [])[:20]:
            report(f"  {problem}")
        return 2
    except Exception as error:
        report(f"INTERNAL ERROR: {type(error).__name__}: {error}")
        return 3


def dispatch(args, hooks, facts, environ):
    base = Path(args.base)
    if args.command == "verify":
        document, status = verify(base, args.out, config=args.config)
        print(f"verification: {document.get('mode') or 'UNKNOWN MODE'}: {document['state']} "
              f"({len(document['problems'])} problems); record {args.out}")
        for problem in document["problems"][:20]:
            report(f"  {problem}")
        return status
    official_sched = mc.load_schedule(HERE / "schedule.toml")
    strata = list(official_sched["strata"])
    if args.command == "run" and not args.official:
        raise UsageError("run needs --official (a campaign that is not official is a pilot)")
    if args.command == "prepare":
        kind, config = load_config(args.config, official_sched)
        settings = prepare_settings(args, kind, config, base, official_sched, environ,
                                    hooks.julia_bins if hooks is not None else None)
        if args.step == "fetch":
            return prepare_fetch(settings)
        return prepare_finalize(settings, hooks or RealHooks(settings.julia_bins, environ))
    if args.command == "pilot" or (args.command == "preflight" and not args.official):
        arms = parse_arms(args.arms) if args.arms else None
        config = load_pilot(args.config, official_sched)
        if args.command == "pilot" and "pilot" not in base.name:
            raise LockRefusal("base", f"the base directory name {base.name!r} lacks pilot")
        hooks = hooks or RealHooks(julia_binaries(args.julia, config, strata), environ)
        plan = plan_from_pilot(config, base, hooks.julia_bins, environ, arms, getattr(hooks, "bundled_depot", ""))
        if args.command == "pilot":                  # the configuration this attempt used, kept as evidence
            copy_path = base / "pilot-config.toml"
            if copy_path.exists() and copy_path.read_bytes() != Path(args.config).read_bytes():
                raise Refused("pilot-config.toml of the base is not the configuration given with --config",
                              field="pilot-config.toml")
            if not copy_path.exists():
                shutil.copyfile(args.config, copy_path)
        return run_plan(plan, hooks, args.command == "preflight")
    lock = load_lock(args.config, strata=strata)
    observed = facts(HERE.parents[2], args.config, base, HERE / "schedule.toml", HERE / "case-mapping.toml")
    unmet = official_gate(lock, observed, args.freeze_sha)
    if unmet:
        raise Refused("the official gate is not met: " + "; ".join(unmet[:5]), field="gate", problems=unmet)
    hooks = hooks or RealHooks(julia_binaries(args.julia, None, strata), environ)
    if not (base / "lock.toml").is_file() or sha256_file(base / "lock.toml") != sha256_file(args.config):
        raise Refused("lock.toml of the base is not the lock given with --config", field="lock.toml")
    plan = plan_from_lock(lock, base, hooks.julia_bins, environ, args.freeze_sha, getattr(hooks, "bundled_depot", ""))
    return run_plan(plan, hooks, args.command == "preflight")


def run_plan(plan, hooks, only_preflight):
    bind = getattr(hooks, "bind", None)
    if bind is not None:                             # the real hooks learn the plan and keep the driver off the CPU
        bind(plan)
    if only_preflight:
        observations = {(r, mm): hooks.probe(plan.roles[r], mm) for r in plan.role_names()
                        for mm in plan.sched["strata"]}
        problems = preflight_checks(plan, observations)
        for problem in problems:
            report(problem)
        print(f"preflight: {len(problems)} problems")
        return 2 if problems else 0
    outcome = execute(plan, hooks)
    print(f"campaign {outcome.state}: {outcome.processes} processes, comparator exit {outcome.comparator_exit}")
    for item in outcome.nonok:
        report(f"process {item['process']} exited 2; failed cases: {item['failed_cases']}")
    return outcome.exit_code


if __name__ == "__main__":
    raise SystemExit(main())
