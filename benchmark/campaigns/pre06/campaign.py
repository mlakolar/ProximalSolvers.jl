#!/usr/bin/env python3
"""Run the frozen Stage 2A campaign for one Julia version, or verify its evidence.

A receipt around the pinned checkout's own benchmark/setup.jl, run.jl, local.jl,
validate.py and summarize.py: it checks every frozen identity in campaign.toml before,
during and after the run, records every command, environment, output and exit code, and
stops at the first failed check. It changes nothing that is measured. Linux only.

  campaign.py run --julia-version 1.13 --julia BIN --pinned DIR --work DIR --root DIR \
                  --freeze-sha SHA
  campaign.py verify ROOT --freeze-sha SHA
  campaign.py verify ROOT --archive --freeze-sha SHA                 (official archive)
  campaign.py verify ROOT --archive --allow-pilot [--freeze-sha SHA]  (pilot rehearsal)
  campaign.py ids

Exit status: 0 valid records and every case ok; 2 valid records with a non-ok case (the
numerical gate fails); 1 a stop, any integrity failure or a usage error. `verify` ends
with RECORD INTEGRITY, NUMERICAL and HARDWARE lines and an EVIDENCE line: OFFICIAL only
for valid official evidence, PILOT / NON-OFFICIAL for valid pilot evidence, NOT VALID on
any integrity failure. Accept exit 0 or 2 only together with these lines.

See README.md in this directory; the governing design is STAGE2_PLAN.md.
"""

import argparse
from collections import Counter
import csv
import datetime
import hashlib
import json
import os
import re
import shlex
import shutil
import subprocess
import sys
import time
import tomllib
from pathlib import Path

HERE = Path(__file__).resolve().parent
RAW_SUFFIXES = ("-metadata-start.toml", "-metadata.toml", "-catalog.tsv", "-metrics.tsv",
                "-samples.tsv", "-errors.tsv")
CATALOG_FIELDS = ("id", "group", "problem", "solver", "variant", "phase", "suite", "inputs",
                  "issue", "measure", "target")
PASS_THROUGH = ("PATH", "HOME", "USER", "LOGNAME", "LANG", "LC_ALL", "TMPDIR", "JULIA_PKG_SERVER")
PYTHON = (sys.executable, "-B", "-E", "-s")   # no bytecode in the checkouts, no user site
CASE_ID = re.compile(r"[A-Za-z0-9_.+-]+(/[A-Za-z0-9_.+-]+){4}")
PILOT_OVERRIDES = ("PS_SAMPLES", "PS_SECONDS", "PS_CASE_SECONDS")

# Identity of the environment as Julia loads it; printed as TOML.
PROBE = r"""
import Pkg, TOML, LinearAlgebra
import ProximalBase, ProximalSolvers
deps = Dict{String,Any}()
for (uuid, p) in Pkg.dependencies()
  deps[p.name] = Dict("uuid" => string(uuid), "version" => string(something(p.version, "")),
    "tree" => string(something(p.tree_hash, "")), "path" => p.is_tracking_path,
    "repo" => p.is_tracking_repo, "registry" => p.is_tracking_registry,
    "source" => string(something(p.source, "")))
end
base = realpath(pkgdir(ProximalBase))
TOML.print(Dict{String,Any}("julia" => string(VERSION), "commit" => Base.GIT_VERSION_INFO.commit,
  "bindir" => Sys.BINDIR, "cpu_name" => Sys.CPU_NAME, "cpu_model" => Sys.cpu_info()[1].model,
  "threads" => Threads.nthreads(), "blas" => string(LinearAlgebra.BLAS.get_config()),
  "proximalbase_dir" => base, "proximalbase_loaded_tree" => bytes2hex(Pkg.GitTools.tree_hash(base)),
  "proximalbase_version" => string(pkgversion(ProximalBase)),
  "proximalsolvers_dir" => realpath(pkgdir(ProximalSolvers)),
  "active_project" => Base.active_project(), "load_path" => LOAD_PATH,
  "depot_path" => DEPOT_PATH, "deps" => deps); sorted = true)
"""

# The catalog rows the runner would write, built by run.jl's own functions without measuring.
CATALOG = r"""
include(joinpath(pwd(), "benchmark", "run.jl"))
settings = runner_settings()
for spec in select_cases(build_catalog(settings.suite, settings.groups), settings.cases)
  tsv_line(stdout, (getproperty(spec.meta, Symbol(f)) for f in CATALOG_HEADER)...)
end
"""


class Stop(Exception):
    """A failed check. The campaign stops; its evidence is kept."""


def check(condition, message):
    if not condition:
        raise Stop(message)


def utc():
    return datetime.datetime.now(datetime.timezone.utc).isoformat(timespec="milliseconds")


def sha256(path):
    digest = hashlib.sha256()
    with Path(path).open("rb") as stream:
        for block in iter(lambda: stream.read(1 << 20), b""):
            digest.update(block)
    return digest.hexdigest()


def read(path, default="unavailable"):
    try:
        return Path(path).read_text().strip()
    except OSError:
        return default


def cpu_set(text):
    cpus = set()
    for part in text.split(","):
        low, _, high = part.partition("-")
        cpus.update(range(int(low), int(high or low) + 1))
    return cpus


def git(repo, *args):
    result = subprocess.run(["git", "-C", str(repo), *args], capture_output=True, text=True)
    check(result.returncode == 0, f"git {' '.join(args)} failed in {repo}: {result.stderr.strip()}")
    return result.stdout.strip()


CHECKSUM_LINE = re.compile(r"([0-9a-f]{64})  (.+)")


def read_checksums(path):
    """A `sha256sum` list as {relative path: digest}; a Stop on a malformed line, an
    absolute or non-normalized path, or a path listed twice."""
    try:
        text = Path(path).read_text(encoding="utf-8")
    except (OSError, UnicodeDecodeError) as error:
        raise Stop(f"{path}: unreadable: {type(error).__name__}: {error}") from None
    check(text.endswith("\n"), f"{path}: empty or not newline-terminated")
    listed = {}
    for number, line in enumerate(text[:-1].split("\n"), 1):
        match = CHECKSUM_LINE.fullmatch(line)
        check(match, f"{path}: malformed line {number}: {line!r}")
        name = match[2]
        parts = name.split("/")
        check(not name.startswith("/") and "" not in parts and "." not in parts
              and ".." not in parts, f"{path}: not a normalized relative path: {name!r}")
        check(name not in listed, f"{path}: {name} is listed twice")
        listed[name] = match[1]
    return listed


def write_new(path, text):
    with Path(path).open("x", encoding="utf-8") as stream:   # never overwrite a record
        stream.write(text)


# ---------------------------------------------------------------------------------------
# The campaign definition


def load_campaign(directory=HERE):
    """campaign.toml and the case IDs of cases.txt, after checking that they agree."""
    directory = Path(directory)
    campaign = tomllib.loads((directory / "campaign.toml").read_text(encoding="utf-8"))
    data = (directory / "cases.txt").read_bytes()
    check(hashlib.sha256(data).hexdigest() == campaign["cases"]["sha256"],
          "cases.txt does not have the SHA-256 recorded in campaign.toml")
    check(data.endswith(b"\n") and b"\r" not in data, "cases.txt must be LF-terminated lines")
    ids = data.decode("ascii").split("\n")[:-1]
    for case in ids:
        check(CASE_ID.fullmatch(case), f"cases.txt: not an exact case ID: {case!r}")
    check(len(set(ids)) == len(ids), "cases.txt has duplicate IDs")
    roles = [entry["role"] for entry in campaign["case"]]
    check(ids == [entry["id"] for entry in campaign["case"]],
          "cases.txt and the [[case]] entries of campaign.toml differ")
    check(len(ids) == campaign["cases"]["count"]
          and roles.count("primary") == campaign["cases"]["primary"]
          and roles.count("diagnostic") == campaign["cases"]["diagnostic"]
          and roles.count("primary") + roles.count("diagnostic") == len(ids),
          "case count or roles disagree with campaign.toml")
    return campaign, ids


def julia_entry(campaign, version):
    check(version in campaign["julia"], f"unknown Julia version {version}; "
          f"choose one of {sorted(campaign['julia'])}")
    return campaign["julia"][version]


def expected_catalog(campaign):
    rows = {}
    for entry in campaign["case"]:
        group, problem, solver, variant, phase = entry["id"].split("/")
        check(phase == entry["phase"], f"phase of {entry['id']} disagrees with its ID")
        rows[entry["id"]] = dict(id=entry["id"], group=group, problem=problem, solver=solver,
                                 variant=variant, phase=phase, suite=entry["suite"],
                                 inputs=entry["inputs"], issue=entry["issue"],
                                 measure=entry["measure"], target=float(entry["target"]))
    return rows


def check_catalog_rows(rows, campaign, source):
    expected = expected_catalog(campaign)
    seen = [row["id"] for row in rows]
    check(len(seen) == len(set(seen)), f"{source}: duplicate case IDs")
    check(set(seen) == set(expected), f"{source}: IDs differ from cases.txt: "
          f"missing={sorted(set(expected) - set(seen))} extra={sorted(set(seen) - set(expected))}")
    for row in rows:
        want = expected[row["id"]]
        for field in CATALOG_FIELDS:
            value = float(row[field]) if field == "target" else row[field]
            check(value == want[field], f"{source}: {row['id']} has {field}={row[field]!r}, "
                  f"campaign.toml has {want[field]!r}")


def expected_metadata(campaign, version, settings, ids, pinned):
    groups = ",".join(sorted({group.strip() for group in settings["PS_GROUPS"].split(",")}))
    return dict(julia=julia_entry(campaign, version)["version"], suite=settings["PS_SUITE"],
                groups=groups, case_filter=",".join(ids),
                harness_hash=campaign["proximalsolvers"]["harness_hash"],
                proximalsolvers_sha=campaign["proximalsolvers"]["commit"],
                proximalsolvers_dirty=False,
                proximalsolvers_hash=campaign["proximalsolvers"]["package_hash"],
                proximalsolvers_path=pinned, expected_package_root=pinned,
                proximalbase_version=campaign["proximalbase"]["version"],
                proximalbase_hash=campaign["proximalbase"]["package_hash"],
                julia_threads=1, blas_threads=1, cpu_model=campaign["machine"]["cpu_model"],
                cpu=julia_entry(campaign, version)["cpu_name"],
                samples_target=int(settings["PS_SAMPLES"]),
                seconds_limit=float(settings["PS_SECONDS"]),
                case_seconds=float(settings["PS_CASE_SECONDS"]),
                profile_seconds=float(settings["PS_PROFILE_SECONDS"]))


# ---------------------------------------------------------------------------------------
# Checks shared by `run` (after each repetition) and `verify` (from archived evidence)


def same(value, want):
    """Equal in type and value: TOML `true` is not 1, and `0` is not `false`."""
    return type(value) is type(want) and value == want


def tsv(path):
    with Path(path).open(newline="", encoding="utf-8") as stream:
        return list(csv.DictReader(stream, delimiter="\t"))


def check_repetition(raw, version, rep, expected, campaign, exit_code):
    """The records of one repetition agree with the frozen campaign; returns its metrics."""
    prefix = f"julia-{expected['julia']}-rep{rep:02d}"
    for suffix in RAW_SUFFIXES:
        check((raw / (prefix + suffix)).is_file(), f"missing output {prefix}{suffix}")
    for name in ("-profiles.txt", "-metadata-finalizing.toml"):
        check(not (raw / (prefix + name)).exists(), f"unexpected output {prefix}{name}")
    start = tomllib.loads((raw / f"{prefix}-metadata-start.toml").read_text())
    final = tomllib.loads((raw / f"{prefix}-metadata.toml").read_text())
    for label, meta in (("start", start), ("final", final)):
        check(same(meta.get("rep"), rep), f"{prefix} {label} metadata: rep={meta.get('rep')}")
        for key, want in expected.items():
            check(same(meta.get(key), want), f"{prefix} {label} metadata: {key}={meta.get(key)!r}, "
                  f"expected {want!r}")
    check(final.get("finished") is True, f"{prefix}: not finished")
    check(same(final.get("cases"), campaign["cases"]["count"]), f"{prefix}: wrong case count")
    nonok = final.get("nonok_cases")
    check(same(nonok, 0) or (type(nonok) is int and nonok > 0), f"{prefix}: nonok_cases={nonok!r}")
    check(exit_code in campaign["protocol"]["accepted_exit_codes"],
          f"{prefix}: exit code {exit_code} (startup, load or recording failure)")
    check((exit_code == 0) == (nonok == 0), f"{prefix}: exit code {exit_code} with "
          f"nonok_cases={nonok}")
    check_catalog_rows(tsv(raw / f"{prefix}-catalog.tsv"), campaign, f"{prefix}-catalog.tsv")
    metrics = tsv(raw / f"{prefix}-metrics.tsv")
    check(sorted(row["id"] for row in metrics) == sorted(expected_catalog(campaign)),
          f"{prefix}-metrics.tsv does not cover the campaign cases once")
    check(sum(row["status"] != "ok" for row in metrics) == nonok,
          f"{prefix}: metrics and metadata disagree on non-ok cases")
    return {row["id"]: dict(status=row["status"], median_ns=row["median_ns"],
                            worst_value=row["worst_value"], target=row["target"],
                            data_hash=row["data_hash"]) for row in metrics}


def check_fixed_inputs(campaign, metrics):
    """Fixed-input cases must have one data_hash in every repetition (validate.py checks
    only the format)."""
    for entry in campaign["case"]:
        if entry["inputs"] == "fixed":
            hashes = {rep[entry["id"]]["data_hash"] for rep in metrics.values()}
            check(len(hashes) == 1, f"fixed-input {entry['id']} has differing data hashes")


def check_lock(manifest_path, campaign, version, pinned):
    """The Manifest is the frozen lock: same entries, versions and trees; one path entry."""
    manifest = tomllib.loads(Path(manifest_path).read_text(encoding="utf-8"))
    entry = julia_entry(campaign, version)
    check(manifest.get("julia_version") == entry["version"]
          and manifest.get("manifest_format") == entry["manifest_format"],
          "Manifest julia_version/manifest_format differ from campaign.toml")
    observed = {}
    for name, items in manifest["deps"].items():
        check(len(items) == 1, f"Manifest has {len(items)} entries for {name}")
        item = items[0]
        check("repo-url" not in item and "repo-rev" not in item, f"{name} tracks a repository")
        if name == "ProximalSolvers":
            check((Path(manifest_path).parent / item.get("path", "")).resolve()
                  == Path(pinned).resolve(),
                  f"ProximalSolvers path {item.get('path')!r} is not the pinned checkout")
        else:
            check("path" not in item, f"{name} is a path dependency")
        observed[name] = dict(name=name, uuid=item["uuid"], version=item.get("version", ""),
                              tree=item.get("git-tree-sha1", ""))
    frozen = {item["name"]: item for item in entry["lock"]}
    check(observed == frozen, "Manifest differs from the frozen lock: " + "; ".join(
        f"{name}: {observed.get(name)} != {frozen.get(name)}"
        for name in sorted(set(observed) | set(frozen)) if observed.get(name) != frozen.get(name)))
    base = observed[campaign["proximalbase"]["name"]]
    check(base["uuid"] == campaign["proximalbase"]["uuid"]
          and base["version"] == campaign["proximalbase"]["version"]
          and base["tree"] == campaign["proximalbase"]["tree"],
          "ProximalBase in the Manifest is not the registered release tree")


def check_project(project_path, pinned_checkout_project, pinned):
    """The environment's Project.toml is benchmark/Project.toml with only the develop
    source that Pkg adds (Julia 1.11 and later write it into [sources])."""
    project = tomllib.loads(Path(project_path).read_text(encoding="utf-8"))
    template = tomllib.loads(Path(pinned_checkout_project).read_text(encoding="utf-8"))
    check(project.get("deps") == template["deps"] and project.get("compat") == template["compat"],
          "environment Project.toml deps/compat differ from benchmark/Project.toml")
    sources = project.get("sources", {})
    check(set(sources) <= {"ProximalSolvers"} and all(
        (Path(project_path).parent / source.get("path", "")).resolve() == Path(pinned).resolve()
        and len(source) == 1
        for source in sources.values()), f"unexpected [sources] {sources}")
    check(set(project) <= {"deps", "compat", "sources"}, "unexpected Project.toml sections")


def check_probe(probe, campaign, version, pinned, environment, depot):
    entry = julia_entry(campaign, version)
    check(Path(probe["active_project"]) == Path(environment) / "Project.toml",
          f"active project {probe['active_project']} is not the campaign environment")
    install = Path(probe["bindir"]).parent
    check(Path(probe["depot_path"][0]) == Path(depot) and all(
        install in Path(path).parents for path in probe["depot_path"][1:]),
          f"depot path {probe['depot_path']} is not the campaign depot and Julia's own")
    base = campaign["proximalbase"]
    check(probe["julia"] == entry["version"] and probe["commit"] == entry["commit"],
          f"Julia {probe['julia']} ({probe['commit']}) is not the frozen build {entry['version']} "
          f"({entry['commit']})")
    check(probe["cpu_model"] == campaign["machine"]["cpu_model"], "not the frozen machine model")
    check(probe["proximalbase_version"] == base["version"], "loaded ProximalBase version differs")
    check(probe["proximalbase_loaded_tree"] == base["tree"],
          "the loaded ProximalBase directory is not the v0.5.4 release tree")
    dep = probe["deps"]["ProximalBase"]
    check(dep["registry"] and not dep["path"] and not dep["repo"] and dep["tree"] == base["tree"],
          "ProximalBase is not tracked from the registry at the release tree")
    check(Path(probe["proximalsolvers_dir"]) == Path(pinned).resolve(),
          f"ProximalSolvers loads from {probe['proximalsolvers_dir']}, not the pinned checkout")
    check(probe["deps"]["ProximalSolvers"]["path"], "ProximalSolvers is not path-developed")


def hardware_issues(campaign, record):
    """Why one repetition was not under the controlled-hardware conditions (empty if it was)."""
    machine = campaign["machine"]
    issues = []
    monitor = record["monitor"]
    if set(monitor["observed_cpus"]) != {machine["logical_cpu"]}:
        issues.append(f"observed on CPUs {monitor['observed_cpus']}")
    offline = record["before"]["sibling_online"] == "0" == record["after"]["sibling_online"]
    if not offline and (record["sibling_busy"] is None
                        or record["sibling_busy"] > machine["max_sibling_busy"]):
        issues.append(f"SMT sibling busy {record['sibling_busy']}")
    load1 = float(record["before"]["loadavg"].split()[0])
    if load1 > machine["max_load1"]:
        issues.append(f"load1 {load1} at start")
    for when in ("before", "after"):
        state = record[when]
        for key in ("governor", "energy_performance_preference", "no_turbo"):
            if state[key] != machine[key]:
                issues.append(f"{key}={state[key]} {when}")
    return issues


# ---------------------------------------------------------------------------------------
# Machine state (Linux sysfs and procfs)


def cpu_times(cpu):
    for line in Path("/proc/stat").read_text().splitlines():
        fields = line.split()
        if fields[0] == f"cpu{cpu}":
            values = [int(value) for value in fields[1:]]
            return sum(values), values[3] + values[4]   # total, idle + iowait
    return None   # offline


def machine_state(campaign):
    machine = campaign["machine"]
    cpu, sibling = machine["logical_cpu"], machine["smt_sibling"]
    freq = Path(f"/sys/devices/system/cpu/cpu{cpu}/cpufreq")
    temps = {}
    for zone in sorted(Path("/sys/class/thermal").glob("thermal_zone*")):
        temps[read(zone / "type")] = read(zone / "temp")
    return dict(utc=utc(), loadavg=read("/proc/loadavg"), governor=read(freq / "scaling_governor"),
                energy_performance_preference=read(freq / "energy_performance_preference"),
                no_turbo=read("/sys/devices/system/cpu/intel_pstate/no_turbo"),
                scaling_driver=read(freq / "scaling_driver"),
                scaling_min_khz=read(freq / "scaling_min_freq"),
                scaling_max_khz=read(freq / "scaling_max_freq"),
                scaling_cur_khz=read(freq / "scaling_cur_freq"),
                sibling_online=read(f"/sys/devices/system/cpu/cpu{sibling}/online", "1"),
                smt_control=read("/sys/devices/system/cpu/smt/control"),
                power_supply={path.parent.name: read(path) for path in
                              sorted(Path("/sys/class/power_supply").glob("*/online"))},
                # RAPL package limits and energy; energy_uj is often readable only by root.
                rapl={path.name: read(path) for path in
                      sorted(Path("/sys/class/powercap/intel-rapl:0").glob("*"))
                      if path.name in ("energy_uj", "constraint_0_power_limit_uw",
                                       "constraint_1_power_limit_uw")},
                thermal_millicelsius=temps,
                times={str(c): cpu_times(c) for c in (cpu, sibling)})


def settle(max_load1, limit):
    """Wait up to `limit` seconds for the 1-minute load average to fall to `max_load1`
    (the campaign's own setup and precompilation raise it); returns the seconds waited."""
    started = time.monotonic()
    while float(read("/proc/loadavg").split()[0]) > max_load1:
        if time.monotonic() - started >= limit:
            break
        time.sleep(1.0)
    return time.monotonic() - started


def check_machine(campaign):
    """The frozen logical CPU exists here, is a performance core, and has the frozen sibling."""
    machine = campaign["machine"]
    check(sys.platform.startswith("linux"), "campaign.py runs only on Linux (taskset, sysfs)")
    for tool in ("git", "taskset", "lscpu"):
        check(shutil.which(tool), f"missing tool: {tool}")
    cpu, sibling = machine["logical_cpu"], machine["smt_sibling"]
    performance = read("/sys/devices/cpu_core/cpus")
    check(performance == machine["performance_cpus"],
          f"performance cores here are {performance!r}, frozen {machine['performance_cpus']!r}")
    check(cpu in cpu_set(performance), f"cpu{cpu} is not a performance core")
    check(read(f"/sys/devices/system/cpu/cpu{cpu}/online", "1") == "1", f"cpu{cpu} is offline")
    siblings = cpu_set(read(f"/sys/devices/system/cpu/cpu{cpu}/topology/thread_siblings_list"))
    check(siblings == {cpu, sibling} or siblings == {cpu},
          f"cpu{cpu} has SMT siblings {sorted(siblings)}, frozen {sibling}")
    model = next((line.split(":", 1)[1].strip() for line in
                  Path("/proc/cpuinfo").read_text().splitlines()
                  if line.startswith("model name")), "")
    check(model == machine["cpu_model"], f"CPU model {model!r} is not the frozen machine")


def inventory_text():
    commands = [["uname", "-a"], ["hostname"], ["cat", "/etc/os-release"], ["lscpu"],
                ["lscpu", "-e"], ["cat", "/sys/devices/cpu_core/cpus"],
                ["cat", "/sys/devices/cpu_atom/cpus"], ["cat", "/proc/cmdline"],
                ["cat", "/proc/meminfo"], ["nproc"], ["uptime"], ["git", "--version"],
                [sys.executable, "--version"]]
    parts = []
    for command in commands:
        try:
            result = subprocess.run(command, capture_output=True, text=True)
            output = result.stdout + result.stderr
        except OSError as error:
            output = f"unavailable: {error}\n"
        parts.append(f"$ {shlex.join(command)}\n{output}")
    cpus = sorted(Path("/sys/devices/system/cpu").glob("cpu[0-9]*"), key=lambda p: int(p.name[3:]))
    parts.append("$ per-CPU topology and frequency policy\n" + "".join(
        f"{p.name} siblings={read(p / 'topology/thread_siblings_list')} "
        f"max_khz={read(p / 'cpufreq/cpuinfo_max_freq')} "
        f"governor={read(p / 'cpufreq/scaling_governor')} "
        f"epp={read(p / 'cpufreq/energy_performance_preference')} "
        f"cppc_highest_perf={read(p / 'acpi_cppc/highest_perf')}\n" for p in cpus))
    return "\n".join(parts)


# ---------------------------------------------------------------------------------------
# The run


class Receipt:
    """Append-only record of one Julia version's attempt."""

    def __init__(self, directory):
        self.directory = directory
        self.logs = directory / "logs"
        self.logs.mkdir(parents=True)
        self.events = directory / "receipt.jsonl"
        self.log = directory / "commands-and-exit-codes.log"

    def event(self, kind, **fields):
        with self.events.open("a", encoding="utf-8") as stream:
            stream.write(json.dumps(dict(event=kind, utc=utc(), **fields), sort_keys=True) + "\n")

    def note(self, line):
        with self.log.open("a", encoding="utf-8") as stream:
            stream.write(f"{utc()} {line}\n")

    def command(self, name, argv, env, cwd, accept=(0,), monitor=None):
        """Run argv, keeping stdout/stderr in logs/NAME.out/.err; returns the exit code."""
        out, err = self.logs / f"{name}.out", self.logs / f"{name}.err"
        self.note(f"{name}: cwd={cwd} env={shlex.join(f'{k}={v}' for k, v in sorted(env.items()))} "
                  f"argv={shlex.join(argv)}")
        started, clock = utc(), time.monotonic()
        with out.open("x") as stdout, err.open("x") as stderr:
            process = subprocess.Popen(argv, cwd=cwd, env=env, stdout=stdout, stderr=stderr)
            observed = monitor(process) if monitor else None
            code = process.wait()
        wall = time.monotonic() - clock
        self.note(f"{name}: exit={code} wall_s={wall:.3f}")
        self.event("command", name=name, argv=argv, env=env, cwd=str(cwd), start=started,
                   end=utc(), wall_s=wall, exit=code, stdout=str(out.relative_to(self.directory)),
                   stderr=str(err.relative_to(self.directory)), monitor=observed)
        check(code in accept, f"{name} exited with {code}; see {out} and {err}")
        return code, wall, observed


def watch_affinity(cpu):
    """While the pinned Julia process runs, record its allowed and observed CPUs."""
    def monitor(process):
        allowed, observed, samples = set(), set(), 0
        status, stat = Path(f"/proc/{process.pid}/status"), Path(f"/proc/{process.pid}/stat")
        while process.poll() is None:
            try:
                if read(f"/proc/{process.pid}/comm", "") == "julia":   # after taskset's exec
                    text = status.read_text()
                    allowed.add(re.search(r"Cpus_allowed_list:\s*(\S+)", text)[1])
                    observed.add(int(stat.read_text().rsplit(")", 1)[1].split()[36]))
                    samples += 1
            except (OSError, TypeError, IndexError, ValueError):
                pass
            time.sleep(0.2)
        return dict(allowed=sorted(allowed), observed_cpus=sorted(observed), samples=samples)
    return monitor


def file_hashes(root, paths):
    return {str(path.relative_to(root)): sha256(path) for path in sorted(paths)}


def clean(repo):
    return git(repo, "status", "--porcelain", "--untracked-files=all", "--ignored") == ""


def check_freeze_checkout(campaign, freeze_sha=None):
    """This file's checkout: clean, at `freeze_sha` if given, and leaving the measured
    package, harness and tools identical to the pinned commit. Returns (path, HEAD)."""
    freeze = Path(git(HERE, "rev-parse", "--show-toplevel"))
    head = git(freeze, "rev-parse", "HEAD")
    check(not freeze_sha or head == freeze_sha,
          f"freeze checkout HEAD {head} is not --freeze-sha {freeze_sha}")
    check(clean(freeze), "freeze checkout is not clean (tracked, untracked or ignored files)")
    source = campaign["proximalsolvers"]
    unchanged = subprocess.run(["git", "-C", str(freeze), "diff", "--quiet", source["commit"],
                                "HEAD", "--", *source["unchanged_paths"]])
    check(unchanged.returncode == 0, "the freeze commit changes pinned package or harness files")
    return freeze, head


def check_pinned_checkout(campaign, pinned):
    source = campaign["proximalsolvers"]
    check(Path(git(pinned, "rev-parse", "--show-toplevel")).resolve() == pinned,
          f"{pinned} is not the top of a git checkout")
    check(git(pinned, "rev-parse", "HEAD") == source["commit"],
          f"pinned checkout is not at {source['commit']}")
    check(git(pinned, "rev-parse", "HEAD^{tree}") == source["tree"], "pinned tree differs")
    check(clean(pinned), "pinned checkout is not clean (tracked, untracked or ignored files)")


def busy_fraction(before, after):
    if before is None or after is None or after[0] == before[0]:
        return None
    return ((after[0] - before[0]) - (after[1] - before[1])) / (after[0] - before[0])


def process_env(campaign, start, settings, ids):
    """The environment of every Julia process after setup, except per-step variables."""
    return dict(settings, PS_CASES=",".join(ids), PS_EXPECTED_PACKAGE_ROOT=start["pinned"],
                JULIA_DEPOT_PATH=start["depot_path"], JULIA_PKG_OFFLINE="true")


def run(args):
    campaign, ids = load_campaign()
    version = args.julia_version
    entry = julia_entry(campaign, version)
    machine, protocol = campaign["machine"], campaign["protocol"]
    settings = dict(campaign["settings"])
    reps = protocol["repetitions"]
    if args.pilot:
        check("pilot" in Path(args.root).name, "a pilot root's name must contain 'pilot'")
        reps = args.reps or reps
        for override in args.override:
            name, _, value = override.partition("=")
            check(name in PILOT_OVERRIDES, f"a pilot may override only {PILOT_OVERRIDES}")
            settings[name] = value
    else:
        check(not (args.reps or args.override or args.no_exploratory),
              "--reps, --override and --no-exploratory are pilot-only")
        check(Path(args.root).name == campaign["archive"]["name"],
              f"the official root directory must be named {campaign['archive']['name']}")
        check(args.freeze_sha, "an official run needs --freeze-sha (the freeze commit on #110)")
    check(1 <= reps <= 10, "repetitions must be 1-10")
    check(sys.version_info >= (3, 11), "Python 3.11 or later is required (tomllib)")
    check_machine(campaign)

    # Checkouts: the pinned one is measured; the freeze one (this file's) holds the campaign.
    pinned = Path(args.pinned).resolve()
    check_pinned_checkout(campaign, pinned)
    freeze, freeze_head = check_freeze_checkout(campaign, args.freeze_sha)
    julia = Path(args.julia).resolve()
    check(julia.is_file() and os.access(julia, os.X_OK), f"{julia} is not an executable")
    root, work = Path(args.root).resolve(), Path(args.work).resolve()
    for path in (root, work):
        for repo in (pinned, freeze):
            check(path != repo and repo not in path.parents and path not in repo.parents,
                  f"{path} must be outside {repo}")
    check(root != work and root not in work.parents and work not in root.parents,
          "--root and --work must be separate directories")
    julia_dir = root / f"julia-{version}"
    check(not julia_dir.exists(), f"{julia_dir} exists: never reuse an attempt; use a fresh root")
    environment = work / f"env-{version}"
    check(not environment.exists(), f"{environment} exists: use a fresh environment")
    # The campaign depot, then Julia's own bundled depots; never the user's ~/.julia.
    install = julia.parent.parent
    depot_path = ":".join(str(path) for path in (work / "depot", install / "local/share/julia",
                                                  install / "share/julia"))
    root.mkdir(parents=True, exist_ok=True)
    for name in ("campaign.toml", "cases.txt"):   # shared by both Julia versions of a root
        copy = root / name
        if copy.exists():
            check(copy.read_bytes() == (HERE / name).read_bytes(), f"{copy} is another campaign's")
        else:
            shutil.copyfile(HERE / name, copy)
    start = dict(mode="pilot" if args.pilot else "official",
                 campaign_id=campaign["campaign_id"], julia_version=version,
                 julia_binary=str(julia), julia_binary_sha256=sha256(julia),
                 campaign_py_sha256=sha256(HERE / "campaign.py"),
                 pinned=str(pinned), pinned_sha=campaign["proximalsolvers"]["commit"],
                 freeze=str(freeze), freeze_head=freeze_head, freeze_sha_expected=args.freeze_sha,
                 cases_sha256=campaign["cases"]["sha256"], repetitions=reps, settings=settings,
                 no_exploratory=args.no_exploratory, case_filter=",".join(ids), root=str(root),
                 work=str(work), environment=str(environment), depot_path=depot_path,
                 argv=sys.argv, cwd=os.getcwd(), python=sys.version)
    raw = julia_dir / "raw"
    receipt = Receipt(julia_dir)
    status, reason = "stopped", None
    try:
        # Keep this process off the measured CPU and its sibling.
        os.sched_setaffinity(0, os.sched_getaffinity(0) - {machine["logical_cpu"],
                                                           machine["smt_sibling"]})
        receipt.event("start", **start)
        passed = {key: os.environ[key] for key in PASS_THROUGH if key in os.environ}
        setup_env = dict(passed, **settings, JULIA_DEPOT_PATH=depot_path)
        run_env = dict(passed, **process_env(campaign, start, settings, ids))
        flags = [str(julia), *protocol["julia_flags"]]
        write_new(julia_dir / "machine-inventory.txt", inventory_text())

        # Environment: the approved setup.jl, then the frozen identities.
        receipt.command("setup", [*flags, "benchmark/setup.jl", str(pinned), str(environment),
                                  protocol["proximalbase_spec"]], setup_env, pinned)
        project, manifest = environment / "Project.toml", environment / "Manifest.toml"
        check_project(project, pinned / "benchmark" / "Project.toml", pinned)
        check_lock(manifest, campaign, version, pinned)
        for path in (project, manifest):   # immutable snapshots, outside both checkouts
            shutil.copyfile(path, julia_dir / path.name)
            os.chmod(julia_dir / path.name, 0o444)
        snapshot = {name: sha256(julia_dir / name) for name in ("Project.toml", "Manifest.toml")}
        registry = read(work / "depot" / "registries" / "General.toml")
        receipt.event("environment", snapshot_sha256=snapshot, registry=registry)
        # From here Pkg is offline: no registry or package updates.
        receipt.command("probe", [*flags, f"--project={environment}", "-e", PROBE], run_env, pinned)
        probe = tomllib.loads((receipt.logs / "probe.out").read_text())
        check_probe(probe, campaign, version, pinned, environment, work / "depot")
        shutil.copyfile(receipt.logs / "probe.out", julia_dir / "environment-inventory.toml")

        def unchanged_environment():
            check({name: sha256(environment / name) for name in snapshot} == snapshot,
                  "the environment's Project.toml or Manifest.toml changed after its snapshot")
            check(git(pinned, "rev-parse", "HEAD") == campaign["proximalsolvers"]["commit"]
                  and clean(pinned), "the pinned checkout changed")

        # Case selection, before any measurement.
        receipt.command("list", [*flags, f"--project={environment}", "benchmark/run.jl"],
                        dict(run_env, PS_LIST="true"), pinned)
        check_listing(receipt.logs / "list.out", ids)
        receipt.command("catalog", [*flags, f"--project={environment}", "-e", CATALOG],
                        run_env, pinned)
        check_catalog_dump(receipt.logs / "catalog.out", campaign)
        unchanged_environment()

        # Repetitions: fresh pinned processes; checks after each one.
        expected = expected_metadata(campaign, version, settings, ids, str(pinned))
        cpu, sibling = machine["logical_cpu"], machine["smt_sibling"]
        sealed, metrics, hardware = {}, {}, []
        raw.mkdir()
        for rep in range(1, reps + 1):
            waited = settle(machine["max_load1"], machine["settle_seconds"])
            before = machine_state(campaign)
            code, wall, monitor = receipt.command(
                f"rep{rep:02d}", ["taskset", "-c", str(cpu), *flags, f"--project={environment}",
                                  "benchmark/run.jl"],
                dict(run_env, PS_REPETITION=str(rep), PS_OUTPUT=str(raw)), pinned,
                accept=protocol["accepted_exit_codes"], monitor=watch_affinity(cpu))
            after = machine_state(campaign)
            check(monitor["allowed"] == [str(cpu)] and monitor["samples"] > 0,
                  f"rep{rep:02d} ran with affinity {monitor['allowed']}, not cpu{cpu}")
            record = dict(rep=rep, settle_s=waited, before=before, after=after, monitor=monitor,
                          cpu_busy=busy_fraction(before["times"][str(cpu)],
                                                 after["times"][str(cpu)]),
                          sibling_busy=busy_fraction(before["times"][str(sibling)],
                                                     after["times"][str(sibling)]))
            record["issues"] = hardware_issues(campaign, record)
            hardware.append(record)
            receipt.event("hardware", **record)
            metrics[rep] = check_repetition(raw, version, rep, expected, campaign, code)
            new = seal_repetition(raw, entry["version"], rep, sealed)
            elapsed = tomllib.loads((raw / f"julia-{entry['version']}-rep{rep:02d}"
                                     "-metadata.toml").read_text())["elapsed_s"]
            receipt.event("repetition", rep=rep, exit=code, wall_s=wall, run_records_s=elapsed,
                          outside_run_records_s=wall - elapsed, outputs=new, cases=metrics[rep])
            unchanged_environment()
        check_fixed_inputs(campaign, metrics)

        # Record integrity (gate A) with the pinned validate.py; then the summary.
        versions = ["--versions", entry["version"]]
        receipt.command("validate", [*PYTHON, "benchmark/validate.py", str(raw),
                                     str(julia_dir / "validation.json"), "--expected-runs",
                                     str(reps), *versions], passed, pinned)
        validation = json.loads((julia_dir / "validation.json").read_text())
        check(validation["valid"] and validation["counts"]["processes"] == reps,
              "validate.py did not find valid records")
        receipt.command("summarize", [*PYTHON, "benchmark/summarize.py", str(raw),
                                      str(julia_dir / "summary"), "--expected-runs", str(reps),
                                      *versions], passed, pinned)
        receipt.command("check_analysis", [*PYTHON, "benchmark/check_analysis.py"], passed, pinned)
        unchanged_environment()

        # Untimed exploratory receipts (labelled; not formal records).
        if not args.no_exploratory:
            exploratory = julia_dir / "exploratory"
            (exploratory / "first-call").mkdir(parents=True)
            for name, argv in local_commands(protocol, ids, flags, environment, cpu, exploratory):
                receipt.command(name, argv, run_env, pinned, accept=(0, 2))
            unchanged_environment()

        nonok, issues = outcomes(campaign, metrics, hardware)
        status = "completed"
        receipt.event("result", record_integrity="valid",
                      numerical="all ok" if not nonok else "non-ok cases", nonok=nonok,
                      hardware="controlled" if not issues else "observational",
                      hardware_issues=issues)
    except Exception as error:   # fail closed: any failure stops the attempt
        reason = f"{type(error).__name__}: {error}"
        receipt.event("stop", reason=reason)
        receipt.note(f"STOP {reason}")
    finally:
        write_new(julia_dir / "result.json", json.dumps(dict(status=status, reason=reason),
                                                        indent=2) + "\n")
        files = [path for path in julia_dir.rglob("*") if path.is_file()]
        write_new(julia_dir / "checksums.sha256", "".join(
            f"{digest}  {name}\n" for name, digest in file_hashes(julia_dir, files).items()))
    report = verify_julia(julia_dir, campaign, ids, freeze_head)
    print(json.dumps(report, indent=2))
    return exit_status([report])


def raw_names(full_version, reps):
    return {f"julia-{full_version}-rep{r:02d}{suffix}"
            for r in range(1, reps + 1) for suffix in RAW_SUFFIXES}


def seal_repetition(raw, full_version, rep, sealed):
    """After repetition `rep`: earlier repetitions' files unchanged and exactly the record
    files of repetitions 1..rep present. Adds the new files' SHA-256 to `sealed` and
    returns them."""
    for previous, digest in sealed.items():
        check(sha256(raw / previous) == digest, f"{previous} changed after its repetition")
    names = {path.name for path in raw.iterdir()}
    wanted = raw_names(full_version, rep)
    check(names == wanted, f"unexpected raw files {sorted(names ^ wanted)}")
    new = {name: sha256(raw / name) for name in sorted(names - set(sealed))}
    sealed.update(new)
    return new


def local_commands(protocol, ids, flags, environment, cpu, exploratory):
    """The exploratory local.jl processes: work counters for all IDs, then one per case."""
    local = ["taskset", "-c", str(cpu), *flags, f"--project={environment}",
             "benchmark/local.jl", "--rep", str(protocol["local_rep"])]
    yield "work-counters", [*local, "--save", str(exploratory / "work-counters.local.tsv"), *ids]
    for number, case in enumerate(ids, 1):
        yield f"first-call-{number:02d}", [
            *local, "--samples", str(protocol["local_first_call_samples"]), "--save",
            str(exploratory / "first-call" / f"{number:02d}.local.tsv"), case]


def check_listing(path, ids):
    listed = [line.split("\t")[0] for line in Path(path).read_text().splitlines()]
    check(len(listed) == len(set(listed)), "PS_LIST printed duplicate IDs")
    check(sorted(listed) == sorted(ids), "PS_LIST IDs differ from cases.txt: missing="
          f"{sorted(set(ids) - set(listed))} extra={sorted(set(listed) - set(ids))}")


def check_catalog_dump(path, campaign):
    rows = [line.split("\t") for line in Path(path).read_text().splitlines()]
    check(all(len(row) == len(CATALOG_FIELDS) for row in rows), "malformed catalog dump")
    check_catalog_rows([dict(zip(CATALOG_FIELDS, row)) for row in rows], campaign,
                       "catalog before measurement")


def outcomes(campaign, metrics, hardware):
    """Numerical (gate B) and hardware results, from the records alone."""
    roles = {entry["id"]: entry["role"] for entry in campaign["case"]}
    nonok = [dict(id=case, role=roles[case], rep=rep, status=status) for case, rep, status in
             sorted({(case, rep, row["status"]) for rep, rows in metrics.items()
                     for case, row in rows.items() if row["status"] != "ok"})]
    issues = sorted({issue for record in hardware for issue in hardware_issues(campaign, record)})
    return nonok, issues


def exit_status(reports):
    """1: a stop or an integrity failure; 2: valid records with a non-ok case; 0: all ok."""
    if not reports or any(report["failures"] for report in reports):
        return 1
    return 2 if any(report.get("nonok") for report in reports) else 0


# ---------------------------------------------------------------------------------------
# Verification from evidence alone


def events(julia_dir):
    return [json.loads(line) for line in (julia_dir / "receipt.jsonl").read_text().splitlines()]


def verify_julia(julia_dir, campaign, ids, freeze_head):
    """Re-check one Julia version's evidence without Julia; returns a report whose
    `failures` lists every integrity problem found."""
    report = dict(julia=julia_dir.name, failures=[])
    try:
        verify_evidence(julia_dir, campaign, ids, freeze_head, report)
    except Exception as error:   # any unreadable or inconsistent evidence fails
        report["failures"].append(f"{type(error).__name__}: {error}")
    report["record_integrity"] = "invalid" if report["failures"] else "valid"
    return report


def verify_evidence(julia_dir, campaign, ids, freeze_head, report):
    fail = report["failures"].append
    protocol, machine = campaign["protocol"], campaign["machine"]
    listed = read_checksums(julia_dir / "checksums.sha256")
    present = {str(p.relative_to(julia_dir)) for p in julia_dir.rglob("*") if p.is_file()}
    if present - {"checksums.sha256"} != set(listed):
        fail(f"files differ from checksums.sha256: "
             f"{sorted((present - {'checksums.sha256'}) ^ set(listed))}")
    for name, digest in listed.items():
        if (julia_dir / name).is_file() and sha256(julia_dir / name) != digest:
            fail(f"checksum mismatch: {name}")
    result = json.loads((julia_dir / "result.json").read_text())
    log = events(julia_dir)
    check(log and log[0]["event"] == "start", "the receipt has no start event")
    start = log[0]
    report.update(status=result["status"], mode=start["mode"], reason=result["reason"],
                  freeze_head=start["freeze_head"])
    check(result["status"] == "completed", f"attempt stopped: {result['reason']}")
    version = julia_dir.name.removeprefix("julia-")
    entry = julia_entry(campaign, version)
    check(start["julia_version"] == version, "receipt and directory name disagree on Julia")

    # The run's identity and protocol come from the freeze, not from the receipt.
    check(start["campaign_id"] == campaign["campaign_id"]
          and start["cases_sha256"] == campaign["cases"]["sha256"]
          and start["case_filter"] == ",".join(ids), "the evidence is of another campaign or case list")
    check(start["pinned_sha"] == campaign["proximalsolvers"]["commit"], "another pinned commit")
    check(start["freeze_head"] == freeze_head, f"the evidence was produced at freeze "
          f"{start['freeze_head']}; this checkout is {freeze_head}")
    check(start["campaign_py_sha256"] == sha256(HERE / "campaign.py"), "another campaign.py")
    reps = start["repetitions"]
    if start["mode"] == "official":
        check(start["settings"] == campaign["settings"] and reps == protocol["repetitions"]
              and not start["no_exploratory"] and start["freeze_sha_expected"] == freeze_head,
              "official evidence with other settings, repetitions or freeze SHA")
        check(Path(start["root"]).name == campaign["archive"]["name"]
              and "--pilot" not in start["argv"],
              "official evidence with another root name or a --pilot command line")
    else:
        check(start["mode"] == "pilot", f"unknown mode {start['mode']}")
        check("pilot" in Path(start["root"]).name and "--pilot" in start["argv"],
              "pilot evidence without a pilot root name and a --pilot command line")
    pinned, environment = start["pinned"], start["environment"]
    check_lock(julia_dir / "Manifest.toml", campaign, version, pinned)
    check_project(julia_dir / "Project.toml", HERE.parent.parent / "Project.toml", pinned)
    check_probe(tomllib.loads((julia_dir / "environment-inventory.toml").read_text()),
                campaign, version, pinned, environment, start["depot_path"].split(":")[0])
    snapshot = next(e for e in log if e["event"] == "environment")["snapshot_sha256"]
    for name, digest in snapshot.items():
        if sha256(julia_dir / name) != digest:
            fail(f"{name} snapshot differs from the one recorded at setup")

    # Every command of the protocol, once, in order, with its exact argv, environment and exit.
    commands = {}
    for event in log:
        if event["event"] == "command":
            check(event["name"] not in commands, f"duplicate command {event['name']}")
            commands[event["name"]] = event
    exploratory = julia_dir / "exploratory"
    local = [] if start["no_exploratory"] else list(local_commands(
        protocol, ids, [start["julia_binary"], *protocol["julia_flags"]], environment,
        machine["logical_cpu"], Path(start["root"]) / julia_dir.name / "exploratory"))
    order = ["setup", "probe", "list", "catalog", *(f"rep{r:02d}" for r in range(1, reps + 1)),
             "validate", "summarize", "check_analysis", *(name for name, _ in local)]
    check(list(commands) == order, f"commands {list(commands)} differ from the protocol")
    flags = [start["julia_binary"], *protocol["julia_flags"]]
    run_env = process_env(campaign, start, start["settings"], ids)
    raw_path = str(Path(start["root"]) / julia_dir.name / "raw")
    want = {"setup": ([*flags, "benchmark/setup.jl", pinned, environment,
                       protocol["proximalbase_spec"]],
                      dict(start["settings"], JULIA_DEPOT_PATH=start["depot_path"]), (0,)),
            "probe": ([*flags, f"--project={environment}", "-e", PROBE], run_env, (0,)),
            "list": ([*flags, f"--project={environment}", "benchmark/run.jl"],
                     dict(run_env, PS_LIST="true"), (0,)),
            "catalog": ([*flags, f"--project={environment}", "-e", CATALOG], run_env, (0,))}
    for rep in range(1, reps + 1):
        want[f"rep{rep:02d}"] = (["taskset", "-c", str(machine["logical_cpu"]), *flags,
                                  f"--project={environment}", "benchmark/run.jl"],
                                 dict(run_env, PS_REPETITION=str(rep), PS_OUTPUT=raw_path),
                                 tuple(protocol["accepted_exit_codes"]))
    for name in ("validate", "summarize", "check_analysis"):
        want[name] = (None, None, (0,))
    for name, argv in local:
        want[name] = (argv, run_env, (0, 2))
    for name, (argv, env, exits) in want.items():
        command = commands[name]
        if argv is not None and command["argv"] != argv:
            fail(f"{name} ran {command['argv']}")
        if env is not None and {k: v for k, v in command["env"].items()
                                if k not in PASS_THROUGH} != env:
            fail(f"{name} ran with another environment")
        if command["exit"] not in exits:
            fail(f"{name} exited with {command['exit']}")
        if command["cwd"] != pinned:
            fail(f"{name} ran in {command['cwd']}")
    check_listing(julia_dir / commands["list"]["stdout"], ids)
    check_catalog_dump(julia_dir / commands["catalog"]["stdout"], campaign)
    required = ["validation.json", "summary/summary.csv", "summary/SUMMARY.md",
                "machine-inventory.txt", "environment-inventory.toml"]
    if not start["no_exploratory"]:
        required += ["exploratory/work-counters.local.tsv", *(
            f"exploratory/first-call/{n:02d}.local.tsv" for n in range(1, len(ids) + 1))]
    missing = [name for name in required if not (julia_dir / name).is_file()]
    if missing:
        fail(f"missing outputs {missing}")

    # The records of every repetition, as after each repetition of the run.
    raw = julia_dir / "raw"
    expected = expected_metadata(campaign, version, start["settings"], ids, pinned)
    hardware = [e for e in log if e["event"] == "hardware"]
    check([e["rep"] for e in hardware] == list(range(1, reps + 1)),
          "hardware records do not cover every repetition")
    metrics = {}
    for record in hardware:
        monitor = commands[f"rep{record['rep']:02d}"]["monitor"]
        if monitor != record["monitor"] or monitor["allowed"] != [str(machine["logical_cpu"])] \
                or monitor["samples"] <= 0:
            fail(f"rep{record['rep']:02d} affinity record {monitor}")
    for rep in range(1, reps + 1):
        metrics[rep] = check_repetition(raw, version, rep, expected, campaign,
                                        commands[f"rep{rep:02d}"]["exit"])
    if {path.name for path in raw.iterdir()} != raw_names(entry["version"], reps):
        fail("raw files differ from the expected repetitions")
    check_fixed_inputs(campaign, metrics)
    sys.path.insert(0, str(HERE.parent.parent))
    sys.dont_write_bytecode = True
    try:
        import validate   # the freeze checkout's copy, identical to the pinned one
    finally:
        sys.path.pop(0)
    checked = validate.validate(raw, reps, [entry["version"]])
    if not checked["valid"]:
        fail(f"validate.py: {checked['issues']}")
    if checked != json.loads((julia_dir / "validation.json").read_text()):
        fail("validation.json differs from a fresh validation")

    # Numerical and hardware results, recomputed; the receipt must agree.
    nonok, issues = outcomes(campaign, metrics, hardware)
    outcome = next(e for e in log if e["event"] == "result")
    if (nonok, issues) != (outcome["nonok"], outcome["hardware_issues"]):
        fail("the recorded numerical or hardware result differs from the evidence")
    report.update(numerical="all ok" if not nonok else "non-ok cases", nonok=nonok,
                  nonok_primary=sorted({row["id"] for row in nonok if row["role"] == "primary"}),
                  hardware="controlled" if not issues else "observational",
                  hardware_issues=issues, repetitions=reps)


def verify(args):
    campaign, ids = load_campaign()
    _, freeze_head = check_freeze_checkout(campaign, args.freeze_sha)
    root = Path(args.root).resolve()
    reports = []

    def problem(label, message):
        reports.append(dict(julia=label, failures=[message]))

    for name in ("campaign.toml", "cases.txt"):
        if not (root / name).is_file() or (root / name).read_bytes() != (HERE / name).read_bytes():
            problem(name, f"{name} is missing or differs from the freeze checkout")
    sums = root / "checksums.sha256"
    if sums.exists():   # the archive-level list (archive.sh checksums); excludes only itself
        try:
            listed = read_checksums(sums)
        except Stop as error:
            listed = None
            problem("checksums.sha256", f"archive checksums: {error}")
        if listed is not None:
            files = {str(p.relative_to(root)) for p in root.rglob("*") if p.is_file()}
            files -= {sums.name}
            bad = sorted(name for name in listed if not (root / name).is_file()
                         or sha256(root / name) != listed[name])
            if bad or files != set(listed):
                problem("checksums.sha256", f"archive checksums: mismatched={bad} "
                        f"unlisted={sorted(files - set(listed))}")
    elif args.archive:
        problem("checksums.sha256", "the archive has no checksums.sha256")
    directories = sorted(root.glob("julia-*"))
    for julia_dir in directories:
        reports.append(verify_julia(julia_dir, campaign, ids, freeze_head))
    modes = {report.get("mode") for report in reports if "mode" in report}
    names = {path.name for path in directories}
    wanted = {f"julia-{version}" for version in campaign["julia"]}
    # Official: any official evidence, or an archive without --allow-pilot. Otherwise
    # `--archive --allow-pilot` is a pilot archive rehearsal, never official evidence.
    official = "official" in modes or (args.archive and not args.allow_pilot)
    if official:
        if names != wanted or modes != {"official"}:
            problem("root", f"an official root holds exactly {sorted(wanted)}, all official; "
                    f"found {sorted(names)} ({sorted(modes, key=str)})")
        if root.name != campaign["archive"]["name"]:
            problem("root", f"the official root must be named {campaign['archive']['name']}")
        if not args.freeze_sha:
            problem("root", "official evidence needs --freeze-sha (the freeze commit on #110)")
    elif args.archive:
        if names != wanted or modes != {"pilot"}:
            problem("root", f"a pilot archive rehearsal holds exactly {sorted(wanted)}, all "
                    f"pilot; found {sorted(names)} ({sorted(modes, key=str)})")
        if "pilot" not in root.name or root.name == campaign["archive"]["name"]:
            problem("root", "a pilot archive's name must contain 'pilot' and differ from "
                    f"{campaign['archive']['name']}")
    attempts = Counter()
    for path in sorted((root / "attempts").glob("*")) if (root / "attempts").exists() else []:
        match = re.fullmatch(r"julia-(.+)-attempt([0-9]+)", path.name)
        try:
            stopped = json.loads((path / "result.json").read_text())["status"] == "stopped"
        except (OSError, ValueError, KeyError):
            stopped = False
        if not match or not stopped:
            problem(f"attempts/{path.name}", "attempts/ may hold only stopped attempts, "
                    "named julia-<V>-attempt<N>")
        else:
            attempts[match[1]] += 1
    for version, count in attempts.items():
        if count > campaign["protocol"]["max_complete_attempts"] - 1:
            problem("attempts", f"{count} stopped attempts of Julia {version}")
    if not (modes <= {"official"} or args.allow_pilot):
        problem("root", "pilot evidence; pass --allow-pilot to check it")
    print(json.dumps(reports, indent=2))
    code = exit_status(reports)
    primary = sorted({case for report in reports for case in report.get("nonok_primary", [])})
    print(f"RECORD INTEGRITY: {'FAIL' if code == 1 else 'PASS'}")
    if code != 1:
        print(f"NUMERICAL: {'FAIL' if code == 2 else 'PASS'} (non-ok primary cases: "
              f"{primary or 'none'})")
        print("HARDWARE: " + ", ".join(
            f"{r['julia']} {r['hardware']}" for r in reports if "hardware" in r))
    if code == 1:
        print("EVIDENCE: NOT VALID (integrity failure; never Stage 2A baseline evidence)")
    elif official and modes == {"official"}:
        print("EVIDENCE: OFFICIAL")
    else:
        print("EVIDENCE: PILOT / NON-OFFICIAL (never Stage 2A baseline evidence)")
    return code


class Parser(argparse.ArgumentParser):
    """Usage errors exit 1: exit status 2 means valid records with a non-ok case."""

    def error(self, message):
        self.print_usage(sys.stderr)
        self.exit(1, f"{self.prog}: error: {message}\n")


def main():
    parser = Parser(description=__doc__,
                                     formatter_class=argparse.RawDescriptionHelpFormatter)
    commands = parser.add_subparsers(dest="command", required=True)
    runner = commands.add_parser("run", help="run one Julia version of the campaign")
    runner.add_argument("--julia-version", required=True, help="1.10 or 1.13")
    runner.add_argument("--julia", required=True, help="the Julia executable of that build")
    runner.add_argument("--pinned", required=True, help="clean checkout of the pinned commit")
    runner.add_argument("--work", required=True, help="environments and depot (not archived)")
    runner.add_argument("--root", required=True, help="evidence root (the archive directory)")
    runner.add_argument("--freeze-sha", help="the freeze commit recorded on #110")
    runner.add_argument("--pilot", action="store_true", help="a readiness pilot, never official")
    runner.add_argument("--reps", type=int, help="pilot only: repetitions")
    runner.add_argument("--override", action="append", default=[],
                        help=f"pilot only: NAME=VALUE for one of {PILOT_OVERRIDES}")
    runner.add_argument("--no-exploratory", action="store_true",
                        help="pilot only: skip the local.jl receipts")
    verifier = commands.add_parser("verify", help="re-check an evidence root without Julia")
    verifier.add_argument("root")
    verifier.add_argument("--freeze-sha", help="require this checkout to be the freeze commit "
                          "(required for official evidence)")
    verifier.add_argument("--allow-pilot", action="store_true",
                          help="accept pilot evidence (always labelled PILOT / NON-OFFICIAL); "
                          "with --archive: a pilot archive rehearsal")
    verifier.add_argument("--archive", action="store_true",
                          help="require the archive-level checksums.sha256 and a complete "
                          "root (official unless --allow-pilot)")
    commands.add_parser("ids", help="print PS_CASES (cases.txt joined by commas)")
    args = parser.parse_args()
    try:
        if args.command == "ids":
            print(",".join(load_campaign()[1]))
            return 0
        return run(args) if args.command == "run" else verify(args)
    except Stop as error:
        print(f"STOP {error}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    sys.exit(main())
