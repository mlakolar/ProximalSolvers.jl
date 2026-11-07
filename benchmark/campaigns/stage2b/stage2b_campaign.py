#!/usr/bin/env python3
"""Stage 2B campaign driver (#110, #218): the Python core.

    python3 -B stage2b_campaign.py preflight --config FILE --base BASE [--official --freeze-sha SHA] [--arms AB,AA]
    python3 -B stage2b_campaign.py prepare   --config FILE --base BASE --step fetch|finalize
    python3 -B stage2b_campaign.py run       --config LOCK --base BASE --official --freeze-sha SHA
    python3 -B stage2b_campaign.py pilot     --config PILOT --base BASE [--arms AB]
    python3 -B stage2b_campaign.py verify    --base BASE --out FILE

Standard library only (Python 3.11 or later). The driver launches `benchmark/run.jl` of each role's checkout and
never measures anything itself. Everything that depends on Julia or on the host is injected: the pure functions
take observation dictionaries, and `execute` receives a `Hooks` object (probe, command runner, clock, machine
sampler, data-hash check). The real Julia hooks, `prepare` and the real pilot flow are not part of this module
yet: the subcommands that need them exit with status 3 and launch nothing.

Exit status: 0 success; 1 completed with non-ok cases (a process exit 2 or comparator exit 1; reported and
retained); 2 refused or stopped (official gate, preflight problem, infrastructure stop, comparator refusal,
failed verification); 3 usage or internal error (also "not implemented here").

BASE layout (one directory per campaign attempt; `installations`, `environments` and `depots` are private working
directories and are not evidence; everything else is evidence and is covered by `checksums.sha256`):

    roots/{ab-a,ab-b,aa-a,aa-b}/        comparator roots: stack-identity.toml, fingerprints.tsv and
                                        fingerprints.datahash.tsv (ab-a and ab-b only), julia-MM/{raw/,
                                        Project.toml, Manifest.toml, environment-inventory.toml}
    installations/<role>/ProximalSolvers.jl   the role's checkout (ProximalBase.jl next to it for stack B)
    environments/<role>/env-MM          the role's Julia environment per stratum
    depots/<role>                       the role's private depot (first JULIA_DEPOT_PATH entry)
    schedule.toml  case-mapping.toml  lock.toml     the copies this campaign used (lock.toml: official only)
    receipt.jsonl  declared-differences.toml
    logs/                               seals.jsonl commands.jsonl hardware.jsonl campaign.json comparator.json,
                                        per-process stdout and stderr, STATE.json, completion.json
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


class NotImplementedHere(UsageError):
    """The subcommand needs the real Julia hooks, which a later task provides."""


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
    rows = facts.get("mapping_rows") or []
    need(bool(rows), "MAPPING", "no case-mapping rows were observed")
    for row in rows:
        if row.get("class") in ("B", "C", "D"):
            need(row.get("approved") is True, "MAPPING", f"case {row.get('id')}: class {row.get('class')} "
                 "is not approved")
    approvals = (lock or {}).get("approvals")
    if not isinstance(approvals, dict):
        need(False, "APPROVALS", "the lock has no [approvals] table")
        return unmet
    for gate in GATES:
        value = approvals.get(gate)
        need(isinstance(value, str) and APPROVAL_URL.fullmatch(value), f"APPROVAL_{gate}",
             f"{gate} needs a maintainer comment URL of this repository, not {value!r}")
    urls = approvals.get("case_mapping")
    need(isinstance(urls, list) and bool(urls) and all(isinstance(u, str) and APPROVAL_URL.fullmatch(u)
                                                         for u in urls),
         "APPROVAL_CASE_MAPPING", "the case-mapping approvals need maintainer comment URLs of this repository")
    return unmet


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


def parse_pilot(data, official_sched):
    """Validate a pilot configuration against the official schedule; any refusal is a Refused.

    The pilot has its own campaign and schedule ids (both contain `-pilot` and differ from the official ones)
    and no [stack_b] table: its stack B is a second independent installation of stack A."""
    if isinstance(data, dict) and "stack_b" in data:
        raise LockRefusal("stack_b", "a pilot has no [stack_b] table")
    _table(data, PILOT_TOP, (), "pilot")
    if data["schema"] != 1 or isinstance(data["schema"], bool):
        raise LockRefusal("schema", "must be 1")
    campaign = _table(data["campaign"], ("id",), ("session_id",), "campaign")
    schedule = _table(data["schedule"], ("id",), (), "schedule")
    pilot = _table(data["pilot"], ("arms",), (), "pilot")
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
    return data


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
    bundled_depot: str          # the Julia installation's own depot, appended after the private one ("" = none)
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
                "harness_hash": a["harness_hash"], "manifest_sha256": {}}
    b = lock["stack_b"]
    return {"ps": {k: b["proximalsolvers"][k] for k in ("commit", "tree", "version", "package_hash")},
            "pb": {k: b["proximalbase"][k] for k in ("commit", "tree", "version", "package_hash")},
            "harness_hash": b["harness_hash"],
            "manifest_sha256": {mm: env["manifest_sha256"] for mm, env in b["environments"].items()}}


def read_identity_file(base, role):
    path = Path(base) / "roots" / role / "stack-identity.toml"
    try:
        return tomllib.loads(path.read_text(encoding="utf-8"))
    except (OSError, UnicodeDecodeError, tomllib.TOMLDecodeError) as error:
        raise Refused(f"cannot read the identity of {role}: {error}") from error


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
    declared_arms = tomllib.loads((base / "schedule.toml").read_text(encoding="utf-8"))["schedule"]["arms"]
    arms = tuple(arm for arm in ARMS if arm in declared_arms)
    session = lock["campaign"].get("session_id") or mint_session_id()
    roles = build_roles(sched, base, arms, True, lock, julia_bins, bundled_depot)
    return Plan(base=base, sched=sched, official=True, campaign_id=sched["campaign_id"], session_id=session,
                arms=arms, roles=roles, cpu=sched["machine"]["logical_cpu"],
                case_filter=sched["settings"]["case_filter"], parent_env=dict(parent_env), lock=lock,
                freeze_sha=freeze_sha)


def plan_from_pilot(config, base, julia_bins, parent_env, arms=None, bundled_depot=""):
    """The plan of a pilot: stack B is a second independent installation of stack A; never official."""
    base = Path(base)
    if "pilot" not in base.name:
        raise LockRefusal("base", f"the base directory name {base.name!r} lacks pilot")
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
    session = config["campaign"].get("session_id") or mint_session_id()
    roles = build_roles(sched, base, chosen, False, None, julia_bins, bundled_depot)
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


def launch_env(plan, spec, mm, rep):
    """The measurement environment: a whitelist, never the parent environment."""
    env = {name: plan.parent_env[name] for name in ENV_PASSTHROUGH if name in plan.parent_env}
    env.update({name: plan.parent_env[name] for name in JOB_ID_VARIABLES if name in plan.parent_env})
    s = plan.sched["settings"]
    depots = str(spec.depot) + (f":{spec.bundled_depot}" if spec.bundled_depot else "")
    env.update({
        "JULIA_NUM_THREADS": "1", "OPENBLAS_NUM_THREADS": "1", "JULIA_LOAD_PATH": "@:@stdlib",
        "JULIA_DEPOT_PATH": depots, "JULIA_PKG_OFFLINE": "true",
        "PS_SUITE": s["suite"], "PS_GROUPS": s["groups"], "PS_SAMPLES": str(s["samples_target"]),
        "PS_SECONDS": repr(float(s["seconds_limit"])), "PS_CASE_SECONDS": repr(float(s["case_seconds"])),
        "PS_PROFILE_SECONDS": repr(float(s["profile_seconds"])), "PS_CASES": plan.case_filter,
        "PS_REPETITION": str(rep), "PS_OUTPUT": str(plan.raw(spec.name, mm)),
        "PS_EXPECTED_PACKAGE_ROOT": str(spec.checkout)})
    return env


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
    export: used by prepare (the fingerprint exporter), not by the engine"""
    probe: object
    runner: object
    clock: object = utc_now
    sampler: object = None
    julia_bins: dict = dataclasses.field(default_factory=dict)
    datahash_ok: object = None
    depot_digest: object = None
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


def machine_record(sample, cpu_name, logical_cpu):
    """The `machine` object of a receipt process event (cpu is Sys.CPU_NAME from the probe)."""
    missing = [k for k in SAMPLE_KEYS if k not in sample]
    if missing:
        raise ValueError(f"the machine sample lacks {missing}")
    return {"cpu_model": sample["cpu_model"], "cpu": cpu_name, "logical_cpu": logical_cpu,
            "governor": sample["governor"], "epp": sample["epp"], "no_turbo": sample["no_turbo"],
            "smt_control": sample["smt_control"]}


# --------------------------------------------------------------------------------------- preflight

def _dig(observation, path):
    value = observation
    for part in path.split("."):
        if not isinstance(value, dict) or part not in value:
            return None
        value = value[part]
    return value


def pseudo_root(spec, observation):
    """A root dictionary of the shape `migration_compare.check_independent` reads, built from an observation."""
    strata, inv, procs = {}, {}, {}
    for mm, obs in observation.items():
        env = _dig(obs, "environment.dir")
        checkout, depot = _dig(obs, "checkout_realpath"), _dig(obs, "depot_realpath")
        env_real = _dig(obs, "environment.realpath")
        if None in (env, checkout, depot, env_real):
            continue
        strata[mm] = {"inv": {"depot_path": [str(spec.depot)], "depot_realpath": norm(depot),
                              "active_project": f"{env}/Project.toml",
                              "active_project_realpath": f"{norm(env_real)}/Project.toml",
                              "proximalsolvers_dir": norm(checkout)},
                      "procs": {0: {"meta": {"proximalsolvers_path": str(spec.checkout),
                                             "expected_package_root": str(spec.checkout)}}}}
        if spec.bundled_depot:
            strata[mm]["inv"]["depot_path"].append(spec.bundled_depot)
    return {"name": ROLE_LABEL[spec.name], "ident": {"installation": spec.installation}, "strata": strata}


def preflight_checks(plan, observations):
    """Every problem of the observations against the plan, never only the first (an empty list: ready).

    `observations` maps (role, stratum) to a dictionary:

        julia           {version, commit, cpu_name}        the binary that will run
        ps              {commit, tree, version, dirty, loaded_realpath, package_hash}
        pb              {loaded_tree, manifest_tree, version, package_hash}
        checkout_realpath, depot_realpath                  realpaths of the role's checkout and first depot
        environment     {dir, realpath, project_exists, manifest_exists}
        manifest_sha256, harness_hash
        affinity_cpus   the CPUs the pinned launch is restricted to (a list of integers)
        machine         {cpu_model, cpu, logical_cpu}

    Each problem is `<CODE>: <role> <stratum>: <detail>`; the codes are JULIA_VERSION, JULIA_COMMIT, PS_VERSION,
    PB_VERSION, PS_COMMIT, PS_TREE, DIRTY, PB_TREE, PS_PATH, MANIFEST_SHA256, ENV_MISSING, AFFINITY, CASE_FILTER,
    HARNESS_HASH, PACKAGE_HASH, MACHINE, SHARED and OBSERVATION (a key that is absent or of the wrong type).
    The policy values (governor, epp, no_turbo, smt_control) are labelled, not refused."""
    problems, sched = [], plan.sched
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
    return problems


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
        if not (isinstance(machine, dict) and tuple(machine) == MACHINE_KEYS
                and isinstance(machine["logical_cpu"], int)
                and all(isinstance(machine[k], str) for k in MACHINE_KEYS if k != "logical_cpu")):
            raise ValueError(f"machine must have exactly the keys {MACHINE_KEYS}")
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
    used = set()

    def match(kind, name, uuid=None, change=None):
        for index, entry in enumerate(lock_entries):
            if entry["kind"] == kind and entry["name"] == name and (kind == "compat" or (
                    entry["uuid"] == uuid and entry["change"] == change)):
                yield index, entry
    manifest_rows, groups = [], {}
    for mm in strata:
        sa, sb = roots["a"]["strata"][mm], roots["b"]["strata"][mm]
        for item in sorted(mc.manifest_diff(sa["manifest"]["entries"], sb["manifest"]["entries"])):
            groups.setdefault(item, []).append(mm)
    for item, applied in sorted(groups.items()):
        name, uuid, kind, a_version, b_version, a_tree, b_tree = item
        covered = set()
        for index, entry in match("manifest", name, uuid, kind):
            julia = [mm for mm in entry.get("julia", strata) if mm in applied]
            if not julia:
                continue
            used.add(index)
            covered |= set(julia)
            row = {"name": name, "uuid": uuid, "kind": kind, "a_version": a_version, "b_version": b_version,
                   "a_tree": a_tree, "b_tree": b_tree, "reason": entry["reason"]}
            if sorted(julia) != sorted(strata):
                row["julia"] = julia
            manifest_rows.append(row)
        for mm in applied:
            if mm not in covered:
                problems.append(f"manifest {name} {kind} julia {mm}: observed, but the lock has no reason for it")
    compat_rows, compat_groups = [], {}
    for mm in strata:
        pa, pb_ = roots["a"]["strata"][mm]["project"], roots["b"]["strata"][mm]["project"]
        ca, cb = pa["compat"], pb_["compat"]
        for name in sorted(ca.keys() | cb.keys()):
            if ca.get(name) != cb.get(name):
                compat_groups.setdefault((name, ca.get(name, ""), cb.get(name, "")), []).append(mm)
        exempt = {t[0] for t in groups if t[2] in ("added", "removed")}
        da, db = pa["deps"], pb_["deps"]
        for name in sorted(n for n in da.keys() | db.keys() if da.get(n) != db.get(n) and n not in exempt):
            problems.append(f"Project.toml [deps] {name} differs in julia {mm} without an added or removed "
                            "Manifest difference")
    for (name, a, b), applied in sorted(compat_groups.items()):
        covered = set()
        for index, entry in match("compat", name):
            julia = [mm for mm in entry.get("julia", strata) if mm in applied]
            if not julia:
                continue
            used.add(index)
            covered |= set(julia)
            row = {"name": name, "a": a, "b": b, "reason": entry["reason"]}
            if sorted(julia) != sorted(strata):
                row["julia"] = julia
            compat_rows.append(row)
        for mm in applied:
            if mm not in covered:
                problems.append(f"compat {name} julia {mm}: observed, but the lock has no reason for it")
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
    if (base / "roots" / "aa-a").is_dir() and (base / "roots" / "aa-b").is_dir():
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


def comparison_summary(out):
    """What two runs of the comparator must agree on: the refusal (class, field) pairs and the CSV rows with
    the path labels removed (the scrub prints a root path as `<a>` or as `basename#tag`)."""
    out = Path(out)
    summary = {"refusals": None, "rows": None, "counts": None}
    if (out / "refusals.json").is_file():
        document = json.loads((out / "refusals.json").read_text(encoding="utf-8"))
        summary["refusals"] = sorted((r["class"], r["field"]) for r in document["refusals"])
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
    for relative in ("receipt.jsonl", "declared-differences.toml", "comparison", "checksums.sha256",
                     "logs/seals.jsonl", "logs/commands.jsonl", "logs/hardware.jsonl", "logs/campaign.json",
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


def sample_differences(first, other):
    return {k: [first.get(k), other.get(k)] for k in SAMPLE_KEYS if first.get(k) != other.get(k)}


class Attempt:
    """The records of one attempt: STATE, receipt, sidecar logs. Created exclusively at the start."""

    def __init__(self, plan, hooks):
        self.plan, self.hooks = plan, hooks
        logs = plan.base / "logs"
        logs.mkdir(parents=True, exist_ok=True)
        create_exclusive(logs / "STATE.json", state_text("running", campaign_id=plan.campaign_id,
                                                         session_id=plan.session_id))
        for name in ("seals.jsonl", "commands.jsonl", "hardware.jsonl"):
            create_exclusive(logs / name)
        self.receipt = Receipt(plan.base / "receipt.jsonl")
        start = hooks.clock()
        self.receipt.campaign(plan.campaign_id, plan.session_id, plan.sched["id"], start)
        create_exclusive(logs / "campaign.json", json.dumps({
            "schema": 1, "campaign_id": plan.campaign_id, "session_id": plan.session_id,
            "schedule_id": plan.sched["id"], "official": plan.official, "freeze_sha": plan.freeze_sha,
            "arms": list(plan.arms), "started_utc": utc_text(start),
            "schedule_sha256": sha256_file(plan.base / "schedule.toml")}, indent=2) + "\n")

    def finish(self, state, **info):
        """STATE.json, then the checksums of the whole evidence (best effort: the attempt is over either way)."""
        logs = self.plan.base / "logs"
        replace_file(logs / "STATE.json", state_text(state, campaign_id=self.plan.campaign_id,
                                                      session_id=self.plan.session_id, **info))
        write_checksums(self.plan.base)

    def stop(self, reason, key=None, **info):
        self.finish("stopped", reason=reason, process=key.name if key else None, **info)
        raise Stopped(reason)


def execute(plan, hooks):
    """Run a campaign (or a pilot) in `plan.base`: the one engine behind `run` and `pilot`.

    Raises Refused before anything is launched (existing evidence, identity files, preflight problems) and
    Stopped after an infrastructure failure (evidence kept, STATE.json says why, nothing resumed). Returns an
    Outcome when every process ran; exit_code is 0, 1 (a process exit 2 or comparator exit 1) or 2 (the comparator
    refused)."""
    if hooks.sampler is None:
        raise UsageError("the engine needs a machine sampler")
    check_fresh(plan)
    check_identity_files(plan)
    order = process_order(plan)
    observations = {}
    for role in plan.role_names():
        for mm in plan.sched["strata"]:
            observations[(role, mm)] = hooks.probe(plan.roles[role], mm)
    problems = preflight_checks(plan, observations)
    if problems:
        raise Refused("preflight found problems: " + "; ".join(problems[:5]), field="preflight",
                      problems=problems)
    attempt = Attempt(plan, hooks)
    first = hooks.sampler()
    nonok = []
    try:
        for key in order:
            run_one(plan, hooks, attempt, key, observations, first, nonok)
        return finalize(plan, hooks, attempt, len(order), nonok)
    except (Stopped, Refused):
        raise
    except Exception as error:                      # a bug or an unforeseen failure still keeps the evidence
        with contextlib.suppress(Exception):
            attempt.finish("stopped", reason=f"internal error: {type(error).__name__}: {error}")
        raise


def run_one(plan, hooks, attempt, key, observations, first, nonok):
    spec = plan.roles[key.role]
    logs, raw = plan.base / "logs", plan.raw(key.role, key.mm)
    stem = plan.stem(key.mm, key.rep)
    previous = observations.get((key.role, key.mm)) or {}
    observations[(key.role, key.mm)] = obs = hooks.probe(spec, key.mm)
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
    digest_before = hooks.depot_digest(spec) if hooks.depot_digest else None
    before = hooks.sampler()
    if sample_differences(first, before):
        append_jsonl(logs / "hardware.jsonl", {"process": key.name, "moment": "before", "sample": before,
                                               "disagrees": sample_differences(first, before)})
        attempt.stop("the machine values differ from the first sample", key)
    raw.mkdir(parents=True, exist_ok=True)
    argv, env = launch_argv(plan, spec, key.mm), launch_env(plan, spec, key.mm, key.rep)
    start = hooks.clock()
    try:
        result = hooks.runner(argv, env, str(spec.checkout), plan.cpu)
    except Exception as error:                      # a launch that failed is still one honest process event
        result = RunResult(-1, b"", f"runner failed: {type(error).__name__}: {error}".encode())
    end = hooks.clock()
    after = hooks.sampler()
    for suffix, data in (("stdout", result.stdout), ("stderr", result.stderr)):
        (logs / f"{key.name}.{suffix}").write_bytes(data or b"")
    seconds = (end - start).total_seconds()
    seal_error, failed = None, []
    try:
        failed = seal_process(plan, key, result.exit, seconds)
    except SealProblem as error:
        seal_error = error
    machine = machine_record(before, _dig(obs, "julia.cpu_name"), plan.cpu)
    attempt.receipt.process(key.arm, key.letter, plan.sched["strata"][key.mm]["version"], key.rep,
                            spec.installation, start, end, result.exit, seal_error is None, machine)
    append_jsonl(logs / "commands.jsonl", {
        "process": key.name, "argv": argv, "cwd": str(spec.checkout), "env": env, "start_utc": utc_text(start),
        "end_utc": utc_text(end), "exit": result.exit, "stdout": f"logs/{key.name}.stdout",
        "stderr": f"logs/{key.name}.stderr", "machine_before": before, "machine_after": after})
    append_jsonl(logs / "hardware.jsonl", {"process": key.name, "moment": "after", "sample": after,
                                           "disagrees": sample_differences(first, after)})
    if seal_error is not None:
        attempt.stop(str(seal_error), key)
    if result.exit == 2:
        nonok.append({"process": key.name, "failed_cases": failed})
    if sample_differences(first, after):
        attempt.stop("the machine values changed during the process", key)
    if hooks.depot_digest and hooks.depot_digest(spec) != digest_before:
        attempt.stop("the compiled-cache digest of the depot changed during the process", key)
    if hooks.datahash_ok is not None and not hooks.datahash_ok(key.role, key.mm, key.rep):
        attempt.stop("the data_hash sidecar differs from metrics.tsv", key)


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
        "nonok_processes": nonok}, indent=2) + "\n")
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


def check_roots(base, sched, receipt, aa, problems):
    """Per root and stratum: the six files of every repetition, coverage of every case, the identity file, the
    receipt facts, and for the A/B roots the fingerprint files and the data_hash sidecars."""
    roles = ("ab-a", "ab-b") + (("aa-a", "aa-b") if aa else ())
    cases = sched["settings"]["case_filter"].split(",")
    arm_of = {"ab-a": ("AB", "A"), "ab-b": ("AB", "B"), "aa-a": ("AA", "A"), "aa-b": ("AA", "B")}
    for role in roles:
        root = Path(base) / "roots" / role
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
                        meta = tomllib.loads(meta_path.read_text(encoding="utf-8"))
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


def check_fingerprints(root, sched, role, problems):
    path, sidecar = root / FP_NAME, root / DATAHASH_NAME
    cases = sched["settings"]["case_filter"].split(",")
    rows = {}
    if not path.is_file():
        problems.append(f"{role}: {FP_NAME} is missing")
    else:
        header, body = read_tsv(path)
        if header != ["julia", "id", "rep", "kind", "name", "value"]:
            problems.append(f"{role}: {FP_NAME} has a wrong header")
        else:
            for row in body:
                if len(row) == 6:
                    rows.setdefault((row[0], row[1], row[2]), set()).add((row[3], row[4]))
    hashes = {}
    if not sidecar.is_file():
        problems.append(f"{role}: {DATAHASH_NAME} is missing")
    else:
        header, body = read_tsv(sidecar)
        if "\t".join(header) != DATAHASH_HEADER:
            problems.append(f"{role}: {DATAHASH_NAME} has a wrong header")
        else:
            hashes = {(r[0], r[1], r[2]): r[3] for r in body if len(r) == 4}
    for mm, info in sched["strata"].items():
        for rep in sched["reps"]:
            stem = f"julia-{info['version']}-rep{rep:02d}"
            metrics = root / f"julia-{mm}" / "raw" / f"{stem}-metrics.tsv"
            data = {}
            if metrics.is_file():
                header, body = read_tsv(metrics)
                if "id" in header and "data_hash" in header:
                    data = {r[header.index("id")]: r[header.index("data_hash")] for r in body}
            for case in cases:
                key = (info["version"], case, str(rep))
                if path.is_file() and rows:
                    present = rows.get(key, set())
                    missing = [f"{k}/{n}" for k, n in REQUIRED_FP_ROWS if (k, n) not in present]
                    if not any(k == "fixture" for k, _ in present):
                        missing.append("fixture")
                    if missing:
                        problems.append(f"{role}: {FP_NAME} lacks {missing} for {key}")
                if sidecar.is_file() and hashes:
                    if key not in hashes:
                        problems.append(f"{role}: {DATAHASH_NAME} has no row for {key}")
                    elif case in data and hashes[key] != data[case]:
                        problems.append(f"{role}: data_hash sidecar differs from metrics.tsv for {key}")


def verify(base, out, replay=True):
    """Read-only check of a BASE (no Julia, no original paths, works on a copied tree) and the verification
    record `out`, a fresh path outside BASE. Returns (document, exit status).

    The campaign state decides what success means: only a sealed logs/completion.json that is consistent with
    everything else verifies as a success. A stopped attempt, a missing completion record or a reproduced
    comparator refusal never does; a reproduced refusal is `refused` ("verified: refused")."""
    base, out = Path(base), Path(out)
    if out.exists():
        raise UsageError(f"{out} exists: the verification record is written to a fresh path")
    if base.resolve() in out.resolve().parents or out.resolve() == base.resolve():
        raise UsageError("the verification record must not be written into the evidence")
    problems = []
    document = {"schema": 1, "problems": problems}
    sched = None
    try:
        sched = mc.load_schedule(base / "schedule.toml")
    except (mc.Usage, OSError) as error:
        problems.append(f"schedule.toml: {error}")
    try:
        state = json.loads((base / "logs" / "STATE.json").read_text(encoding="utf-8"))
    except (OSError, ValueError):
        state = {}
    required = ["case-mapping.toml", "receipt.jsonl", "logs/seals.jsonl", "logs/commands.jsonl",
                "logs/hardware.jsonl", "logs/STATE.json", "logs/campaign.json", "checksums.sha256"]
    if state.get("state") == "completed":
        required.append("declared-differences.toml")
    for relative in required:
        if not (base / relative).is_file():
            problems.append(f"{relative} is missing")
    # checksums: the file set and every digest
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
    for folder, _, names in os.walk(base):
        for name in names:
            if (Path(folder) / name).is_symlink():
                problems.append(f"{(Path(folder) / name).relative_to(base).as_posix()} is a symbolic link")
    problems += verify_seals(base) if (base / "logs" / "seals.jsonl").is_file() else []
    document["campaign_state"] = state.get("state")
    completion = None
    if (base / "logs" / "completion.json").is_file():
        try:
            completion = json.loads((base / "logs" / "completion.json").read_text(encoding="utf-8"))
        except ValueError:
            problems.append("logs/completion.json is not valid JSON")
    aa = (base / "roots" / "aa-a").is_dir() or (base / "roots" / "aa-b").is_dir()
    if aa and not ((base / "roots" / "aa-a").is_dir() and (base / "roots" / "aa-b").is_dir()):
        problems.append("only one A/A root exists")
    receipt = {}
    if sched is not None:
        receipt = check_receipt_text(base, sched, aa, problems, complete=state.get("state") != "stopped")
        if state.get("state") in ("completed", "refused"):
            check_roots(base, sched, receipt, aa, problems)
    expected_count = 0 if sched is None else len(sched["strata"]) * len(sched["reps"]) * 2 * (2 if aa else 1)
    document["campaign_outcome"] = None
    if state.get("state") == "completed":
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
            if "logs/completion.json" not in {s["file"] for s in read_seals(base)}:
                problems.append("logs/completion.json is not sealed")
    elif completion is not None:
        problems.append("logs/completion.json exists but the state is not completed")
    stored_exit = None
    try:
        stored_exit = json.loads((base / "logs" / "comparator.json").read_text(encoding="utf-8"))["exit"]
    except (OSError, ValueError, KeyError):
        if state.get("state") in ("completed",):
            problems.append("logs/comparator.json is missing")
    if completion is not None and stored_exit is not None and completion.get("comparator_exit") != stored_exit:
        problems.append("completion.json and logs/comparator.json disagree on the comparator exit")
    document["comparator_exit"] = None
    document["classification"] = None
    if replay and sched is not None and (base / "comparison").is_dir() and state.get("state") != "stopped":
        scratch = Path(tempfile.mkdtemp(prefix="stage2b-verify-"))
        try:
            code, _ = run_comparator(base, scratch / "replay")
            document["comparator_exit"] = code
            again, stored = comparison_summary(scratch / "replay"), comparison_summary(base / "comparison")
            document["classification"] = again["counts"] if again["counts"] is not None else [
                list(pair) for pair in again["refusals"] or []]
            if stored_exit is not None and code != stored_exit:
                problems.append(f"the replay exits with {code}, the campaign recorded {stored_exit}")
            if again["refusals"] != stored["refusals"]:
                problems.append("the refusals of the replay differ from the stored comparison")
            if again["rows"] != stored["rows"]:
                problems.append("the comparison rows of the replay differ from the stored comparison")
        finally:
            shutil.rmtree(scratch, ignore_errors=True)
    elif state.get("state") == "completed" and not (base / "comparison").is_dir():
        problems.append("comparison/ is missing")
    if problems:
        document["state"], status = "failed", 2
    elif state.get("state") == "completed" and completion is not None:
        success = document["campaign_outcome"] == "comparable" and document["comparator_exit"] in (0, None)
        document["state"], status = ("verified", 0) if success else ("verified_non_ok", 1)
    elif state.get("state") == "refused":
        document["state"], status = "refused", 2
    elif state.get("state") == "stopped":
        document["state"], status = "stopped", 2
    else:
        document["state"], status = "no_success_record", 2
    document["problems"] = list(problems)
    out.parent.mkdir(parents=True, exist_ok=True)
    create_exclusive(out, json.dumps(document, indent=2) + "\n")
    return document, status


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
        if name == "prepare":
            sub.add_argument("--step", required=True, choices=("fetch", "finalize"))
    verify_parser = commands.add_parser("verify", allow_abbrev=False)
    verify_parser.add_argument("--base", required=True)
    verify_parser.add_argument("--out", required=True)
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
        document, status = verify(base, args.out)
        print(f"verification: {document['state']} ({len(document['problems'])} problems); record {args.out}")
        for problem in document["problems"][:20]:
            report(f"  {problem}")
        return status
    official_sched = mc.load_schedule(HERE / "schedule.toml")
    if args.command == "run" and not args.official:
        raise UsageError("run needs --official (a campaign that is not official is a pilot)")
    if args.command == "pilot" or (args.command == "preflight" and not args.official):
        arms = parse_arms(args.arms) if args.arms else None
        config = load_pilot(args.config, official_sched)
        if args.command == "pilot" and "pilot" not in base.name:
            raise LockRefusal("base", f"the base directory name {base.name!r} lacks pilot")
        if hooks is None:
            raise NotImplementedHere("not implemented in this task: the pilot needs the Julia hooks; the "
                                     "configuration is valid and nothing was launched")
        plan = plan_from_pilot(config, base, hooks.julia_bins, environ, arms)
        return run_plan(plan, hooks, args.command == "preflight")
    if args.command == "prepare":
        load_config(args.config, official_sched)
        raise NotImplementedHere(f"not implemented in this task: prepare --step {args.step} needs Julia; "
                                 "nothing was launched")
    lock = load_lock(args.config, strata=list(official_sched["strata"]))
    observed = facts(HERE.parents[2], args.config, base, HERE / "schedule.toml", HERE / "case-mapping.toml")
    unmet = official_gate(lock, observed, args.freeze_sha)
    if unmet:
        raise Refused("the official gate is not met: " + "; ".join(unmet[:5]), field="gate", problems=unmet)
    if hooks is None:
        raise NotImplementedHere("not implemented in this task: the official run needs the Julia hooks; the gate "
                                 "is met and nothing was launched")
    if not (base / "lock.toml").is_file() or sha256_file(base / "lock.toml") != sha256_file(args.config):
        raise Refused("lock.toml of the base is not the lock given with --config", field="lock.toml")
    plan = plan_from_lock(lock, base, hooks.julia_bins, environ, args.freeze_sha)
    return run_plan(plan, hooks, args.command == "preflight")


def run_plan(plan, hooks, only_preflight):
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
