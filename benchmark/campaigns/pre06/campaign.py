#!/usr/bin/env python3
"""Run the frozen Stage 2A campaign for one Julia version, or verify its evidence.

A receipt around the pinned checkout's own benchmark/setup.jl, run.jl, local.jl,
validate.py and summarize.py: it checks every frozen identity in campaign.toml before,
during and after the run, records every command, environment, output and exit code, and
stops at the first failed check. It changes nothing that is measured. Linux only.

  campaign.py run --julia-version 1.13 --julia BIN --pinned DIR --work DIR --root DIR \
                  --freeze-sha SHA
  campaign.py verify ROOT
  campaign.py ids

See README.md in this directory; the governing design is STAGE2_PLAN.md.
"""

import argparse
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
        check(meta.get("rep") == rep, f"{prefix} {label} metadata: rep={meta.get('rep')}")
        for key, want in expected.items():
            check(meta.get(key) == want, f"{prefix} {label} metadata: {key}={meta.get(key)!r}, "
                  f"expected {want!r}")
    check(final.get("finished") is True, f"{prefix}: not finished")
    check(final.get("cases") == campaign["cases"]["count"], f"{prefix}: wrong case count")
    nonok = final.get("nonok_cases")
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
            check(Path(item.get("path", "")).resolve() == Path(pinned).resolve(),
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
        Path(source.get("path", "")).resolve() == Path(pinned).resolve() and len(source) == 1
        for source in sources.values()), f"unexpected [sources] {sources}")
    check(set(project) <= {"deps", "compat", "sources"}, "unexpected Project.toml sections")


def check_probe(probe, campaign, version, pinned):
    entry = julia_entry(campaign, version)
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
    if monitor["observed_cpus"] and set(monitor["observed_cpus"]) != {machine["logical_cpu"]}:
        issues.append(f"observed on CPUs {monitor['observed_cpus']}")
    if record["sibling_busy"] is None or record["sibling_busy"] > machine["max_sibling_busy"]:
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
    raise Stop(f"cpu{cpu} is not in /proc/stat")


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
    source = campaign["proximalsolvers"]
    check(git(pinned, "rev-parse", "HEAD") == source["commit"], "pinned checkout is not at "
          f"{source['commit']}")
    check(git(pinned, "rev-parse", "HEAD^{tree}") == source["tree"], "pinned tree differs")
    check(git(pinned, "status", "--porcelain", "--untracked-files=all") == "",
          "pinned checkout is not clean")
    freeze = Path(git(HERE, "rev-parse", "--show-toplevel"))
    freeze_head = git(freeze, "rev-parse", "HEAD")
    check(not args.freeze_sha or freeze_head == args.freeze_sha,
          f"freeze checkout HEAD {freeze_head} is not --freeze-sha {args.freeze_sha}")
    check(git(freeze, "status", "--porcelain", "--untracked-files=all") == "",
          "freeze checkout is not clean")
    unchanged = subprocess.run(["git", "-C", str(freeze), "diff", "--quiet", source["commit"],
                                "HEAD", "--", *source["unchanged_paths"]])
    check(unchanged.returncode == 0, "the freeze commit changes pinned package or harness files")

    root, work = Path(args.root).resolve(), Path(args.work).resolve()
    for path in (root, work):
        check(pinned not in path.parents and path != pinned and freeze not in path.parents,
              f"{path} must be outside both checkouts")
    julia_dir = root / f"julia-{version}"
    check(not julia_dir.exists(), f"{julia_dir} exists: never reuse an attempt; use a fresh root")
    environment = work / f"env-{version}"
    check(not environment.exists(), f"{environment} exists: use a fresh environment")
    root.mkdir(parents=True, exist_ok=True)
    for name in ("campaign.toml", "cases.txt"):   # shared by both Julia versions of a root
        copy = root / name
        if copy.exists():
            check(copy.read_bytes() == (HERE / name).read_bytes(), f"{copy} is another campaign's")
        else:
            shutil.copyfile(HERE / name, copy)
    raw = julia_dir / "raw"
    receipt = Receipt(julia_dir)
    status, reason = "stopped", None
    try:
        # Keep this process off the measured CPU and its sibling.
        os.sched_setaffinity(0, os.sched_getaffinity(0) - {machine["logical_cpu"],
                                                           machine["smt_sibling"]})
        julia = Path(args.julia).resolve()
        env = {key: os.environ[key] for key in PASS_THROUGH if key in os.environ}
        env.update(settings, PS_CASES=",".join(ids), PS_EXPECTED_PACKAGE_ROOT=str(pinned),
                   JULIA_DEPOT_PATH=f"{work / 'depot'}:")
        flags = [str(julia), *protocol["julia_flags"]]
        receipt.event("start", mode="pilot" if args.pilot else "official",
                      campaign_id=campaign["campaign_id"], julia_version=version,
                      julia_binary=str(julia), julia_binary_sha256=sha256(julia),
                      pinned=str(pinned), pinned_sha=source["commit"], freeze=str(freeze),
                      freeze_head=freeze_head, freeze_sha_expected=args.freeze_sha,
                      cases_sha256=campaign["cases"]["sha256"], repetitions=reps,
                      settings=settings, case_filter=env["PS_CASES"], work=str(work),
                      argv=sys.argv, cwd=os.getcwd(), python=sys.version)
        write_new(julia_dir / "machine-inventory.txt", inventory_text())

        # Environment: the approved setup.jl, then the frozen identities.
        receipt.command("setup", [*flags, "benchmark/setup.jl", str(pinned), str(environment),
                                  protocol["proximalbase_spec"]], env, pinned)
        project, manifest = environment / "Project.toml", environment / "Manifest.toml"
        check_project(project, pinned / "benchmark" / "Project.toml", pinned)
        check_lock(manifest, campaign, version, pinned)
        for path in (project, manifest):   # immutable snapshots, outside both checkouts
            shutil.copyfile(path, julia_dir / path.name)
            os.chmod(julia_dir / path.name, 0o444)
        snapshot = {name: sha256(julia_dir / name) for name in ("Project.toml", "Manifest.toml")}
        registry = read(work / "depot" / "registries" / "General.toml")
        receipt.event("environment", snapshot_sha256=snapshot, registry=registry)
        run_env = dict(env, JULIA_PKG_OFFLINE="true")   # no registry or package updates from here
        receipt.command("probe", [*flags, f"--project={environment}", "-e", PROBE], run_env, pinned)
        probe = tomllib.loads((receipt.logs / "probe.out").read_text())
        check_probe(probe, campaign, version, pinned)
        shutil.copyfile(receipt.logs / "probe.out", julia_dir / "environment-inventory.toml")

        def unchanged_environment():
            check({name: sha256(environment / name) for name in snapshot} == snapshot,
                  "the environment's Project.toml or Manifest.toml changed after its snapshot")
            check(git(pinned, "rev-parse", "HEAD") == source["commit"] and
                  git(pinned, "status", "--porcelain", "--untracked-files=all") == "",
                  "the pinned checkout changed")

        # Case selection, before any measurement.
        receipt.command("list", [*flags, f"--project={environment}", "benchmark/run.jl"],
                        dict(run_env, PS_LIST="true"), pinned)
        listed = [line.split("\t")[0] for line in (receipt.logs / "list.out").read_text().splitlines()]
        check(len(listed) == len(set(listed)), "PS_LIST printed duplicate IDs")
        check(sorted(listed) == sorted(ids), "PS_LIST IDs differ from cases.txt: missing="
              f"{sorted(set(ids) - set(listed))} extra={sorted(set(listed) - set(ids))}")
        receipt.command("catalog", [*flags, f"--project={environment}", "-e", CATALOG],
                        run_env, pinned)
        fields = [line.split("\t") for line in
                  (receipt.logs / "catalog.out").read_text().splitlines()]
        check(all(len(row) == len(CATALOG_FIELDS) for row in fields), "malformed catalog dump")
        check_catalog_rows([dict(zip(CATALOG_FIELDS, row)) for row in fields], campaign,
                           "catalog before measurement")
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
            spans = {c: [after["times"][str(c)][i] - before["times"][str(c)][i] for i in (0, 1)]
                     for c in (cpu, sibling)}
            busy = {c: (span[0] - span[1]) / span[0] if span[0] else None
                    for c, span in spans.items()}
            record = dict(rep=rep, settle_s=waited, before=before, after=after, monitor=monitor,
                          cpu_busy=busy[cpu], sibling_busy=busy[sibling])
            record["issues"] = hardware_issues(campaign, record)
            hardware.append(record)
            receipt.event("hardware", **record)
            metrics[rep] = check_repetition(raw, version, rep, expected, campaign, code)
            for previous, digest in sealed.items():
                check(sha256(raw / previous) == digest, f"{previous} changed after its repetition")
            names = {path.name for path in raw.iterdir()}
            wanted = {f"julia-{entry['version']}-rep{r:02d}{s}"
                      for r in range(1, rep + 1) for s in RAW_SUFFIXES}
            check(names == wanted, f"unexpected raw files {sorted(names ^ wanted)}")
            new = {name: sha256(raw / name) for name in sorted(names - set(sealed))}
            sealed.update(new)
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
                                     str(reps), *versions], env, pinned)
        validation = json.loads((julia_dir / "validation.json").read_text())
        check(validation["valid"] and validation["counts"]["processes"] == reps,
              "validate.py did not find valid records")
        receipt.command("summarize", [*PYTHON, "benchmark/summarize.py", str(raw),
                                      str(julia_dir / "summary"), "--expected-runs", str(reps),
                                      *versions], env, pinned)
        receipt.command("check_analysis", [*PYTHON, "benchmark/check_analysis.py"], env, pinned)
        unchanged_environment()

        # Untimed exploratory receipts (labelled; not formal records).
        if not args.no_exploratory:
            exploratory = julia_dir / "exploratory"
            (exploratory / "first-call").mkdir(parents=True)
            local = ["taskset", "-c", str(cpu), *flags, f"--project={environment}",
                     "benchmark/local.jl", "--rep", str(protocol["local_rep"])]
            receipt.command("work-counters", [*local, "--save",
                                              str(exploratory / "work-counters.local.tsv"), *ids],
                            run_env, pinned, accept=(0, 2))
            for number, case in enumerate(ids, 1):
                receipt.command(f"first-call-{number:02d}", [
                    *local, "--samples", str(protocol["local_first_call_samples"]), "--save",
                    str(exploratory / "first-call" / f"{number:02d}.local.tsv"), case],
                    run_env, pinned, accept=(0, 2))
            unchanged_environment()

        # Numerical gate (B) is separate from record integrity (A).
        nonok = sorted({(case, rep, row["status"]) for rep, rows in metrics.items()
                        for case, row in rows.items() if row["status"] != "ok"})
        issues = sorted({issue for record in hardware for issue in record["issues"]})
        status = "completed"
        receipt.event("result", record_integrity="valid",
                      numerical="all ok" if not nonok else "non-ok cases",
                      nonok=[dict(id=c, rep=r, status=s) for c, r, s in nonok],
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
    report = verify_julia(julia_dir, campaign, ids, HERE.parent.parent, quiet=False)
    return 0 if status == "completed" and report["status"] == "completed" else 1


# ---------------------------------------------------------------------------------------
# Verification from evidence alone


def events(julia_dir):
    return [json.loads(line) for line in (julia_dir / "receipt.jsonl").read_text().splitlines()]


def verify_julia(julia_dir, campaign, ids, benchmark, quiet=True):
    """Re-check one Julia version's evidence without Julia; returns a short report."""
    report = dict(julia=julia_dir.name, failures=[])

    def fail(message):
        report["failures"].append(message)

    listed = {}
    lines = (julia_dir / "checksums.sha256").read_text().splitlines()
    for line in lines:
        digest, _, name = line.partition("  ")
        listed[name] = digest
    present = {str(p.relative_to(julia_dir)) for p in julia_dir.rglob("*") if p.is_file()}
    if present - {"checksums.sha256"} != set(listed):
        fail(f"files differ from checksums.sha256: {sorted((present - {'checksums.sha256'}) ^ set(listed))}")
    for name, digest in listed.items():
        if (julia_dir / name).is_file() and sha256(julia_dir / name) != digest:
            fail(f"checksum mismatch: {name}")
    result = json.loads((julia_dir / "result.json").read_text())
    log = events(julia_dir)
    start = log[0]
    report.update(status=result["status"], mode=start["mode"], reason=result["reason"])
    if result["status"] != "completed":
        fail(f"attempt stopped: {result['reason']}")
        return finish(report, quiet)
    version = julia_dir.name.removeprefix("julia-")
    pinned = start["pinned"]
    try:
        entry = julia_entry(campaign, version)
        if start["cases_sha256"] != campaign["cases"]["sha256"] or start["case_filter"] != ",".join(ids):
            fail("the evidence was produced from another case list")
        check_lock(julia_dir / "Manifest.toml", campaign, version, pinned)
        check_project(julia_dir / "Project.toml", benchmark / "Project.toml", pinned)
        check_probe(tomllib.loads((julia_dir / "environment-inventory.toml").read_text()),
                    campaign, version, pinned)
        snapshot = next(e for e in log if e["event"] == "environment")["snapshot_sha256"]
        for name, digest in snapshot.items():
            if sha256(julia_dir / name) != digest:
                fail(f"{name} snapshot differs from the one recorded at setup")
        commands = {e["name"]: e for e in log if e["event"] == "command"}
        listed = [line.split("\t")[0] for line in
                  (julia_dir / commands["list"]["stdout"]).read_text().splitlines()]
        if sorted(listed) != sorted(ids) or commands["list"]["env"].get("PS_LIST") != "true":
            fail("the archived PS_LIST output differs from cases.txt")
        check_catalog_rows([dict(zip(CATALOG_FIELDS, line.split("\t"))) for line in
                            (julia_dir / commands["catalog"]["stdout"]).read_text().splitlines()],
                           campaign, "archived catalog")
        if start["mode"] == "official" and start["freeze_head"] != start["freeze_sha_expected"]:
            fail("official run without a matching --freeze-sha")
        raw = julia_dir / "raw"
        expected = expected_metadata(campaign, version, start["settings"], ids, pinned)
        metrics = {}
        for rep in range(1, start["repetitions"] + 1):
            command = commands[f"rep{rep:02d}"]
            argv = command["argv"]
            if argv[:3] != ["taskset", "-c", str(campaign["machine"]["logical_cpu"])]:
                fail(f"rep{rep:02d} was not pinned to the frozen CPU")
            if command["monitor"]["allowed"] != [str(campaign["machine"]["logical_cpu"])]:
                fail(f"rep{rep:02d} affinity {command['monitor']['allowed']}")
            if command["env"].get("PS_REPETITION") != str(rep):
                fail(f"rep{rep:02d} has PS_REPETITION={command['env'].get('PS_REPETITION')}")
            for key, value in start["settings"].items():
                if command["env"].get(key) != value:
                    fail(f"rep{rep:02d} ran with {key}={command['env'].get(key)}")
            metrics[rep] = check_repetition(raw, version, rep, expected, campaign, command["exit"])
        wanted = {f"julia-{entry['version']}-rep{r:02d}{s}"
                  for r in range(1, start["repetitions"] + 1) for s in RAW_SUFFIXES}
        if {p.name for p in raw.iterdir()} != wanted:
            fail("raw files differ from the expected repetitions")
        check_fixed_inputs(campaign, metrics)
    except (Stop, OSError, KeyError, ValueError, StopIteration) as error:
        fail(f"{type(error).__name__}: {error}")
        return finish(report, quiet)
    sys.path.insert(0, str(benchmark))
    sys.dont_write_bytecode = True
    try:
        import validate   # the freeze checkout's copy, identical to the pinned one
    finally:
        sys.path.pop(0)
    checked = validate.validate(raw, start["repetitions"], [entry["version"]])
    if not checked["valid"]:
        fail(f"validate.py: {checked['issues']}")
    if checked != json.loads((julia_dir / "validation.json").read_text()):
        fail("validation.json differs from a fresh validation")
    # Recompute the numerical and hardware results from the evidence; the receipt must agree.
    outcome = next(e for e in log if e["event"] == "result")
    nonok = [dict(id=c, rep=r, status=s) for c, r, s in sorted(
        {(case, rep, row["status"]) for rep, rows in metrics.items()
         for case, row in rows.items() if row["status"] != "ok"})]
    hardware = [e for e in log if e["event"] == "hardware"]
    issues = sorted({issue for record in hardware for issue in hardware_issues(campaign, record)})
    if [e["rep"] for e in hardware] != list(range(1, start["repetitions"] + 1)):
        fail("hardware records do not cover every repetition")
    if (nonok, issues) != (outcome["nonok"], outcome["hardware_issues"]):
        fail("recorded numerical or hardware result differs from the evidence")
    report.update(record_integrity="valid" if not report["failures"] else "invalid",
                  numerical="all ok" if not nonok else "non-ok cases", nonok=nonok,
                  hardware="controlled" if not issues else "observational",
                  hardware_issues=issues, repetitions=start["repetitions"],
                  freeze_head=start["freeze_head"])
    return finish(report, quiet)


def finish(report, quiet):
    if not quiet:
        print(json.dumps(report, indent=2))
    return report


def verify(args):
    campaign, ids = load_campaign()
    root = Path(args.root)
    reports = []
    sums = root / "checksums.sha256"
    if sums.exists():   # the archive-level list (README, "Archive"); excludes itself
        listed = dict(reversed(line.split("  ", 1)) for line in sums.read_text().splitlines())
        files = {str(p.relative_to(root)) for p in root.rglob("*") if p.is_file()} - {sums.name}
        bad = sorted(name for name in listed if not (root / name).is_file()
                     or sha256(root / name) != listed[name])
        if bad or files != set(listed):
            reports.append(dict(julia="checksums.sha256", failures=[
                f"archive checksums: mismatched={bad} unlisted={sorted(files - set(listed))}"]))
    elif args.archive:
        reports.append(dict(julia="checksums.sha256", failures=["archive has no checksums.sha256"]))
    for name in ("campaign.toml", "cases.txt"):
        if (root / name).read_bytes() != (HERE / name).read_bytes():
            reports.append(dict(julia=name, failures=[f"{name} differs from the freeze checkout"]))
    for julia_dir in sorted(root.glob("julia-*")):
        reports.append(verify_julia(julia_dir, campaign, ids, HERE.parent.parent))
    print(json.dumps(reports, indent=2))
    official = all(r.get("mode") == "official" for r in reports if "mode" in r)
    ok = reports and not any(r["failures"] for r in reports) and (official or args.allow_pilot)
    print(f"VERIFY {'PASS' if ok else 'FAIL'}: {len(reports)} item(s); record integrity and "
          "numerical results are reported separately above")
    return 0 if ok else 1


def main():
    parser = argparse.ArgumentParser(description=__doc__,
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
    verifier.add_argument("--allow-pilot", action="store_true")
    verifier.add_argument("--archive", action="store_true",
                          help="require the archive-level checksums.sha256")
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
