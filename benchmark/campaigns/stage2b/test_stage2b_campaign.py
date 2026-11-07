#!/usr/bin/env python3
"""Offline tests of stage2b_campaign.py (the Stage 2B campaign driver core, #218).

    python3 -B test_stage2b_campaign.py        (or python3 -B -m unittest test_stage2b_campaign -v)

Standard library only (Python 3.11 or later). No Julia, no cluster, no network, no `gh`. The command runner, the
probe, the clock and the machine sampler are mocks; a stub runner that fails the test when it is invoked guards
every refusal that must happen before any process starts. The synthetic roots come from `stage2b_fixtures.py`.

Test classes (the integration class builds the full-shape set once: two Julia strata, 19 cases, 8 repetitions,
four roots, and runs the engine over it with mocked hooks; its tests copy the finished tree for every mutation):

    TomlTests, FingerprintTests   the TOML writer; the SHA-1 fingerprints against the known values
    LockTests, GateTests          the campaign lock; the official gate and the pilot refusals (stub runner)
    PreflightTests                the observation checks, all problems at once
    WriterTests                   identity, receipt, machine sampler, evidence paths, declared differences
    SealTests, EngineTests        sealing, stop state, exit statuses over a small (one repetition) pilot-shaped set
    IntegrationTests              the full shape: execute, verify, copies, the negative controls of the tree
    CliTests                      the command line and its exit statuses
"""

import atexit
import contextlib
import copy
import datetime
import io
import json
import math
import os
import re
import shutil
import stat
import subprocess
import sys
import tempfile
import time
import tomllib
import unittest
import unittest.mock
from pathlib import Path

import stage2b_fixtures as F
import stage2b_campaign as C

mc = C.mc
HERE = Path(__file__).resolve().parent
REPO = HERE.parents[2]
TMP = Path(tempfile.mkdtemp(prefix="stage2b-campaign-tests-"))
atexit.register(shutil.rmtree, TMP, True)

FREEZE = "f1" * 20
SESSION = "session-20261201T080000Z-ab12"
URL = "https://github.com/mlakolar/ProximalSolvers.jl/issues/110#issuecomment-6694764350"
BASE_COMMIT = "412063d8ac24b84a10ccde09cf072bb396109ffd"
STACK_A_COMMIT = "b0de3f7fc91767b97197ff4b458207e308998943"
JULIA_BINS = {"1.10": "/opt/julia-1.10.13/bin/julia", "1.13": "/opt/julia-1.13.3/bin/julia"}
ENVIRON = {"PATH": "/usr/bin", "HOME": "/tmp/home", "LANG": "C", C.JOB_ID_VARIABLES[0]: "4242", "SSH_AUTH_SOCK": "/s/a",
           "AWS_SECRET_ACCESS_KEY": "do-not-archive"}
LABEL_ROLE = {label: role for role, label in C.ROLE_LABEL.items()}
_counter = [0]


def fresh(name="t"):
    _counter[0] += 1
    path = TMP / f"{name}-{_counter[0]}"
    path.mkdir()
    return path


def never(*args, **kwargs):
    raise AssertionError("the command runner was invoked")


def hooks_that_never_run():
    return C.Hooks(probe=never, runner=never, clock=never, sampler=never, julia_bins=dict(JULIA_BINS),
                   depot_digest=never, datahash_ok=never)


def writable(path):
    os.chmod(path, 0o644)
    return Path(path)


def edit_text(path, function):
    path = writable(path)
    path.write_text(function(path.read_text(encoding="utf-8")), encoding="utf-8")


def clone(base, name="copy"):
    dest = fresh(name) / "tree"
    shutil.copytree(base, dest, symlinks=True)
    return dest


# ------------------------------------------------------------------------------------- synthetic inputs

def make_lock(camp, session=SESSION):
    """A synthetic lock that matches the fixture's stack B exactly (no real candidate exists anywhere)."""
    b = camp.stack("b")
    environments = {}
    for jkey in camp.jkeys:
        directory = camp.stratum("b", jkey)
        environments[jkey] = {"project": f"locks/{jkey}/Project.toml",
                              "project_sha256": C.sha256_file(directory / "Project.toml"),
                              "manifest": f"locks/{jkey}/Manifest.toml",
                              "manifest_sha256": C.sha256_file(directory / "Manifest.toml")}
    declared = F.declared_differences(camp)
    entries = [{"kind": "manifest", "name": r["name"], "uuid": r["uuid"], "change": r["kind"],
                "reason": "synthetic reason", "approval_url": URL, **({"julia": r["julia"]} if "julia" in r else {})}
               for r in declared.get("manifest", [])]
    entries += [{"kind": "compat", "name": r["name"], "reason": "synthetic compat reason", "approval_url": URL,
                 **({"julia": r["julia"]} if "julia" in r else {})} for r in declared.get("compat", [])]
    return {
        "schema": 1, "campaign": {"id": camp.sched["schedule"]["campaign_id"], "session_id": session},
        "stack_b": {
            "proximalsolvers": {"commit": b["ps"]["commit"], "tree": b["ps"]["tree"], "version": b["ps"]["version"],
                                "package_hash": b["ps"]["hash"],
                                "source": "https://github.com/mlakolar/ProximalSolvers.jl"},
            "proximalbase": {"commit": b["pb"]["commit"], "tree": b["pb"]["tree"], "version": b["pb"]["version"],
                             "package_hash": b["pb"]["hash"], "source": "https://github.com/mlakolar/ProximalBase.jl",
                             "release": "development"},
            "harness_hash": b["harness"], "environments": environments},
        "declared": entries,
        "harness": {"port_commit": declared["harness"]["port_commit"],
                    "changed_lines": declared["harness"]["changed_lines"], "approval_url": URL},
        "approvals": {**{g: URL for g in C.GATES}, "case_mapping": [URL]}}


def sidecar_rows(camp, label):
    rows = []
    for jkey in camp.jkeys:
        for rep in camp.reps:
            header, body = C.read_tsv(camp.record(label, jkey, rep, "metrics"))
            for row in body:
                rows.append("\t".join([camp.version(jkey), row[header.index("id")], str(rep),
                                       row[header.index("data_hash")]]))
    return C.DATAHASH_HEADER + "\n" + "\n".join(rows) + "\n"


def assemble_base(camp, base, session=SESSION, with_raw=False, aa=True):
    """A driver BASE from a fixture set: the driver's own identity writer, the fixture's environments and
    fingerprints, empty raw/ directories (or the fixture's records with `with_raw`)."""
    base = Path(base)
    base.mkdir(parents=True)
    for name in ("schedule.toml", "case-mapping.toml"):
        shutil.copyfile(camp.base / name, base / name)
    for label in F.LABELS:
        if label.startswith("aa") and not aa:
            continue
        role = LABEL_ROLE[label]
        ident = tomllib.loads((camp.root(label) / "stack-identity.toml").read_text(encoding="utf-8"))
        C.write_identity(base, role, ident["installation"], ident["campaign_id"], session, ident["proximalsolvers"],
                         ident["proximalbase"])
        for jkey in camp.jkeys:
            target = base / "roots" / role / f"julia-{jkey}"
            target.mkdir(parents=True, exist_ok=True)
            for name in ("Project.toml", "Manifest.toml", "environment-inventory.toml"):
                shutil.copyfile(camp.stratum(label, jkey) / name, target / name)
            (target / "raw").mkdir(exist_ok=True)
            if with_raw:
                for item in camp.raw(label, jkey).iterdir():
                    shutil.copyfile(item, target / "raw" / item.name)
        if role in ("ab-a", "ab-b"):
            shutil.copyfile(camp.fingerprints(label), base / "roots" / role / C.FP_NAME)
            (base / "roots" / role / C.DATAHASH_NAME).write_text(sidecar_rows(camp, label), encoding="utf-8")
    return base


def good_obs(spec, mm, sched, base):
    """A consistent observation of one role and stratum (synthetic real paths per role)."""
    real, want, machine = f"/real/{spec.name}", spec.expected, sched["machine"]
    info = sched["strata"][mm]
    manifest = want["manifest_sha256"].get(mm) or C.sha256_file(base / "roots" / spec.name / f"julia-{mm}" /
                                                                 "Manifest.toml")
    return {
        "julia": {"version": info["version"], "commit": info["commit"], "cpu_name": machine["cpu"][mm]},
        "ps": {"commit": want["ps"]["commit"], "tree": want["ps"]["tree"], "version": want["ps"]["version"],
               "dirty": False, "loaded_realpath": f"{real}/ProximalSolvers.jl",
               "package_hash": want["ps"]["package_hash"]},
        "pb": {"loaded_tree": want["pb"]["tree"], "manifest_tree": want["pb"]["tree"],
               "version": want["pb"]["version"], "package_hash": want["pb"]["package_hash"]},
        "checkout_realpath": f"{real}/ProximalSolvers.jl", "depot_realpath": f"{real}/depot",
        "environment": {"dir": str(spec.environments[mm]), "realpath": f"{real}/env-{mm}", "project_exists": True,
                        "manifest_exists": True},
        "manifest_sha256": manifest,
        "project_sha256": want["project_sha256"].get(mm) or C.sha256_file(base / "roots" / spec.name /
                                                                            f"julia-{mm}" / "Project.toml"),
        "harness_hash": want["harness_hash"], "affinity_cpus": [machine["logical_cpu"]],
        "machine": {"cpu_model": machine["cpu_model"], "cpu": machine["cpu"][mm],
                    "logical_cpu": machine["logical_cpu"]}}


class Host:
    """Mocked hooks over a fixture set: the runner copies the fixture's six record files of the process into
    PS_OUTPUT; `rules` change what a given process does (role, stratum and repetition may be None)."""

    def __init__(self, camp, sched, base, step=20):
        self.camp, self.sched, self.base = camp, sched, Path(base)
        self.now = datetime.datetime(2026, 12, 1, 9, 0, 0, tzinfo=datetime.timezone.utc)
        self.step, self.calls, self.rules, self.obs_edits, self.sample_edits = step, [], [], [], []
        self.reads = 0
        self.datahash = True

    def rule(self, role=None, mm=None, rep=None, **effects):
        self.rules.append(((role, mm, rep), effects))

    def clock(self):
        self.now += datetime.timedelta(seconds=self.step)
        return self.now

    def sampler(self):
        machine = self.sched["machine"]
        sample = {"cpu_model": machine["cpu_model"], "governor": machine["governor"], "epp": machine["epp"],
                  "no_turbo": machine["no_turbo"], "smt_control": machine["smt_control"]}
        self.reads += 1
        for when, edit in self.sample_edits:
            if self.reads >= when:
                edit(sample)
        return sample

    def probe(self, spec, mm):
        obs = good_obs(spec, mm, self.sched, self.base)
        for edit in self.obs_edits:
            edit(spec.name, mm, obs)
        return obs

    def match(self, role, mm, rep):
        found = {}
        for (r, m, p), effects in self.rules:
            if r in (None, role) and m in (None, mm) and p in (None, rep):
                found.update(effects)
        return found

    def runner(self, argv, env, cwd, cpu):
        self.calls.append((list(argv), dict(env), cwd, cpu))
        role = Path(cwd).parent.name
        output = Path(env["PS_OUTPUT"])
        mm, rep = output.parent.name.removeprefix("julia-"), int(env["PS_REPETITION"])
        effects = self.match(role, mm, rep)
        if effects.get("fail_start"):
            raise OSError("cannot start the process")
        label = C.ROLE_LABEL[role]
        stem = f"julia-{self.camp.version(mm)}-rep{rep:02d}"
        nonok = tomllib.loads(self.camp.record(label, mm, rep, "metadata").read_text(encoding="utf-8"))["nonok_cases"]
        for kind in C.RECORD_KINDS:
            if kind not in effects.get("skip", ()):
                source = self.camp.record(label, mm, rep, kind)
                shutil.copyfile(source, output / source.name)
        if "mutate" in effects:
            effects["mutate"](output, stem)
        if effects.get("interrupt"):
            raise effects["interrupt"]
        if "extra" in effects:
            (output / effects["extra"]).write_text("x")
        return C.RunResult(effects.get("exit", 2 if nonok else 0), b"stdout", b"stderr")

    def datahash_ok(self, role, mm, rep):
        return self.datahash

    def hooks(self, **overrides):
        values = dict(probe=self.probe, runner=self.runner, clock=self.clock, sampler=self.sampler,
                      julia_bins=dict(JULIA_BINS), datahash_ok=self.datahash_ok,
                      depot_digest=lambda spec: "digest-of-the-depot-cache")
        values.update(overrides)
        return C.Hooks(**values)


def official_plan(base, lock):
    return C.plan_from_lock(lock, base, JULIA_BINS, ENVIRON, FREEZE)


def facts_for(base, lock, freeze=FREEZE):
    sched = mc.load_schedule(HERE / "schedule.toml")
    b = lock["stack_b"]
    rows = tomllib.loads((HERE / "case-mapping.toml").read_text(encoding="utf-8"))["case"]
    return {"head": freeze, "clean": True, "lock_tracked": True, "strata": list(sched["strata"]),
            "manifest_sha256": {mm: C.sha256_file(Path(base) / "roots" / "ab-b" / f"julia-{mm}" / "Manifest.toml")
                                for mm in sched["strata"]},
            "checkouts": {"ps_b": {k: b["proximalsolvers"][k] for k in ("commit", "tree", "package_hash")},
                          "pb_b": {k: b["proximalbase"][k] for k in ("commit", "tree", "package_hash")}},
            "mapping_rows": [{"id": r["id"], "class": r["class"], "approved": r["approved"]} for r in rows]}


def pilot_edit(schedule):
    schedule["schedule"]["id"] = "stage2b-pilot-v1"
    schedule["schedule"]["campaign_id"] = "pb06-migration-stage2b-pilot-v1"
    schedule["schedule"]["arms"] = ["AB"]


def pilot_config(session=SESSION, arms=("AB",)):
    campaign = {"id": "pb06-migration-stage2b-pilot-v1"}
    if session is not None:
        campaign["session_id"] = session
    return {"schema": 1, "campaign": campaign, "schedule": {"id": "stage2b-pilot-v1"}, "pilot": {"arms": list(arms)}}


C.write_toml(TMP / "held-pilot-config.toml", pilot_config())


PILOT_FILE = TMP / "held-pilot-config.toml"


def add_pilot_config(base, source=None):
    """The configuration copy that `pilot` stores in a base (tests that call `execute` directly add it)."""
    shutil.copyfile(source or PILOT_FILE, Path(base) / "pilot-config.toml")


def call_main(argv, hooks=None, facts=None, environ=None):
    out, err = io.StringIO(), io.StringIO()
    kwargs = {"environ": ENVIRON if environ is None else environ}
    if facts is not None:
        kwargs["facts"] = facts
    with contextlib.redirect_stdout(out), contextlib.redirect_stderr(err):
        code = C.main(argv, hooks=hooks, **kwargs)
    return code, out.getvalue(), err.getvalue()


# ------------------------------------------------------------------------------------------------- TOML

class TomlTests(unittest.TestCase):
    def roundtrip(self, data):
        text = C.toml_dumps(data)
        self.assertEqual(tomllib.loads(text), data, text)
        self.assertEqual(text, C.toml_dumps(copy.deepcopy(data)), "deterministic")
        return text

    def test_scalars_strings_and_keys(self):
        self.roundtrip({"a": 1, "b": True, "c": False, "d": 0.5, "e": -3, "f": "text",
                        "quote": 'say "hi" \\ done', "newline": "a\nb\tc\r", "unicode": "λ Λ ü",
                        "control": "x\x01y\x7fz\x08\x0c", "empty": "", "1.10": "dotted key", "k with space": 1})

    def test_tables_arrays_and_arrays_of_tables(self):
        text = self.roundtrip({
            "schema": 1, "list": [1, 2, 3], "strings": ["a", "b"], "empty": [], "nested": [[1, 2], [3]],
            "table": {"x": 1, "sub": {"y": "z", "deep": {"w": [1]}}}, "empty_table": {},
            "machine": {"cpu": {"1.10": "goldmont", "1.13": "raptorlake"}},
            "rows": [{"name": "a", "n": 1}, {"name": "b", "tags": ["p"], "inner": {"k": 2}}],
            "only_tables": {"one": {"a": 1}, "two": {"b": 2}}})
        self.assertLess(text.index("schema"), text.index("[table]"), "scalars come before tables")

    def test_non_finite_floats_and_foreign_types_are_refused(self):
        for value in (float("nan"), float("inf"), object(), None, datetime.date(2026, 1, 1)):
            with self.assertRaises((ValueError, TypeError)):
                C.toml_dumps({"v": value})

    def test_identity_declared_and_schedule_documents_round_trip(self):
        for path in (HERE / "schedule.toml", HERE / "case-mapping.toml"):
            data = tomllib.loads(path.read_text(encoding="utf-8"))
            self.assertEqual(tomllib.loads(C.toml_dumps(data)), data, path.name)

    def test_write_toml_is_exclusive_and_verified(self):
        path = fresh() / "x.toml"
        C.write_toml(path, {"schema": 1})
        with self.assertRaises(FileExistsError):
            C.write_toml(path, {"schema": 2})
        self.assertEqual(tomllib.loads(path.read_text()), {"schema": 1})


# ------------------------------------------------------------------------------------------- fingerprints

def git_available(commit):
    return subprocess.run(["git", "-C", str(REPO), "cat-file", "-e", f"{commit}^{{commit}}"],
                          capture_output=True).returncode == 0


def extract_commit(commit, dest):
    """The files a fingerprint reads, at `commit`, into `dest` (git archive; no network)."""
    import tarfile
    data = subprocess.run(["git", "-C", str(REPO), "archive", "--format=tar", commit], capture_output=True,
                          check=True).stdout
    with tarfile.open(fileobj=io.BytesIO(data)) as archive:
        members = [m for m in archive.getmembers() if m.isfile() and (
            m.name == "Project.toml" or m.name.startswith(("src/", "ext/")) or
            (m.name.startswith("benchmark/") and m.name.count("/") == 1 and m.name.endswith(".jl")))]
        for member in members:
            target = Path(dest) / member.name
            target.parent.mkdir(parents=True, exist_ok=True)
            target.write_bytes(archive.extractfile(member).read())


class FingerprintTests(unittest.TestCase):
    def test_known_values_of_the_working_tree(self):
        self.assertEqual(C.harness_hash(REPO / "benchmark"), "0fd2b44dfea0b1f77c2c67228bf149207982ab8b")
        self.assertEqual(C.package_fingerprint(REPO), "f37fc61f300ad597a33c7ab5f448d38c865db854")

    @unittest.skipUnless(git_available(BASE_COMMIT), "the base commit is not in this clone")
    def test_known_values_at_the_base_commit(self):
        where = fresh("base-commit")
        extract_commit(BASE_COMMIT, where)
        self.assertEqual(C.harness_hash(where / "benchmark"), "0fd2b44dfea0b1f77c2c67228bf149207982ab8b")
        self.assertEqual(C.package_fingerprint(where), "f37fc61f300ad597a33c7ab5f448d38c865db854")

    @unittest.skipUnless(git_available(STACK_A_COMMIT), "the Stack A commit is not in this clone")
    def test_known_values_at_the_stack_a_commit(self):
        where = fresh("stack-a")
        extract_commit(STACK_A_COMMIT, where)
        self.assertEqual(C.harness_hash(where / "benchmark"), "b7bf3d953ec6e9f9720e74d7895b5cf95a629fd4")
        self.assertEqual(C.harness_hash(where / "benchmark"), mc.load_schedule(HERE / "schedule.toml")
                         ["stack_a"]["harness_hash"])
        self.assertEqual(C.package_fingerprint(where), mc.load_schedule(HERE / "schedule.toml")["stack_a"]
                         ["proximalsolvers"]["package_hash"])

    def test_the_rules_on_a_small_tree(self):
        root = fresh("pkg")
        (root / "src").mkdir()
        (root / "ext").mkdir()
        (root / "Project.toml").write_text("name = 'X'\n")
        (root / "src" / "b.jl").write_text("b")
        (root / "src" / "a.jl").write_text("a")
        (root / "src" / "notes.txt").write_text("ignored")
        (root / "ext" / "e.jl").write_text("e")
        first = C.package_fingerprint(root)
        (root / "src" / "notes.txt").write_text("still ignored")
        self.assertEqual(C.package_fingerprint(root), first)
        (root / "src" / "a.jl").write_text("A")
        self.assertNotEqual(C.package_fingerprint(root), first)
        (root / "src" / "a.jl").write_text("a")
        self.assertEqual(C.package_fingerprint(root), first)
        shutil.rmtree(root / "ext")
        self.assertNotEqual(C.package_fingerprint(root), first)
        digest = __import__("hashlib").sha1()
        for relative, content in (("Project.toml", b"name = 'X'\n"), ("src/a.jl", b"a"), ("src/b.jl", b"b")):
            digest.update(relative.encode() + b"\0" + content + b"\0")
        self.assertEqual(C.package_fingerprint(root), digest.hexdigest(), "sorted paths, NUL, bytes, NUL")

    def test_the_harness_needs_all_four_files(self):
        root = fresh("harness")
        for name in ("problems.jl", "certificates.jl", "cases.jl"):
            (root / name).write_text(name)
        with self.assertRaises(FileNotFoundError):
            C.harness_hash(root)
        (root / "run.jl").write_text("run")
        self.assertEqual(len(C.harness_hash(root)), 40)


# --------------------------------------------------------------------------------------- lock and gate

class LockTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.camp = F.build_campaign(fresh("lock"), "migration")
        cls.lock = make_lock(cls.camp)

    def test_a_valid_lock_round_trips_through_the_writer_and_the_loader(self):
        path = fresh() / "lock.toml"
        C.write_toml(path, self.lock)
        self.assertEqual(C.load_lock(path, strata=self.camp.jkeys), self.lock)

    def test_every_malformed_lock_is_refused_naming_the_field(self):
        def edited(function):
            lock = copy.deepcopy(self.lock)
            function(lock)
            return lock
        cases = {
            "schema": edited(lambda l: l.update(schema=2)),
            "stack_b.proximalsolvers.commit": edited(lambda l: l["stack_b"]["proximalsolvers"].update(commit="main")),
            "stack_b.proximalbase.tree": edited(lambda l: l["stack_b"]["proximalbase"].update(tree="ABC" * 13 + "A")),
            "stack_b.proximalsolvers.package_hash": edited(
                lambda l: l["stack_b"]["proximalsolvers"].update(package_hash="1234")),
            "stack_b.proximalsolvers.source": edited(lambda l: l["stack_b"]["proximalsolvers"].pop("source")),
            "stack_b.proximalbase.release": edited(lambda l: l["stack_b"]["proximalbase"].update(release="beta")),
            "stack_b.proximalbase.tag": edited(lambda l: l["stack_b"]["proximalbase"].update(release="registered")),
            "stack_b.harness_hash": edited(lambda l: l["stack_b"].update(harness_hash="x")),
            "stack_b.surplus": edited(lambda l: l["stack_b"].update(surplus=1)),
            "stack_b.environments": edited(lambda l: l["stack_b"]["environments"].pop("1.13")),
            "stack_b.environments.1.10.manifest": edited(
                lambda l: l["stack_b"]["environments"]["1.10"].update(manifest="/abs/Manifest.toml")),
            "stack_b.environments.1.10.manifest_sha256": edited(
                lambda l: l["stack_b"]["environments"]["1.10"].update(manifest_sha256="abc")),
            "declared[1].kind": edited(lambda l: l["declared"][0].update(kind="other")),
            "declared[1].reason": edited(lambda l: l["declared"][0].update(reason="")),
            "declared[1].change": edited(lambda l: l["declared"][0].update(change="moved")),
            "harness.port_commit": edited(lambda l: l["harness"].update(port_commit="main")),
            "harness.changed_lines": edited(lambda l: l["harness"].update(changed_lines=[])),
            "approvals.G3": edited(lambda l: l["approvals"].pop("G3")),
            "approvals.case_mapping": edited(lambda l: l["approvals"].update(case_mapping="x")),
            "campaign.session_id": edited(lambda l: l["campaign"].update(session_id="session-1")),
            "campaign.id": edited(lambda l: l["campaign"].update(id="")),
            "lock.moving": edited(lambda l: l.update(moving="ref")),
        }
        for field, lock in cases.items():
            with self.subTest(field=field):
                with self.assertRaises(C.LockRefusal) as caught:
                    C.parse_lock(lock, strata=self.camp.jkeys)
                self.assertEqual(caught.exception.field, field)
                self.assertIn(field, str(caught.exception))

    def test_a_lock_without_a_candidate_loads_and_is_not_official(self):
        lock = copy.deepcopy(self.lock)
        for key in ("stack_b", "declared", "harness", "approvals"):
            lock.pop(key)
        self.assertEqual(C.parse_lock(lock), lock)
        self.assertTrue(any(g.startswith("STACK_B") for g in C.official_gate(lock, facts_for(
            assemble_base(self.camp, fresh() / "b"), self.lock), FREEZE)))

    def test_an_unreadable_or_invalid_file_is_a_refusal(self):
        for text in ("not toml [", ""):
            path = fresh() / "lock.toml"
            path.write_text(text)
            with self.assertRaises(C.LockRefusal):
                C.load_lock(path)
        with self.assertRaises(C.LockRefusal):
            C.load_lock(fresh() / "missing.toml")


class GateTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.camp = F.build_campaign(fresh("gate"), "migration")
        cls.lock = make_lock(cls.camp)
        cls.base = assemble_base(cls.camp, fresh("gate-base") / "base")
        cls.facts = facts_for(cls.base, cls.lock)

    def codes(self, lock=None, facts=None, freeze=FREEZE):
        unmet = C.official_gate(lock or self.lock, facts or self.facts, freeze)
        return sorted({entry.split(":")[0] for entry in unmet})

    def test_the_synthetic_candidate_passes_the_gate(self):
        self.assertEqual(C.official_gate(self.lock, self.facts, FREEZE), [])

    def test_each_rule_is_reported(self):
        def lock_with(function):
            lock = copy.deepcopy(self.lock)
            function(lock)
            return lock

        def facts_with(function):
            facts = copy.deepcopy(self.facts)
            function(facts)
            return facts
        cases = [
            ("FREEZE_SHA", dict(freeze=None)), ("FREEZE_SHA", dict(freeze="main")),
            ("HEAD", dict(freeze="0" * 40)),
            ("HEAD", dict(facts=facts_with(lambda f: f.update(head="1" * 40)))),
            ("CLEAN", dict(facts=facts_with(lambda f: f.update(clean=False)))),
            ("LOCK_TRACKED", dict(facts=facts_with(lambda f: f.update(lock_tracked=False)))),
            ("STACK_B", dict(lock=lock_with(lambda l: l.pop("stack_b")))),
            ("PS_B_COMMIT", dict(lock=lock_with(lambda l: l["stack_b"]["proximalsolvers"].update(commit="main")))),
            ("PS_B_COMMIT", dict(lock=lock_with(lambda l: l["stack_b"]["proximalsolvers"].update(commit=None)))),
            ("PS_B_COMMIT", dict(lock=lock_with(lambda l: l["stack_b"]["proximalsolvers"].update(commit="abc123")))),
            ("PS_B_COMMIT", dict(facts=facts_with(lambda f: f["checkouts"]["ps_b"].update(commit="2" * 40)))),
            ("PS_B_TREE", dict(facts=facts_with(lambda f: f["checkouts"]["ps_b"].update(tree="2" * 40)))),
            ("PS_B_PACKAGE_HASH", dict(lock=lock_with(
                lambda l: l["stack_b"]["proximalsolvers"].update(package_hash="")))),
            ("PB_B_COMMIT", dict(facts=facts_with(lambda f: f["checkouts"].pop("pb_b")))),
            ("PB_B_TREE", dict(lock=lock_with(lambda l: l["stack_b"]["proximalbase"].update(tree="v0.6.0")))),
            ("PB_B_PACKAGE_HASH", dict(facts=facts_with(lambda f: f["checkouts"]["pb_b"].update(
                package_hash="3" * 40)))),
            ("HARNESS_HASH", dict(lock=lock_with(lambda l: l["stack_b"].update(harness_hash="")))),
            ("ENVIRONMENTS", dict(lock=lock_with(lambda l: l["stack_b"]["environments"].pop("1.13")))),
            ("MANIFEST_SHA256", dict(facts=facts_with(lambda f: f["manifest_sha256"].update({"1.10": "0" * 64})))),
            ("MANIFEST_SHA256", dict(facts=facts_with(lambda f: f["manifest_sha256"].pop("1.13")))),
            ("MAPPING", dict(facts=facts_with(lambda f: f["mapping_rows"].append(
                {"id": "x", "class": "C", "approved": False})))),
            ("MAPPING", dict(facts=facts_with(lambda f: next(r for r in f["mapping_rows"] if r["class"] == "B")
                                              .update(approved=False)))),
            ("MAPPING", dict(facts=facts_with(lambda f: f.update(mapping_rows=[])))),
            ("APPROVALS", dict(lock=lock_with(lambda l: l.pop("approvals")))),
            ("APPROVAL_G1", dict(lock=lock_with(lambda l: l["approvals"].update(G1="")))),
            ("APPROVAL_G8", dict(lock=lock_with(lambda l: l["approvals"].update(
                G8="https://github.com/other/repo/issues/1#issuecomment-2")))),
            ("APPROVAL_G4", dict(lock=lock_with(lambda l: l["approvals"].update(
                G4="https://github.com/mlakolar/ProximalSolvers.jl/issues/110")))),
            ("APPROVAL_CASE_MAPPING", dict(lock=lock_with(lambda l: l["approvals"].update(case_mapping=[])))),
            ("APPROVAL_CASE_MAPPING", dict(lock=lock_with(lambda l: l["approvals"].update(case_mapping=["x"])))),
        ]
        for code, kwargs in cases:
            with self.subTest(code=code, change=sorted(kwargs)):
                self.assertIn(code, self.codes(**kwargs))

    def test_the_gate_accepts_issue_and_pull_comment_urls_only(self):
        for url, ok in (("https://github.com/mlakolar/ProximalSolvers.jl/pull/221#issuecomment-1", True),
                        ("https://github.com/mlakolar/ProximalSolvers.jl/issues/110#issuecomment-6694764350", True),
                        ("http://github.com/mlakolar/ProximalSolvers.jl/issues/1#issuecomment-1", False),
                        ("https://github.com/mlakolar/ProximalSolvers.jl/issues/1#issuecomment-", False),
                        ("https://github.com/mlakolar/ProximalSolvers.jl/discussions/1#issuecomment-1", False)):
            lock = copy.deepcopy(self.lock)
            lock["approvals"]["G2"] = url
            self.assertEqual("APPROVAL_G2" not in self.codes(lock=lock), ok, url)

    def test_no_environment_variable_changes_the_gate(self):
        lock = copy.deepcopy(self.lock)
        lock["approvals"]["G5"] = ""
        with unittest.mock.patch.dict(os.environ, {"STAGE2B_OFFICIAL": "1", "APPROVED": "true", "CI": "1"}):
            self.assertIn("APPROVAL_G5", self.codes(lock=lock))

    def run_cli(self, lock, facts, freeze=FREEZE, extra=()):
        directory = fresh("gate-cli")
        path = directory / "lock.toml"
        C.write_toml(path, lock)
        argv = ["run", "--config", str(path), "--base", str(directory / "base"), "--official", *extra]
        if freeze is not None:
            argv += ["--freeze-sha", freeze]
        return call_main(argv, hooks=hooks_that_never_run(), facts=lambda *a: facts)

    def test_every_refusal_stops_the_command_before_any_process(self):
        def lock_with(function):
            lock = copy.deepcopy(self.lock)
            function(lock)
            return lock

        def facts_with(function):
            facts = copy.deepcopy(self.facts)
            function(facts)
            return facts
        controls = {
            "no freeze sha": dict(lock=self.lock, facts=self.facts, freeze=None),
            "head differs": dict(lock=self.lock, facts=facts_with(lambda f: f.update(head="1" * 40))),
            "dirty": dict(lock=self.lock, facts=facts_with(lambda f: f.update(clean=False))),
            "no candidate": dict(lock=lock_with(lambda l: l.pop("stack_b")), facts=self.facts),
            "missing migrated commit": dict(lock=lock_with(
                lambda l: l["stack_b"]["proximalsolvers"].pop("commit")), facts=self.facts),
            "branch name": dict(lock=lock_with(lambda l: l["stack_b"]["proximalsolvers"].update(commit="master")),
                                facts=self.facts),
            "lock not tracked": dict(lock=self.lock, facts=facts_with(lambda f: f.update(lock_tracked=False))),
            "missing approvals": dict(lock=lock_with(lambda l: l["approvals"].update(G6="")), facts=self.facts),
            "no approvals table": dict(lock=lock_with(lambda l: l.pop("approvals")), facts=self.facts),
            "unapproved mapping": dict(lock=self.lock, facts=facts_with(
                lambda f: f["mapping_rows"].append({"id": "x", "class": "D", "approved": False}))),
        }
        for name, control in controls.items():
            with self.subTest(name):
                code, out, err = self.run_cli(**control)
                self.assertEqual(code, 2, err)
                self.assertIn("REFUSED", err)
                self.assertEqual(out, "")

    def test_run_without_official_is_a_usage_error_and_launches_nothing(self):
        directory = fresh("gate-usage")
        C.write_toml(directory / "lock.toml", self.lock)
        code, _, err = call_main(["run", "--config", str(directory / "lock.toml"), "--base", str(directory / "b"),
                                  "--freeze-sha", FREEZE], hooks=hooks_that_never_run(),
                                 facts=lambda *a: self.facts)
        self.assertEqual(code, 3)
        self.assertIn("--official", err)
        self.assertFalse((directory / "b").exists())

    def test_a_passing_gate_builds_the_real_hooks_and_stops_before_any_process_without_the_lock_copy(self):
        directory = fresh("gate-ok")
        C.write_toml(directory / "lock.toml", self.lock)
        calls = []
        with unittest.mock.patch.object(C.subprocess, "run", lambda *a, **k: calls.append(a)):
            code, _, err = call_main(["run", "--config", str(directory / "lock.toml"), "--base",
                                      str(directory / "b"), "--official", "--freeze-sha", FREEZE,
                                      "--julia", "1.10=/opt/julia-1.10.13/bin/julia",
                                      "--julia", "1.13=/opt/julia-1.13.3/bin/julia"], facts=lambda *a: self.facts)
        self.assertEqual(code, 2, err)
        self.assertIn("lock.toml of the base", err)
        self.assertEqual(calls, [])
        self.assertFalse((directory / "b").exists())

    def test_the_official_gate_stops_the_real_hooks_before_the_runner(self):
        directory = fresh("gate-real")
        lock = copy.deepcopy(self.lock)
        lock["approvals"]["G3"] = ""
        C.write_toml(directory / "lock.toml", lock)
        calls = []
        with unittest.mock.patch.object(C.subprocess, "run", lambda *a, **k: calls.append(a)):
            code, _, err = call_main(["run", "--config", str(directory / "lock.toml"), "--base",
                                      str(directory / "b"), "--official", "--freeze-sha", FREEZE,
                                      "--julia", "1.10=/opt/julia-1.10.13/bin/julia",
                                      "--julia", "1.13=/opt/julia-1.13.3/bin/julia"], facts=lambda *a: self.facts)
        self.assertEqual((code, calls), (2, []))
        self.assertIn("APPROVAL_G3", err)

    def test_the_real_collector_reads_git_and_the_base(self):
        repo = fresh("repo")
        env = {"GIT_AUTHOR_NAME": "t", "GIT_AUTHOR_EMAIL": "t@x", "GIT_COMMITTER_NAME": "t",
               "GIT_COMMITTER_EMAIL": "t@x", "PATH": os.environ["PATH"], "HOME": str(repo)}

        def git(*args, cwd=repo):
            subprocess.run(["git", "-C", str(cwd), *args], check=True, capture_output=True, env=env)
        git("init", "-q")
        (repo / "lock.toml").write_text("schema = 1\n")
        (repo / ".gitignore").write_text("ignored.txt\n")
        git("add", "lock.toml", ".gitignore")
        git("commit", "-q", "-m", "x")
        base = assemble_base(self.camp, fresh("collect") / "base")
        for directory, name in (("ProximalSolvers.jl", "ps"), ("ProximalBase.jl", "pb")):
            checkout = base / "installations" / "ab-b" / directory
            checkout.mkdir(parents=True)
            (checkout / "Project.toml").write_text(f"name = '{name}'\n")
            git("init", "-q", cwd=checkout)
            git("add", "Project.toml", cwd=checkout)
            git("commit", "-q", "-m", "x", cwd=checkout)
        facts = C.collect_repo_facts(repo, repo / "lock.toml", base, HERE / "schedule.toml",
                                     HERE / "case-mapping.toml", run=lambda argv, **kw: subprocess.run(
                                         argv, env=env, **kw))
        self.assertTrue(facts["clean"] and facts["lock_tracked"])
        self.assertEqual(len(facts["head"]), 40)
        self.assertEqual(set(facts["checkouts"]), {"ps_b", "pb_b"})
        self.assertEqual(facts["checkouts"]["ps_b"]["commit"], subprocess.run(
            ["git", "-C", str(base / "installations/ab-b/ProximalSolvers.jl"), "rev-parse", "HEAD"],
            capture_output=True, text=True, env=env).stdout.strip())
        self.assertEqual(set(facts["manifest_sha256"]), {"1.10", "1.13"})
        (repo / "untracked.txt").write_text("x")
        self.assertFalse(C.collect_repo_facts(repo, repo / "lock.toml", base, HERE / "schedule.toml",
                                              HERE / "case-mapping.toml", run=lambda argv, **kw: subprocess.run(
                                                  argv, env=env, **kw))["clean"])
        (repo / "untracked.txt").unlink()
        (repo / "ignored.txt").write_text("x")
        self.assertFalse(C.git_clean(repo, run=lambda argv, **kw: subprocess.run(argv, env=env, **kw)),
                         "an ignored file makes the checkout not clean")
        (repo / "ignored.txt").unlink()
        (repo / "lock.toml").write_text("schema = 2\n")
        self.assertFalse(C.git_clean(repo, run=lambda argv, **kw: subprocess.run(argv, env=env, **kw)))
        outside = fresh() / "lock.toml"
        outside.write_text("x")
        (repo / "lock.toml").write_text("schema = 1\n")
        self.assertFalse(C.collect_repo_facts(repo, outside, base, HERE / "schedule.toml", HERE / "case-mapping.toml",
                                              run=lambda argv, **kw: subprocess.run(argv, env=env, **kw))
                         ["lock_tracked"])


class PilotTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.official = mc.load_schedule(HERE / "schedule.toml")
        cls.camp = F.build_campaign(fresh("pilot"), "identical", reps=1, schedule_edit=pilot_edit)

    def config_with(self, function):
        config = pilot_config()
        function(config)
        return config

    def test_a_valid_pilot_configuration(self):
        self.assertEqual(C.parse_pilot(pilot_config(), self.official), pilot_config())

    def test_every_pilot_refusal(self):
        cases = {
            "official campaign id": self.config_with(lambda c: c["campaign"].update(id=self.official["campaign_id"])),
            "official schedule id": self.config_with(lambda c: c["schedule"].update(id=self.official["id"])),
            "campaign id without -pilot": self.config_with(lambda c: c["campaign"].update(id="other-v1")),
            "schedule id without -pilot": self.config_with(lambda c: c["schedule"].update(id="other-v1")),
            "stack_b table": self.config_with(lambda c: c.update(stack_b={"proximalsolvers": {}})),
            "unknown key": self.config_with(lambda c: c.update(extra=1)),
            "bad arms": self.config_with(lambda c: c["pilot"].update(arms=["XY"])),
            "empty arms": self.config_with(lambda c: c["pilot"].update(arms=[])),
        }
        for name, config in cases.items():
            with self.subTest(name):
                with self.assertRaises(C.LockRefusal):
                    C.parse_pilot(config, self.official)

    def test_base_directory_and_schedule_copy_refusals(self):
        base = assemble_base(self.camp, fresh("pilot-base") / "plain-base", aa=False)
        with self.assertRaises(C.LockRefusal) as caught:
            C.plan_from_pilot(pilot_config(), base, JULIA_BINS, ENVIRON)
        self.assertEqual(caught.exception.field, "base")
        pilot = assemble_base(self.camp, fresh("pilot-base") / "x-pilot", aa=False)
        plan = C.plan_from_pilot(pilot_config(), pilot, JULIA_BINS, ENVIRON)
        self.assertFalse(plan.official)
        self.assertEqual(plan.arms, ("AB",))
        self.assertEqual(sorted(plan.roles), ["ab-a", "ab-b"])
        self.assertEqual(plan.roles["ab-b"].expected["ps"]["commit"], self.official["stack_a"]["proximalsolvers"]
                         ["commit"], "the pilot's stack B is a second installation of stack A")
        for edit, field in ((lambda s: s["schedule"].update(id=self.official["id"]), "schedule.id"),
                            (lambda s: s["schedule"].update(campaign_id=self.official["campaign_id"]), "campaign.id")):
            copy_base = assemble_base(self.camp, fresh("pilot-base") / "y-pilot", aa=False)
            schedule = tomllib.loads((copy_base / "schedule.toml").read_text())
            edit(schedule)
            (copy_base / "schedule.toml").write_text(C.toml_dumps(schedule))
            with self.assertRaises(C.LockRefusal) as caught:
                C.plan_from_pilot(pilot_config(), copy_base, JULIA_BINS, ENVIRON)
            self.assertEqual(caught.exception.field, field)

    def test_cli_refusals_never_start_a_process(self):
        directory = fresh("pilot-cli")
        refusals = {
            "official campaign id": pilot_config(), "no pilot in base name": pilot_config(),
        }
        refusals["official campaign id"]["campaign"]["id"] = self.official["campaign_id"]
        for name, config in refusals.items():
            path = directory / f"{name.replace(' ', '-')}.toml"
            C.write_toml(path, config)
            base = directory / ("work-pilot" if name != "no pilot in base name" else "work")
            code, _, err = call_main(["pilot", "--config", str(path), "--base", str(base)],
                                     hooks=hooks_that_never_run())
            self.assertEqual(code, 2, (name, err))
            self.assertFalse(base.exists())

    def test_a_valid_pilot_without_hooks_builds_the_real_ones_and_probes_first(self):
        base = assemble_base(self.camp, fresh("pilot-real") / "x-pilot", aa=False)
        directory = fresh("pilot-ok")
        C.write_toml(directory / "p.toml", pilot_config())
        calls = []

        def scripted(argv, **kwargs):
            calls.append((list(argv), kwargs))
            return subprocess.CompletedProcess(argv, 1, b"", b"no julia here")
        with unittest.mock.patch.object(C.subprocess, "run", scripted), unittest.mock.patch(
                "os.sched_getaffinity", return_value={1, 2, 6}), unittest.mock.patch("os.sched_setaffinity") as setter:
            code, _, err = call_main(["pilot", "--config", str(directory / "p.toml"), "--base", str(base),
                                      "--julia", "1.10=/opt/julia-1.10.13/bin/julia",
                                      "--julia", "1.13=/opt/julia-1.13.3/bin/julia"])
        self.assertEqual(code, 2, err)
        self.assertIn("environment probe", err)
        argv, kwargs = calls[0]
        self.assertEqual(argv[:4], ["taskset", "-c", "6", "/opt/julia-1.10.13/bin/julia"])
        self.assertEqual(argv[4:6], list(C.JULIA_FLAGS))
        self.assertTrue(argv[-1].endswith("environment_probe.jl"))
        self.assertIs(kwargs["shell"], False)
        setter.assert_called_once_with(0, {1, 2})
        self.assertEqual(len(calls), 1, "nothing is launched after a failed probe")
        self.assertFalse((base / "receipt.jsonl").exists())

    def test_the_environment_never_changes_the_mode(self):
        directory = fresh("pilot-env")
        config = pilot_config()
        config["campaign"]["id"] = self.official["campaign_id"]
        C.write_toml(directory / "p.toml", config)
        environ = dict(ENVIRON, STAGE2B_OFFICIAL="1", OFFICIAL="true", FREEZE_SHA=FREEZE)
        with unittest.mock.patch.dict(os.environ, environ):
            code, _, _ = call_main(["pilot", "--config", str(directory / "p.toml"),
                                    "--base", str(directory / "x-pilot")], hooks=hooks_that_never_run(),
                                   environ=environ)
        self.assertEqual(code, 2)


# --------------------------------------------------------------------------------------------- preflight

class PreflightTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.camp = F.build_campaign(fresh("pre"), "migration")
        cls.lock = make_lock(cls.camp)
        cls.base = assemble_base(cls.camp, fresh("pre-base") / "base")
        cls.plan = official_plan(cls.base, cls.lock)

    def observations(self):
        return {(role, mm): good_obs(self.plan.roles[role], mm, self.plan.sched, self.base)
                for role in self.plan.role_names() for mm in self.plan.sched["strata"]}

    def problems(self, edit=None, plan=None):
        obs = self.observations()
        if edit:
            edit(obs)
        return C.preflight_checks(plan or self.plan, obs)

    def codes(self, *args, **kwargs):
        return sorted({p.split(":")[0] for p in self.problems(*args, **kwargs)})

    def test_consistent_observations_have_no_problems(self):
        self.assertEqual(self.problems(), [])

    def test_each_defect_is_a_problem(self):
        def set_(role, mm, path, value):
            def edit(obs):
                target = obs[(role, mm)]
                *parents, last = path.split(".")
                for part in parents:
                    target = target[part]
                target[last] = value
            return edit
        cases = [
            ("JULIA_VERSION", set_("ab-a", "1.10", "julia.version", "1.10.12")),
            ("JULIA_VERSION", set_("ab-b", "1.13", "julia.version", "1.13.2")),
            ("JULIA_COMMIT", set_("ab-a", "1.13", "julia.commit", "0" * 40)),
            ("PS_VERSION", set_("ab-b", "1.10", "ps.version", "0.3.1")),
            ("PB_VERSION", set_("ab-b", "1.10", "pb.version", "0.5.4")),
            ("PS_COMMIT", set_("ab-a", "1.10", "ps.commit", "1" * 40)),
            ("PS_TREE", set_("ab-a", "1.10", "ps.tree", "1" * 40)),
            ("DIRTY", set_("ab-a", "1.10", "ps.dirty", True)),
            ("PB_TREE", set_("ab-b", "1.10", "pb.loaded_tree", "2" * 40)),
            ("PB_TREE", set_("ab-b", "1.10", "pb.manifest_tree", "2" * 40)),
            ("PS_PATH", set_("aa-a", "1.13", "ps.loaded_realpath", "/real/elsewhere/ProximalSolvers.jl")),
            ("MANIFEST_SHA256", set_("ab-b", "1.10", "manifest_sha256", "0" * 64)),
            ("ENV_MISSING", set_("aa-b", "1.10", "environment.manifest_exists", False)),
            ("ENV_MISSING", set_("aa-b", "1.10", "environment.project_exists", False)),
            ("AFFINITY", set_("ab-a", "1.10", "affinity_cpus", [6, 7])),
            ("AFFINITY", set_("ab-a", "1.10", "affinity_cpus", [3])),
            ("HARNESS_HASH", set_("ab-a", "1.10", "harness_hash", "9" * 40)),
            ("PACKAGE_HASH", set_("ab-a", "1.10", "ps.package_hash", "9" * 40)),
            ("PACKAGE_HASH", set_("aa-b", "1.13", "pb.package_hash", "8" * 40)),
            ("PACKAGE_HASH", set_("ab-b", "1.10", "pb.package_hash", "9" * 40)),
            ("MACHINE", set_("ab-a", "1.10", "machine.cpu_model", "Other CPU")),
            ("MACHINE", set_("ab-a", "1.13", "machine.cpu", "goldmont")),
            ("MACHINE", set_("ab-a", "1.13", "machine.logical_cpu", 2)),
            ("SHARED", set_("ab-b", "1.10", "depot_realpath", "/real/ab-a/depot")),
            ("SHARED", set_("ab-b", "1.10", "checkout_realpath", "/real/ab-a/ProximalSolvers.jl")),
            ("SHARED", set_("aa-b", "1.13", "environment.realpath", "/real/aa-a/env-1.13")),
            ("OBSERVATION", set_("ab-a", "1.10", "julia", {})),
        ]
        for code, edit in cases:
            with self.subTest(code=code):
                self.assertIn(code, self.codes(edit))

    def test_a_shared_literal_depot_checkout_or_environment_is_a_problem(self):
        plan = copy.deepcopy(self.plan)
        plan.roles["ab-b"].depot = plan.roles["ab-a"].depot
        self.assertIn("SHARED", self.codes(plan=plan))
        plan = copy.deepcopy(self.plan)
        plan.roles["ab-b"].checkout = Path(str(plan.roles["ab-a"].checkout) + "/./")
        self.assertIn("SHARED", self.codes(plan=plan))
        plan = copy.deepcopy(self.plan)
        plan.roles["aa-a"].environments["1.10"] = plan.roles["ab-a"].environments["1.10"]
        obs = self.observations()
        obs[("aa-a", "1.10")]["environment"]["dir"] = obs[("ab-a", "1.10")]["environment"]["dir"]
        self.assertIn("SHARED", sorted({p.split(":")[0] for p in C.preflight_checks(plan, obs)}))
        plan = copy.deepcopy(self.plan)
        plan.roles["ab-b"].installation = plan.roles["ab-a"].installation
        self.assertIn("SHARED", self.codes(plan=plan))

    def test_the_case_filter_must_be_the_schedules_byte_for_byte(self):
        for changed in (self.plan.case_filter + "\n", self.plan.case_filter + ",", self.plan.case_filter.upper(),
                        ",".join(reversed(self.plan.case_filter.split(","))), self.plan.case_filter.replace(",", ", ")):
            plan = copy.deepcopy(self.plan)
            plan.case_filter = changed
            self.assertIn("CASE_FILTER", self.codes(plan=plan))

    def test_every_problem_is_reported_not_only_the_first(self):
        def edit(obs):
            obs[("ab-a", "1.10")]["julia"]["version"] = "1.10.12"
            obs[("ab-a", "1.10")]["ps"]["dirty"] = True
            obs[("ab-b", "1.13")]["affinity_cpus"] = [1]
            obs[("aa-a", "1.10")]["harness_hash"] = "0" * 40
        problems = self.problems(edit)
        self.assertGreaterEqual(len(problems), 4)
        self.assertEqual({p.split(":")[0] for p in problems}, {"JULIA_VERSION", "DIRTY", "AFFINITY", "HARNESS_HASH"})

    def test_policy_values_are_labelled_not_refused(self):
        obs = self.observations()
        obs[("ab-a", "1.10")]["machine"]["governor"] = "performance"
        self.assertEqual(C.preflight_checks(self.plan, obs), [])

    def test_the_engine_launches_nothing_while_a_problem_remains(self):
        host = Host(self.camp, self.plan.sched, self.base)
        host.obs_edits.append(lambda role, mm, obs: obs.update(harness_hash="0" * 40) if role == "ab-b" else None)
        with self.assertRaises(C.Refused) as caught:
            C.execute(self.plan, host.hooks())
        self.assertTrue(any(p.startswith("HARNESS_HASH") for p in caught.exception.problems))
        self.assertEqual(host.calls, [])
        self.assertFalse((self.base / "receipt.jsonl").exists())
        self.assertFalse((self.base / "logs").exists())


# ----------------------------------------------------------------------------------------------- writers

class WriterTests(unittest.TestCase):
    PS = {"commit": "a" * 40, "tree": "b" * 40, "version": "0.3.2"}
    PB = {"commit": "c" * 40, "tree": "d" * 40, "version": "0.6.0", "release": "development"}

    def test_the_session_id_has_the_documented_shape_and_is_never_reused(self):
        moment = datetime.datetime(2026, 12, 1, 8, 30, 5, tzinfo=datetime.timezone.utc)
        first = C.mint_session_id(moment)
        self.assertRegex(first, r"session-20261201T083005Z-[0-9a-f]{4}")
        seen = {first}
        for _ in range(50):
            seen.add(C.mint_session_id(moment, used=seen))
        self.assertEqual(len(seen), 51)

    def test_identity_exact_keys_validation_and_exclusive_create(self):
        base = fresh("identity")
        path = C.write_identity(base, "ab-b", "inst-b1", "camp", SESSION, self.PS, self.PB)
        data = tomllib.loads(path.read_text())
        self.assertEqual(set(data), {"schema", "installation", "campaign_id", "session_id", "proximalsolvers",
                                     "proximalbase"})
        self.assertEqual(data["proximalbase"], self.PB)
        ok = {"commit": "a" * 40, "tree": "b" * 40, "version": "0.3.2"}
        bad = [
            dict(installation="has space"), dict(installation=""), dict(installation="a/b"),
            dict(ps=dict(ok, commit="master")), dict(ps=dict(ok, tree="abc")), dict(ps={"commit": "a" * 40}),
            dict(pb=dict(self.PB, release="stable")), dict(pb=dict(self.PB, release="registered")),
            dict(pb=dict(self.PB, extra="x")), dict(session=""), dict(role="ab-c"),
        ]
        for change in bad:
            with self.subTest(change=change):
                args = dict(role="aa-a", installation="inst-1", session=SESSION, ps=self.PS, pb=self.PB)
                args.update(change)
                with self.assertRaises(ValueError):
                    C.write_identity(fresh("identity"), args["role"], args["installation"], "camp", args["session"],
                                     args["ps"], args["pb"])
        with self.assertRaises(FileExistsError):
            C.write_identity(base, "ab-b", "inst-b2", "camp", SESSION, self.PS, self.PB)
        registered = C.write_identity(base, "aa-b", "inst.b_2-x", "camp", SESSION, self.PS,
                                      dict(self.PB, release="registered", tag="v0.6.0"))
        self.assertEqual(tomllib.loads(registered.read_text())["proximalbase"]["tag"], "v0.6.0")

    MACHINE = {"cpu_model": "M", "cpu": "raptorlake", "logical_cpu": 6, "governor": "powersave",
               "epp": "balance_performance", "no_turbo": "0", "smt_control": "on"}

    def moments(self):
        start = datetime.datetime(2026, 12, 1, 9, 0, 0, 123000, tzinfo=datetime.timezone.utc)
        return start, start + datetime.timedelta(seconds=16.5)

    def test_the_receipt_is_exclusive_ordered_exact_and_utc_with_milliseconds(self):
        path = fresh("receipt") / "receipt.jsonl"
        receipt = C.Receipt(path)
        with self.assertRaises(FileExistsError):
            C.Receipt(path)
        start, end = self.moments()
        with self.assertRaises(RuntimeError):
            receipt.process("AB", "A", "1.10.13", 1, "inst-a1", start, end, 0, True, self.MACHINE)
        receipt.campaign("camp", SESSION, "sched", start)
        with self.assertRaises(RuntimeError):
            receipt.campaign("camp", SESSION, "sched", start)
        receipt.process("AB", "A", "1.10.13", 1, "inst-a1", start, end, 0, True, self.MACHINE)
        receipt.process("AB", "B", "1.10.13", 1, "inst-b1", start + datetime.timedelta(seconds=30),
                        end + datetime.timedelta(seconds=30), 3, False, self.MACHINE)
        events = C.read_jsonl(path)
        self.assertEqual([e["event"] for e in events], ["campaign", "process", "process"])
        self.assertEqual(tuple(events[0]), C.CAMPAIGN_KEYS)
        self.assertEqual(tuple(events[1]), C.PROCESS_KEYS)
        self.assertEqual(events[1]["start_utc"], "2026-12-01T09:00:00.123+00:00")
        self.assertEqual(events[1]["end_utc"], "2026-12-01T09:00:16.623+00:00")
        self.assertEqual((events[2]["exit"], events[2]["complete"]), (3, False), "a failed process is recorded")
        self.assertEqual(events[1]["block"], events[1]["rep"])
        for text in (events[0]["utc"], events[1]["start_utc"], events[1]["end_utc"]):
            self.assertRegex(text, C.TIME_TEXT.pattern)

    def test_the_receipt_rejects_wrong_values_and_records_a_collision_unchanged(self):
        receipt = C.Receipt(fresh("receipt") / "r.jsonl")
        start, end = self.moments()
        receipt.campaign("camp", SESSION, "sched", start)
        bad = [dict(arm="XX"), dict(role="C"), dict(exit=True), dict(exit="0"), dict(complete=1), dict(rep=True),
               dict(machine=dict(self.MACHINE, extra=1)), dict(machine={k: v for k, v in self.MACHINE.items()
                                                                        if k != "epp"}),
               dict(machine=dict(self.MACHINE, logical_cpu="6")), dict(start=datetime.datetime(2026, 1, 1))]
        for change in bad:
            args = dict(arm="AB", role="A", julia="1.10.13", rep=1, installation="i", start=start, end=end,
                        exit=0, complete=True, machine=self.MACHINE)
            args.update(change)
            with self.subTest(change=change):
                with self.assertRaises((ValueError, TypeError)):
                    receipt.process(**args)
        receipt.process("AB", "A", "1.10.13", 1, "i", start, start, 0, True, self.MACHINE)
        last = C.read_jsonl(receipt.path)[-1]
        self.assertEqual(last["start_utc"], last["end_utc"], "the readings are recorded as they were taken")

    def test_the_machine_sampler_records_unavailable_files(self):
        root = fresh("sysfs")
        self.assertEqual(C.sample_machine(6, root), {"cpu_model": "unavailable", "governor": "unavailable",
                                                      "epp": "unavailable", "no_turbo": "unavailable",
                                                      "smt_control": "unavailable"})
        (root / "proc").mkdir()
        (root / "proc/cpuinfo").write_text("processor\t: 0\nmodel name\t: Test CPU @ 1GHz\n")
        freq = root / "sys/devices/system/cpu/cpu6/cpufreq"
        freq.mkdir(parents=True)
        (freq / "scaling_governor").write_text("powersave\n")
        (root / "sys/devices/system/cpu/smt").mkdir(parents=True)
        (root / "sys/devices/system/cpu/smt/control").write_text("on\n")
        sample = C.sample_machine(6, root)
        self.assertEqual((sample["cpu_model"], sample["governor"], sample["smt_control"], sample["epp"],
                          sample["no_turbo"]), ("Test CPU @ 1GHz", "powersave", "on", "unavailable",
                                                "unavailable"))
        record = C.machine_record(sample, "raptorlake", 6)
        self.assertEqual(tuple(record), C.MACHINE_KEYS)
        self.assertEqual(record["cpu"], "raptorlake")
        with self.assertRaises(ValueError):
            C.machine_record({"cpu_model": "x"}, "c", 6)

    def test_evidence_paths_exclude_private_directories_and_the_listings(self):
        base = fresh("evidence")
        for name in ("roots/ab-a/x.txt", "logs/a.log", "receipt.jsonl", "installations/ab-a/big.bin",
                     "environments/ab-a/e", "depots/ab-a/d", "checksums.sha256", "verification.json",
                     "comparison/report.md"):
            (base / name).parent.mkdir(parents=True, exist_ok=True)
            (base / name).write_text(name)
        self.assertEqual(C.evidence_paths(base), ["comparison/report.md", "logs/a.log", "receipt.jsonl",
                                                  "roots/ab-a/x.txt"])
        C.write_checksums(base)
        self.assertEqual(sorted(C.read_checksums(base / "checksums.sha256")), C.evidence_paths(base))
        C.write_checksums(base)                                   # a second write replaces the read-only listing

    def test_roles_and_the_layout_constants(self):
        self.assertEqual(C.ROLE_LABEL, {"ab-a": "a", "ab-b": "b", "aa-a": "aa_a", "aa-b": "aa_b"})
        self.assertEqual(C.ARM_ROLES, {"AB": {"A": "ab-a", "B": "ab-b"}, "AA": {"A": "aa-a", "B": "aa-b"}})


class DeclaredDifferencesTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.camp = F.build_campaign(fresh("decl"), "migration")
        cls.lock = make_lock(cls.camp)
        cls.base = assemble_base(cls.camp, fresh("decl-base") / "base", with_raw=True)
        cls.expected = F.declared_differences(cls.camp)

    def refusal(self, lock, base=None):
        with self.assertRaises(C.DeclaredRefusal) as caught:
            C.declared_differences(base or self.base, lock)
        return " | ".join(caught.exception.problems) + str(caught.exception)

    def test_the_observed_differences_with_the_locks_reasons_equal_the_fixtures_declaration(self):
        declared = C.declared_differences(self.base, self.lock)
        self.assertEqual(declared["proximalsolvers"], self.expected["proximalsolvers"])
        self.assertEqual(declared["proximalbase"], self.expected["proximalbase"])
        self.assertEqual([r["name"] for r in declared["manifest"]], [r["name"] for r in self.expected["manifest"]])
        self.assertEqual(declared["manifest"][0]["reason"], "synthetic reason", "the reason is the lock's")
        self.assertEqual(declared["compat"][0]["reason"], "synthetic compat reason")
        self.assertEqual(declared["harness"], self.expected["harness"])
        path = C.write_declared_differences(self.base, self.lock) and self.base / "declared-differences.toml"
        self.assertEqual(tomllib.loads(path.read_text())["harness"]["port_commit"], self.lock["harness"]["port_commit"])
        path.unlink()

    def test_a_missing_reason_is_a_refusal_never_invented(self):
        lock = copy.deepcopy(self.lock)
        lock["declared"] = [e for e in lock["declared"] if e["kind"] != "manifest"]
        self.assertIn("observed, but the lock has no reason", self.refusal(lock))
        lock = copy.deepcopy(self.lock)
        lock["declared"] = [e for e in lock["declared"] if e["kind"] != "compat"]
        self.assertIn("compat ProximalBase", self.refusal(lock))
        lock = copy.deepcopy(self.lock)
        del lock["harness"]
        self.assertIn("no [harness]", self.refusal(lock))

    def test_a_declared_difference_that_is_not_observed_is_a_refusal(self):
        lock = copy.deepcopy(self.lock)
        lock["declared"].append({"kind": "manifest", "name": "Nothing", "uuid": "u", "change": "changed",
                                 "reason": "r", "approval_url": URL})
        self.assertIn("declared in the lock but not observed", self.refusal(lock))
        lock = copy.deepcopy(self.lock)
        lock["declared"].append({"kind": "compat", "name": "Absent", "reason": "r", "approval_url": URL})
        self.assertIn("Absent", self.refusal(lock))
        lock = copy.deepcopy(self.lock)
        lock["declared"][0]["julia"] = ["1.10"]
        lock["declared"].append(dict(lock["declared"][0], julia=["1.13"]))
        C.declared_differences(self.base, lock)                    # a split per stratum is fine
        lock["declared"].append(dict(lock["declared"][0], julia=["1.10"]))
        self.assertIn("declared twice", self.refusal(lock))

    def test_the_harness_declaration_must_match_the_mapping_and_the_observation(self):
        lock = copy.deepcopy(self.lock)
        lock["harness"]["approval_url"] = "https://github.com/mlakolar/ProximalSolvers.jl/issues/1#issuecomment-1"
        self.assertIn("approval_url", self.refusal(lock))
        lock = copy.deepcopy(self.lock)
        lock["stack_b"]["harness_hash"] = "5" * 40
        self.assertIn("differs from the lock", self.refusal(lock))

    def test_the_lock_must_agree_with_the_roots(self):
        lock = copy.deepcopy(self.lock)
        lock["stack_b"]["proximalsolvers"]["commit"] = "6" * 40
        self.assertIn("differs from the lock", self.refusal(lock))

    def test_without_a_lock_any_observed_difference_is_refused_and_none_gives_schema_only(self):
        self.assertIn("lock has no reason", self.refusal(None))
        camp = F.build_campaign(fresh("decl-id"), "identical")
        base = assemble_base(camp, fresh("decl-id-base") / "base", with_raw=True)
        self.assertEqual(C.declared_differences(base, None), {"schema": 1})
        C.write_declared_differences(base, None)
        self.assertEqual(tomllib.loads((base / "declared-differences.toml").read_text()), {"schema": 1})
        lock = make_lock(self.camp)
        self.assertIn("declared in the lock but not observed", self.refusal(lock, base))

    def test_a_manifest_difference_added_to_one_stratum_is_split_by_stratum(self):
        camp = F.build_campaign(fresh("decl-man"), "manifest")
        lock = make_lock(camp)
        base = assemble_base(camp, fresh("decl-man-base") / "base", with_raw=True)
        declared = C.declared_differences(base, lock)
        kinds = {(r["name"], r["kind"], tuple(r.get("julia", ()))) for r in declared["manifest"]}
        self.assertIn(("NewDep", "added", ("1.13",)), kinds)
        strip = lambda rows: [{k: v for k, v in r.items() if k != "reason"} for r in rows]
        self.assertEqual(strip(declared["manifest"]), strip(F.declared_differences(camp)["manifest"]),
                         "the observed rows equal the fixture's independent derivation")
        for row in declared["manifest"]:
            self.assertEqual(row["reason"], "synthetic reason")

    def test_an_unreadable_root_is_a_refusal(self):
        base = clone(self.base)
        shutil.rmtree(base / "roots" / "ab-b" / "julia-1.10" / "raw")
        self.assertIn("cannot be read", self.refusal(self.lock, base))


# -------------------------------------------------------------------------------------- sealing, engine

def pilot_world(arms=("AB",), name="pilot"):
    camp = F.build_campaign(fresh(name), "identical", reps=1, schedule_edit=pilot_edit)
    return camp


class EngineBase(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.camp = pilot_world()

    def make(self, session=SESSION):
        base = assemble_base(self.camp, fresh("engine") / "run-pilot", session=session, aa=False)
        plan = C.plan_from_pilot(pilot_config(session), base, JULIA_BINS, ENVIRON)
        add_pilot_config(base)
        return base, plan, Host(self.camp, plan.sched, base)

    def state(self, base):
        return json.loads((base / "logs" / "STATE.json").read_text())

    def receipt(self, base):
        return C.read_jsonl(base / "receipt.jsonl")


class SealTests(EngineBase):
    def key(self, plan, role="ab-a", rep=1, mm="1.10"):
        return C.Key("AB", role, mm, rep)

    def fill(self, base, plan, key, exit_code=0, **host_rules):
        host = Host(self.camp, plan.sched, base)
        host.rule(**host_rules)
        plan.raw(key.role, key.mm).mkdir(parents=True, exist_ok=True)
        env = C.launch_env(plan, plan.roles[key.role], key.mm, key.rep)
        host.runner([], env, str(plan.roles[key.role].checkout), 6)

    def setup_logs(self, base):
        (base / "logs").mkdir(exist_ok=True)

    def test_a_clean_process_is_sealed_read_only_with_its_digests(self):
        base, plan, _ = self.make()
        self.setup_logs(base)
        key = self.key(plan)
        self.fill(base, plan, key)
        failed = C.seal_process(plan, key, 0, 20.0)
        self.assertEqual(failed, [])
        seals = C.read_seals(base)
        stem = plan.stem("1.10", 1)
        self.assertEqual({Path(s["file"]).name for s in seals}, C.stem_files(stem))
        for seal in seals:
            path = base / seal["file"]
            self.assertEqual(stat.S_IMODE(path.stat().st_mode), 0o444)
            self.assertEqual(C.sha256_file(path), seal["sha256"])
        self.assertEqual(C.verify_seals(base), [])

    def test_the_unacceptable_outcomes_are_seal_problems(self):
        cases = {
            "exit 3": dict(exit_code=3), "killed": dict(exit_code=-9), "exit 1": dict(exit_code=1),
            "elapsed beyond the interval": dict(exit_code=0, seconds=1.0),
            "exit 2 with no non-ok case": dict(exit_code=2),
            "missing file": dict(exit_code=0, skip=["samples"]),
            "missing metadata": dict(exit_code=0, skip=["metadata"]),
            "extra file": dict(exit_code=0, extra="julia-1.10.13-rep01-surplus.txt"),
            "unknown raw entry": dict(exit_code=0, extra="stray.txt"),
        }
        for name, case in cases.items():
            with self.subTest(name):
                base, plan, _ = self.make()
                self.setup_logs(base)
                key = self.key(plan)
                seconds = case.pop("seconds", 20.0)
                exit_code = case.pop("exit_code")
                self.fill(base, plan, key, **case)
                with self.assertRaises(C.SealProblem):
                    C.seal_process(plan, key, exit_code, seconds)
                self.assertEqual(C.read_seals(base), [], "nothing is sealed after a problem")
                self.assertTrue(C.prefix_files(plan.raw(key.role, key.mm), plan.stem(key.mm, 1)) or
                                case.get("skip") == ["x"], "the files are preserved, never deleted")

    def test_exit_two_is_kept_and_its_failed_cases_are_reported(self):
        camp = F.build_campaign(fresh("seal-nonok"), "identical", reps=1, schedule_edit=pilot_edit)
        case_id = camp.case_ids[3]
        camp.set_status("a", "1.10", case_id, "target_missed", receipt=False)
        base = assemble_base(camp, fresh("seal-nonok-base") / "x-pilot", aa=False)
        plan = C.plan_from_pilot(pilot_config(), base, JULIA_BINS, ENVIRON)
        (base / "logs").mkdir()
        host = Host(camp, plan.sched, base)
        plan.raw("ab-a", "1.10").mkdir(parents=True, exist_ok=True)
        host.runner([], C.launch_env(plan, plan.roles["ab-a"], "1.10", 1), str(plan.roles["ab-a"].checkout), 6)
        self.assertEqual(C.seal_process(plan, C.Key("AB", "ab-a", "1.10", 1), 2, 20.0), [case_id])

    def test_a_changed_or_deleted_sealed_file_is_found_and_a_sealed_file_is_read_only(self):
        base, plan, _ = self.make()
        self.setup_logs(base)
        key = self.key(plan)
        self.fill(base, plan, key)
        C.seal_process(plan, key, 0, 20.0)
        raw = plan.raw("ab-a", "1.10")
        target = raw / f"{plan.stem('1.10', 1)}-metrics.tsv"
        with self.assertRaises(PermissionError):
            target.write_text("x")
        writable(target).write_text("changed")
        self.assertTrue(any("changed" in p for p in C.verify_seals(base)))
        target.unlink()
        self.assertTrue(any("missing" in p for p in C.verify_seals(base)))
        base2, plan2, _ = self.make()
        self.setup_logs(base2)
        self.fill(base2, plan2, key)
        C.seal_process(plan2, key, 0, 20.0)
        mode_target = plan2.raw("ab-a", "1.10") / f"{plan2.stem('1.10', 1)}-catalog.tsv"
        mode_target.chmod(0o644)
        self.assertTrue(any("not read-only" in p for p in C.verify_seals(base2)))
        self.assertEqual(C.verify_seals(base2, check_mode=False), [])


class EngineTests(EngineBase):
    def test_a_complete_pilot_run_orders_launches_and_records(self):
        base, plan, host = self.make()
        outcome = C.execute(plan, host.hooks())
        self.assertEqual((outcome.exit_code, outcome.state, outcome.processes, outcome.comparator_exit),
                         (0, "completed", 4, 0))
        order = C.process_order(plan)
        self.assertEqual([(k.arm, k.role, k.mm, k.rep) for k in order],
                         [("AB", "ab-a", "1.10", 1), ("AB", "ab-b", "1.10", 1),
                          ("AB", "ab-a", "1.13", 1), ("AB", "ab-b", "1.13", 1)])
        self.assertEqual(len(host.calls), 4)
        argv, env, cwd, cpu = host.calls[0]
        spec = plan.roles["ab-a"]
        self.assertEqual(argv, ["taskset", "-c", "6", JULIA_BINS["1.10"], "--startup-file=no", "--history-file=no",
                                f"--project={spec.environments['1.10']}", f"{spec.checkout}/benchmark/run.jl"])
        self.assertEqual((cwd, cpu), (str(spec.checkout), 6))
        s = plan.sched["settings"]
        self.assertEqual(env["PS_CASES"], s["case_filter"])
        self.assertEqual(env["PS_REPETITION"], "1")
        self.assertEqual(env["PS_OUTPUT"], str(base / "roots" / "ab-a" / "julia-1.10" / "raw"))
        self.assertEqual(env["PS_EXPECTED_PACKAGE_ROOT"], str(spec.checkout))
        self.assertEqual((env["PS_SUITE"], env["PS_GROUPS"], env["PS_SAMPLES"], env["PS_SECONDS"],
                          env["PS_CASE_SECONDS"], env["PS_PROFILE_SECONDS"]),
                         ("extended", s["groups"], "100", "3.0", "60.0", "0.0"))
        self.assertEqual(env["JULIA_DEPOT_PATH"], str(spec.depot))
        for name, value in (("JULIA_NUM_THREADS", "1"), ("OPENBLAS_NUM_THREADS", "1"),
                            ("JULIA_LOAD_PATH", "@:@stdlib"), ("JULIA_PKG_OFFLINE", "true")):
            self.assertEqual(env[name], value)
        self.assertEqual(env[C.JOB_ID_VARIABLES[0]], "4242")
        for secret in ("SSH_AUTH_SOCK", "AWS_SECRET_ACCESS_KEY"):
            self.assertNotIn(secret, env)
        commands = C.read_jsonl(base / "logs" / "commands.jsonl")
        self.assertEqual(len(commands), 4)
        self.assertNotIn("AWS_SECRET_ACCESS_KEY", json.dumps(commands))
        redacted = {k: ("<redacted>" if k in ("HOME", "USER", "LOGNAME", "TMPDIR") else v) for k, v in env.items()}
        self.assertEqual(commands[0]["env"], redacted)
        self.assertEqual(commands[0]["env"]["HOME"], "<redacted>")
        self.assertEqual(env["HOME"], ENVIRON["HOME"], "the process itself gets the real value")
        self.assertEqual(commands[0]["cwd"], str(spec.checkout))
        self.assertEqual(set(commands[0]["machine_before"]), set(C.SAMPLE_KEYS))
        events = self.receipt(base)
        self.assertEqual(events[0]["event"], "campaign")
        self.assertEqual(events[0]["session_id"], SESSION)
        self.assertEqual([(e["role"], e["julia"], e["exit"], e["complete"]) for e in events[1:]],
                         [("A", "1.10.13", 0, True), ("B", "1.10.13", 0, True), ("A", "1.13.3", 0, True),
                          ("B", "1.13.3", 0, True)])
        for event in events[1:]:
            self.assertEqual(tuple(event["machine"]), C.MACHINE_KEYS)
        self.assertEqual(self.state(base)["state"], "completed")
        completion = json.loads((base / "logs" / "completion.json").read_text())
        self.assertEqual((completion["processes"], completion["comparator_exit"], completion["outcome"]),
                         (4, 0, "comparable"))
        self.assertEqual(C.verify_seals(base), [])
        self.assertEqual(tomllib.loads((base / "declared-differences.toml").read_text()), {"schema": 1})
        document, status = C.verify(base, fresh("v") / "verification.json", config=PILOT_FILE)
        self.assertEqual((status, document["state"], document["problems"]), (0, "pilot_verified", []))
        self.assertEqual(document["mode"], "PILOT / NON-OFFICIAL")
        for command in commands:
            self.assertLess(C._parse_time(command["start_utc"]), C._parse_time(command["end_utc"]))

    def test_block_order_follows_the_schedule(self):
        camp = F.build_campaign(fresh("order"), "identical", reps=4, schedule_edit=pilot_edit)
        base = assemble_base(camp, fresh("order-base") / "x-pilot", aa=False)
        plan = C.plan_from_pilot(pilot_config(), base, JULIA_BINS, ENVIRON)
        roles = [(k.mm, k.rep, k.letter) for k in C.process_order(plan)]
        self.assertEqual(roles[:8], [("1.10", 1, "A"), ("1.10", 1, "B"), ("1.10", 2, "B"), ("1.10", 2, "A"),
                                     ("1.10", 3, "B"), ("1.10", 3, "A"), ("1.10", 4, "A"), ("1.10", 4, "B")])
        self.assertEqual(len(roles), 16)

    def test_both_arms_run_ab_then_aa_per_stratum(self):
        def both(schedule):
            pilot_edit(schedule)
            schedule["schedule"]["arms"] = ["AB", "AA"]
        camp = F.build_campaign(fresh("arms"), "identical", reps=1, schedule_edit=both)
        base = assemble_base(camp, fresh("arms-base") / "x-pilot")
        config = pilot_config(arms=("AB", "AA"))
        plan = C.plan_from_pilot(config, base, JULIA_BINS, ENVIRON)
        self.assertEqual([(k.arm, k.mm) for k in C.process_order(plan)][::2],
                         [("AB", "1.10"), ("AA", "1.10"), ("AB", "1.13"), ("AA", "1.13")])
        with self.assertRaises(C.LockRefusal) as caught:          # the arms must be those of the schedule copy
            C.plan_from_pilot(config, base, JULIA_BINS, ENVIRON, arms=("AB",))
        self.assertEqual(caught.exception.field, "pilot.arms")
        with self.assertRaises(C.LockRefusal):
            C.plan_from_pilot(pilot_config(), base, JULIA_BINS, ENVIRON, arms=("AA",))

    def test_processes_never_overlap_and_the_clock_is_read_around_each_call(self):
        base, plan, host = self.make()
        readings = []
        original = host.runner

        def runner(*args):
            readings.append(("call", host.now))
            return original(*args)
        C.execute(plan, host.hooks(runner=runner))
        events = self.receipt(base)[1:]
        stamps = [(C._parse_time(e["start_utc"]), C._parse_time(e["end_utc"])) for e in events]
        for (s1, e1), (s2, e2) in zip(stamps, stamps[1:]):
            self.assertLess(s1, e1)
            self.assertLess(e1, s2)
        for (_, moment), (start, _) in zip(readings, stamps):
            self.assertEqual(moment, start, "the start reading is taken immediately before the call")

    def test_an_exit_of_three_stops_the_attempt_with_an_honest_process_event(self):
        base, plan, host = self.make()
        host.rule(role="ab-b", mm="1.10", exit=3, skip=["samples", "metrics"])
        with self.assertRaises(C.Stopped):
            C.execute(plan, host.hooks())
        self.assertEqual(len(host.calls), 2, "nothing further was launched")
        events = self.receipt(base)
        self.assertEqual([(e["role"], e["exit"], e["complete"]) for e in events[1:]],
                         [("A", 0, True), ("B", 3, False)])
        state = self.state(base)
        self.assertEqual(state["state"], "stopped")
        self.assertIn("exited with 3", state["reason"])
        self.assertEqual(state["process"], "AB-B-1.10-rep01")
        self.assertFalse((base / "logs" / "completion.json").exists())
        self.assertTrue(C.prefix_files(plan.raw("ab-b", "1.10"), plan.stem("1.10", 1)), "partial files are kept")
        document, status = C.verify(base, fresh("v") / "v.json", config=PILOT_FILE)
        self.assertEqual((status, document["state"]), (2, "stopped"))
        self.assertTrue((base / "checksums.sha256").is_file())

    def test_a_killed_process_and_an_unexpected_exit_stop_the_attempt(self):
        for exit_code in (-9, 1, 139):
            with self.subTest(exit=exit_code):
                base, plan, host = self.make()
                host.rule(role="ab-a", mm="1.10", exit=exit_code)
                with self.assertRaises(C.Stopped):
                    C.execute(plan, host.hooks())
                self.assertEqual(len(host.calls), 1)
                event = self.receipt(base)[-1]
                self.assertEqual((event["exit"], event["complete"]), (exit_code, False))
                self.assertEqual(self.state(base)["state"], "stopped")

    def test_exit_zero_with_non_ok_cases_and_exit_two_with_none_are_inconsistent(self):
        camp = F.build_campaign(fresh("incons"), "identical", reps=1, schedule_edit=pilot_edit)
        camp.set_status("a", "1.10", camp.case_ids[0], "target_missed", receipt=False)
        for exit_code, label, expect in ((0, "a", "exit 0 with nonok_cases"), (2, "b", "exit 2 with nonok_cases")):
            with self.subTest(exit=exit_code):
                base = assemble_base(camp, fresh("incons-base") / "x-pilot", aa=False)
                plan = C.plan_from_pilot(pilot_config(), base, JULIA_BINS, ENVIRON)
                host = Host(camp, plan.sched, base)
                host.rule(role=LABEL_ROLE[label], mm="1.10", exit=exit_code)
                with self.assertRaises(C.Stopped) as caught:
                    C.execute(plan, host.hooks())
                self.assertIn(expect, str(caught.exception))
                self.assertFalse(self.receipt(base)[-1]["complete"])

    def test_exit_two_is_kept_reported_and_never_retried(self):
        camp = F.build_campaign(fresh("nonok"), "identical", reps=1, schedule_edit=pilot_edit)
        case_id = camp.case_ids[5]
        for label in ("a", "b"):
            camp.set_status(label, "1.10", case_id, "target_missed", receipt=False)
        base = assemble_base(camp, fresh("nonok-base") / "x-pilot", aa=False)
        plan = C.plan_from_pilot(pilot_config(), base, JULIA_BINS, ENVIRON)
        add_pilot_config(base)
        host = Host(camp, plan.sched, base)
        outcome = C.execute(plan, host.hooks())
        self.assertEqual(outcome.exit_code, 1)
        self.assertEqual(len(host.calls), 4, "no retry")
        self.assertEqual([n["failed_cases"] for n in outcome.nonok], [[case_id], [case_id]])
        self.assertEqual(self.state(base)["state"], "completed")
        self.assertEqual(json.loads((base / "logs" / "completion.json").read_text())["outcome"], "non_ok")
        self.assertEqual({e["exit"] for e in self.receipt(base)[1:3]}, {2})
        document, status = C.verify(base, fresh("v") / "v.json", config=PILOT_FILE)
        self.assertEqual((status, document["state"], document["problems"]), (1, "pilot_verified_non_ok", []))
        code, out, err = call_main(["verify", "--base", str(base), "--out", str(fresh("v") / "v.json"),
                                    "--config", str(PILOT_FILE)])
        self.assertEqual(code, 1)
        self.assertIn("PILOT / NON-OFFICIAL", out)

    def test_a_stopped_state_refuses_every_further_launch(self):
        base, plan, host = self.make()
        host.rule(role="ab-a", mm="1.10", exit=3)
        with self.assertRaises(C.Stopped):
            C.execute(plan, host.hooks())
        again = Host(self.camp, plan.sched, base)
        for hooks in (again.hooks(), hooks_that_never_run()):
            with self.assertRaises(C.Refused) as caught:
                C.execute(plan, hooks)
            self.assertIn("already holds a campaign state (stopped)", str(caught.exception))
        self.assertEqual(again.calls, [])
        self.assertEqual(self.state(base)["state"], "stopped", "the state is not reset")

    def test_a_second_execute_over_a_finished_root_or_an_existing_prefix_is_refused(self):
        base, plan, host = self.make()
        C.execute(plan, host.hooks())
        before = C.checksum_text(base)
        with self.assertRaises(C.Refused):
            C.execute(plan, hooks_that_never_run())
        self.assertEqual(C.checksum_text(base), before, "the evidence is unchanged")
        base2, plan2, _ = self.make()
        raw = plan2.raw("ab-b", "1.13")
        raw.mkdir(parents=True, exist_ok=True)
        (raw / f"{plan2.stem('1.13', 1)}-metrics.tsv").write_text("partial")
        with self.assertRaises(C.Refused) as caught:
            C.execute(plan2, hooks_that_never_run())
        self.assertIn("never overwritten", str(caught.exception))
        self.assertEqual((raw / f"{plan2.stem('1.13', 1)}-metrics.tsv").read_text(), "partial")
        self.assertFalse((base2 / "receipt.jsonl").exists())

    def test_the_identity_files_must_match_the_plan(self):
        base, plan, host = self.make()
        edit_text(base / "roots" / "ab-b" / "stack-identity.toml", lambda t: t.replace("inst-b1", "inst-zz"))
        with self.assertRaises(C.Refused) as caught:
            C.execute(plan, host.hooks())
        self.assertIn("installation", str(caught.exception))
        base, plan, host = self.make()
        edit_text(base / "roots" / "ab-a" / "stack-identity.toml", lambda t: t.replace(SESSION, "session-0"))
        with self.assertRaises(C.Refused) as caught:
            C.execute(plan, host.hooks())
        self.assertIn("session_id", str(caught.exception))
        self.assertEqual(host.calls, [])

    def test_two_roles_with_one_installation_id_are_refused_when_the_plan_is_built(self):
        base = assemble_base(self.camp, fresh("dup") / "x-pilot", aa=False)
        edit_text(base / "roots" / "ab-b" / "stack-identity.toml", lambda t: t.replace("inst-b1", "inst-a1"))
        with self.assertRaises(C.Refused):
            C.plan_from_pilot(pilot_config(), base, JULIA_BINS, ENVIRON)

    def test_a_changed_sealed_file_stops_before_the_next_process(self):
        base, plan, host = self.make()
        first = plan.raw("ab-a", "1.10") / f"{plan.stem('1.10', 1)}-samples.tsv"
        original = host.runner

        def runner(argv, env, cwd, cpu):
            if len(host.calls) == 1:                                   # the second process is about to start
                writable(first).write_text("tampered")
            return original(argv, env, cwd, cpu)
        # the first process is sealed after it ends; the tampering happens during the second one
        with self.assertRaises(C.Stopped) as caught:
            C.execute(plan, host.hooks(runner=runner))
        self.assertTrue("sealed files changed" in str(caught.exception))
        self.assertEqual(len(host.calls), 2, "the third process is not launched")
        events = self.receipt(base)[1:]
        self.assertEqual(len(events), 2, "exactly the two launched processes are in the receipt")
        self.assertEqual(self.state(base)["state"], "stopped")

    def test_a_deleted_sealed_file_stops_before_the_next_process(self):
        base, plan, host = self.make()
        first = plan.raw("ab-a", "1.10") / f"{plan.stem('1.10', 1)}-errors.tsv"
        original = host.runner

        def runner(argv, env, cwd, cpu):
            if len(host.calls) == 1:
                first.unlink()
            return original(argv, env, cwd, cpu)
        with self.assertRaises(C.Stopped):
            C.execute(plan, host.hooks(runner=runner))
        self.assertEqual(len(host.calls), 2)

    def test_a_process_that_cannot_start_is_one_failed_event(self):
        base, plan, host = self.make()
        host.rule(role="ab-a", mm="1.10", fail_start=True)
        with self.assertRaises(C.Stopped):
            C.execute(plan, host.hooks())
        event = self.receipt(base)[-1]
        self.assertEqual((event["exit"], event["complete"]), (-1, False))
        self.assertIn(b"runner failed", (base / "logs" / "AB-A-1.10-rep01.stderr").read_bytes())

    def test_the_machine_values_must_not_change(self):
        base, plan, host = self.make()
        host.sample_edits.append((4, lambda s: s.update(governor="performance")))
        with self.assertRaises(C.Stopped) as caught:
            C.execute(plan, host.hooks())
        self.assertIn("machine values", str(caught.exception))
        records = C.read_jsonl(base / "logs" / "hardware.jsonl")
        self.assertTrue(any(r["disagrees"] for r in records))
        self.assertEqual(self.state(base)["state"], "stopped")

    def test_the_depot_cache_digest_and_the_data_hash_check_can_stop_the_run(self):
        base, plan, host = self.make()
        digests = iter(range(100))
        with self.assertRaises(C.Stopped) as caught:
            C.execute(plan, host.hooks(depot_digest=lambda spec: next(digests)))
        self.assertIn("compiled-cache", str(caught.exception))
        base, plan, host = self.make()
        host.datahash = False
        with self.assertRaises(C.Stopped) as caught:
            C.execute(plan, host.hooks())
        self.assertIn("data_hash", str(caught.exception))
        self.assertEqual(len(host.calls), 1)

    def test_a_changed_manifest_between_processes_stops_the_run(self):
        base, plan, host = self.make()
        calls = []

        def edit(role, mm, obs):
            calls.append(1)
            if len(calls) > 4:
                obs["manifest_sha256"] = "0" * 64
        host.obs_edits.append(edit)
        with self.assertRaises(C.Stopped) as caught:
            C.execute(plan, host.hooks())
        self.assertIn("ENV_CHANGED", str(caught.exception.args))
        self.assertEqual(host.calls, [])

    def test_the_comparator_refusal_is_reported_as_refused_without_a_completion_record(self):
        base, plan, host = self.make()
        edit_text(base / "roots" / "ab-b" / "julia-1.10" / "environment-inventory.toml",
                  lambda t: t.replace('depot_realpath = "/synthroot/inst-b1/depot"',
                                      'depot_realpath = "/synthroot/inst-a1/depot"'))
        outcome = C.execute(plan, host.hooks())
        self.assertEqual((outcome.exit_code, outcome.state, outcome.comparator_exit), (2, "refused", 2))
        self.assertFalse((base / "logs" / "completion.json").exists())
        self.assertEqual(self.state(base)["state"], "refused")
        document, status = C.verify(base, fresh("v") / "v.json", config=PILOT_FILE)
        self.assertEqual((status, document["state"], document["problems"]), (2, "refused", []))
        refusals = json.loads((base / "comparison" / "refusals.json").read_text())["refusals"]
        self.assertIn(("ORDER", "ab:installation"), {(r["class"], r["field"]) for r in refusals})


# -------------------------------------------------------------------------------------- the full shape

def run_full(camp, lock=None, tweak=None, rules=(), name="full"):
    """Assemble a BASE from the full-shape fixture set and run `main run --official` over it with mocked hooks."""
    lock = lock or make_lock(camp)
    directory = fresh(name)
    base = assemble_base(camp, directory / "base")
    if tweak:
        tweak(base)
    lock_path = directory / "lock.toml"
    C.write_toml(lock_path, lock)
    shutil.copyfile(lock_path, base / "lock.toml")
    sched = mc.load_schedule(base / "schedule.toml")
    host = Host(camp, sched, base)
    for rule in rules:
        host.rule(**rule)
    facts = facts_for(base, lock)
    code, out, err = call_main(["run", "--config", str(lock_path), "--base", str(base), "--official",
                                "--freeze-sha", FREEZE], hooks=host.hooks(), facts=lambda *a: facts)
    return base, host, code, out, err


_FULL = {}


def shared_full():
    """The full-shape tree, built, run and verified once for every class that mutates copies of it."""
    if not _FULL:
        started = time.monotonic()
        camp = F.build_campaign(fresh("full"), "migration")
        base, host, code, out, err = run_full(camp)
        run_seconds = time.monotonic() - started
        started = time.monotonic()
        record = fresh("good-verify") / "verification.json"
        document, status = C.verify(base, record)
        _FULL.update(camp=camp, base=base, host=host, code=code, out=out, err=err, run_seconds=run_seconds,
                     record=record, document=document, status=status, verify_seconds=time.monotonic() - started)
    return _FULL


def refresh_seals(base):
    """Rewrite the digest of every sealed file that still exists (so a test isolates one guard)."""
    lines = []
    for seal in C.read_seals(base):
        path = Path(base) / seal["file"]
        if path.is_file():
            seal["sha256"], seal["size"] = C.sha256_file(path), path.stat().st_size
        lines.append(json.dumps(seal))
    writable(Path(base) / "logs" / "seals.jsonl").write_text("\n".join(lines) + "\n")


def refresh_all(base):
    refresh_seals(base)
    C.write_checksums(base)


class IntegrationTests(unittest.TestCase):
    """The authoritative full-shape test: built once, verified, copied and mutated."""

    @classmethod
    def setUpClass(cls):
        for key, value in shared_full().items():
            setattr(cls, key, value)

    @classmethod
    def tearDownClass(cls):
        print(f"\nfull shape: assemble and execute {cls.run_seconds:.1f} s, verify {cls.verify_seconds:.1f} s",
              file=sys.stderr)

    def verify(self, base, replay=True):
        return C.verify(base, fresh("v") / "verification.json", replay=replay)

    def reseal(self, base):
        C.write_checksums(base)

    def mutated(self, function, reseal=False):
        base = clone(self.base)
        function(base)
        if reseal:
            self.reseal(base)
        return base

    def assertProblem(self, base, text, replay=True, state="failed"):
        record = fresh("v") / "verification.json"
        document, status = C.verify(base, record, replay=replay)
        self.assertEqual((document["state"], status), (state, 2), document["problems"][:5])
        self.assertEqual(json.loads(record.read_text()), document, "the record is written outside the evidence")
        self.assertTrue(any(text in p for p in document["problems"]), (text, document["problems"][:8]))
        return document

    # ---- the accepted run ----
    def test_the_full_shape_run_is_complete_and_valid(self):
        self.assertEqual(self.code, 0, self.err)
        self.assertEqual(self.status, 0, self.document["problems"])
        self.assertEqual((self.document["state"], self.document["problems"], self.document["comparator_exit"]),
                         ("verified", [], 0))
        self.assertEqual(self.document["classification"], {"COMPARABLE": 38})
        self.assertEqual(len(self.host.calls), 64, "2 strata x 2 arms x 8 repetitions x 2 roles")
        events = C.read_jsonl(self.base / "receipt.jsonl")
        self.assertEqual(sum(e["event"] == "process" for e in events), 64)
        self.assertEqual(events[0]["campaign_id"], "pb06-migration-stage2b-v1")
        self.assertEqual(json.loads((self.base / "logs" / "campaign.json").read_text())["freeze_sha"], FREEZE)
        self.assertEqual(json.loads(self.record.read_text()), self.document)
        self.assertEqual(self.record.parent.name.startswith("good-verify"), True)
        self.assertEqual(set(self.document), {"schema", "problems", "mode", "campaign_state", "campaign_outcome",
                                              "comparator_exit", "classification", "state"})

    def test_the_driver_order_is_ab_then_aa_per_stratum_and_the_declared_file_is_the_locks(self):
        arms = []
        for event in C.read_jsonl(self.base / "receipt.jsonl")[1:]:
            if not arms or arms[-1] != (event["julia"], event["arm"]):
                arms.append((event["julia"], event["arm"]))
        self.assertEqual(arms, [("1.10.13", "AB"), ("1.10.13", "AA"), ("1.13.3", "AB"), ("1.13.3", "AA")])
        declared = tomllib.loads((self.base / "declared-differences.toml").read_text())
        self.assertEqual(declared["harness"]["port_commit"], make_lock(self.camp)["harness"]["port_commit"])
        self.assertEqual(declared["manifest"][0]["reason"], "synthetic reason")

    def test_the_layout_and_the_private_directories(self):
        entries = sorted(p.name for p in self.base.iterdir())
        for name in ("roots", "logs", "comparison", "receipt.jsonl", "schedule.toml", "case-mapping.toml",
                     "lock.toml", "declared-differences.toml", "checksums.sha256"):
            self.assertIn(name, entries)
        self.assertNotIn("verification.json", entries)
        self.assertFalse(any(p.startswith(C.PRIVATE_DIRECTORIES) for p in C.evidence_paths(self.base)))
        self.assertEqual(sorted(p.name for p in (self.base / "roots").iterdir()), ["aa-a", "aa-b", "ab-a", "ab-b"])
        listed = C.read_checksums(self.base / "checksums.sha256")
        self.assertEqual(sorted(listed), C.evidence_paths(self.base))
        self.assertEqual(C.verify_seals(self.base), [])
        self.assertEqual(len(C.read_seals(self.base)), 64 * 6 + 1)

    def test_a_copy_verifies_to_the_same_classification(self):
        copy_ = clone(self.base)
        document, status = self.verify(copy_)
        self.assertEqual((status, document["state"], document["problems"]), (0, "verified", []))
        self.assertEqual(document["classification"], self.document["classification"])
        self.assertEqual(document["comparator_exit"], self.document["comparator_exit"])
        self.assertEqual(C.comparison_summary(copy_ / "comparison"), C.comparison_summary(self.base / "comparison"))

    def test_the_comparator_replay_uses_the_trees_own_files_and_both_flags(self):
        argv = C.comparator_argv(self.base, fresh() / "out")
        self.assertIn("--schedule", argv)
        self.assertEqual(argv[argv.index("--schedule") + 1], str(self.base / "schedule.toml"))
        self.assertEqual(argv[argv.index("--aa") + 1:argv.index("--aa") + 3],
                         [str(self.base / "roots" / "aa-a"), str(self.base / "roots" / "aa-b")])
        pilot = F.build_campaign(fresh("no-aa"), "identical", reps=1, schedule_edit=pilot_edit)
        no_aa = assemble_base(pilot, fresh("no-aa-base") / "x-pilot", aa=False)
        self.assertNotIn("--aa", C.comparator_argv(no_aa, fresh() / "o"), "the schedule has no AA arm")

    def test_the_records_in_the_full_set_are_finite_and_complete(self):
        for role in C.ROLES:
            for mm in ("1.10", "1.13"):
                raw = self.base / "roots" / role / f"julia-{mm}" / "raw"
                self.assertEqual(len(list(raw.iterdir())), 8 * 6)
        for role in C.ROLES:
            for path in sorted((self.base / "roots" / role).glob("julia-*/raw/*-metrics.tsv")):
                header, rows = C.read_tsv(path)
                for row in rows:
                    value = float(row[header.index("median_ns")])
                    self.assertTrue(math.isfinite(value) and value > 0, path.name)

    # ---- verify of a mutated copy: evidence, seals, receipt ----
    def test_a_changed_sealed_file(self):
        path = lambda b: b / "roots/ab-a/julia-1.10/raw/julia-1.10.13-rep03-samples.tsv"
        base = self.mutated(lambda b: writable(path(b)).write_text(path(b).read_text() + "\n"))
        self.assertProblem(base, "sealed file")
        self.assertProblem(base, "differs from its digest", replay=False)

    def test_a_deleted_sealed_file_and_a_missing_repetition(self):
        base = self.mutated(lambda b: (b / "roots/ab-b/julia-1.13/raw/julia-1.13.3-rep02-metadata.toml").unlink())
        self.assertProblem(base, "is missing")
        self.assertProblem(base, "sealed file")

        def drop_repetition(b):
            for kind in C.RECORD_KINDS:
                ext = "toml" if kind.startswith("metadata") else "tsv"
                (b / f"roots/aa-a/julia-1.10/raw/julia-1.10.13-rep05-{kind}.{ext}").unlink()
        base = self.mutated(drop_repetition, reseal=True)
        document = self.assertProblem(base, "rep05-catalog.tsv is missing")
        self.assertEqual(document["comparator_exit"], 2)

    def test_a_missing_case_in_metrics(self):
        def drop_row(b):
            path = b / "roots/ab-a/julia-1.10/raw/julia-1.10.13-rep01-metrics.tsv"
            lines = writable(path).read_text().split("\n")
            writable(path).write_text("\n".join(lines[:2] + lines[3:]))
        base = self.mutated(drop_row, reseal=True)
        self.assertProblem(base, "does not cover every declared case")

    def test_a_missing_or_corrupted_archive(self):
        base = self.mutated(lambda b: shutil.rmtree(b / "comparison"))
        self.assertProblem(base, "comparison/", replay=True)
        base = self.mutated(lambda b: writable(b / "comparison" / "report.md").write_text("tampered"))
        self.assertProblem(base, "differs from its digest", replay=False)
        base = self.mutated(lambda b: writable(b / "comparison" / "migration-comparison.csv").write_text("x\n"),
                            reseal=True)
        self.assertProblem(base, "comparison rows of the replay differ")
        base = self.mutated(lambda b: (b / "checksums.sha256").unlink())
        self.assertProblem(base, "checksums.sha256")
        base = self.mutated(lambda b: (b / "logs" / "seals.jsonl").unlink())
        self.assertProblem(base, "logs/seals.jsonl is missing")
        base = self.mutated(lambda b: os.symlink(b / "receipt.jsonl", b / "logs" / "link"))
        self.assertProblem(base, "symbolic link", replay=False)

    def edit_receipt(self, function):
        def edit(b):
            events = C.read_jsonl(b / "receipt.jsonl")
            events = function(events) or events
            writable(b / "receipt.jsonl").write_text("".join(json.dumps(e) + "\n" for e in events))
        return self.mutated(edit, reseal=True)

    def test_receipt_defects(self):
        def process(events, arm="AB", role="A", julia="1.10.13", rep=1):
            return next(e for e in events if e["event"] == "process" and (e["arm"], e["role"], e["julia"], e["rep"])
                        == (arm, role, julia, rep))

        def swap(events):
            a, b = process(events, rep=2, role="A"), process(events, rep=2, role="B")
            a["start_utc"], b["start_utc"] = b["start_utc"], a["start_utc"]
            a["end_utc"], b["end_utc"] = b["end_utc"], a["end_utc"]
        document = self.assertProblem(self.edit_receipt(swap), "order")
        self.assertEqual(document["comparator_exit"], 2)

        def overlap(events):
            first, second = process(events, rep=1, role="A"), process(events, rep=1, role="B")
            second["start_utc"] = first["start_utc"].replace(".000", ".001")
        self.assertProblem(self.edit_receipt(overlap), "overlap")
        self.assertProblem(self.edit_receipt(lambda e: e.remove(process(e, rep=4, role="B"))), "is missing")
        self.assertProblem(self.edit_receipt(lambda e: e.append(copy.deepcopy(process(e, rep=4)))), "occurs twice")
        self.assertProblem(self.edit_receipt(lambda e: process(e, rep=3).update(installation="inst-zz")),
                           "installation differs from the identity")
        self.assertProblem(self.edit_receipt(lambda e: e.append({"event": "note"})), "not a process event")
        self.assertProblem(self.edit_receipt(lambda e: e.insert(2, copy.deepcopy(e[0]))), "more than one campaign")
        self.assertProblem(self.edit_receipt(lambda e: process(e, rep=5).update(complete=False)), "complete False")
        self.assertProblem(self.edit_receipt(lambda e: process(e, rep=5).update(exit=3)), "exit 3")
        self.assertProblem(self.edit_receipt(lambda e: process(e, rep=5, arm="AA").update(exit=2)),
                           "exit 2 with nonok_cases 0")
        self.assertProblem(self.edit_receipt(lambda e: process(e, rep=6).update(exit=0, start_utc="soon")),
                           "invalid values")

        def late_block(events):                      # block 1 after block 2: not in increasing time order
            for event in events[1:]:
                if (event["arm"], event["julia"], event["rep"]) == ("AB", "1.10.13", 1):
                    event["start_utc"] = event["start_utc"].replace("2026-12-01", "2027-01-01")
                    event["end_utc"] = event["end_utc"].replace("2026-12-01", "2027-01-01")
        self.assertProblem(self.edit_receipt(late_block), "not after the previous block")

    def test_the_wrong_installation_identity(self):
        base = self.mutated(lambda b: edit_text(b / "roots/ab-b/stack-identity.toml",
                                                lambda t: t.replace("inst-b1", "inst-q9")), reseal=True)
        document = self.assertProblem(base, "installation differs from the identity")
        self.assertEqual(document["comparator_exit"], 2)

    # ---- the comparator on the assembled tree ----
    def test_a_changed_manifest_is_an_undeclared_difference(self):
        base = self.mutated(lambda b: edit_text(b / "roots/ab-b/julia-1.10/Manifest.toml",
                                                lambda t: t.replace('version = "1.9.0"', 'version = "1.9.1"')),
                            reseal=True)
        document = self.assertProblem(base, "the replay exits with 2")
        self.assertEqual(document["comparator_exit"], 2)

    def test_declared_differences_missing_and_extra(self):
        base = self.mutated(lambda b: writable(b / "declared-differences.toml").write_text("schema = 1\n"),
                            reseal=True)
        document = self.assertProblem(base, "the replay exits with 2")
        self.assertEqual(document["classification"] is not None, True)

        def extra(b):
            with writable(b / "declared-differences.toml").open("a") as stream:
                stream.write('\n[[compat]]\nname = "Extra"\na = "1"\nb = "2"\nreason = "r"\n')
        self.assertProblem(self.mutated(extra, reseal=True), "the replay exits with 2")

    def test_fingerprint_files_and_rows(self):
        def edit_rows(role, kind, name, new="0" * 64):
            def edit(b):
                path = b / "roots" / role / C.FP_NAME

                def change(text):
                    lines, done = [], False
                    for line in text.split("\n"):
                        cells = line.split("\t")
                        if not done and len(cells) == 6 and cells[3:5] == [kind, name] and cells[2] == "1" and \
                                cells[1].startswith("cd/lasso-dense/cd/B/call"):
                            cells[5], done = new, True
                        lines.append("\t".join(cells))
                    return "\n".join(lines)
                edit_text(path, change)
            return edit
        for kind, name, exit_code in (("reset", "values", 1), ("config", "solver", 1), ("config", "options", 1),
                                      ("fixture", "X", 2), ("file", "certificates.jl", 2)):
            with self.subTest(row=f"{kind}/{name}"):
                base = self.mutated(edit_rows("ab-b", kind, name), reseal=True)
                document = self.assertProblem(base, f"the replay exits with {exit_code}")
                self.assertEqual(document["comparator_exit"], exit_code)
        base = self.mutated(lambda b: (b / "roots/ab-a" / C.FP_NAME).unlink(), reseal=True)
        document = self.assertProblem(base, "fingerprints.tsv is missing")
        self.assertEqual(document["comparator_exit"], 1, "a missing file makes every case NOT COMPARABLE")

        def drop_row(b):
            path = b / "roots/ab-b" / C.FP_NAME
            lines = path.read_text().split("\n")
            index = next(i for i, l in enumerate(lines) if l.split("\t")[3:5] == ["config", "solver"])
            del lines[index]
            writable(path).write_text("\n".join(lines))
        base = self.mutated(drop_row, reseal=True)
        document = self.assertProblem(base, "lacks ['config/solver']")
        self.assertEqual(document["comparator_exit"], 1)
        base = self.mutated(lambda b: (b / "roots/ab-b" / C.DATAHASH_NAME).unlink(), reseal=True)
        self.assertProblem(base, "fingerprints.datahash.tsv is missing", replay=False)

        def wrong_hash(b):
            edit_text(b / "roots/ab-a" / C.DATAHASH_NAME, lambda t: t.replace("\t1\t", "\t1\t0", 1))
        self.assertProblem(self.mutated(wrong_hash, reseal=True), "data_hash sidecar differs")

    def test_mixed_julia_versions_and_a_changed_metadata_value(self):
        def retag(b):
            for kind in ("metadata", "metadata-start"):
                edit_text(b / f"roots/ab-a/julia-1.10/raw/julia-1.10.13-rep01-{kind}.toml",
                          lambda t: t.replace('julia = "1.10.13"', 'julia = "1.10.12"'))
        document = self.assertProblem(self.mutated(retag, reseal=True), "the replay exits with 2")
        self.assertEqual(document["comparator_exit"], 2)

    # ---- the completion record and the state ----
    def test_success_without_a_completion_record_never_verifies(self):
        def drop_completion(b):                     # also its seal line, so that only the record itself is missing
            (b / "logs" / "completion.json").unlink()
            seals = writable(b / "logs" / "seals.jsonl")
            lines = [l for l in seals.read_text().split("\n") if l and '"logs/completion.json"' not in l]
            seals.write_text("\n".join(lines) + "\n")
        base = self.mutated(drop_completion, reseal=True)
        document, status = self.verify(base)
        self.assertNotEqual(document["state"], "verified")
        self.assertEqual((status, document["state"]), (2, "failed"))
        self.assertTrue(all("completion.json" in p for p in document["problems"]), document["problems"])
        self.assertIn("the state is completed but logs/completion.json is missing", document["problems"])
        base = self.mutated(lambda b: (b / "logs" / "completion.json").unlink(), reseal=True)
        document, status = self.verify(base)
        self.assertEqual(status, 2)
        self.assertTrue(any("completion.json" in p for p in document["problems"]), document["problems"])

    def test_a_state_that_claims_success_or_hides_the_stop(self):
        def claim(b):
            (b / "logs" / "completion.json").unlink()
            replace = json.loads((b / "logs" / "STATE.json").read_text())
            replace["state"] = "running"
            writable(b / "logs" / "STATE.json").write_text(json.dumps(replace))
        base = self.mutated(claim, reseal=True)
        document, status = self.verify(base)
        self.assertEqual((document["state"], status), ("failed", 2))

        def stray(b):
            C.create_exclusive(b / "logs" / "completion.json.copy", "x")
            writable(b / "logs" / "STATE.json").write_text(
                json.dumps({"schema": 1, "state": "stopped", "reason": "x"}))
        base = self.mutated(stray, reseal=True)
        document, status = self.verify(base)
        self.assertEqual(status, 2)
        self.assertTrue(any("exists but the state is not completed" in p for p in document["problems"]))

    def test_the_completion_record_must_be_consistent(self):
        def completion(change):
            def edit(b):
                path = b / "logs" / "completion.json"
                data = json.loads(path.read_text())
                data.update(change)
                write_json(path, data)
            return edit
        for change, text in ((dict(processes=63), "counts 63 processes"), (dict(receipt_sha256="0" * 64),
                                                                              "the receipt digest differs"),
                             (dict(comparator_exit=1), "disagree on the comparator exit")):
            with self.subTest(change=change):
                self.assertProblem(self.mutated(completion(change)), text, replay=False)

    def test_verify_never_writes_into_the_evidence_and_needs_a_fresh_path(self):
        before = C.checksum_text(self.base)
        with self.assertRaises(C.UsageError):
            C.verify(self.base, self.base / "verification.json")
        with self.assertRaises(C.UsageError):
            C.verify(self.base, self.record)
        self.assertEqual(C.checksum_text(self.base), before)
        self.assertFalse((self.base / "verification.json").exists())

    # ---- run-time defects, through the whole pipeline ----
    def test_the_same_checkout_or_depot_in_both_roots_is_refused_by_the_comparator(self):
        def same(field):
            def edit(camp):
                a, b = camp.stack("a"), camp.stack("b")
                for key in field:
                    b[key] = a[key]
                camp.rebuild_root("b")
            return edit
        for name, fields in (("checkout", ("checkout",)), ("depot", ("depot", "depot_real")),
                             ("environment", ("env", "env_real"))):
            with self.subTest(name):
                camp = F.build_campaign(fresh(f"same-{name}"), "migration")
                same(fields)(camp)
                base, host, code, _, err = run_full(camp, name=f"same-{name}-run")
                self.assertEqual(code, 2, err)
                self.assertEqual(len(host.calls), 64, "the mocked preflight sees independent installations")
                refusals = json.loads((base / "comparison" / "refusals.json").read_text())["refusals"]
                self.assertIn(("ORDER", "ab:installation"), {(r["class"], r["field"]) for r in refusals})
                self.assertFalse((base / "logs" / "completion.json").exists())
                document, status = C.verify(base, fresh("v") / "v.json")
                self.assertEqual((document["state"], status, document["problems"]), ("refused", 2, []))

    def test_a_missing_declared_difference_at_run_time_is_refused_without_a_comparison(self):
        lock = make_lock(self.camp)
        lock["declared"] = [e for e in lock["declared"] if e["kind"] != "compat"]
        base, host, code, _, err = run_full(self.camp, lock=lock, name="no-reason")
        self.assertEqual(code, 2)
        self.assertIn("no reason", err + "".join(json.dumps(C.read_jsonl(base / "receipt.jsonl"))))
        self.assertEqual(json.loads((base / "logs" / "STATE.json").read_text())["state"], "refused")
        self.assertFalse((base / "comparison").exists())
        self.assertFalse((base / "declared-differences.toml").exists())
        document, status = C.verify(base, fresh("v") / "v.json")
        self.assertEqual((status, document["state"]), (2, "refused"))

    def test_a_changed_reset_row_at_run_time_is_not_comparable_with_exit_one(self):
        camp = F.build_campaign(fresh("reset"), "migration")
        rows = [(i, r) for i, r in enumerate(F.tsv_read(camp.fingerprints("b"))[1])
                if r[3:5] == ["reset", "values"] and r[1] == camp.case_ids[0] and r[2] == "1"]
        F.tsv_edit(camp.fingerprints("b"), {"julia": "1.10.13", "id": camp.case_ids[0], "rep": "1",
                                            "kind": "reset", "name": "values"}, "value", "0" * 64)
        self.assertTrue(rows)
        base, host, code, out, err = run_full(camp, name="reset-run")
        self.assertEqual(code, 1, err)
        document, status = C.verify(base, fresh("v") / "v.json")
        self.assertEqual((status, document["state"], document["problems"]), (1, "verified_non_ok", []))
        self.assertEqual(document["comparator_exit"], 1)

    def test_a_stopped_full_run_is_not_a_success(self):
        base, host, code, _, err = run_full(self.camp, rules=[dict(role="ab-b", mm="1.13", rep=3, exit=3)],
                                            name="stopped-full")
        self.assertEqual(code, 2)
        self.assertIn("REFUSED", err)
        self.assertEqual(json.loads((base / "logs" / "STATE.json").read_text())["state"], "stopped")
        document, status = C.verify(base, fresh("v") / "v.json")
        self.assertEqual((status, document["state"]), (2, "stopped"))
        self.assertFalse((base / "logs" / "completion.json").exists())


# ----------------------------------------------------------------------------- revision 1: the findings

def historical_lock(camp):
    """A lock whose stack B is the historical stack A (a candidate that must never be official)."""
    lock = make_lock(camp)
    a = mc.load_schedule(HERE / "schedule.toml")["stack_a"]
    b = lock["stack_b"]
    for key in ("proximalsolvers", "proximalbase"):
        for field in ("commit", "tree", "version", "package_hash"):
            b[key][field] = a[key][field]
    b["proximalbase"].update(release="registered", tag=a["proximalbase"]["tag"])
    b["harness_hash"] = a["harness_hash"]
    return lock


class GateHistoricalTests(unittest.TestCase):
    """Finding 1: the historical stack is not an official B candidate."""

    @classmethod
    def setUpClass(cls):
        cls.camp = F.build_campaign(fresh("hist"), "migration")
        cls.base = assemble_base(cls.camp, fresh("hist-base") / "base")

    def codes(self, lock):
        return {e.split(":")[0] for e in C.official_gate(lock, facts_for(self.base, lock), FREEZE)}

    def test_the_historical_stack_is_refused_through_the_command(self):
        lock = historical_lock(self.camp)
        facts = facts_for(self.base, lock)
        self.assertEqual(C.parse_lock(lock), lock, "the lock itself is well formed")
        directory = fresh("hist-cli")
        C.write_toml(directory / "lock.toml", lock)
        code, out, err = call_main(["run", "--config", str(directory / "lock.toml"), "--base",
                                    str(directory / "base"), "--official", "--freeze-sha", FREEZE],
                                   hooks=hooks_that_never_run(), facts=lambda *a: facts)
        self.assertEqual((code, out), (2, ""))
        self.assertIn("REFUSED", err)
        self.assertFalse((directory / "base").exists(), "nothing was started")
        self.assertTrue({"PB_B_VERSION", "HISTORICAL_PROXIMALSOLVERS_COMMIT", "HISTORICAL_PROXIMALBASE_TREE",
                         "HISTORICAL_HARNESS_HASH"} <= self.codes(lock))

    def test_each_historical_field_and_the_version_rule(self):
        for key, field in (("proximalsolvers", "commit"), ("proximalsolvers", "tree"), ("proximalbase", "commit"),
                           ("proximalbase", "tree"), ("proximalbase", "package_hash")):
            lock = make_lock(self.camp)
            lock["stack_b"][key][field] = mc.load_schedule(HERE / "schedule.toml")["stack_a"][key][field]
            self.assertIn(f"HISTORICAL_{key.upper()}_{field.upper()}", self.codes(lock), (key, field))
        lock = make_lock(self.camp)
        lock["stack_b"]["harness_hash"] = mc.load_schedule(HERE / "schedule.toml")["stack_a"]["harness_hash"]
        self.assertIn("HISTORICAL_HARNESS_HASH", self.codes(lock))
        for version, accepted in (("0.6.0", True), ("0.6.0-rc1", True), ("0.6", False), ("0.5.4", False),
                                  ("0.7.0", False), ("1.0.0", False), ("v0.6.0", False)):
            lock = make_lock(self.camp)
            lock["stack_b"]["proximalbase"]["version"] = version
            self.assertEqual("PB_B_VERSION" not in self.codes(lock), accepted, version)
        self.assertEqual(self.codes(make_lock(self.camp)), set())


class ObservationTests(unittest.TestCase):
    """Finding 2: the complete observation set is validated; independence is never skipped."""

    @classmethod
    def setUpClass(cls):
        PreflightTests.setUpClass.__func__(cls)

    observations = PreflightTests.observations
    problems = PreflightTests.problems

    def test_a_missing_depot_realpath_and_shared_environments_are_problems_and_no_launch(self):
        def edit(obs):
            del obs[("ab-b", "1.10")]["depot_realpath"]
            obs[("ab-b", "1.10")]["environment"]["dir"] = obs[("ab-a", "1.10")]["environment"]["dir"]
            obs[("ab-b", "1.10")]["environment"]["realpath"] = obs[("ab-a", "1.10")]["environment"]["realpath"]
        problems = self.problems(edit)
        codes = {p.split(":")[0] for p in problems}
        self.assertEqual(codes, {"OBSERVATION", "SHARED"}, problems)
        self.assertTrue(any("depot_realpath is missing" in p for p in problems))
        self.assertTrue(any("environment" in p for p in problems if p.startswith("SHARED")))
        base = assemble_base(self.camp, fresh("obs-base") / "base")
        plan = official_plan(base, self.lock)
        host = Host(self.camp, plan.sched, base)
        host.obs_edits.append(lambda role, mm, obs: obs.pop("depot_realpath")
                              if (role, mm) == ("ab-b", "1.10") else None)
        host.obs_edits.append(lambda role, mm, obs: obs["environment"].update(
            dir=str(plan.roles["ab-a"].environments[mm])) if role == "ab-b" else None)
        with self.assertRaises(C.Refused):
            C.execute(plan, host.hooks())
        self.assertEqual(host.calls, [])
        self.assertFalse((base / "receipt.jsonl").exists())

    def test_every_key_is_required_and_typed(self):
        paths = ["julia.version", "julia.commit", "julia.cpu_name", "ps.commit", "ps.tree", "ps.version", "ps.dirty",
                 "ps.loaded_realpath", "ps.package_hash", "pb.loaded_tree", "pb.manifest_tree", "pb.version",
                 "pb.package_hash", "checkout_realpath", "depot_realpath", "environment.dir",
                 "environment.realpath", "environment.project_exists", "environment.manifest_exists",
                 "manifest_sha256", "project_sha256", "harness_hash", "affinity_cpus", "machine.cpu_model",
                 "machine.cpu", "machine.logical_cpu"]
        for path in paths:
            def remove(obs, path=path):
                target = obs[("ab-a", "1.13")]
                *parents, last = path.split(".")
                for part in parents:
                    target = target[part]
                del target[last]
            problems = self.problems(remove)
            self.assertTrue(any(p.startswith("OBSERVATION") and path in p for p in problems), (path, problems[:3]))

    def test_wrong_types_relative_paths_and_bad_digests(self):
        cases = [("manifest_sha256", "abc"), ("project_sha256", 5), ("depot_realpath", "relative/path"),
                 ("affinity_cpus", [6, "7"]), ("ps", {"dirty": "no"}), ("machine", {"logical_cpu": True})]
        for key, value in cases:
            def edit(obs, key=key, value=value):
                if isinstance(value, dict):
                    obs[("ab-a", "1.10")][key] = dict(obs[("ab-a", "1.10")][key], **value)
                else:
                    obs[("ab-a", "1.10")][key] = value
            self.assertTrue(any(p.startswith("OBSERVATION") for p in self.problems(edit)), key)

    def test_a_missing_or_unknown_role_or_stratum_is_a_problem(self):
        def drop(obs):
            del obs[("aa-b", "1.13")]
        self.assertTrue(any("no observation" in p for p in self.problems(drop)))

        def extra(obs):
            obs[("zz", "1.10")] = obs[("ab-a", "1.10")]
        self.assertTrue(any("not a role or stratum" in p for p in self.problems(extra)))
        self.assertTrue(any(p.startswith("OBSERVATION") for p in C.preflight_checks(self.plan, {})))

    def test_the_project_digest_of_stack_b_is_the_locks(self):
        def edit(obs):
            obs[("ab-b", "1.10")]["project_sha256"] = "0" * 64
        self.assertIn("PROJECT_SHA256", {p.split(":")[0] for p in self.problems(edit)})


class MandatoryHookTests(EngineBase):
    """Finding 3: depot_digest and datahash_ok are required and recorded."""

    def test_omitted_callbacks_are_refusals_before_any_launch(self):
        for name in ("depot_digest", "datahash_ok", "sampler"):
            base, plan, host = self.make()
            with self.assertRaises(C.Refused) as caught:
                C.execute(plan, host.hooks(**{name: None}))
            self.assertEqual(caught.exception.field, "hooks")
            self.assertIn(name, str(caught.exception))
            self.assertEqual(host.calls, [])
            self.assertFalse((base / "logs").exists())
            self.assertFalse((base / "receipt.jsonl").exists())
        base, plan, host = self.make()
        hooks = C.Hooks(probe=host.probe, runner=host.runner, clock=host.clock, sampler=host.sampler,
                        julia_bins=dict(JULIA_BINS))
        with self.assertRaises(C.Refused):
            C.execute(plan, hooks)

    def test_the_digest_is_recorded_before_and_after_every_process(self):
        base, plan, host = self.make()
        C.execute(plan, host.hooks())
        for command in C.read_jsonl(base / "logs" / "commands.jsonl"):
            self.assertEqual(command["depot_digest_before"], "digest-of-the-depot-cache")
            self.assertEqual(command["depot_digest_after"], "digest-of-the-depot-cache")

    def test_a_changed_digest_and_a_corrupted_data_hash_stop_the_run(self):
        base, plan, host = self.make()
        digests = iter(range(100))
        with self.assertRaises(C.Stopped):
            C.execute(plan, host.hooks(depot_digest=lambda spec: next(digests)))
        self.assertEqual(self.state(base)["state"], "stopped")
        record = C.read_jsonl(base / "logs" / "commands.jsonl")[0]
        self.assertNotEqual(record["depot_digest_before"], record["depot_digest_after"])
        base, plan, host = self.make()
        host.datahash = False
        with self.assertRaises(C.Stopped):
            C.execute(plan, host.hooks())
        self.assertEqual(len(self.receipt(base)) - 1, 1)
        self.assertIn("data_hash", self.state(base)["reason"])


class LifecycleTests(EngineBase):
    """Finding 4: once the runner was called, one process event exists whatever follows."""

    def assertOneEvent(self, base, exit_code, complete=False):
        events = self.receipt(base)[1:]
        self.assertEqual(len(events), 1)
        self.assertEqual((events[0]["exit"], events[0]["complete"]), (exit_code, complete))
        self.assertEqual(self.state(base)["state"], "stopped")
        self.assertTrue((base / "checksums.sha256").is_file())
        self.assertEqual(C.read_checksums(base / "checksums.sha256").keys(), set(C.evidence_paths(base)))

    def test_an_error_of_the_machine_sampler_after_the_launch(self):
        base, plan, host = self.make()

        def failing(sample):
            raise OSError("sysfs vanished")
        host.sample_edits.append((3, failing))               # the third read: after the first process
        with self.assertRaises(OSError):
            C.execute(plan, host.hooks())
        self.assertOneEvent(base, 0)
        self.assertIn("OSError", self.state(base)["reason"])
        self.assertEqual(self.state(base)["process"], "AB-A-1.10-rep01")

    def test_an_interrupt_from_the_runner_after_the_launch(self):
        for interrupt in (KeyboardInterrupt(), SystemExit(1)):
            base, plan, host = self.make()
            host.rule(role="ab-a", mm="1.10", interrupt=interrupt)
            with self.assertRaises(type(interrupt)):
                C.execute(plan, host.hooks())
            self.assertOneEvent(base, -1)
            self.assertEqual(len(host.calls), 1)
            document, status = C.verify(base, fresh("v") / "v.json", config=PILOT_FILE)
            self.assertEqual((status, document["state"]), (2, "stopped"))

    def test_an_error_while_the_output_is_written_or_the_digest_is_read(self):
        base, plan, host = self.make()
        calls = []

        def digest(spec):
            calls.append(1)
            if len(calls) == 2:                               # the digest after the first process
                raise RuntimeError("cache unreadable")
            return "d"
        with self.assertRaises(RuntimeError):
            C.execute(plan, host.hooks(depot_digest=digest))
        self.assertOneEvent(base, 0)

    def test_a_runner_that_raised_is_still_one_failed_event(self):
        base, plan, host = self.make()
        host.rule(role="ab-a", mm="1.10", fail_start=True)
        with self.assertRaises(C.Stopped):
            C.execute(plan, host.hooks())
        self.assertOneEvent(base, -1)


class RevisionVerifyTests(unittest.TestCase):
    """Findings 5 to 9 and 11: verify derives what it requires from the archive and never from what exists."""

    @classmethod
    def setUpClass(cls):
        for key, value in shared_full().items():
            setattr(cls, key, value)

    def mutated(self, function, refresh=True):
        base = clone(self.base)
        function(base)
        if refresh:
            refresh_all(base)
        return base

    def failed(self, base, text, replay=True):
        record = fresh("v") / "verification.json"
        document, status = C.verify(base, record, replay=replay)
        self.assertEqual((document["state"], status), ("failed", 2), document["problems"][:5])
        self.assertTrue(record.is_file())
        self.assertTrue(any(text in p for p in document["problems"]), (text, document["problems"][:10]))
        return document

    # -- 5: required arms
    def test_removing_the_aa_arm_everywhere_still_fails(self):
        def drop(b):
            shutil.rmtree(b / "roots" / "aa-a")
            shutil.rmtree(b / "roots" / "aa-b")
            events = [e for e in C.read_jsonl(b / "receipt.jsonl") if e.get("arm") != "AA"]
            writable(b / "receipt.jsonl").write_text("".join(json.dumps(e) + "\n" for e in events))
            seals = writable(b / "logs" / "seals.jsonl")
            seals.write_text("".join(l + "\n" for l in seals.read_text().split("\n") if l and "roots/aa-" not in l))
            path = b / "logs" / "completion.json"
            record = json.loads(path.read_text())
            record.update(processes=32, receipt_sha256=C.sha256_file(b / "receipt.jsonl"))
            write_json(path, record)
        base = self.mutated(drop)
        document = self.failed(base, "the root is missing", replay=False)
        self.assertTrue(any("arm AA" in p and "is missing" in p for p in document["problems"]))
        self.assertTrue(any("counts 32 processes, expected 64" in p for p in document["problems"]))

    def test_a_schedule_edited_to_drop_the_arm_disagrees_with_the_recorded_campaign(self):
        def edit(b):
            edit_text(b / "schedule.toml", lambda t: t.replace('arms = ["AB", "AA"]', 'arms = ["AB"]'))
        self.failed(self.mutated(edit), "schedule.toml of the archive differs from the verifier's", replay=False)

    # -- 6: lock and metadata
    def test_a_deleted_lock(self):
        base = self.mutated(lambda b: (b / "lock.toml").unlink())
        self.failed(base, "lock.toml is missing from the tree of an official attempt", replay=False)

    def test_a_changed_b_identity_with_a_cleared_approval(self):
        def edit(b):
            edit_text(b / "lock.toml", lambda t: t.replace(f'G8 = "{URL}"', 'G8 = ""'))
            edit_text(b / "roots/ab-b/stack-identity.toml", lambda t: t.replace(
                self.camp.stack("b")["ps"]["commit"], "7" * 40))
            for rep in (1, 2):
                path = b / f"roots/ab-b/julia-1.10/raw/julia-1.10.13-rep{rep:02d}-metadata.toml"
                edit_text(path, lambda t: t.replace(self.camp.stack("b")["ps"]["hash"], "8" * 40))
        base = self.mutated(edit)
        document = self.failed(base, "APPROVAL_G8", replay=False)
        for text in ("stack-identity.toml: proximalsolvers.commit differs from the lock",
                     "metadata proximalsolvers_hash differs from the lock",
                     "lock.toml differs from the digest recorded"):
            self.assertTrue(any(text in p for p in document["problems"]), (text, document["problems"][:6]))

    def test_a_changed_manifest_or_project_digest_of_stack_b(self):
        def edit(b):
            edit_text(b / "roots/ab-b/julia-1.13/Project.toml", lambda t: t + "\n# changed\n")
        self.failed(self.mutated(edit), "differs from the lock's SHA-256", replay=False)

    def test_a_completion_record_with_unrelated_ids_and_an_unknown_schema(self):
        def edit(b):
            path = b / "logs" / "completion.json"
            record = json.loads(path.read_text())
            record.update(schema=99, campaign_id="other", session_id="session-x", schedule_id="elsewhere")
            write_json(path, record)
        document = self.failed(self.mutated(edit), "logs/completion.json: schema is not 1", replay=False)
        for key in ("campaign_id", "session_id", "schedule_id"):
            self.assertTrue(any(f"logs/completion.json: {key}" in p for p in document["problems"]), key)

    def test_ids_across_the_archive_must_agree(self):
        def edit(b):
            edit_text(b / "roots/ab-a/stack-identity.toml", lambda t: t.replace(SESSION, "session-0"))
            edit_text(b / "logs/STATE.json", lambda t: t.replace('"schema": 1', '"schema": 2'))
            events = C.read_jsonl(b / "receipt.jsonl")
            events[0]["session_id"] = "session-1"
            writable(b / "receipt.jsonl").write_text("".join(json.dumps(e) + "\n" for e in events))
        document = self.failed(self.mutated(edit), "stack-identity.toml: session_id differs", replay=False)
        for text in ("logs/STATE.json: schema is not 1", "receipt.jsonl: session_id of the campaign event"):
            self.assertTrue(any(text in p for p in document["problems"]), text)

    # -- 7: seal coverage and mode
    def test_only_the_completion_seal_and_writable_records(self):
        def edit(b):
            seals = writable(b / "logs" / "seals.jsonl")
            seals.write_text("".join(l + "\n" for l in seals.read_text().split("\n") if '"logs/completion.json"' in l))
            for path in (b / "roots").glob("*/julia-*/raw/*"):
                path.chmod(0o644)
        document = self.failed(self.mutated(edit), "seal coverage", replay=False)
        self.assertTrue(any("has no seal" in p for p in document["problems"]))
        self.assertTrue(any("not mode 0444" in p for p in document["problems"]))

    def test_removed_duplicate_extra_and_misbound_seals(self):
        def lines(b):
            return [l for l in (b / "logs" / "seals.jsonl").read_text().split("\n") if l]

        def write(b, items):
            writable(b / "logs" / "seals.jsonl").write_text("".join(l + "\n" for l in items))
        self.failed(self.mutated(lambda b: write(b, lines(b)[5:])), "has no seal", replay=False)
        self.failed(self.mutated(lambda b: write(b, lines(b) + lines(b)[:1])), "has 2 seals", replay=False)

        def extra(b):
            C.create_exclusive(b / "logs" / "stray.txt", "x")
            write(b, lines(b) + [json.dumps({"file": "logs/stray.txt", "sha256": C.sha256_file(b / "logs/stray.txt"),
                                             "size": 1, "process": "x"})])
        self.failed(self.mutated(extra), "sealed but not a required file", replay=False)

        def misbound(b):
            first = json.loads(lines(b)[0])
            first["process"] = "AB-B-1.13-rep08"
            write(b, [json.dumps(first)] + lines(b)[1:])
        self.failed(self.mutated(misbound), "is sealed for", replay=False)

    # -- 8: sidecar and fingerprint coverage
    def test_header_only_sidecars_and_fingerprint_files(self):
        for name, header in ((C.DATAHASH_NAME, C.DATAHASH_HEADER), (C.FP_NAME, mc.FP_HEADER)):
            for role in ("ab-a", "ab-b"):
                def edit(b, name=name, header=header, role=role):
                    writable(b / "roots" / role / name).write_text(header + "\n")
                document = self.failed(self.mutated(edit), f"{role}: {name}", replay=False)
                self.assertGreater(len(document["problems"]), 100, "every expected key is reported")

    def test_malformed_duplicate_extra_rows_and_headers(self):
        def sidecar(change):
            def edit(b):
                path = b / "roots/ab-a" / C.DATAHASH_NAME
                lines = path.read_text().split("\n")
                writable(path).write_text("\n".join(change(lines)))
            return edit
        self.failed(self.mutated(sidecar(lambda l: l + [l[1]])), "duplicate row", replay=False)
        self.failed(self.mutated(sidecar(lambda l: l[:-1] + ["9.9.9\tx\t1\tabc", ""])), "not a declared", replay=False)
        self.failed(self.mutated(sidecar(lambda l: l[:-2] + ["one\ttwo", ""])), "fields", replay=False)
        self.failed(self.mutated(sidecar(lambda l: ["julia\tid\trep\tdatahash"] + l[1:])), "wrong header",
                    replay=False)

        def fingerprints(change):
            def edit(b):
                path = b / "roots/ab-b" / C.FP_NAME
                lines = path.read_text().split("\n")
                writable(path).write_text("\n".join(change(lines)))
            return edit
        self.failed(self.mutated(fingerprints(lambda l: l[:-1] + [l[1], ""])), "duplicate row", replay=False)
        self.failed(self.mutated(fingerprints(lambda l: l[:-1] + ["9.9.9\tx\t1\tfixture\tX\t" + "0" * 64, ""])),
                    "not a declared", replay=False)
        self.failed(self.mutated(fingerprints(lambda l: l[:-1] + [
            l[1].rsplit("\t", 1)[0] + "\tnot-a-hash", ""])), "neither 64 hex nor none", replay=False)
        self.failed(self.mutated(fingerprints(lambda l: ["julia\tid\trep\tkind\tname"] + l[1:])), "wrong header",
                    replay=False)

    # -- 9: symlinks
    def test_a_symlinked_raw_directory(self):
        def edit(b):
            raw = b / "roots/ab-a/julia-1.10/raw"
            outside = fresh("outside") / "raw"
            shutil.copytree(raw, outside)
            shutil.rmtree(raw)
            os.symlink(outside, raw)
        base = self.mutated(edit)
        document = self.failed(base, "roots/ab-a/julia-1.10/raw is a symbolic link", replay=False)
        self.assertTrue(any("seal coverage" in p or "checksums" in p for p in document["problems"]),
                        "the files behind the link are not in the inventory")

    def test_a_symlinked_base_or_ancestor_directory(self):
        link = fresh("linked") / "base-link"
        os.symlink(self.base, link)
        document, status = C.verify(link, fresh("v") / "v.json", replay=False)
        self.assertEqual(status, 2)
        self.assertTrue(any("the base directory is a symbolic link" in p for p in document["problems"]))
        self.failed(self.mutated(lambda b: os.symlink(b / "logs", b / "comparison" / "logs-link")),
                    "comparison/logs-link is a symbolic link", replay=False)

    def test_a_mandatory_file_missing_from_the_inventory(self):
        def edit(b):
            path = writable(b / "checksums.sha256")
            path.write_text("".join(l + "\n" for l in path.read_text().split("\n") if l and "logs/hardware" not in l))
        base = clone(self.base)
        edit(base)
        document, status = C.verify(base, fresh("v") / "v.json", replay=False)
        self.assertEqual(status, 2)
        self.assertTrue(any("mandatory file logs/hardware.jsonl is not in the inventory" in p
                            for p in document["problems"]))

    # -- 11: replay triples
    def test_the_replay_compares_refusal_details_on_a_copy(self):
        camp = F.build_campaign(fresh("triples"), "migration")
        camp.stack("b")["checkout"] = camp.stack("a")["checkout"]
        camp.rebuild_root("b")
        base, _, code, _, _ = run_full(camp, name="triples-run")
        self.assertEqual(code, 2)
        stored = C.comparison_summary(base / "comparison")
        self.assertTrue(stored["triples"] and all(len(t) == 3 for t in stored["triples"]))
        self.assertFalse(any("<a>" in t[2] or "<b>" in t[2] for t in stored["triples"]), "labels are normalised")
        copy_ = clone(base)
        document, status = C.verify(copy_, fresh("v") / "v.json")
        self.assertEqual((status, document["state"], document["problems"]), (2, "refused", []))
        edit_text(copy_ / "comparison" / "refusals.json", lambda t: t.replace("checkout", "checkoutX", 1))
        C.write_checksums(copy_)
        refresh_seals(copy_)
        document, _ = C.verify(copy_, fresh("v") / "v.json")
        self.assertTrue(any("refusals of the replay differ" in p for p in document["problems"]))


class PilotConfigCopyTests(unittest.TestCase):
    """Finding 6, pilot: the stored configuration is bound to the attempt."""

    def test_the_pilot_config_copy_is_kept_and_checked(self):
        camp = F.build_campaign(fresh("pc"), "identical", reps=1, schedule_edit=pilot_edit)
        base = assemble_base(camp, fresh("pc-base") / "x-pilot", aa=False)
        directory = fresh("pc-cfg")
        C.write_toml(directory / "p.toml", pilot_config())
        host = Host(camp, mc.load_schedule(base / "schedule.toml"), base)
        code, _, err = call_main(["pilot", "--config", str(directory / "p.toml"), "--base", str(base)],
                                 hooks=host.hooks())
        self.assertEqual(code, 0, err)
        self.assertEqual((base / "pilot-config.toml").read_bytes(), (directory / "p.toml").read_bytes())
        document, status = C.verify(base, fresh("v") / "v.json", config=directory / "p.toml")
        self.assertEqual((status, document["problems"]), (0, []))
        bad = clone(base)
        edit_text(bad / "pilot-config.toml", lambda t: t.replace("stage2b-pilot-v1", "stage2b-pilot-v2"))
        refresh_all(bad)
        document, status = C.verify(bad, fresh("v") / "v.json", replay=False, config=directory / "p.toml")
        self.assertEqual(status, 2)
        self.assertTrue(any("pilot-config.toml" in p for p in document["problems"]))


class DeclaredScopeTests(unittest.TestCase):
    """Finding 10: scopes are validated against the schedule, never pruned."""

    @classmethod
    def setUpClass(cls):
        DeclaredDifferencesTests.setUpClass.__func__(cls)

    def test_an_unknown_stratum_is_refused_and_never_pruned(self):
        lock = copy.deepcopy(self.lock)
        lock["declared"][0]["julia"] = ["1.10", "9.99"]
        with self.assertRaises(C.LockRefusal) as caught:
            C.declared_differences(self.base, lock)
        self.assertEqual(caught.exception.field, "declared[1].julia")
        self.assertIn("9.99", str(caught.exception))
        with self.assertRaises(C.LockRefusal):
            C.parse_lock(lock, strata=["1.10", "1.13"])
        lock["declared"][0]["julia"] = ["1.10", "1.10"]
        with self.assertRaises(C.LockRefusal):
            C.parse_lock(lock, strata=["1.10", "1.13"])
        compat = next(i for i, e in enumerate(self.lock["declared"]) if e["kind"] == "compat")
        lock = copy.deepcopy(self.lock)
        lock["declared"][compat]["julia"] = ["9.99"]
        with self.assertRaises(C.LockRefusal) as caught:
            C.declared_differences(self.base, lock)
        self.assertEqual(caught.exception.field, f"declared[{compat + 1}].julia")

    def test_a_scope_in_a_stratum_where_the_difference_is_absent_is_refused(self):
        camp = F.build_campaign(fresh("scope"), "manifest")
        lock = make_lock(camp)
        base = assemble_base(camp, fresh("scope-base") / "base", with_raw=True)
        added = next(e for e in lock["declared"] if e["kind"] == "manifest" and e["name"] == "NewDep")
        self.assertEqual(added["julia"], ["1.13"])
        added["julia"] = ["1.10", "1.13"]
        with self.assertRaises(C.DeclaredRefusal) as caught:
            C.declared_differences(base, lock)
        self.assertIn("where it is not observed", " ".join(caught.exception.problems))
        del added["julia"]
        with self.assertRaises(C.DeclaredRefusal):
            C.declared_differences(base, lock)


# ------------------------------------------------------------------------------------ revision 2

class DepotContinuityTests(EngineBase):
    """The depot caches stay frozen between processes of one installation, not only during them."""

    @staticmethod
    def per_role(values):
        """A depot_digest hook: the read number n (per installation) returns values[n // 2]."""
        reads = {}

        def hook(spec):
            n = reads.get(spec.name, 0)
            reads[spec.name] = n + 1
            return values[min(n // 2, len(values) - 1)]
        return hook

    def test_a_change_between_two_processes_of_a_role_stops_the_run(self):
        base, plan, host = self.make()
        with self.assertRaises(C.Stopped) as caught:
            C.execute(plan, host.hooks(depot_digest=self.per_role(["cache-0", "cache-1"])))
        self.assertIn("between processes", str(caught.exception))
        self.assertEqual(len(host.calls), 2, "the order is A,B,A,B: ab-a's second process is not launched")
        events = self.receipt(base)[1:]
        self.assertEqual(len(events), 2)
        self.assertEqual(self.state(base)["state"], "stopped")
        self.assertIn("between processes", self.state(base)["reason"])
        commands = C.read_jsonl(base / "logs" / "commands.jsonl")
        self.assertEqual(commands[-1]["launched"], False)
        self.assertEqual((commands[-1]["depot_digest_expected"], commands[-1]["depot_digest_before"]),
                         ("cache-0", "cache-1"))
        self.assertTrue(all(e["complete"] for e in events), "the processes that ran were honest and complete")
        self.assertFalse((base / "logs" / "completion.json").exists())

    def test_an_unchanged_cache_is_recorded_as_continuous(self):
        base, plan, host = self.make()
        C.execute(plan, host.hooks())
        commands = C.read_jsonl(base / "logs" / "commands.jsonl")
        self.assertEqual([c["depot_digest_continuous"] for c in commands], [True] * 4)
        by_role = {}
        for command in commands:
            role = "ab-a" if "-A-" in command["process"] else "ab-b"
            self.assertEqual(command["depot_digest_expected"], by_role.get(role), command["process"])
            by_role[role] = command["depot_digest_after"]

    def test_a_prepared_baseline_binds_the_first_launch_of_a_role(self):
        base, plan, host = self.make()
        (base / "logs").mkdir()
        (base / "logs" / "depot-baselines.json").write_text(json.dumps({"ab-b": "prepared"}))
        with self.assertRaises(C.Stopped):
            C.execute(plan, host.hooks())
        self.assertEqual(len(host.calls), 1, "ab-a ran, ab-b's first launch was refused by its baseline")
        base, plan, host = self.make()
        (base / "logs").mkdir()
        (base / "logs" / "depot-baselines.json").write_text(json.dumps({"ab-a": "digest-of-the-depot-cache"}))
        self.assertEqual(C.execute(plan, host.hooks()).exit_code, 0)


def two_stratum_camp(name):
    """A full set in which StatsBase changes 1.9.0 -> 2.0.0 in Julia 1.10 and 1.9.0 -> 3.0.0 in Julia 1.13, and its
    compat entry 1 -> 2 and 1 -> 3, with a lock that declares each change in its own stratum."""
    camp = F.build_campaign(fresh(name), "migration")
    for jkey, version in (("1.10", "2.0.0"), ("1.13", "3.0.0")):
        directory = camp.stratum("b", jkey)
        edit_text(directory / "Manifest.toml", lambda t, v=version: t.replace('version = "1.9.0"', f'version = "{v}"'))
        edit_text(directory / "Project.toml", lambda t, v=version[0]: t.replace('StatsBase = "1"', f'StatsBase = "{v}"'))
    lock = make_lock(camp)
    uuid = tomllib.loads((camp.stratum("b", "1.10") / "Manifest.toml").read_text())["deps"]["StatsBase"][0]["uuid"]
    for jkey in ("1.10", "1.13"):
        lock["declared"].append({"kind": "manifest", "name": "StatsBase", "uuid": uuid, "change": "changed",
                                 "reason": f"StatsBase in {jkey}", "approval_url": URL, "julia": [jkey]})
        lock["declared"].append({"kind": "compat", "name": "StatsBase", "reason": f"compat in {jkey}",
                                 "approval_url": URL, "julia": [jkey]})
    return camp, lock


class DisjointStratumTests(unittest.TestCase):
    """A dependency that changes to different values in different strata is declared per stratum."""

    @classmethod
    def setUpClass(cls):
        cls.camp, cls.lock = two_stratum_camp("disjoint")
        cls.base = assemble_base(cls.camp, fresh("disjoint-base") / "base", session="session-0001", with_raw=True)
        shutil.copyfile(cls.camp.receipt, cls.base / "receipt.jsonl")

    def test_the_driver_accepts_it_and_the_comparator_agrees(self):
        declared = C.write_declared_differences(self.base, self.lock)
        rows = [r for r in declared["manifest"] if r["name"] == "StatsBase"]
        self.assertEqual([(r["julia"], r["a_version"], r["b_version"], r["reason"]) for r in rows],
                         [(["1.10"], "1.9.0", "2.0.0", "StatsBase in 1.10"),
                          (["1.13"], "1.9.0", "3.0.0", "StatsBase in 1.13")])
        compat = [r for r in declared["compat"] if r["name"] == "StatsBase"]
        self.assertEqual([(r["julia"], r["a"], r["b"], r["reason"]) for r in compat],
                         [(["1.10"], "1", "2", "compat in 1.10"), (["1.13"], "1", "3", "compat in 1.13")])
        code, stderr = C.run_comparator(self.base, fresh("disjoint-out") / "out")
        self.assertEqual(code, 0, stderr)
        self.assertNotIn("UNDECLARED", stderr)

    def test_every_refusal_still_applies(self):
        def lock_with(function):
            lock = copy.deepcopy(self.lock)
            function(lock)
            return lock

        def refused(lock, text):
            with self.assertRaises(C.Refused) as caught:
                C.declared_differences(self.base, lock)
            self.assertIn(text, " ".join(caught.exception.problems) + str(caught.exception))
        for kind in ("manifest", "compat"):
            indexes = [i for i, e in enumerate(self.lock["declared"]) if e["kind"] == kind and e["name"] == "StatsBase"]
            refused(lock_with(lambda l: l["declared"].pop(indexes[1])), "observed, but the lock has no reason")
            refused(lock_with(lambda l: l["declared"][indexes[0]].update(julia=["1.10", "1.13"])), "declared twice")
            refused(lock_with(lambda l: l["declared"][indexes[0]].update(julia=["9.99"])), "9.99")
            refused(lock_with(lambda l: l["declared"].append(dict(l["declared"][indexes[0]]))), "declared twice")
        manifest = next(i for i, e in enumerate(self.lock["declared"]) if e["kind"] == "manifest" and e["name"] == "ProximalBase")
        refused(lock_with(lambda l: l["declared"][manifest].update(julia=["1.10"])), "observed, but the lock has no reason")

    def test_an_unscoped_declaration_over_different_values_is_split_into_value_groups(self):
        lock = copy.deepcopy(self.lock)
        lock["declared"] = [e for e in lock["declared"] if not (e["name"] == "StatsBase" and e["kind"] == "manifest")]
        uuid = next(e for e in self.lock["declared"] if e["name"] == "StatsBase" and e["kind"] == "manifest")["uuid"]
        lock["declared"].append({"kind": "manifest", "name": "StatsBase", "uuid": uuid, "change": "changed",
                                 "reason": "all", "approval_url": URL})
        rows = [r for r in C.declared_differences(self.base, lock)["manifest"] if r["name"] == "StatsBase"]
        self.assertEqual([(r["julia"], r["b_version"]) for r in rows], [(["1.10"], "2.0.0"), (["1.13"], "3.0.0")])


# ------------------------------------------------------------------------------------ revision 3: the ruling

_PILOT = {}


def shared_pilot():
    """A reduced pilot (one repetition, AB only) run through `main pilot`, with its configuration."""
    if not _PILOT:
        camp = F.build_campaign(fresh("sp"), "identical", reps=1, schedule_edit=pilot_edit)
        base = assemble_base(camp, fresh("sp-base") / "x-pilot", aa=False)
        host = Host(camp, mc.load_schedule(base / "schedule.toml"), base)
        code, out, err = call_main(["pilot", "--config", str(PILOT_FILE), "--base", str(base)], hooks=host.hooks())
        assert code == 0, err
        _PILOT["base"] = base
    return _PILOT["base"]


def read_json(path):
    return json.loads(Path(path).read_text())


def write_json(path, data):
    writable(path).write_text(json.dumps(data, indent=2) + "\n")
    if Path(path).name == "completion.json":                  # a sealed record stays read-only: one guard per control
        os.chmod(path, 0o444)


def rebind(base, **campaign_changes):
    """Edit logs/campaign.json (None deletes a key) and regenerate every digest that refers to it, the completion
    record, the seals and the checksums, so that only the guard under test can object."""
    base = Path(base)
    campaign = read_json(base / "logs" / "campaign.json")
    for key, value in campaign_changes.items():
        if value is None:
            campaign.pop(key, None)
        else:
            campaign[key] = value
    write_json(base / "logs" / "campaign.json", campaign)
    completion = read_json(base / "logs" / "completion.json")
    completion["campaign_sha256"] = C.sha256_file(base / "logs" / "campaign.json")
    completion["schedule_sha256"] = C.sha256_file(base / "schedule.toml")
    completion["case_mapping_sha256"] = C.sha256_file(base / "case-mapping.toml")
    for key, name in (("lock_sha256", "lock.toml"), ("pilot_config_sha256", "pilot-config.toml")):
        if key in completion and (base / name).is_file():
            completion[key] = C.sha256_file(base / name)
    write_json(base / "logs" / "completion.json", completion)
    refresh_all(base)


class ModeTests(unittest.TestCase):
    """The ruling: mode comes from the identity, the schedule from the verifier, the files are bound."""

    @classmethod
    def setUpClass(cls):
        for key, value in shared_full().items():
            setattr(cls, key, value)
        cls.pilot = shared_pilot()

    def mutated(self, function, *, base=None):
        copy_ = clone(base or self.base)
        function(copy_)
        return copy_

    def failed(self, base, texts, config=None, replay=False, state="failed"):
        record = fresh("v") / "verification.json"
        document, status = C.verify(base, record, replay=replay, config=config)
        self.assertEqual((document["state"], status), (state, 2), document["problems"][:6])
        self.assertEqual(json.loads(record.read_text())["problems"], document["problems"])
        for text in ([texts] if isinstance(texts, str) else texts):
            self.assertTrue(any(text in p for p in document["problems"]), (text, document["problems"][:8]))
        self.assertNotIn(document["state"], ("verified", "pilot_verified"))
        return document

    # -- downgrades of an official attempt
    def test_downgrade_official_false_and_no_lock(self):
        base = self.mutated(lambda b: ((b / "lock.toml").unlink(), rebind(b, official=False)))
        self.failed(base, ["logs/campaign.json: official is False", "lock.toml is missing from the tree"])

    def test_downgrade_missing_official_field_and_no_lock(self):
        base = self.mutated(lambda b: ((b / "lock.toml").unlink(), rebind(b, official=None)))
        self.failed(base, ["logs/campaign.json: official is None", "lock.toml is missing from the tree"])

    def test_downgrade_malformed_mode_and_a_pilot_config_in_place_of_the_lock(self):
        base = self.mutated(lambda b: ((b / "lock.toml").unlink(), rebind(b, official="false")))
        self.failed(base, ["official is 'false'", "lock.toml is missing"])
        base = self.mutated(lambda b: ((b / "lock.toml").unlink(), add_pilot_config(b), rebind(b)))
        self.failed(base, ["pilot-config.toml exists in the tree of an official attempt",
                           "lock.toml is missing"])
        base = self.mutated(lambda b: rebind(b, official=1))
        self.failed(base, "official is 1")

    def test_a_contradictory_or_unknown_identity_is_a_problem(self):
        official = mc.load_schedule(HERE / "schedule.toml")
        self.assertEqual(C.classify_mode(official, [(official["campaign_id"], official["id"])]), ("official", []))
        self.assertEqual(C.classify_mode(official, [("x-pilot-v1", "y-pilot-v1")])[0], "pilot")
        for pairs, text in (([(official["campaign_id"], "z-pilot")], "mixes"),
                            ([("a-pilot", official["id"])], "mixes"),
                            ([("plain", "other")], "neither official nor a pilot"),
                            ([("a-pilot", "plain")], "neither official nor a pilot"),
                            ([(official["campaign_id"], official["id"]), ("a-pilot", "b-pilot")], "disagree"),
                            ([(None, None)], "neither")):
            mode, problems = C.classify_mode(official, pairs)
            self.assertIsNone(mode, pairs)
            self.assertTrue(any(text in p for p in problems), (pairs, problems))

        def mixed(b):
            edit_text(b / "schedule.toml", lambda t: t.replace('campaign_id = "pb06-migration-stage2b-v1"',
                                                               'campaign_id = "pb06-migration-stage2b-pilot-v1"'))
        document = self.failed(self.mutated(mixed), "mixes the official and the pilot names")
        self.assertIsNone(document["mode"])

    # -- schedule reference
    def test_an_altered_archived_schedule_with_the_recorded_digest_kept(self):
        def edit(b):
            edit_text(b / "schedule.toml", lambda t: t + "\n# edited\n")
            refresh_all(b)
        self.failed(self.mutated(edit), ["schedule.toml of the archive differs from the verifier's schedule.toml",
                                         "logs/completion.json: schedule_sha256 is not the digest of schedule.toml"])

    def test_a_recorded_schedule_digest_that_is_not_the_verifiers(self):
        self.failed(self.mutated(lambda b: rebind(b, schedule_sha256="0" * 64)),
                    "schedule_sha256 is not the digest of the verifier's schedule.toml")

    def test_the_verifiers_schedule_must_be_tracked_and_unmodified(self):
        for failing in (["ls-files"], ["diff"]):
            def run(argv, **kw):
                if failing[0] in argv:
                    return subprocess.CompletedProcess(argv, 1, "", "")
                return subprocess.run(argv, **kw)
            document, status = C.verify(clone(self.base), fresh("v") / "v.json", replay=False, run=run)
            self.assertEqual((document["state"], status), ("failed", 2))
            self.assertTrue(any("verifier's schedule.toml" in p for p in document["problems"]), document["problems"])
        self.assertEqual(C.verifier_schedule_problems(), [], "the repository's schedule.toml is tracked and clean")

        def broken(argv, **kw):
            raise OSError("no git")
        self.assertTrue(C.verifier_schedule_problems(broken))

    def test_the_coordinated_schedule_downgrade_fails_against_the_trusted_schedule(self):
        def downgrade(b):
            shutil.rmtree(b / "roots" / "aa-a")
            shutil.rmtree(b / "roots" / "aa-b")
            writable(b / "receipt.jsonl").write_text("".join(
                json.dumps(e) + "\n" for e in C.read_jsonl(b / "receipt.jsonl") if e.get("arm") != "AA"))
            seals = writable(b / "logs" / "seals.jsonl")
            seals.write_text("".join(l + "\n" for l in seals.read_text().split("\n") if l and "roots/aa-" not in l))
            edit_text(b / "schedule.toml", lambda t: t.replace('arms = ["AB", "AA"]', 'arms = ["AB"]'))
            completion = read_json(b / "logs" / "completion.json")
            completion.update(processes=32, receipt_sha256=C.sha256_file(b / "receipt.jsonl"))
            write_json(b / "logs" / "completion.json", completion)
            rebind(b, arms=["AB"], schedule_sha256=C.sha256_file(b / "schedule.toml"))
        base = self.mutated(downgrade)
        document = self.failed(base, ["schedule.toml of the archive differs from the verifier's schedule.toml",
                                      "schedule_sha256 is not the digest of the verifier's schedule.toml",
                                      "the root is missing"])
        self.assertTrue(any("counts 32 processes, expected 64" in p for p in document["problems"]))
        # with the archive's own schedule the same tree is internally consistent: only the reference catches it
        self.assertEqual(sorted(C.schedule_arms(base)), ["AB"])

    # -- configuration digests
    def test_a_changed_lock_or_campaign_record_without_a_valid_completion_binding(self):
        def lock(b):
            edit_text(b / "lock.toml", lambda t: t + "\n# changed\n")
            refresh_all(b)
        self.failed(self.mutated(lock), ["logs/completion.json: lock_sha256 is not the digest of lock.toml",
                                        "lock.toml differs from the digest recorded in logs/campaign.json"])

        def campaign(b):
            write_json(b / "logs" / "campaign.json", dict(read_json(b / "logs" / "campaign.json"), note="x"))
            refresh_all(b)
        self.failed(self.mutated(campaign), "logs/completion.json: campaign_sha256 is not the digest of "
                                            "logs/campaign.json")

        def completion(b):
            record = read_json(b / "logs" / "completion.json")
            record["pilot_config_sha256"] = "0" * 64
            write_json(b / "logs" / "completion.json", record)
            refresh_all(b)
        self.failed(self.mutated(completion), "pilot_config_sha256 does not apply to this attempt")

    def test_a_changed_pilot_configuration_without_a_valid_completion_binding(self):
        def edit(b):
            edit_text(b / "pilot-config.toml", lambda t: t + "\n# changed\n")
            refresh_all(b)
        self.failed(self.mutated(edit, base=self.pilot), ["logs/completion.json: pilot_config_sha256 is not the "
                                                          "digest of pilot-config.toml",
                                                          "pilot-config.toml differs from the digest recorded"],
                    config=PILOT_FILE)

    # -- pilots
    def test_a_clean_pilot_verifies_only_as_a_pilot(self):
        record = fresh("v") / "v.json"
        document, status = C.verify(self.pilot, record, config=PILOT_FILE)
        self.assertEqual((status, document["state"], document["mode"], document["problems"]),
                         (0, "pilot_verified", "PILOT / NON-OFFICIAL", []))
        self.assertEqual(read_json(record)["mode"], "PILOT / NON-OFFICIAL")
        self.assertEqual(read_json(self.pilot / "logs" / "campaign.json")["official"], False)
        document, _ = C.verify(self.base, fresh("v") / "v.json", config=PILOT_FILE)
        self.assertEqual((document["state"], document["mode"]), ("verified", "OFFICIAL"),
                         "a supplied configuration is ignored for an official attempt")

    def test_pilot_completeness(self):
        pilot = self.pilot
        self.failed(self.mutated(lambda b: ((b / "pilot-config.toml").unlink(), refresh_all(b)), base=pilot),
                    "pilot-config.toml is missing from the tree of a pilot attempt", config=PILOT_FILE)
        self.failed(self.mutated(lambda b: (writable(b / "pilot-config.toml").write_text("not toml ["),
                                            rebind(b)), base=pilot),
                    ["pilot-config.toml differs from the configuration supplied"], config=PILOT_FILE)
        garbage = fresh("garbage") / "p.toml"
        garbage.write_text("not toml [")
        self.failed(self.mutated(lambda b: (shutil.copyfile(garbage, writable(b / "pilot-config.toml")), rebind(b)),
                                 base=pilot), "pilot configuration:", config=garbage)
        for change in (dict(official=True), dict(official=None), dict(official="false")):
            self.failed(self.mutated(lambda b, c=change: rebind(b, **c), base=pilot),
                        "logs/campaign.json: official is", config=PILOT_FILE)
        other = fresh("other") / "p.toml"
        C.write_toml(other, dict(pilot_config(), pilot={"arms": ["AB"]}, campaign={
            "id": "pb06-migration-stage2b-pilot-v1", "session_id": "session-20261201T080000Z-ffff"}))
        self.failed(clone(pilot), "differs from the configuration supplied with --config", config=other)
        self.failed(clone(pilot), "a pilot needs --config")
        code, out, err = call_main(["verify", "--base", str(pilot), "--out", str(fresh("v") / "v.json")])
        self.assertEqual(code, 2)
        self.assertIn("PILOT / NON-OFFICIAL", out)

    def test_a_pilot_schedule_must_match_its_configuration(self):
        def edit(b):
            edit_text(b / "schedule.toml", lambda t: t.replace("stage2b-pilot-v1", "stage2b-pilot-v9"))
            rebind(b, schedule_id="stage2b-pilot-v9")
        self.failed(self.mutated(edit, base=self.pilot), "pilot configuration: the ids differ", config=PILOT_FILE)
        self.failed(self.mutated(lambda b: rebind(b, schedule_sha256="1" * 64), base=self.pilot),
                    "schedule_sha256 is not the digest of the archived schedule.toml", config=PILOT_FILE)

    def test_a_pilot_never_satisfies_the_official_gate(self):
        directory = fresh("pilot-gate")
        code, out, err = call_main(["run", "--config", str(PILOT_FILE), "--base", str(directory / "base"),
                                    "--official", "--freeze-sha", FREEZE], hooks=hooks_that_never_run(),
                                   facts=lambda *a: self.fail("the gate must not be reached"))
        self.assertEqual((code, out), (2, ""))
        self.assertIn("REFUSED", err)
        self.assertFalse((directory / "base").exists())
        with self.assertRaises(C.LockRefusal):
            C.load_lock(PILOT_FILE)
        lock = make_lock(self.camp)
        lock["campaign"]["id"] = "pb06-migration-stage2b-pilot-v1"
        with self.assertRaises(C.Refused):                       # a pilot-named campaign cannot become a plan
            C.plan_from_lock(lock, assemble_base(self.camp, fresh("pg") / "base"), JULIA_BINS, ENVIRON, FREEZE)

    # -- portable retrieval
    def test_a_portable_copy_verifies_without_installations_or_depots(self):
        target = fresh("portable")
        subprocess.run(["cp", "-a", str(self.base), str(target / "extracted")], check=True)
        self.assertFalse([p for p in (target / "extracted").iterdir() if p.name in C.PRIVATE_DIRECTORIES])
        document, status = C.verify(target / "extracted", fresh("v") / "v.json")
        self.assertEqual((status, document["state"], document["problems"]), (0, "verified", []))
        import tarfile
        archive = fresh("tar") / "attempt.tar"
        with tarfile.open(archive, "w") as handle:
            handle.add(self.base, arcname="attempt")
        where = fresh("tar-out")
        with tarfile.open(archive) as handle:
            handle.extractall(where, filter="tar")
        document, status = C.verify(where / "attempt", fresh("v") / "v.json")
        self.assertEqual((status, document["state"], document["problems"]), (0, "verified", []))
        pilot_copy = fresh("pilot-portable") / "x-pilot"
        subprocess.run(["cp", "-a", str(self.pilot), str(pilot_copy)], check=True)
        document, status = C.verify(pilot_copy, fresh("v") / "v.json", config=PILOT_FILE)
        self.assertEqual((status, document["state"]), (0, "pilot_verified"))

    def test_the_official_state_and_mode_of_the_full_shape_tree(self):
        self.assertEqual((self.document["state"], self.document["mode"]), ("verified", "OFFICIAL"))
        completion = read_json(self.base / "logs" / "completion.json")
        campaign = read_json(self.base / "logs" / "campaign.json")
        self.assertIs(campaign["official"], True)
        self.assertEqual(completion["schedule_sha256"], C.sha256_file(HERE / "schedule.toml"))
        self.assertEqual(completion["campaign_sha256"], C.sha256_file(self.base / "logs" / "campaign.json"))
        self.assertEqual(completion["lock_sha256"], C.sha256_file(self.base / "lock.toml"))
        self.assertNotIn("pilot_config_sha256", completion)


# ------------------------------------------------------------------------------------ revision 4: A2 and the rest

def regenerate_comparison(base):
    """Re-run the comparator on the archive and replace comparison/, comparator.json and the completion's exit,
    as someone rewriting the evidence consistently would (the internal checksums and seals are refreshed after)."""
    scratch = fresh("regen") / "out"
    code, _ = C.run_comparator(base, scratch)
    shutil.rmtree(Path(base) / "comparison")
    shutil.copytree(scratch, Path(base) / "comparison")
    write_json(Path(base) / "logs" / "comparator.json", {"schema": 1, "exit": code, "stderr": ""})
    completion = read_json(Path(base) / "logs" / "completion.json")
    completion["comparator_exit"] = code
    write_json(Path(base) / "logs" / "completion.json", completion)
    return code


class PolicyTests(unittest.TestCase):
    """Ruling A2: the trusted policy set (schedule, case mapping, held pilot configuration), a closed inventory of
    policy files, and replayed outputs. All through the real `verify`."""

    @classmethod
    def setUpClass(cls):
        for key, value in shared_full().items():
            setattr(cls, key, value)
        cls.pilot = shared_pilot()

    def mutated(self, function, base=None):
        copy_ = clone(base or self.base)
        function(copy_)
        return copy_

    def failed(self, base, texts, config=None, replay=True):
        record = fresh("v") / "verification.json"
        document, status = C.verify(base, record, replay=replay, config=config)
        self.assertEqual((document["state"], status), ("failed", 2), document["problems"][:6])
        self.assertEqual(json.loads(record.read_text())["problems"], document["problems"])
        self.assertNotIn(document["state"], ("verified", "pilot_verified", "verified_non_ok"))
        for text in ([texts] if isinstance(texts, str) else texts):
            self.assertTrue(any(text in p for p in document["problems"]), (text, document["problems"][:8]))
        return document

    # -- 1: the mapping is a trusted policy input
    def test_a_harmless_mapping_edit_with_regenerated_checksums(self):
        def edit(b):
            edit_text(b / "case-mapping.toml", lambda t: t + "\n# harmless\n")
            rebind(b, case_mapping_sha256=C.sha256_file(b / "case-mapping.toml"))
        self.failed(self.mutated(edit), "case-mapping.toml of the archive differs from the verifier's", replay=False)

    def test_a_semantic_mapping_change_with_everything_regenerated(self):
        def deviation(b):
            text = (b / "case-mapping.toml").read_text()
            first = text.index("[[case]]")
            edit_text(b / "case-mapping.toml", lambda t: t.replace(
                "approved = false", f'approved = true\napproval_url = "{URL}"\ndeviation = "synthetic"', 1))
            assert first >= 0
            regenerate_comparison(b)
            rebind(b, case_mapping_sha256=C.sha256_file(b / "case-mapping.toml"))
        base = self.mutated(deviation)
        stored = C.comparison_summary(base / "comparison")
        self.assertIn("NOT COMPARABLE", " ".join(" ".join(r) for r in stored["rows"]), "the forged outcome differs")
        document = self.failed(base, "case-mapping.toml of the archive differs from the verifier's")
        self.assertNotIn("the replay exits", " ".join(document["problems"]),
                         "the forged archive is internally consistent: only the trusted mapping catches it")

        def class_d(b):
            edit_text(b / "case-mapping.toml", lambda t: t.replace('class = "A"', 'class = "D"', 1))
            regenerate_comparison(b)
            rebind(b, case_mapping_sha256=C.sha256_file(b / "case-mapping.toml"))
        self.failed(self.mutated(class_d), "case-mapping.toml of the archive differs from the verifier's")

    def test_the_mapping_digests_are_recorded_and_bound(self):
        self.failed(self.mutated(lambda b: rebind(b, case_mapping_sha256="0" * 64)),
                    ["case_mapping_sha256 is missing or not the digest",
                     "record different case_mapping_sha256 values"], replay=False)
        self.failed(self.mutated(lambda b: rebind(b, case_mapping_sha256=None)),
                    "case_mapping_sha256 is missing or not the digest", replay=False)

        def completion(b):
            record = read_json(b / "logs" / "completion.json")
            record["case_mapping_sha256"] = "1" * 64
            write_json(b / "logs" / "completion.json", record)
            refresh_all(b)
        self.failed(self.mutated(completion), "logs/completion.json: case_mapping_sha256 is not the digest of "
                                              "case-mapping.toml", replay=False)

        def omitted(b):
            record = read_json(b / "logs" / "completion.json")
            del record["case_mapping_sha256"]
            write_json(b / "logs" / "completion.json", record)
            refresh_all(b)
        self.failed(self.mutated(omitted), "logs/completion.json: case_mapping_sha256 is not the digest",
                    replay=False)

    def test_a_pilot_uses_the_committed_mapping_and_the_verifiers_mapping_is_tracked(self):
        def edit(b):
            edit_text(b / "case-mapping.toml", lambda t: t + "\n# pilot edit\n")
            rebind(b, case_mapping_sha256=C.sha256_file(b / "case-mapping.toml"))
        self.failed(self.mutated(edit, base=self.pilot), "case-mapping.toml of the archive differs from the "
                    "verifier's", config=PILOT_FILE, replay=False)

        def run(argv, **kw):
            if "ls-files" in argv and any(a.endswith("case-mapping.toml") for a in argv):
                return subprocess.CompletedProcess(argv, 1, "", "")
            return subprocess.run(argv, **kw)
        document, status = C.verify(clone(self.base), fresh("v") / "v.json", replay=False, run=run)
        self.assertEqual((document["state"], status), ("failed", 2))
        self.assertTrue(any("the verifier's case-mapping.toml is not tracked" in p for p in document["problems"]))
        base = assemble_base(self.camp, fresh("pm") / "x-pilot", aa=False)
        edit_text(base / "case-mapping.toml", lambda t: t + "\n# edit\n")
        with self.assertRaises(C.Refused):
            C.plan_from_pilot(pilot_config(), base, JULIA_BINS, ENVIRON)

    # -- 2: the closed, mode-specific policy-file inventory
    def test_the_other_modes_configuration_is_forbidden(self):
        def lock_in_pilot(b):
            shutil.copyfile(self.base / "lock.toml", b / "lock.toml")
            refresh_all(b)
        self.failed(self.mutated(lock_in_pilot, base=self.pilot), "lock.toml is forbidden in a pilot attempt",
                    config=PILOT_FILE, replay=False)

        def logs_lock_in_pilot(b):
            shutil.copyfile(self.base / "lock.toml", b / "logs" / "lock.toml")
            refresh_all(b)
        self.failed(self.mutated(logs_lock_in_pilot, base=self.pilot), "logs/lock.toml is forbidden in a pilot",
                    config=PILOT_FILE, replay=False)

        def config_in_official(b):
            add_pilot_config(b)
            refresh_all(b)
        self.failed(self.mutated(config_in_official), "pilot-config.toml is forbidden in an official attempt",
                    replay=False)

        def logs_config_in_official(b):
            shutil.copyfile(PILOT_FILE, b / "logs" / "pilot-config.toml")
            refresh_all(b)
        self.failed(self.mutated(logs_config_in_official), "logs/pilot-config.toml is forbidden in an official",
                    replay=False)

    def test_a_foreign_top_level_entry_is_refused_and_private_directories_are_not(self):
        for base, config in ((self.base, None), (self.pilot, PILOT_FILE)):
            def foreign(b):
                (b / "notes.txt").write_text("x")
                refresh_all(b)
            self.failed(self.mutated(foreign, base=base), "notes.txt is not an entry of the documented layout",
                        config=config, replay=False)
            copy_ = clone(base)
            for name in C.PRIVATE_DIRECTORIES:
                (copy_ / name / "role").mkdir(parents=True)
                (copy_ / name / "role" / "big.bin").write_text("private")
            document, status = C.verify(copy_, fresh("v") / "v.json", config=config)
            self.assertEqual((status, document["problems"]), (0, []), "private directories are allowed")

    def test_the_official_state_requires_its_lock_and_a_pilot_its_configuration(self):
        base = self.mutated(lambda b: ((b / "lock.toml").unlink(), rebind(b, official=False)))
        self.failed(base, ["official is False", "lock.toml is missing"], replay=False)
        base = self.mutated(lambda b: ((b / "pilot-config.toml").unlink(), refresh_all(b)), base=self.pilot)
        self.failed(base, "pilot-config.toml is missing", config=PILOT_FILE, replay=False)

    # -- 3: replayed outputs
    def test_report_lists_and_declared_reasons_are_replayed_or_recomputed(self):
        def report(b):
            edit_text(b / "comparison" / "report.md", lambda t: t.replace("COMPARABLE", "COMPARABLE!", 1))
            refresh_all(b)
        self.failed(self.mutated(report), "report.md of the replay differs from the stored comparison")

        def lists(b):
            data = read_json(b / "comparison" / "lists.json")
            data["not_ok"].append({"julia": "x", "id": "y"})
            write_json(b / "comparison" / "lists.json", data)
            refresh_all(b)
        self.failed(self.mutated(lists), "lists.json of the replay differs from the stored comparison")

        def missing(b):
            (b / "comparison" / "report.md").unlink()
            refresh_all(b)
        self.failed(self.mutated(missing), ["comparison/ lacks report.md or lists.json",
                                            "report.md of the replay differs"])

        def reason(b):
            edit_text(b / "declared-differences.toml", lambda t: t.replace("synthetic reason", "a better reason"))
            refresh_all(b)
        document = self.failed(self.mutated(reason), "declared-differences.toml differs from the declaration "
                                                     "recomputed")
        self.assertEqual(document["comparator_exit"], 0, "the comparator itself does not read reasons")

        def pilot_declared(b):
            with writable(b / "declared-differences.toml").open("a") as stream:
                stream.write('\n[[compat]]\nname = "X"\na = "1"\nb = "2"\nreason = "r"\n')
            refresh_all(b)
        self.failed(self.mutated(pilot_declared, base=self.pilot), "not the minimal `schema = 1`", config=PILOT_FILE,
                    replay=False)

    def test_the_static_candidate_checks_and_the_freeze_sha_are_reapplied(self):
        def old_version(b):
            edit_text(b / "lock.toml", lambda t: t.replace('version = "0.6.0"', 'version = "0.5.4"'))
            rebind(b, lock_sha256=C.sha256_file(b / "lock.toml"))
        self.failed(self.mutated(old_version), "lock.toml: PB_B_VERSION", replay=False)

        def historical(b):
            a = mc.load_schedule(HERE / "schedule.toml")["stack_a"]
            edit_text(b / "lock.toml", lambda t: t.replace(self.camp.stack("b")["ps"]["commit"],
                                                           a["proximalsolvers"]["commit"]))
            rebind(b, lock_sha256=C.sha256_file(b / "lock.toml"))
        self.failed(self.mutated(historical), "HISTORICAL_PROXIMALSOLVERS_COMMIT", replay=False)
        for value in (None, "abc123", "g" * 40):
            self.failed(self.mutated(lambda b, v=value: rebind(b, freeze_sha=v)),
                        "logs/campaign.json: freeze_sha is not a full 40-hex SHA", replay=False)

    def test_the_positive_controls_carry_their_mode(self):
        document, status = C.verify(self.base, fresh("v") / "v.json")
        self.assertEqual((status, document["state"], document["mode"], document["problems"]),
                         (0, "verified", "OFFICIAL", []))
        document, status = C.verify(self.pilot, fresh("v") / "v.json", config=PILOT_FILE)
        self.assertEqual((status, document["state"], document["mode"], document["problems"]),
                         (0, "pilot_verified", "PILOT / NON-OFFICIAL", []))


class AttemptHardeningTests(EngineBase):
    """The attempt lifecycle: invalid samples, failures after the attempt began, stray configuration, redaction, session."""

    def stopped_without_a_launch(self, base, host, plan):
        self.assertEqual(host.calls, [])
        self.assertEqual(self.state(base)["state"], "stopped")
        self.assertEqual(self.receipt(base)[1:], [], "no process event: nothing was launched")
        self.assertTrue((base / "checksums.sha256").is_file())

    def test_an_invalid_machine_sample_stops_before_the_launch(self):
        for when, edit in ((1, lambda s: s.update(no_turbo=0)), (2, lambda s: s.update(governor=None)),
                           (2, lambda s: s.pop("epp"))):
            base, plan, host = self.make()
            host.sample_edits.append((when, edit))
            with self.assertRaises(C.Stopped) as caught:
                C.execute(plan, host.hooks())
            self.assertIn("machine", str(caught.exception))
            self.stopped_without_a_launch(base, host, plan)
        with self.assertRaises(ValueError):
            C.machine_record({"cpu_model": "m", "governor": "g", "epp": "e", "no_turbo": 0, "smt_control": "on"},
                             "c", 6)
        with self.assertRaises(ValueError):
            C.machine_record({"cpu_model": "m", "governor": "g", "epp": "e", "no_turbo": "0", "smt_control": "on"},
                             "c", True)

    def test_every_failure_after_the_attempt_began_finishes_it(self):
        base, plan, host = self.make()

        def failing(sample):
            raise OSError("sysfs vanished")
        host.sample_edits.append((1, failing))                  # the first sample, outside any process
        with self.assertRaises(OSError):
            C.execute(plan, host.hooks())
        self.stopped_without_a_launch(base, host, plan)
        self.assertIn("OSError", self.state(base)["reason"])
        base, plan, host = self.make()
        original = C.write_declared_differences

        def refuse(base_, lock):
            raise C.Refused("finalize refused something else")
        C.write_declared_differences = refuse
        try:
            with self.assertRaises(C.Refused):
                C.execute(plan, host.hooks())
        finally:
            C.write_declared_differences = original
        self.assertEqual(self.state(base)["state"], "stopped")
        self.assertIn("finalize refused something else", self.state(base)["reason"])
        self.assertTrue((base / "checksums.sha256").is_file())

    def test_stray_configuration_is_refused_before_any_file_is_written(self):
        base, plan, host = self.make()
        shutil.copyfile(PILOT_FILE, base / "lock.toml")
        with self.assertRaises(C.Refused) as caught:
            C.execute(plan, host.hooks())
        self.assertEqual(caught.exception.field, "lock.toml")
        self.assertFalse((base / "logs").exists())
        base, plan, host = self.make()
        (base / "logs").mkdir()
        shutil.copyfile(PILOT_FILE, base / "logs" / "lock.toml")
        with self.assertRaises(C.Refused):
            C.execute(plan, host.hooks())
        self.assertEqual(host.calls, [])
        camp = F.build_campaign(fresh("stray"), "migration")
        lock = make_lock(camp)
        official = assemble_base(camp, fresh("stray-base") / "base")
        add_pilot_config(official)
        plan = official_plan(official, lock)
        with self.assertRaises(C.Refused) as caught:
            C.execute(plan, Host(camp, plan.sched, official).hooks())
        self.assertEqual(caught.exception.field, "pilot-config.toml")
        self.assertFalse((official / "logs").exists())
        self.assertFalse((official / "receipt.jsonl").exists())

    def test_the_session_comes_from_the_identity_files_when_the_configuration_has_none(self):
        base = assemble_base(self.camp, fresh("session") / "x-pilot", session="session-20270101T000000Z-abcd",
                             aa=False)
        plan = C.plan_from_pilot(pilot_config(session=None), base, JULIA_BINS, ENVIRON)
        self.assertEqual(plan.session_id, "session-20270101T000000Z-abcd")
        add_pilot_config(base)
        host = Host(self.camp, plan.sched, base)
        outcome = C.execute(plan, host.hooks())
        self.assertEqual(outcome.exit_code, 0)
        self.assertEqual(self.receipt(base)[0]["session_id"], "session-20270101T000000Z-abcd")
        disagree = assemble_base(self.camp, fresh("session2") / "x-pilot", aa=False)
        edit_text(disagree / "roots" / "ab-b" / "stack-identity.toml", lambda t: t.replace(SESSION, "session-0"))
        with self.assertRaises(C.Refused) as caught:
            C.plan_from_pilot(pilot_config(session=None), disagree, JULIA_BINS, ENVIRON)
        self.assertEqual(caught.exception.field, "session_id")
        camp = F.build_campaign(fresh("sessionlock"), "migration")
        lock = make_lock(camp)
        del lock["campaign"]["session_id"]
        official = assemble_base(camp, fresh("sessionlock-base") / "base")
        self.assertEqual(official_plan(official, lock).session_id, SESSION)
        self.assertRegex(C.mint_session_id(), r"session-[0-9]{8}T[0-9]{6}Z-[0-9a-f]{4}")

    def test_personal_values_are_redacted_in_the_evidence_only(self):
        base, plan, host = self.make()
        environ = dict(ENVIRON, USER="alice", LOGNAME="alice", TMPDIR="/private/tmp/alice")
        plan.parent_env = environ
        C.execute(plan, host.hooks())
        for argv, env, cwd, cpu in host.calls:
            self.assertEqual((env["HOME"], env["USER"], env["LOGNAME"], env["TMPDIR"]),
                             (environ["HOME"], "alice", "alice", "/private/tmp/alice"))
        text = (base / "logs" / "commands.jsonl").read_text()
        for personal in (environ["HOME"], "alice", "/private/tmp/alice"):
            self.assertNotIn(personal, text)
        command = C.read_jsonl(base / "logs" / "commands.jsonl")[0]
        self.assertEqual({k: command["env"][k] for k in ("HOME", "USER", "LOGNAME", "TMPDIR")},
                         dict.fromkeys(("HOME", "USER", "LOGNAME", "TMPDIR"), "<redacted>"))
        self.assertEqual(command["env"][C.JOB_ID_VARIABLES[0]], "4242")
        self.assertEqual(command["env"]["PS_REPETITION"], "1")


# ------------------------------------------------------------------------------------------------- CLI

class CliTests(unittest.TestCase):
    def test_usage_errors_exit_three(self):
        for argv in ([], ["bogus"], ["run"], ["run", "--config", "x"], ["verify", "--base", "x"],
                     ["prepare", "--config", "x", "--base", "y", "--step", "other"],
                     ["pilot", "--config", "x", "--base", "y", "--arms", "ZZ"],
                     ["pilot", "--config", "x", "--base", "y", "--unknown"]):
            with self.subTest(argv=argv):
                code, _, err = call_main(argv, hooks=hooks_that_never_run())
                self.assertEqual(code, 3, err)

    def test_prepare_validates_the_configuration_and_launches_nothing(self):
        directory = fresh("prepare")
        camp = F.build_campaign(fresh("prepare-camp"), "migration")
        C.write_toml(directory / "lock.toml", make_lock(camp))
        for step in ("fetch", "finalize"):
            code, _, err = call_main(["prepare", "--config", str(directory / "lock.toml"), "--base",
                                      str(directory / "base"), "--step", step], hooks=hooks_that_never_run())
            self.assertEqual(code, 2, err)
            self.assertFalse((directory / "base").exists(), "a refusal creates nothing")
        C.write_toml(directory / "bad.toml", {"schema": 2, "campaign": {"id": "x"}})
        code, _, err = call_main(["prepare", "--config", str(directory / "bad.toml"), "--base",
                                  str(directory / "base"), "--step", "fetch"], hooks=hooks_that_never_run())
        self.assertEqual(code, 2, "an invalid configuration is a refusal")
        self.assertFalse((directory / "base").exists())

    def test_preflight_reports_through_the_same_function(self):
        camp = F.build_campaign(fresh("pf"), "identical", reps=1, schedule_edit=pilot_edit)
        base = assemble_base(camp, fresh("pf-base") / "x-pilot", aa=False)
        directory = fresh("pf-cfg")
        C.write_toml(directory / "p.toml", pilot_config())
        host = Host(camp, mc.load_schedule(base / "schedule.toml"), base)
        code, out, err = call_main(["preflight", "--config", str(directory / "p.toml"), "--base", str(base)],
                                   hooks=host.hooks())
        self.assertEqual((code, out.strip()), (0, "preflight: 0 problems"))
        self.assertEqual(host.calls, [])
        self.assertFalse((base / "logs").exists(), "preflight is read-only")
        host.obs_edits.append(lambda role, mm, obs: obs["julia"].update(version="1.10.12"))
        code, out, err = call_main(["preflight", "--config", str(directory / "p.toml"), "--base", str(base)],
                                   hooks=host.hooks())
        self.assertEqual(code, 2)
        self.assertIn("JULIA_VERSION", err)

    def test_the_pilot_runs_end_to_end_with_mocked_hooks(self):
        camp = F.build_campaign(fresh("pe"), "identical", reps=1, schedule_edit=pilot_edit)
        base = assemble_base(camp, fresh("pe-base") / "x-pilot", aa=False)
        directory = fresh("pe-cfg")
        C.write_toml(directory / "p.toml", pilot_config())
        host = Host(camp, mc.load_schedule(base / "schedule.toml"), base)
        code, out, err = call_main(["pilot", "--config", str(directory / "p.toml"), "--base", str(base)],
                                   hooks=host.hooks())
        self.assertEqual(code, 0, err)
        self.assertIn("campaign completed", out)
        self.assertEqual(len(host.calls), 4)
        code, out, _ = call_main(["verify", "--base", str(base), "--out", str(fresh("pe-v") / "v.json"),
                                  "--config", str(directory / "p.toml")])
        self.assertEqual(code, 0)
        self.assertIn("PILOT / NON-OFFICIAL", out)
        code, _, _ = call_main(["verify", "--base", str(base), "--out", str(fresh("pe-v") / "v.json")])
        self.assertEqual(code, 2, "a pilot cannot be verified without the configuration the verifier holds")
        code, _, err = call_main(["pilot", "--config", str(directory / "p.toml"), "--base", str(base)],
                                 hooks=hooks_that_never_run())
        self.assertEqual(code, 2, "a finished base is never reused")


# ----------------------------------------------------------------------------- real hooks, prepare, finalize

import argparse
import gzip
import hashlib
import itertools
import tarfile

REAL_RUN = subprocess.run

GIT_ENV = {"GIT_AUTHOR_NAME": "t", "GIT_AUTHOR_EMAIL": "t@example.org", "GIT_COMMITTER_NAME": "t",
           "GIT_COMMITTER_EMAIL": "t@example.org", "GIT_CONFIG_GLOBAL": "/dev/null", "GIT_CONFIG_NOSYSTEM": "1"}
HARNESS_FILES = ("problems.jl", "certificates.jl", "cases.jl", "run.jl")


def git_run(repo, *args):
    env = dict(os.environ, **GIT_ENV)
    return subprocess.run(["git", "-C", str(repo), *args], capture_output=True, text=True, check=True,
                          env=env).stdout.strip()


def make_source(dest, tag=None):
    """A tiny repository standing in for ProximalSolvers: Project.toml, src/, the four harness files. Returns
    (path, pins) with the pins computed by the driver's own fingerprint functions."""
    dest = Path(dest)
    (dest / "src").mkdir(parents=True)
    (dest / "benchmark").mkdir()
    (dest / "Project.toml").write_text('name = "ProximalSolvers"\nversion = "0.3.2"\n')
    (dest / "src" / "ProximalSolvers.jl").write_text("module ProximalSolvers end\n")
    for name in HARNESS_FILES:
        (dest / "benchmark" / name).write_text(f"# {name}\n")
    git_run(dest, "init", "-q", "-b", "main")
    git_run(dest, "add", "-A")
    git_run(dest, "commit", "-q", "-m", "synthetic")
    if tag:
        git_run(dest, "tag", "-a", tag, "-m", tag)
    return dest, {"commit": git_run(dest, "rev-parse", "HEAD"), "tree": git_run(dest, "rev-parse", "HEAD^{tree}"),
                  "package_hash": C.package_fingerprint(dest), "harness_hash": C.harness_hash(dest / "benchmark")}


def lock_tuples(mm):
    return C.lock_entries(C.stage2a_campaign(), mm)


def synthetic_manifest(mm, path="/old/pinned", project_hash="a" * 40):
    """A Manifest whose entries are exactly the Stage 2A lock of the stratum (so that the comparison with the
    campaign definition passes) and whose ProximalSolvers entry carries a `path` line."""
    lines = [f'julia_version = "{mm}.0"', 'manifest_format = "2.1"', f'project_hash = "{project_hash}"', ""]
    for name, uuid, version, tree in lock_tuples(mm):
        lines += [f"[[deps.{name}]]", f'uuid = "{uuid}"']
        if version:
            lines.append(f'version = "{version}"')
        if tree:
            lines.append(f'git-tree-sha1 = "{tree}"')
        if name == "ProximalSolvers":
            lines.append(f'path = "{path}"')
        lines.append("")
    return "\n".join(lines)


def synthetic_project(mm, path="/old/pinned"):
    text = 'name = "Bench"\n\n[deps]\nProximalSolvers = "00000000-0000-0000-0000-000000000001"\n'
    if mm == "1.13":
        text += f'\n[sources]\nProximalSolvers = {{path = "{path}"}}\n'
    return text


def make_archive(dest, strata=("1.10", "1.13"), extra=(), name="pre06-stage2a-campaign-v1", skip=()):
    """A gzip tarball with the Project and Manifest of every stratum (plus `extra` (name, data) members)."""
    root = C.stage2a_campaign()["archive"]["name"]
    path = Path(dest) / f"{name}.tar.gz"
    with tarfile.open(path, "w:gz") as tar:
        def add(member_name, data, kind=tarfile.REGTYPE, link=""):
            info = tarfile.TarInfo(member_name)
            info.type, info.size, info.linkname = kind, len(data), link
            tar.addfile(info, io.BytesIO(data))
        for mm in strata:
            for file_name, text in (("Project.toml", synthetic_project(mm)), ("Manifest.toml", synthetic_manifest(mm))):
                if (mm, file_name) not in skip:
                    add(f"{root}/julia-{mm}/{file_name}", text.encode())
        for member_name, data in extra:
            add(member_name, data)
    return path


def registry_tarball(depot, uuid, version, tree):
    """General.tar.gz of a depot's registry copy listing one package version."""
    directory = Path(depot) / "registries"
    directory.mkdir(parents=True, exist_ok=True)
    with tarfile.open(directory / "General.tar.gz", "w:gz") as tar:
        for name, text in (("Registry.toml", f'[packages]\n{uuid} = {{ name = "ProximalBase", path = "P/ProximalBase" }}\n'),
                           ("P/ProximalBase/Versions.toml", f'["{version}"]\ngit-tree-sha1 = "{tree}"\n')):
            info = tarfile.TarInfo(name)
            info.size = len(text.encode())
            tar.addfile(info, io.BytesIO(text.encode()))


class Scripted:
    """A stand-in for subprocess.run: git runs for real; a Julia command is answered by `julia(argv, env)`;
    every call is recorded as (argv, kwargs)."""

    def __init__(self, julia=None, other=None):
        self.calls, self.julia, self.other = [], julia, other

    def __call__(self, argv, **kwargs):
        self.calls.append((list(argv), kwargs))
        if argv[0] == "git":
            return REAL_RUN(argv, **dict(kwargs, env=dict(os.environ, **GIT_ENV)))
        if self.other is not None:
            answer = self.other(argv, kwargs)
            if answer is not None:
                return answer
        if "julia" in Path(argv[0]).name or (argv[0] == "taskset" and "julia" in Path(argv[3]).name):
            return self.julia(argv, kwargs)
        raise AssertionError(f"unexpected command {argv}")

    def julia_calls(self):
        return [(a, k) for a, k in self.calls if a[0] != "git"]


def completed(argv, code=0, out=b"", err=b""):
    return subprocess.CompletedProcess(argv, code, out, err)


def project_of(argv):
    return Path(next(a for a in argv if a.startswith("--project=")).partition("=")[2])


def stale_julia(stale=True, resolve_edit=None, registry=None, fail_first=0):
    """The Pkg behaviour of the two strata: Julia 1.13 warns that the Manifest is out of sync with the Project
    and `Pkg.resolve()` then rewrites project_hash (what the real Julia did); 1.10 is silent."""
    state = {"failures": fail_first}

    def julia(argv, kwargs):
        env_dir = project_of(argv)
        code = argv[-1]
        depot = kwargs["env"]["JULIA_DEPOT_PATH"].split(":")[0]
        if registry:
            registry_tarball(depot, *registry)
        if state["failures"]:
            state["failures"] -= 1
            return completed(argv, 1, b"", b"ERROR: could not spawn (EAGAIN)")
        is_new = "1.13" in str(env_dir) and stale
        if "Pkg.instantiate()" in code:
            return completed(argv, 0, b"", (b"Warning: the project dependencies or compat requirements have changed "
                                            b"since the manifest was last resolved.\n") if is_new else b"")
        if "Pkg.resolve()" in code:
            manifest = env_dir / "Manifest.toml"
            text = manifest.read_text()
            manifest.write_text(resolve_edit(text) if resolve_edit else re.sub(
                r'project_hash = "[0-9a-f]+"', 'project_hash = "' + "b" * 40 + '"', text))
            return completed(argv, 0)
        raise AssertionError(argv)
    return julia


def fetch_world(name="fetch"):
    """A Prepare over a synthetic source, archive and Julia: returns (Prepare, source pins, directory)."""
    directory = fresh(name)
    source, pins = make_source(directory / "source")
    archive = make_archive(directory)
    official = mc.load_schedule(HERE / "schedule.toml")
    official["stack_a"]["proximalsolvers"].update(commit=pins["commit"], tree=pins["tree"],
                                                  package_hash=pins["package_hash"])
    official["stack_a"]["harness_hash"] = pins["harness_hash"]
    pb = official["stack_a"]["proximalbase"]
    uuid = C.stage2a_campaign()["proximalbase"]["uuid"]
    config = full_pilot_config()
    C.write_toml(directory / "pilot.toml", config)
    args = argparse.Namespace(config=str(directory / "pilot.toml"), step="fetch", julia=None, archive=str(archive))
    st = C.prepare_settings(args, "pilot", config, directory / "bases" / "x-pilot", official, ENVIRON, dict(JULIA_BINS))
    st.source = str(source)
    st.pb_source = None
    return st, pins, directory, (uuid, pb["version"], pb["tree"]), archive


def full_pilot_config(session=SESSION, **overrides):
    config = pilot_config(session)
    config["pilot"].update(samples_target=5, seconds_limit=0.2, case_seconds=10.0)
    config["julia"] = dict(JULIA_BINS)
    config["source"] = {"repository": "/not/used"}
    config["archive"] = {"path": "/not/used.tar.gz"}
    config["resources"] = {"min_cpus": 3}
    config.update(overrides)
    return config


class PilotConfigurationTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.official = mc.load_schedule(HERE / "schedule.toml")

    def refused(self, edit, field):
        config = full_pilot_config()
        edit(config)
        with self.assertRaises(C.LockRefusal) as caught:
            C.parse_pilot(config, self.official)
        self.assertEqual(caught.exception.field, field)

    def test_the_extended_configuration_is_valid_and_the_old_minimum_still_is(self):
        self.assertEqual(C.parse_pilot(full_pilot_config(), self.official)["pilot"]["samples_target"], 5)
        self.assertIn("campaign", C.parse_pilot(pilot_config(), self.official))

    def test_every_new_key_is_strict(self):
        for name, edit, field in (
                ("unknown top key", lambda c: c.update(extra={}), "pilot.extra"),
                ("unknown pilot key", lambda c: c["pilot"].update(extra=1), "pilot.extra"),
                ("sampling not a number", lambda c: c["pilot"].update(seconds_limit="x"), "pilot.seconds_limit"),
                ("samples zero", lambda c: c["pilot"].update(samples_target=0), "pilot.samples_target"),
                ("samples float", lambda c: c["pilot"].update(samples_target=2.5), "pilot.samples_target"),
                ("negative case seconds", lambda c: c["pilot"].update(case_seconds=-1.0), "pilot.case_seconds"),
                ("julia key", lambda c: c["julia"].update({"x": "/a"}), "julia.x"),
                ("julia relative", lambda c: c["julia"].update({"1.10": "julia"}), "julia.1.10"),
                ("julia empty", lambda c: c.update(julia={}), "julia"),
                ("source unknown key", lambda c: c["source"].update(extra="x"), "source.extra"),
                ("source missing", lambda c: c["source"].pop("repository"), "source.repository"),
                ("source white space", lambda c: c["source"].update(repository="a b"), "source.repository"),
                ("archive unknown key", lambda c: c["archive"].update(extra="x"), "archive.extra"),
                ("archive empty", lambda c: c["archive"].update(path=""), "archive.path"),
                ("one CPU", lambda c: c["resources"].update(min_cpus=1), "resources.min_cpus"),
                ("resources unknown", lambda c: c["resources"].update(max_cpus=9), "resources.max_cpus")):
            with self.subTest(name):
                self.refused(edit, field)

    def test_a_stack_b_table_is_still_refused(self):
        self.refused(lambda c: c.update(stack_b={}), "stack_b")


class PathRewriteTests(unittest.TestCase):
    def test_the_manifest_path_line_is_rewritten_line_exactly(self):
        text = synthetic_manifest("1.10")
        new = C.rewrite_manifest_path(text, "/new/checkout")
        old_lines, new_lines = text.split("\n"), new.split("\n")
        self.assertEqual(len(old_lines), len(new_lines))
        changed = [(a, b) for a, b in zip(old_lines, new_lines) if a != b]
        self.assertEqual(changed, [('path = "/old/pinned"', 'path = "/new/checkout"')])

    def test_the_manifest_refuses_a_missing_or_doubled_pattern(self):
        text = synthetic_manifest("1.10")
        cases = {"no path line": text.replace('path = "/old/pinned"\n', ""),
                 "two path lines": text.replace('path = "/old/pinned"\n', 'path = "/old/pinned"\npath = "/x"\n'),
                 "no entry": text.replace("[[deps.ProximalSolvers]]", "[[deps.Other]]"),
                 "two entries": text + "\n[[deps.ProximalSolvers]]\nuuid = \"u\"\n",
                 "carriage return": text.replace('/old/pinned"', '/old/pinned"\r')}
        for name, broken in cases.items():
            with self.subTest(name), self.assertRaises(C.Refused):
                C.rewrite_manifest_path(broken, "/new/checkout")
        for bad in ("relative", '/with"quote', "/with\\slash", "/with\nnewline"):
            with self.subTest(bad), self.assertRaises(C.Refused):
                C.rewrite_manifest_path(text, bad)

    def test_another_entrys_path_line_is_not_touched(self):
        text = synthetic_manifest("1.10").replace("[[deps.Dates]]", '[[deps.Dates]]\npath = "/keep"')
        new = C.rewrite_manifest_path(text, "/new/checkout")
        self.assertIn('path = "/keep"', new)
        self.assertIn('path = "/new/checkout"', new)

    def test_the_project_sources_line_follows_the_same_rule(self):
        text = synthetic_project("1.13")
        new, rewritten = C.rewrite_project_sources(text, "/new/checkout")
        self.assertTrue(rewritten)
        self.assertEqual([b for a, b in zip(text.split("\n"), new.split("\n")) if a != b],
                         ['ProximalSolvers = {path = "/new/checkout"}'])
        plain = synthetic_project("1.10")
        self.assertEqual(C.rewrite_project_sources(plain, "/new/checkout"), (plain, False))
        for name, broken in {"twice": text + 'ProximalSolvers = {path = "/y"}\n',
                             "header only": text.replace('ProximalSolvers = {path = "/old/pinned"}\n', ""),
                             "outside sources": 'ProximalSolvers = {path = "/old/pinned"}\n[sources]\n',
                             "line without header": text.replace("[sources]\n", "")}.items():
            with self.subTest(name), self.assertRaises(C.Refused):
                C.rewrite_project_sources(broken, "/new/checkout")

    def test_entries_and_foreign_line_detection(self):
        old = synthetic_manifest("1.13")
        new = old.replace('project_hash = "' + "a" * 40, 'project_hash = "' + "c" * 40).replace("/old/pinned", "/n")
        self.assertEqual(C.manifest_entries(old), C.manifest_entries(new))
        self.assertEqual(C.foreign_changes(old, new), [])
        self.assertTrue(C.foreign_changes(old, new.replace('manifest_format = "2.1"', 'manifest_format = "2.0"')))
        self.assertEqual(C.manifest_entries(old), lock_tuples("1.13"))


class ArchiveTests(unittest.TestCase):
    def extract(self, archive, destination=None, expected=None):
        destination = destination or fresh("arc") / "out"
        root = C.stage2a_campaign()["archive"]["name"]
        digest = expected or C.sha256_file(archive)
        return C.extract_archive(archive, destination, ["1.10", "1.13"], root, expected=digest)

    def test_only_the_needed_members_are_extracted_into_a_fresh_directory(self):
        archive = make_archive(fresh("arc"), extra=[("pre06-stage2a-campaign-v1/julia-1.10/summary.csv", b"x")])
        out = self.extract(archive)
        self.assertEqual(sorted(p.relative_to(out).as_posix() for p in out.rglob("*") if p.is_file()),
                         ["julia-1.10/Manifest.toml", "julia-1.10/Project.toml", "julia-1.13/Manifest.toml",
                          "julia-1.13/Project.toml"])
        with self.assertRaises(FileExistsError):                   # an existing directory is never reused
            self.extract(archive, out)

    def test_a_wrong_checksum_is_refused_before_anything_is_written(self):
        archive = make_archive(fresh("arc"))
        destination = fresh("arc") / "out"
        with self.assertRaises(C.Refused) as caught:
            C.extract_archive(archive, destination, ["1.10"], "r", expected="0" * 64)
        self.assertIn("SHA-256", str(caught.exception))
        self.assertFalse(destination.exists())
        with self.assertRaises(C.Refused):
            C.check_archive_digest(archive)                       # not the Stage 2A digest

    def test_the_real_digest_is_the_published_one(self):
        self.assertEqual(C.STAGE2A_ARCHIVE_SHA256, "1edd64330606d739acf1d7b4ba0643a4fb6a1366bad4c82393e2ba1ffdcc723e")

    def test_unsafe_missing_duplicate_and_non_regular_members_are_refused(self):
        root = C.stage2a_campaign()["archive"]["name"]
        for name, archive in {
                "parent component": make_archive(fresh("arc"), extra=[("../evil", b"x")]),
                "absolute": make_archive(fresh("arc"), extra=[("/etc/evil", b"x")]),
                "nested parent": make_archive(fresh("arc"), extra=[(f"{root}/../../evil", b"x")]),
                "missing member": make_archive(fresh("arc"), skip=[("1.13", "Manifest.toml")]),
                "duplicate": make_archive(fresh("arc"), extra=[(f"{root}/julia-1.10/Project.toml", b"x")])}.items():
            with self.subTest(name), self.assertRaises(C.Refused):
                self.extract(archive)
        link = fresh("arc") / "link.tar.gz"
        with tarfile.open(link, "w:gz") as tar:
            info = tarfile.TarInfo(f"{root}/julia-1.10/Project.toml")
            info.type, info.linkname = tarfile.SYMTYPE, "/etc/passwd"
            tar.addfile(info)
        with self.assertRaises(C.Refused):
            self.extract(link)
        self.assertFalse(Path("/etc/evil").exists())
        garbage = fresh("arc") / "garbage.tar.gz"
        garbage.write_bytes(gzip.compress(b"not a tar file"))
        with self.assertRaises(C.Refused):
            self.extract(garbage)


class CheckoutTests(unittest.TestCase):
    def test_a_clone_is_independent_detached_and_verified(self):
        directory = fresh("co")
        source, pins = make_source(directory / "source")
        run = Scripted()
        target = directory / "clone"
        C.clone_checkout(source, target, pins["commit"], run)
        clone_argv = run.calls[0][0]
        self.assertEqual(clone_argv[:8], ["git", "-c", "pack.threads=1", "-c", "index.threads=1", "clone", "--quiet",
                                         "--no-hardlinks"])
        self.assertEqual(clone_argv[-3:], ["--", str(source), str(target)])
        self.assertEqual(run.calls[1][0], ["git", "-C", str(target), "checkout", "--quiet", "--detach",
                                           pins["commit"]])
        self.assertEqual(git_run(target, "rev-parse", "--abbrev-ref", "HEAD"), "HEAD")
        objects = target / ".git" / "objects"
        self.assertTrue(all(os.stat(p).st_nlink == 1 for p in objects.rglob("*") if p.is_file()))
        facts = C.verify_checkout(target, pins, pins["harness_hash"], None)
        self.assertEqual(facts["package_hash"], pins["package_hash"])

    def test_every_cleanliness_and_identity_failure_is_refused(self):
        directory = fresh("co")
        source, pins = make_source(directory / "source")
        target = directory / "clone"
        C.clone_checkout(source, target, pins["commit"], None)
        (target / ".gitignore").write_text("*.cache\n")                 # an untracked file ...
        with self.assertRaises(C.Refused) as caught:
            C.verify_checkout(target, pins, pins["harness_hash"], None)
        self.assertIn("not clean", str(caught.exception))
        (target / ".gitignore").unlink()
        (target / "x.cache").write_text("x")
        git_run(target, "config", "core.excludesFile", "/dev/null")
        (target / ".git" / "info" / "exclude").write_text("*.cache\n")  # ... an ignored file ...
        with self.assertRaises(C.Refused) as caught:
            C.verify_checkout(target, pins, pins["harness_hash"], None)
        self.assertIn("not clean", str(caught.exception))
        (target / "x.cache").unlink()
        C.verify_checkout(target, pins, pins["harness_hash"], None)
        (target / "src" / "ProximalSolvers.jl").write_text("changed\n")  # ... a tracked change ...
        with self.assertRaises(C.Refused) as caught:
            C.verify_checkout(target, pins, pins["harness_hash"], None)
        self.assertIn("not clean", str(caught.exception))
        self.assertIn("package fingerprint", str(caught.exception))
        git_run(target, "checkout", "--", ".")
        for name, change in (("commit", dict(commit="1" * 40)), ("tree", dict(tree="2" * 40)),
                             ("package", dict(package_hash="3" * 40))):
            with self.subTest(name), self.assertRaises(C.Refused):
                C.verify_checkout(target, dict(pins, **change), pins["harness_hash"], None)
        with self.assertRaises(C.Refused):
            C.verify_checkout(target, pins, "4" * 40, None)


class FetchTests(unittest.TestCase):
    def fetch(self, julia=None, registry=True, name="fetch"):
        st, pins, directory, tree, archive = fetch_world(name)
        run = Scripted(julia or stale_julia(registry=tree if registry else None))
        st.run = run
        with unittest.mock.patch.object(C, "STAGE2A_ARCHIVE_SHA256", C.sha256_file(archive)), \
                unittest.mock.patch.object(C.time, "sleep"), contextlib.redirect_stdout(io.StringIO()):
            return st, run, directory, pins, C.prepare_fetch(st)

    def test_fetch_builds_every_role_and_records_what_it_did(self):
        st, run, directory, pins, status = self.fetch()
        self.assertEqual(status, 0)
        base = st.base
        for role in ("ab-a", "ab-b"):
            checkout = base / "installations" / role / "ProximalSolvers.jl"
            self.assertEqual(git_run(checkout, "rev-parse", "HEAD"), pins["commit"])
            self.assertTrue((base / "depots" / role).is_dir())
            for mm in ("1.10", "1.13"):
                env = base / "environments" / role / f"env-{mm}"
                manifest = (env / "Manifest.toml").read_text()
                self.assertIn(f'path = "{os.path.realpath(checkout)}"', manifest)
                self.assertNotIn("/old/pinned", manifest)
                project = (env / "Project.toml").read_text()
                self.assertEqual("/old/pinned" in project, False)
                self.assertEqual(os.path.realpath(checkout) in project, mm == "1.13")
                root = base / "roots" / role / f"julia-{mm}"
                for name in ("Project.toml", "Manifest.toml"):
                    self.assertEqual((root / name).read_bytes(), (env / name).read_bytes())
                    self.assertEqual(stat.S_IMODE((root / name).stat().st_mode), 0o444)
        self.assertEqual({p.name for p in (base / "roots").iterdir()}, {"ab-a", "ab-b"})
        self.assertEqual((base / "schedule.toml").read_bytes(), (HERE / "schedule.toml").read_bytes())
        self.assertEqual((base / "pilot-config.toml").read_bytes(), Path(st.config_path).read_bytes())
        summary = json.loads((base / "logs" / "prepare-fetch.json").read_text())
        self.assertTrue(summary["roles"]["ab-a"]["environments"]["1.13"]["stale_warning"])
        self.assertTrue(summary["roles"]["ab-a"]["environments"]["1.13"]["resolved"])
        self.assertFalse(summary["roles"]["ab-a"]["environments"]["1.10"]["stale_warning"])
        self.assertEqual(summary["proximalbase_tag"]["registry_tree"], st.sched["stack_a"]["proximalbase"]["tree"])
        diff = (base / "logs" / "prepare-ab-a-1.13-manifest.diff").read_text()
        self.assertIn("-project_hash", diff)
        self.assertIn("+path =", diff)
        self.assertEqual((base / "logs" / "prepare-ab-a-1.10-project.diff").read_text(), "")

    def test_the_commands_have_the_documented_argv_and_a_whitelisted_environment(self):
        st, run, directory, pins, _ = self.fetch()
        julia = run.julia_calls()
        self.assertEqual(len(julia), 2 * 2 + 2, "an instantiate per role and stratum, a resolve where stale")
        allowed = set(C.ENV_PASSTHROUGH) | {"JULIA_NUM_THREADS", "OPENBLAS_NUM_THREADS", "JULIA_LOAD_PATH",
                                            "JULIA_DEPOT_PATH", "JULIA_PKG_PRECOMPILE_AUTO"}
        for argv, kwargs in julia:
            self.assertEqual(argv[:3], [JULIA_BINS["1.10" if "env-1.10" in argv[3] else "1.13"],
                                        "--startup-file=no", "--history-file=no"])
            self.assertEqual(argv[4], "-e")
            self.assertIn(argv[5], ("using Pkg; Pkg.instantiate()", "using Pkg; Pkg.resolve()"))
            env = kwargs["env"]
            self.assertLessEqual(set(env), allowed)
            self.assertNotIn("JULIA_PKG_OFFLINE", env)
            self.assertEqual(env["JULIA_PKG_PRECOMPILE_AUTO"], "0")
            self.assertEqual(env["JULIA_LOAD_PATH"], "@:@stdlib")
            self.assertTrue(env["JULIA_DEPOT_PATH"].startswith(str(st.base / "depots")))
            self.assertNotIn("SSH_AUTH_SOCK", env)
            self.assertNotIn("AWS_SECRET_ACCESS_KEY", env)
            self.assertIs(kwargs["shell"], False)

    def test_an_existing_role_directory_is_refused_and_nothing_is_deleted(self):
        st, pins, directory, registry, archive = fetch_world()
        keep = st.base / "environments" / "ab-b"
        keep.mkdir(parents=True)
        (keep / "sentinel").write_text("keep")
        st.run = Scripted()
        with self.assertRaises(C.Refused) as caught:
            C.prepare_fetch(st)
        self.assertIn("environments/ab-b", str(caught.exception))
        self.assertEqual((keep / "sentinel").read_text(), "keep")
        self.assertEqual(st.run.calls, [])
        self.assertFalse((st.base / "installations").exists())

    def test_a_second_fetch_on_one_base_is_refused(self):
        st, run, directory, pins, _ = self.fetch()
        before = len(run.calls)
        with self.assertRaises(C.Refused):
            C.prepare_fetch(st)
        self.assertEqual(len(run.calls), before)

    def test_the_archive_checksum_stops_fetch_before_any_command(self):
        st, pins, directory, registry, archive = fetch_world()
        st.run = Scripted()
        with self.assertRaises(C.Refused) as caught:            # the real digest is not that of the synthetic archive
            C.prepare_fetch(st)
        self.assertIn("SHA-256", str(caught.exception))
        self.assertEqual(st.run.calls, [])
        self.assertFalse((st.base / "installations").exists())
        st.archive = None
        with self.assertRaises(C.Refused):
            C.prepare_fetch(st)

    def test_the_resolve_step_may_change_only_the_path_and_project_hash(self):
        def edit_version(text):
            return re.sub(r'project_hash = "[0-9a-f]+"', 'project_hash = "' + "b" * 40 + '"', text).replace(
                'version = "1.11.5"', 'version = "1.11.6"')
        with self.assertRaises(C.Refused) as caught:
            self.fetch(julia=stale_julia(resolve_edit=edit_version))
        self.assertIn("entries differ from the archived Manifest", str(caught.exception))
        self.assertIn("no fresh resolution", str(caught.exception))

        def edit_other_line(text):
            return text.replace('manifest_format = "2.1"', 'manifest_format = "2.0"')
        with self.assertRaises(C.Refused) as caught:
            self.fetch(julia=stale_julia(resolve_edit=edit_other_line))
        self.assertIn("other than the path and project_hash", str(caught.exception))

        def edit_added_entry(text):
            return text + '\n[[deps.Extra]]\nuuid = "e0e0e0e0-0000-0000-0000-000000000000"\nversion = "1.0.0"\n'
        with self.assertRaises(C.Refused):
            self.fetch(julia=stale_julia(resolve_edit=edit_added_entry))

    def test_entries_must_also_equal_the_campaign_definitions_lock(self):
        campaign = C.stage2a_campaign()
        wrong = copy.deepcopy(campaign)
        wrong["julia"]["1.10"]["lock"][0]["version"] = "9.9.9"
        st2, _, directory2, registry2, archive2 = fetch_world("fetch-lock")
        st2.run = Scripted(stale_julia(registry=registry2))
        with unittest.mock.patch.object(C, "STAGE2A_ARCHIVE_SHA256", C.sha256_file(archive2)), \
                unittest.mock.patch.object(C, "stage2a_campaign", lambda: wrong):
            with self.assertRaises(C.Refused) as caught:
                C.prepare_fetch(st2)
        self.assertIn("lock of the Stage 2A campaign definition", str(caught.exception))

    def test_a_failing_pkg_step_is_retried_and_then_refused_with_every_attempt_logged(self):
        st, run, directory, pins, _ = self.fetch(julia=stale_julia(fail_first=2))
        names = sorted(p.name for p in (st.base / "logs").glob("prepare-ab-a-1.10-instantiate*.err"))
        self.assertEqual(names, ["prepare-ab-a-1.10-instantiate-attempt2.err", "prepare-ab-a-1.10-instantiate-attempt3.err",
                                 "prepare-ab-a-1.10-instantiate.err"])
        with self.assertRaises(C.Refused) as caught:
            self.fetch(julia=stale_julia(fail_first=99), name="fetch-fail")
        self.assertIn("3 attempts", str(caught.exception))

    def test_a_missing_registry_is_recorded_and_a_wrong_registry_tree_is_refused(self):
        st, run, directory, pins, _ = self.fetch(registry=False, name="fetch-noreg")
        self.assertIsNone(json.loads((st.base / "logs" / "prepare-fetch.json").read_text())[
                              "proximalbase_tag"]["registry_tree"])
        world = fetch_world("fetch-reg")
        st2, _, _, registry, archive = world
        st2.run = Scripted(stale_julia(registry=(registry[0], registry[1], "f" * 40)))
        with unittest.mock.patch.object(C, "STAGE2A_ARCHIVE_SHA256", C.sha256_file(archive)):
            with self.assertRaises(C.Refused) as caught:
                C.prepare_fetch(st2)
        self.assertIn("registry lists ProximalBase", str(caught.exception))

    def test_the_tag_is_checked_against_a_clone_when_a_locator_is_configured(self):
        directory = fresh("tag")
        source, pins = make_source(directory / "pb", tag="v0.5.4")
        st, *_ = fetch_world("tag-world")
        pb = st.sched["stack_a"]["proximalbase"]
        pb.update(commit=pins["commit"], tree=pins["tree"])
        st.pb_source, st.run = str(source), Scripted()
        depot = fresh("tag-depot")
        uuid = C.stage2a_campaign()["proximalbase"]["uuid"]
        registry_tarball(depot, uuid, pb["version"], pins["tree"])
        record = C.check_pb_tag(st, depot)
        self.assertEqual((record["clone_commit"], record["clone_tree"], record["registry_tree"]),
                         (pins["commit"], pins["tree"], pins["tree"]))
        pb["commit"] = "9" * 40
        with self.assertRaises(C.Refused) as caught:
            C.check_pb_tag(st, depot)
        self.assertIn("commit", str(caught.exception))
        pb.update(commit=pins["commit"], tree="8" * 40)
        with self.assertRaises(C.Refused):
            C.check_pb_tag(st, depot)

    def test_the_registry_reader_handles_tarballs_and_directories(self):
        depot, uuid = fresh("reg"), "0a755509-c5b1-5d6f-9b24-59bcda3c37a3"
        self.assertIsNone(C.registry_tree(depot, uuid, "0.5.4"))
        registry_tarball(depot, uuid, "0.5.4", "a" * 40)
        self.assertEqual(C.registry_tree(depot, uuid, "0.5.4"), "a" * 40)
        self.assertIsNone(C.registry_tree(depot, uuid, "0.5.5"))
        self.assertIsNone(C.registry_tree(depot, "other", "0.5.4"))
        plain = fresh("reg")
        (plain / "registries" / "General" / "P" / "ProximalBase").mkdir(parents=True)
        (plain / "registries" / "General" / "Registry.toml").write_text(
            f'[packages]\n{uuid} = {{ name = "ProximalBase", path = "P/ProximalBase" }}\n')
        (plain / "registries" / "General" / "P" / "ProximalBase" / "Versions.toml").write_text(
            '["0.5.4"]\ngit-tree-sha1 = "' + "b" * 40 + '"\n')
        self.assertEqual(C.registry_tree(plain, uuid, "0.5.4"), "b" * 40)


class OfficialFetchTests(unittest.TestCase):
    """Stack B of an official run: the lock's frozen files, with a synthetic lock only (no candidate exists)."""

    def world(self, stale=False, tamper=None):
        st, pins, directory, registry, archive = fetch_world("official")
        camp = F.build_campaign(fresh("official-camp"), "migration")
        lock = make_lock(camp)
        repo = directory / "repo"
        for mm in ("1.10", "1.13"):
            (repo / "locks" / mm).mkdir(parents=True)
            for name in ("Project.toml", "Manifest.toml"):
                (repo / "locks" / mm / name).write_text(f"# frozen {mm} {name}\n")
                key = name.split(".")[0].lower()
                lock["stack_b"]["environments"][mm][key + "_sha256"] = C.sha256_file(repo / "locks" / mm / name)
        b = lock["stack_b"]
        b["proximalsolvers"].update(commit=pins["commit"], tree=pins["tree"], package_hash=pins["package_hash"])
        b["harness_hash"] = pins["harness_hash"]
        b["proximalbase"].update(release="registered", tag="v0.6.0")
        if tamper:
            tamper(lock, repo)
        official = copy.deepcopy(st.sched)
        args = argparse.Namespace(config=str(directory / "lock.toml"), step="fetch", julia=None,
                                  archive=str(archive))
        C.write_toml(directory / "lock.toml", lock)
        st2 = C.prepare_settings(args, "official", lock, directory / "bases" / "official", official, ENVIRON,
                                 dict(JULIA_BINS))
        st2.repo, st2.source = repo, str(Path(st.source))
        julia = stale_julia(stale=stale, registry=registry)
        st2.run = Scripted(julia)
        return st2, archive, lock

    def test_the_four_roles_stack_b_comes_from_the_lock_and_the_others_from_the_archive(self):
        st, archive, lock = self.world()
        self.assertEqual(st.roles(), ["ab-a", "ab-b", "aa-a", "aa-b"])
        self.assertEqual([st.stack_of(r) for r in st.roles()], ["A", "B", "A", "A"])
        # the synthetic clone source serves stack A at the historical pins of the (patched) schedule
        with unittest.mock.patch.object(C, "STAGE2A_ARCHIVE_SHA256", C.sha256_file(archive)), \
                contextlib.redirect_stdout(io.StringIO()):
            self.assertEqual(C.prepare_fetch(st), 0)
        base = st.base
        for mm in ("1.10", "1.13"):
            env = base / "environments" / "ab-b" / f"env-{mm}"
            for name in ("Project.toml", "Manifest.toml"):
                self.assertEqual((env / name).read_text(), f"# frozen {mm} {name}\n")
        self.assertEqual((base / "lock.toml").read_bytes(), Path(st.config_path).read_bytes())
        self.assertEqual(len({p.name for p in (base / "roots").iterdir()}), 4)

    def test_a_frozen_file_that_differs_from_the_lock_is_refused(self):
        def tamper(lock, repo):
            (repo / "locks" / "1.10" / "Manifest.toml").write_text("changed\n")
        st, archive, lock = self.world(tamper=tamper)
        with unittest.mock.patch.object(C, "STAGE2A_ARCHIVE_SHA256", C.sha256_file(archive)):
            with self.assertRaises(C.Refused) as caught:
                C.prepare_fetch(st)
        self.assertIn("SHA-256 of the lock", str(caught.exception))

    def test_a_path_outside_the_repository_and_a_stale_frozen_manifest_are_refused(self):
        def outside(lock, repo):
            lock["stack_b"]["environments"]["1.10"]["manifest"] = "../elsewhere/Manifest.toml"
        st, archive, lock = self.world(tamper=outside)
        with unittest.mock.patch.object(C, "STAGE2A_ARCHIVE_SHA256", C.sha256_file(archive)):
            with self.assertRaises(C.Refused):
                C.prepare_fetch(st)
        st, archive, lock = self.world(stale=True)
        (st.base / "depots" / "ab-b").mkdir(parents=True)
        (st.base / "logs").mkdir(parents=True)
        with self.assertRaises(C.Refused) as caught:
            C.prepare_environment_b(st, "ab-b", "1.13")
        self.assertIn("out of sync", str(caught.exception))

    def test_a_pilot_cannot_prepare_without_pilot_in_the_base_name_and_a_lock_needs_a_candidate(self):
        st, *_ = fetch_world()
        args = argparse.Namespace(config="x", step="fetch", julia=None, archive=None)
        official = mc.load_schedule(HERE / "schedule.toml")
        with self.assertRaises(C.LockRefusal):
            C.prepare_settings(args, "pilot", full_pilot_config(), Path("/tmp/not-a-p-i-l-o-t"), official, ENVIRON,
                               dict(JULIA_BINS))
        with self.assertRaises(C.Refused):
            C.prepare_settings(args, "official", {"schema": 1, "campaign": {"id": "x"}}, Path("/tmp/b"), official,
                               ENVIRON, dict(JULIA_BINS))
        with self.assertRaises(C.UsageError):
            C.julia_binaries(["1.10=relative"], None, ["1.10"])
        with self.assertRaises(C.Refused):
            C.julia_binaries(["1.10=/a/julia"], None, ["1.10", "1.13"])
        self.assertEqual(C.julia_binaries(["1.10=/b/julia"], {"julia": {"1.10": "/a/julia", "1.13": "/c/julia"}},
                                          ["1.10", "1.13"]), {"1.10": "/b/julia", "1.13": "/c/julia"})


# --------------------------------------------------------------------------------------------- real hooks

def affinity_world(allowed=(1, 2, 6)):
    seen = []
    return (lambda _: set(allowed)), (lambda pid, cpus: seen.append((pid, set(cpus)))), seen


class HostHelperTests(unittest.TestCase):
    def test_the_depot_digest_follows_the_compiled_directories_only(self):
        depot = fresh("depot")
        (depot / "compiled" / "v1.10" / "Pkg").mkdir(parents=True)
        (depot / "packages" / "P" / "x").mkdir(parents=True)
        image = depot / "compiled" / "v1.10" / "Pkg" / "image.so"
        index = depot / "compiled" / "v1.10" / "Pkg" / "image.ji"
        image.write_bytes(b"image")
        index.write_bytes(b"index")
        (depot / "packages" / "P" / "x" / "a.jl").write_text("a")
        before = C.depot_digest(depot)
        self.assertEqual(before, C.depot_digest(depot))
        (depot / "packages" / "P" / "x" / "a.jl").write_text("changed")
        (depot / "logs").mkdir()
        (depot / "logs" / "log").write_text("x")
        self.assertEqual(before, C.depot_digest(depot), "files outside compiled/ do not count")
        os.utime(index, ns=(1, 1))
        self.assertEqual(before, C.depot_digest(depot), "Julia touches a .ji file at every load: not a change")
        for change in ("touch", "size", "new", "index", "delete"):
            with self.subTest(change):
                if change == "touch":
                    os.utime(image, ns=(1, 1))
                elif change == "size":
                    image.write_bytes(b"a rebuilt image")
                elif change == "new":
                    (depot / "compiled" / "v1.10" / "Pkg" / "second.so").write_bytes(b"x")
                elif change == "index":
                    index.write_bytes(b"INDEX")             # same size, other content
                else:
                    image.unlink()
                after = C.depot_digest(depot)
                self.assertNotEqual(before, after)
                before = after

    def test_bundled_depots_and_cpu_lists(self):
        self.assertEqual(C.bundled_depots({"1.10": "/opt/j/bin/julia"}),
                         {"1.10": "/opt/j/local/share/julia:/opt/j/share/julia"})
        self.assertEqual(C.parse_cpu_list("0-2,5\n"), [0, 1, 2, 5])
        self.assertEqual(C.parse_cpu_list("6"), [6])
        with self.assertRaises(ValueError):
            C.parse_cpu_list("a")

    def test_keeping_the_driver_off_the_measured_cpu(self):
        get, put, seen = affinity_world((1, 2, 6))
        self.assertEqual(C.keep_off_cpu(6, get, put), [1, 2])
        self.assertEqual(seen, [(0, {1, 2})])
        for allowed, cpu in (((6,), 6), ((1, 2), 6)):
            get, put, seen = affinity_world(allowed)
            with self.assertRaises(C.Refused):
                C.keep_off_cpu(cpu, get, put)
            self.assertEqual(seen, [])

    def test_datahash_matches_row_for_row(self):
        camp = pilot_world()
        base = assemble_base(camp, fresh("dh") / "x-pilot", aa=False, with_raw=True)
        sched = mc.load_schedule(base / "schedule.toml")
        self.assertTrue(C.datahash_matches(base, sched, "ab-a", "1.10", 1))
        self.assertTrue(C.datahash_matches(base, sched, "ab-b", "1.13", 1))
        sidecar = base / "roots" / "ab-a" / C.DATAHASH_NAME
        original = sidecar.read_text()
        lines = original.split("\n")
        edits = {"a wrong hash": [lines[0], lines[1].rsplit("\t", 1)[0] + "\t" + "0" * 64] + lines[2:],
                 "a missing row": [lines[0]] + lines[2:],
                 "a duplicate row": lines[:2] + [lines[1]] + lines[2:],
                 "header only": [lines[0], ""]}
        for name, new in edits.items():
            with self.subTest(name):
                sidecar.write_text("\n".join(new))
                self.assertFalse(C.datahash_matches(base, sched, "ab-a", "1.10", 1))
        sidecar.write_text(original)
        self.assertTrue(C.datahash_matches(base, sched, "ab-a", "1.10", 1))
        metrics = base / "roots" / "ab-a" / "julia-1.10" / "raw" / "julia-1.10.13-rep01-metrics.tsv"
        metrics_text = metrics.read_text()
        header, *rows = metrics_text.split("\n")
        column = header.split("\t").index("data_hash")
        cells = rows[0].split("\t")
        cells[column] = "0" * 64
        metrics.write_text("\n".join([header, "\t".join(cells)] + rows[1:]))
        self.assertFalse(C.datahash_matches(base, sched, "ab-a", "1.10", 1))
        self.assertFalse(C.datahash_matches(base, sched, "ab-a", "1.10", 2), "no records of this repetition")
        self.assertFalse(C.datahash_matches(base, sched, "ab-a", "1.13", 7))


def probe_text(checkout, pb_dir, depot, env, threads=1, model="Test CPU", name="znver2"):
    data = {"julia": "1.10.13", "commit": "e184dd512e35c5a6e036c9aab5e4de5a3345f62d", "bindir": "/opt/j/bin",
            "cpu_name": name, "cpu_model": model, "threads": threads, "blas": "libopenblas",
            "load_path": ["@", "@stdlib"], "depot_path": [str(depot)], "active_project": f"{env}/Project.toml",
            "active_project_realpath": f"{os.path.realpath(env)}/Project.toml", "depot_realpath": os.path.realpath(depot),
            "proximalbase_dir": str(pb_dir), "proximalbase_version": "0.5.4", "proximalbase_loaded_tree": "1" * 40,
            "proximalsolvers_dir": os.path.realpath(checkout), "proximalsolvers_loaded_tree": "2" * 40,
            "deps": {"ProximalBase": {"uuid": "u", "version": "0.5.4", "tree": "1" * 40, "path": False,
                                      "repo": False, "registry": True, "source": ""}}}
    return C.toml_dumps(data)


class RealHooksTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.camp = pilot_world()

    def world(self, probe=None, affinity=b"Cpus_allowed_list:\t6\n", **kwargs):
        base = assemble_base(self.camp, fresh("rh") / "x-pilot", aa=False)
        plan = C.plan_from_pilot(pilot_config(), base, JULIA_BINS, ENVIRON)
        spec = plan.roles["ab-a"]
        # the role's checkout: a real repository with the four harness files
        source, pins = make_source(base / "installations" / "ab-a" / "ProximalSolvers.jl")
        pb = fresh("rh-pb")
        (pb / "src").mkdir()
        (pb / "Project.toml").write_text('name = "ProximalBase"\nversion = "0.5.4"\n')
        (pb / "src" / "ProximalBase.jl").write_text("module ProximalBase end\n")
        for mm in plan.sched["strata"]:
            spec.environments[mm].mkdir(parents=True)
            (spec.environments[mm] / "Project.toml").write_text("project\n")
            (spec.environments[mm] / "Manifest.toml").write_text("manifest\n")
        text = probe or probe_text(spec.checkout, pb, spec.depot, spec.environments["1.10"], **kwargs)

        def other(argv, kw):
            if argv[0] == "taskset" and "grep" in argv:
                return completed(argv, 0, affinity)
            if argv[-1].endswith("environment_probe.jl"):
                return completed(argv, 0, text.encode())

        run = Scripted(other=other)
        get, put, seen = affinity_world((2, 3, 6))
        hooks = C.RealHooks(JULIA_BINS, ENVIRON, run=run, getaffinity=get, setaffinity=put)
        hooks.bind(plan)
        return hooks, plan, spec, run, pins, pb, seen

    def test_the_hooks_keep_the_driver_off_the_measured_cpu_and_know_the_plan(self):
        hooks, plan, spec, run, pins, pb, seen = self.world()
        self.assertEqual(seen, [(0, {2, 3})])
        self.assertEqual(hooks.julia_bins, JULIA_BINS)
        self.assertEqual(hooks.bundled_depot["1.10"], "/opt/julia-1.10.13/local/share/julia:/opt/julia-1.10.13/share/julia")
        self.assertEqual(hooks.sampler(), C.sample_machine(plan.cpu))
        self.assertEqual(hooks.depot_digest(spec), C.depot_digest(spec.depot))
        self.assertEqual(hooks.clock().tzinfo, datetime.timezone.utc)

    def test_the_runner_passes_argv_environment_and_directory_without_a_shell(self):
        hooks, plan, spec, run, *_ = self.world()
        calls = []

        def fake(argv, **kwargs):
            calls.append((argv, kwargs))
            return completed(argv, -9, b"out", b"err")
        hooks.run = fake
        result = hooks.runner(["taskset", "-c", "6", "x"], {"A": "1"}, "/work", 6)
        self.assertEqual((result.exit, result.stdout, result.stderr), (-9, b"out", b"err"))
        self.assertEqual(calls, [(["taskset", "-c", "6", "x"], {"env": {"A": "1"}, "cwd": "/work",
                                                                  "capture_output": True, "shell": False})])
        def boom(argv, **kwargs):
            raise OSError("no such file")
        hooks.run = boom
        with self.assertRaises(OSError):
            hooks.runner(["x"], {}, "/work", 6)

    def test_the_probe_observation_is_built_from_the_real_system(self):
        hooks, plan, spec, run, pins, pb, seen = self.world()
        observation, text = hooks.probe_raw(spec, "1.10")
        self.assertEqual(C.validate_observation(observation, "x"), [])
        self.assertEqual(observation["ps"]["commit"], pins["commit"])
        self.assertEqual(observation["ps"]["tree"], pins["tree"])
        self.assertEqual(observation["ps"]["dirty"], False)
        self.assertEqual(observation["ps"]["version"], "0.3.2")
        self.assertEqual(observation["ps"]["package_hash"], pins["package_hash"])
        self.assertEqual(observation["ps"]["loaded_realpath"], os.path.realpath(spec.checkout))
        self.assertEqual(observation["pb"]["package_hash"], C.package_fingerprint(pb))
        self.assertEqual(observation["pb"]["loaded_tree"], "1" * 40)
        self.assertEqual(observation["pb"]["manifest_tree"], "1" * 40)
        self.assertEqual(observation["harness_hash"], pins["harness_hash"])
        self.assertEqual(observation["affinity_cpus"], [6])
        self.assertEqual(observation["machine"], {"cpu_model": "Test CPU", "cpu": "znver2", "logical_cpu": 6})
        env = spec.environments["1.10"]
        self.assertEqual(observation["manifest_sha256"], C.sha256_file(env / "Manifest.toml"))
        self.assertEqual(observation["project_sha256"], C.sha256_file(env / "Project.toml"))
        self.assertEqual(observation["environment"], {"dir": str(env), "realpath": os.path.realpath(env),
                                                      "project_exists": True, "manifest_exists": True})
        self.assertEqual(observation["julia"], {"version": "1.10.13", "commit": "e184dd512e35c5a6e036c9aab5e4de5a3345f62d",
                                                "cpu_name": "znver2"})
        self.assertEqual(hooks.probe(spec, "1.10"), observation)
        self.assertIn("proximalsolvers_dir", text)

    def test_the_probe_command_is_the_formal_one_run_on_the_measured_cpu(self):
        hooks, plan, spec, run, *_ = self.world()
        hooks.probe_raw(spec, "1.10")
        argv, kwargs = next((a, k) for a, k in run.calls if a[-1].endswith("environment_probe.jl"))
        self.assertEqual(argv, ["taskset", "-c", "6", JULIA_BINS["1.10"], *C.JULIA_FLAGS,
                                f"--project={spec.environments['1.10']}", str(HERE / "environment_probe.jl")])
        self.assertEqual(argv[:-1], C.launch_argv(plan, spec, "1.10")[:-1])
        self.assertEqual(kwargs["env"], C.launch_env(plan, spec, "1.10", 1))
        self.assertEqual(kwargs["cwd"], str(spec.checkout))
        self.assertEqual(kwargs["env"]["JULIA_PKG_OFFLINE"], "true")
        self.assertNotIn("SSH_AUTH_SOCK", kwargs["env"])
        affinity = next(a for a, _ in run.calls if "grep" in a)
        self.assertEqual(affinity[:4], ["taskset", "-c", "6", "grep"])

    def test_dirty_checkouts_are_observed_untracked_ignored_and_tracked(self):
        hooks, plan, spec, run, pins, pb, seen = self.world()
        checkout = spec.checkout
        for name, change in (("untracked", lambda: (checkout / "new.txt").write_text("x")),
                             ("ignored", lambda: ((checkout / ".git" / "info" / "exclude").write_text("*.cache\n"),
                                                  (checkout / "x.cache").write_text("x"))),
                             ("tracked", lambda: (checkout / "src" / "ProximalSolvers.jl").write_text("y\n"))):
            with self.subTest(name):
                git_run(checkout, "checkout", "--", ".")
                git_run(checkout, "clean", "-fdxq")
                self.assertFalse(hooks.probe(spec, "1.10")["ps"]["dirty"])
                change()
                self.assertTrue(hooks.probe(spec, "1.10")["ps"]["dirty"])

    def test_unusable_probe_results_are_refusals(self):
        for name, kwargs in (("several threads", dict(threads=4)),):
            with self.subTest(name):
                hooks, plan, spec, *_ = self.world(**kwargs)
                with self.assertRaises(C.Refused) as caught:
                    hooks.probe(spec, "1.10")
                self.assertIn("threads", str(caught.exception))
        hooks, plan, spec, *_ = self.world(probe="this is = not toml [")
        with self.assertRaises(C.Refused):
            hooks.probe(spec, "1.10")
        hooks, plan, spec, *_ = self.world(probe='julia = "1.10.13"\n')
        with self.assertRaises(C.Refused):
            hooks.probe(spec, "1.10")
        hooks, plan, spec, run, *_ = self.world()
        hooks.run = lambda argv, **kw: completed(argv, 1, b"", b"Pkg error")
        with self.assertRaises(C.Refused) as caught:
            hooks.probe(spec, "1.10")
        self.assertIn("exited with 1", str(caught.exception))

    def test_the_affinity_is_empty_when_the_pinned_command_fails(self):
        hooks, plan, spec, *_ = self.world(affinity=b"")
        self.assertEqual(hooks.probe(spec, "1.10")["affinity_cpus"], [])
        hooks, plan, spec, *_ = self.world(affinity=b"Cpus_allowed_list:\t0-3\n")
        observation = hooks.probe(spec, "1.10")
        self.assertEqual((observation["affinity_cpus"], observation["machine"]["logical_cpu"]), ([0, 1, 2, 3], -1))

    def test_the_prepare_steps_are_the_formal_command_lines_and_keep_their_logs(self):
        hooks, plan, spec, run, *_ = self.world()
        (plan.base / "logs").mkdir(exist_ok=True)
        answers = []

        def fake(argv, **kwargs):
            answers.append((argv, kwargs))
            return completed(argv, 0, b"listing", b"")
        hooks.run = fake
        hooks.precompile(spec, "1.10")
        hooks.warmup(spec, "1.10", 1)
        hooks.export(spec, "1.10", [1, 2], plan.base / "logs" / "fp.tsv")
        precompile, warmup, export = answers
        self.assertEqual(precompile[0], [JULIA_BINS["1.10"], *C.JULIA_FLAGS, f"--project={spec.environments['1.10']}",
                                         "-e", "using Pkg; Pkg.precompile()"])
        self.assertEqual(precompile[1]["env"], C.launch_env(plan, spec, "1.10", 1))
        self.assertEqual(warmup[0], C.launch_argv(plan, spec, "1.10"))
        self.assertEqual(warmup[1]["env"], dict(C.launch_env(plan, spec, "1.10", 1), PS_LIST="true"))
        self.assertEqual(export[0][:7], ["taskset", "-c", "6", JULIA_BINS["1.10"], *C.JULIA_FLAGS,
                                         f"--project={spec.environments['1.10']}"])
        tail_ = export[0][export[0].index(str(HERE / "export_fingerprints.jl")):]
        self.assertEqual(tail_, [str(HERE / "export_fingerprints.jl"), "--harness", f"{spec.checkout}/benchmark",
                                 "--expected-package-root", str(spec.checkout), "--schedule", str(HERE / "schedule.toml"),
                                 "--reps", "1,2", "--expected-harness-hash", spec.expected["harness_hash"], "--out",
                                 str(plan.base / "logs" / "fp.tsv")])
        for name in ("precompile", "warmup1", "export"):
            self.assertTrue((plan.base / "logs" / f"finalize-ab-a-1.10-{name}.out").is_file(), name)
        commands = C.read_jsonl(plan.base / "logs" / "prepare-commands.jsonl")
        self.assertEqual([c["step"] for c in commands], ["finalize-ab-a-1.10-precompile",
                                                         "finalize-ab-a-1.10-warmup1", "finalize-ab-a-1.10-export"])
        with self.assertRaises(FileExistsError):                  # a log is never overwritten
            hooks.precompile(spec, "1.10")


# ----------------------------------------------------------------------------------------------- finalize

class FakeFinalize:
    """The hooks of `prepare --step finalize` without Julia: every step succeeds with synthetic output."""

    def __init__(self, model="Test CPU @ 3.0GHz", names=None):
        self.julia_bins, self.bundled_depot, self.plan, self.keep_off = dict(JULIA_BINS), "", None, None
        self.model, self.names = model, names or {"1.10": "znver2", "1.13": "znver3"}
        self.calls, self.digest, self.warm_extra, self.exit_of = [], {}, "", {}
        self.digest_sequence = None
        self.edits, self.sample = [], {"cpu_model": model, "governor": "unavailable", "epp": "unavailable",
                                       "no_turbo": "unavailable", "smt_control": "forceoff"}

    def bind(self, plan, keep_off=True):
        self.plan, self.keep_off = plan, keep_off

    def sampler(self):
        return dict(self.sample)

    def depot_digest(self, spec):
        return next(self.digest_sequence) if self.digest_sequence else self.digest.get(spec.name, "digest")

    def result(self, step, spec, mm, out=b"", err=b""):
        self.calls.append((step, spec.name, mm))
        return C.RunResult(self.exit_of.get(step, 0), out, err)

    def precompile(self, spec, mm):
        return self.result("precompile", spec, mm, b"", b"Precompiling packages...")

    def warmup(self, spec, mm, number):
        listing = "".join(f"{case}\textended\t\n" for case in self.plan.sched["settings"]["case_filter"].split(","))
        return self.result(f"warmup{number}", spec, mm, (listing + self.warm_extra).encode())

    def export(self, spec, mm, reps, out):
        self.calls.append(("export", spec.name, mm))
        version = self.plan.sched["strata"][mm]["version"]
        rows, hashes = [mc.FP_HEADER], [C.DATAHASH_HEADER]
        for case in self.plan.sched["settings"]["case_filter"].split(","):
            for rep in reps:
                digest = lambda *parts: hashlib.sha256("/".join(map(str, parts)).encode()).hexdigest()
                rows.append("\t".join([version, case, str(rep), "fixture", "a", digest(spec.name, mm, case, rep)]))
                rows += ["\t".join([version, case, str(rep), kind, name, digest(spec.name, case, rep, kind, name)])
                         for kind, name in C.REQUIRED_FP_ROWS]
                hashes.append("\t".join([version, case, str(rep), digest("data", case, rep, mm)]))
        for suffix, lines in (("", rows), (".datahash.tsv", hashes), (".summary.toml", ["schema = 1"])):
            Path(f"{out}{suffix}").write_text("\n".join(lines) + "\n")
        return C.RunResult(self.exit_of.get("export", 0), b"", b"")

    def probe_raw(self, spec, mm):
        self.calls.append(("probe", spec.name, mm))
        sched = copy.deepcopy(self.plan.sched)
        sched["machine"].update(cpu_model=self.model, cpu=dict(self.names), logical_cpu=self.plan.cpu)
        observation = good_obs(spec, mm, sched, self.plan.base)
        for edit in self.edits:
            edit(spec.name, mm, observation)
        return observation, f"# probe of {spec.name} {mm}\n"


def prepared_base(kind="pilot", config=None, name="fin"):
    """A base in the state `prepare --step fetch` leaves it (no Julia): directories, snapshots, copies."""
    directory = fresh(name)
    base = directory / "bases" / ("x-pilot" if kind == "pilot" else "official")
    config = config or full_pilot_config()
    path = directory / "config.toml"
    C.write_toml(path, config)
    official = mc.load_schedule(HERE / "schedule.toml")
    args = argparse.Namespace(config=str(path), step="finalize", julia=None, archive=None)
    st = C.prepare_settings(args, "pilot", config, base, official, ENVIRON, dict(JULIA_BINS))
    C.write_base_files(st)
    for role in st.roles():
        (base / "installations" / role / "ProximalSolvers.jl").mkdir(parents=True)
        (base / "depots" / role).mkdir(parents=True)
        for mm in official["strata"]:
            env = base / "environments" / role / f"env-{mm}"
            env.mkdir(parents=True)
            root = base / "roots" / role / f"julia-{mm}"
            root.mkdir(parents=True)
            for file_name in ("Project.toml", "Manifest.toml"):
                (env / file_name).write_text(f"# {role} {mm} {file_name}\n")
                shutil.copyfile(env / file_name, root / file_name)
    return st


class FinalizeTests(unittest.TestCase):
    def finalize(self, hooks=None, allowed=(2, 3, 5), st=None, **kwargs):
        st = st or prepared_base()
        hooks = hooks or FakeFinalize()
        get, put, seen = affinity_world(allowed)
        said = []
        with contextlib.redirect_stderr(io.StringIO()):
            status = C.prepare_finalize(st, hooks, get, put, said.append, **kwargs)
        return st, hooks, seen, said, status

    def test_a_pilot_finalize_writes_everything_the_engine_needs(self):
        st, hooks, seen, said, status = self.finalize()
        base = st.base
        self.assertEqual(status, 0)
        self.assertEqual(seen, [(0, {2, 3})], "the driver keeps off the measured CPU 5")
        self.assertFalse(hooks.keep_off, "the hooks do not restrict the driver a second time")
        steps = [c for c in hooks.calls if c[2] == "1.10" and c[1] == "ab-a"]
        self.assertEqual([c[0] for c in steps], ["precompile", "warmup1", "warmup2", "export", "probe"])
        self.assertEqual([c[2] for c in hooks.calls if c[0] == "export"], ["1.10", "1.10", "1.13", "1.13"])
        for role in ("ab-a", "ab-b"):
            ident = tomllib.loads((base / "roots" / role / "stack-identity.toml").read_text())
            self.assertEqual(ident["installation"], C.mint_installation(
                role, base / "installations" / role / "ProximalSolvers.jl", base / "depots" / role))
            self.assertEqual((ident["campaign_id"], ident["session_id"]), ("pb06-migration-stage2b-pilot-v1", SESSION))
            self.assertEqual(ident["proximalbase"]["tag"], "v0.5.4")
            for mm in ("1.10", "1.13"):
                self.assertEqual((base / "roots" / role / f"julia-{mm}" / "environment-inventory.toml").read_text(),
                                 f"# probe of {role} {mm}\n")
            lines = (base / "roots" / role / C.FP_NAME).read_text().split("\n")
            self.assertEqual(sum(1 for l in lines if l.startswith("julia\t")), 1, "one header")
            self.assertEqual([l.split("\t")[0] for l in lines[1:-1]][0], "1.10.13")
            self.assertEqual(lines[-2].split("\t")[0], "1.13.3", "strata in schedule order")
            self.assertTrue((base / "logs" / f"fingerprints-{role}-1.10.tsv.summary.toml").is_file())
        self.assertEqual(len((base / "roots" / "ab-a" / C.DATAHASH_NAME).read_text().split("\n")), 2 * 19 + 2)
        baselines = json.loads((base / "logs" / "depot-baselines.json").read_text())
        self.assertEqual(baselines, {"ab-a": "digest", "ab-b": "digest"})
        marker = json.loads((base / "logs" / "finalize.json").read_text())
        self.assertEqual((marker["state"], marker["cpu"], marker["problems"]), ("finalized", 5, []))
        self.assertTrue(any("finalize: 2 roles, 2 strata, measured CPU 5, 0 problems" in line for line in said))
        # the engine can run on it: plan, identity files and preflight of the fake observations agree
        plan = C.plan_from_pilot(st.config, base, JULIA_BINS, ENVIRON)
        self.assertEqual(plan.cpu, 5)

    def test_the_pilot_schedule_changes_only_the_whitelisted_keys(self):
        st, hooks, *_ = self.finalize()
        base = st.base
        official = tomllib.loads((HERE / "schedule.toml").read_text())
        pilot = tomllib.loads((base / "schedule.toml").read_text())
        before, after = C.flatten(official), C.flatten(pilot)
        changed = {k for k in before.keys() | after.keys() if before.get(k) != after.get(k)}
        self.assertTrue(changed)
        self.assertTrue(all(any(k == a or k.startswith(a + ".") for a in C.PILOT_SCHEDULE_CHANGES) for k in changed),
                        sorted(changed))
        sched = mc.load_schedule(base / "schedule.toml")
        self.assertEqual((sched["id"], sched["campaign_id"]), ("stage2b-pilot-v1", "pb06-migration-stage2b-pilot-v1"))
        self.assertIn("-pilot", sched["id"])
        self.assertEqual((sched["reps"], sched["orders"]), ([1], {1: "AB"}))
        self.assertEqual(tomllib.loads((base / "schedule.toml").read_text())["schedule"]["arms"], ["AB"])
        s = sched["settings"]
        self.assertEqual((s["samples_target"], s["seconds_limit"], s["case_seconds"]), (5, 0.2, 10.0))
        self.assertEqual(s["case_filter"], official["settings"]["case_filter"], "the 19-case filter is kept")
        self.assertEqual((s["suite"], s["groups"], s["profile_seconds"]), (official["settings"]["suite"],
                                                                         official["settings"]["groups"], 0.0))
        m = sched["machine"]
        self.assertEqual((m["cpu_model"], m["cpu"], m["logical_cpu"], m["smt_sibling"]),
                         ("Test CPU @ 3.0GHz", {"1.10": "znver2", "1.13": "znver3"}, 5, -1))
        self.assertEqual((m["governor"], m["epp"], m["no_turbo"], m["smt_control"]),
                         ("unavailable", "unavailable", "unavailable", "forceoff"))
        self.assertEqual(sched["stack_a"], mc.load_schedule(HERE / "schedule.toml")["stack_a"])
        overrides = json.loads((base / "logs" / "pilot-overrides.json").read_text())
        official_digest = C.sha256_file(HERE / "schedule.toml")
        self.assertEqual((overrides["official_schedule_sha256"], overrides["provisional_sha256"]),
                         (official_digest, official_digest))
        self.assertEqual(overrides["final_sha256"], C.sha256_file(base / "schedule.toml"))
        self.assertEqual(overrides["pilot_config_sha256"], C.sha256_file(base / "pilot-config.toml"))
        self.assertEqual(set(overrides["changes"]), changed)
        self.assertFalse((base / "schedule.toml.new").exists(), "no provisional file survives")

    def test_derivation_refuses_any_key_outside_the_whitelist(self):
        official = tomllib.loads((HERE / "schedule.toml").read_text())
        config = full_pilot_config()
        machine = {"cpu_model": "m", "cpu": {"1.10": "a", "1.13": "b"}, "logical_cpu": 3, "smt_sibling": -1,
                   "governor": "g", "epp": "e", "no_turbo": "n", "smt_control": "s"}
        new, changes = C.derive_pilot_schedule(official, config, machine, ("AB",))
        self.assertEqual(new["schedule"]["reps"], [1])
        sneaky = dict(machine, extra="x")                            # an unknown machine key
        with self.assertRaises(C.Refused):
            C.derive_pilot_schedule(official, config, sneaky, ("AB",))
        tampered = copy.deepcopy(official)
        with unittest.mock.patch.object(C, "PILOT_SCHEDULE_CHANGES",
                                        tuple(k for k in C.PILOT_SCHEDULE_CHANGES if k != "machine.smt_sibling")):
            with self.assertRaises(C.Refused) as caught:
                C.derive_pilot_schedule(tampered, config, machine, ("AB",))
        self.assertIn("machine.smt_sibling", str(caught.exception))
        self.assertEqual(official, tomllib.loads((HERE / "schedule.toml").read_text()), "the input is not mutated")
        with self.assertRaises(C.Refused):
            C.derive_pilot_schedule(official, pilot_config(), machine, ("AB",))

    def test_finalize_refuses_to_run_twice_on_one_base(self):
        st, hooks, *_ = self.finalize()
        digest = C.sha256_file(st.base / "schedule.toml")
        calls = len(hooks.calls)
        with self.assertRaises(C.Refused) as caught:
            self.finalize(hooks, st=st)
        self.assertIn("already", str(caught.exception))
        self.assertEqual(len(hooks.calls), calls)
        self.assertEqual(C.sha256_file(st.base / "schedule.toml"), digest, "the schedule is never changed again")
        (st.base / "logs" / "finalize.json").unlink()                 # even without the marker the identity files refuse
        with self.assertRaises(C.Refused):
            self.finalize(hooks, st=st)

    def test_a_failed_finalize_is_not_retried_on_the_same_base(self):
        hooks = FakeFinalize()
        hooks.exit_of["precompile"] = 1
        with self.assertRaises(C.Refused):
            st, *_ = self.finalize(hooks)
        st = prepared_base()
        hooks.exit_of["precompile"] = 1
        with self.assertRaises(C.Refused):
            self.finalize(hooks, st=st)
        hooks.exit_of.clear()
        with self.assertRaises(C.Refused) as caught:
            self.finalize(hooks, st=st)
        self.assertIn("already", str(caught.exception))

    def test_one_allowed_cpu_refuses_before_anything_is_written(self):
        st = prepared_base()
        hooks = FakeFinalize()
        for allowed in ((3,), (3, 4)):                                # fewer than min_cpus = 3
            with self.assertRaises(C.Refused) as caught:
                self.finalize(hooks, allowed=allowed, st=st)
            self.assertIn("CPUs are allowed", str(caught.exception))
        self.assertEqual(hooks.calls, [])
        self.assertFalse((st.base / "logs" / "finalize.json").exists())
        self.assertFalse((st.base / "roots" / "ab-a" / "stack-identity.toml").exists())
        self.finalize(hooks, allowed=(3, 4, 7), st=st)               # the same base then finalizes

    def test_a_base_that_was_not_fetched_is_refused(self):
        st = prepared_base()
        (st.base / "roots" / "ab-b" / "julia-1.13" / "Manifest.toml").chmod(0o644)
        (st.base / "roots" / "ab-b" / "julia-1.13" / "Manifest.toml").unlink()
        with self.assertRaises(C.Refused) as caught:
            self.finalize(st=st)
        self.assertIn("fetch", str(caught.exception))

    def test_each_defect_of_a_step_stops_finalize(self):
        cases = {
            "an export that fails": lambda h: h.exit_of.update(export=1),
            "a warm-up that fails": lambda h: h.exit_of.update(warmup2=3),
            "a warm-up that precompiles again": lambda h: setattr(h, "warm_extra", "Precompiling X\n"),
            "a warm-up that lists too many cases": lambda h: setattr(h, "warm_extra", "extra/case\textended\t\n"),
            "a depot that changes after the first warm-up": lambda h: setattr(
                h, "digest_sequence", itertools.cycle(["one", "two"])),
        }
        for name, setup in cases.items():
            with self.subTest(name):
                hooks = FakeFinalize()
                setup(hooks)
                with self.assertRaises(C.Refused):
                    self.finalize(hooks)

    def test_probe_defects_are_reported_after_the_files_are_written(self):
        hooks = FakeFinalize()
        hooks.edits.append(lambda role, mm, obs: obs["ps"].update(dirty=True) if role == "ab-b" else None)
        with self.assertRaises(C.Refused) as caught:
            st, *_ = self.finalize(hooks)
        self.assertIn("DIRTY", str(caught.exception))
        self.assertTrue(any("DIRTY: ab-b" in p for p in caught.exception.problems))

    def test_the_cpu_model_must_agree_between_julia_and_the_host(self):
        hooks = FakeFinalize()
        hooks.sample["cpu_model"] = "Another CPU"
        with self.assertRaises(C.Refused) as caught:
            self.finalize(hooks)
        self.assertIn("CPU model", str(caught.exception))
        hooks = FakeFinalize()
        hooks.edits.append(lambda role, mm, obs: obs["machine"].update(cpu="other") if role == "ab-b" and mm == "1.10"
                           else None)
        with self.assertRaises(C.Refused) as caught:
            self.finalize(hooks)
        self.assertIn("Sys.CPU_NAME", str(caught.exception))

    def test_a_pilot_without_the_reduced_sampling_values_or_a_session_is_refused(self):
        config = full_pilot_config()
        del config["pilot"]["case_seconds"]
        st = prepared_base(config=config)
        with self.assertRaises(C.Refused) as caught:
            self.finalize(st=st)
        self.assertIn("case_seconds", str(caught.exception))
        self.assertFalse((st.base / "logs" / "finalize.json").exists())
        config = full_pilot_config()
        del config["campaign"]["session_id"]
        st = prepared_base(config=config)
        with self.assertRaises(C.Refused) as caught:
            self.finalize(st=st)
        self.assertIn("session_id", str(caught.exception))

    def test_the_real_cli_path_prepares_and_finalizes_with_given_hooks(self):
        st = prepared_base()
        hooks = FakeFinalize()
        with unittest.mock.patch("os.sched_getaffinity", return_value={1, 2, 3}), \
                unittest.mock.patch("os.sched_setaffinity") as setter:
            code, out, err = call_main(["prepare", "--config", str(st.config_path), "--base", str(st.base), "--step",
                                        "finalize"], hooks=hooks)
        self.assertEqual(code, 0, err)
        self.assertIn("finalize: 2 roles", out)
        setter.assert_called_once_with(0, {1, 2})
        with unittest.mock.patch("os.sched_getaffinity", return_value={1, 2, 3}):
            code, _, err = call_main(["prepare", "--config", str(st.config_path), "--base", str(st.base), "--step",
                                      "finalize"], hooks=hooks)
        self.assertEqual(code, 2)
        self.assertIn("already", err)


class DispatchTests(unittest.TestCase):
    def test_prepare_fetch_through_the_command_line_uses_subprocess_for_git_and_julia(self):
        st, pins, directory, registry, archive = fetch_world("cli-fetch")
        config = full_pilot_config()
        config["source"] = {"repository": str(st.source)}
        config["archive"] = {"path": str(archive)}
        C.write_toml(directory / "cli.toml", config)
        run = Scripted(stale_julia(registry=registry))
        official = mc.load_schedule(HERE / "schedule.toml")
        with unittest.mock.patch.object(C.subprocess, "run", run), unittest.mock.patch.object(
                C, "STAGE2A_ARCHIVE_SHA256", C.sha256_file(archive)), unittest.mock.patch.object(C.time, "sleep"), \
                unittest.mock.patch.object(C, "mc", mc):
            # the synthetic pins replace the historical ones only inside this test
            original = mc.load_schedule

            def patched(path):
                loaded = original(path)
                if Path(path) == HERE / "schedule.toml":
                    loaded["stack_a"] = st.sched["stack_a"]
                return loaded
            with unittest.mock.patch.object(mc, "load_schedule", patched):
                code, out, err = call_main(["prepare", "--config", str(directory / "cli.toml"), "--base",
                                            str(directory / "b" / "x-pilot"), "--step", "fetch"], environ=ENVIRON)
        self.assertEqual(code, 0, err)
        self.assertIn("prepare fetch: 2 roles in x-pilot", out)
        self.assertTrue((directory / "b" / "x-pilot" / "logs" / "prepare-fetch.json").is_file())

    def test_prepare_with_an_invalid_or_absent_configuration_is_a_refusal_that_creates_nothing(self):
        directory = fresh("cli-bad")
        for name, content in (("a pilot without session", pilot_config()),):
            config = copy.deepcopy(content)
            config["julia"] = dict(JULIA_BINS)
            del config["campaign"]["session_id"]
            C.write_toml(directory / "p.toml", config)
            code, _, err = call_main(["prepare", "--config", str(directory / "p.toml"), "--base",
                                      str(directory / "x-pilot"), "--step", "fetch"], hooks=hooks_that_never_run())
            self.assertEqual(code, 2, err)
            self.assertFalse((directory / "x-pilot").exists())
        code, _, err = call_main(["prepare", "--config", str(directory / "p.toml"), "--base",
                                  str(directory / "no-name"), "--step", "fetch"], hooks=hooks_that_never_run())
        self.assertEqual(code, 2)
        self.assertIn("pilot", err)

    def test_the_julia_option_is_validated(self):
        directory = fresh("cli-julia")
        C.write_toml(directory / "p.toml", pilot_config())
        for options in (["--julia", "1.10"], ["--julia", "x=/a"], ["--julia", "1.10=julia"]):
            code, _, err = call_main(["pilot", "--config", str(directory / "p.toml"), "--base", str(directory / "x-pilot"),
                                      *options])
            self.assertEqual(code, 3, (options, err))
        code, _, err = call_main(["pilot", "--config", str(directory / "p.toml"), "--base", str(directory / "x-pilot")])
        self.assertEqual(code, 2, "no binary for any stratum is a refusal")

    def test_preflight_with_real_hooks_prints_every_problem_and_exits_two(self):
        camp = pilot_world()
        base = assemble_base(camp, fresh("pf-real") / "x-pilot", aa=False)
        directory = fresh("pf-real-cfg")
        C.write_toml(directory / "p.toml", pilot_config())
        calls = []

        def scripted(argv, **kwargs):
            calls.append(argv)
            return completed(argv, 1, b"", b"Julia failed")
        with unittest.mock.patch.object(C.subprocess, "run", scripted), unittest.mock.patch(
                "os.sched_getaffinity", return_value={1, 2, 6}), unittest.mock.patch("os.sched_setaffinity"):
            code, out, err = call_main(["preflight", "--config", str(directory / "p.toml"), "--base", str(base),
                                        "--julia", "1.10=/opt/julia-1.10.13/bin/julia",
                                        "--julia", "1.13=/opt/julia-1.13.3/bin/julia"])
        self.assertEqual(code, 2)
        self.assertIn("environment probe", err)
        self.assertFalse((base / "logs").exists(), "preflight writes nothing")
        self.assertEqual(len(calls), 1)


class RealEngineTests(unittest.TestCase):
    """The engine over the real hooks with a scripted subprocess layer: the records come from the fixture, the
    probe and the machine sampler are the mocks of the other tests, everything else is real (command
    construction, the pinned launch, depot digests, the data_hash check, sealing)."""

    def test_a_pilot_runs_through_real_hooks_and_a_scripted_process_layer(self):
        camp = pilot_world("real-engine")
        base = assemble_base(camp, fresh("re") / "x-pilot", aa=False)
        bundled = C.bundled_depots(JULIA_BINS)
        plan = C.plan_from_pilot(pilot_config(), base, JULIA_BINS, ENVIRON, None, bundled)
        add_pilot_config(base)
        host = Host(camp, plan.sched, base)
        runs = []

        def other(argv, kwargs):
            if argv[-1].endswith("run.jl"):
                runs.append(argv)
                result = host.runner(argv, kwargs["env"], kwargs["cwd"], 6)
                return completed(argv, result.exit, result.stdout, result.stderr)
        hooks = C.RealHooks(JULIA_BINS, ENVIRON, run=Scripted(other=other), getaffinity=lambda _: {1, 2, 6},
                            setaffinity=lambda *a: None)
        hooks.probe, hooks.sampler, hooks.clock = host.probe, host.sampler, host.clock
        hooks.bind(plan)
        outcome = C.execute(plan, hooks)
        self.assertEqual((outcome.exit_code, outcome.state, outcome.processes), (0, "completed", 4))
        self.assertEqual(len(runs), 4)
        for argv in runs:
            self.assertEqual(argv[:3], ["taskset", "-c", "6"])
        lines = [json.loads(l) for l in (base / "logs" / "commands.jsonl").read_text().splitlines()]
        self.assertEqual(len({l["depot_digest_before"] for l in lines}), 1)
        self.assertEqual(lines[0]["env"]["JULIA_DEPOT_PATH"].count(":"), 2,
                         "the private depot and the two bundled entries of the Julia installation")


class OfficialGateStubTests(unittest.TestCase):
    def test_with_a_synthetic_lock_the_gate_stops_the_real_hooks_before_the_runner(self):
        camp = F.build_campaign(fresh("gate-stub"), "migration")
        lock = make_lock(camp)
        base = assemble_base(camp, fresh("gate-stub-base") / "official")
        facts = facts_for(base, lock)
        facts["clean"] = False
        directory = fresh("gate-stub-cfg")
        C.write_toml(directory / "lock.toml", lock)
        calls = []
        with unittest.mock.patch.object(C.subprocess, "run", lambda *a, **k: calls.append(a)):
            code, _, err = call_main(["run", "--config", str(directory / "lock.toml"), "--base", str(base), "--official",
                                      "--freeze-sha", FREEZE, "--julia", "1.10=/opt/j10/bin/julia",
                                      "--julia", "1.13=/opt/j13/bin/julia"], facts=lambda *a: facts)
        self.assertEqual((code, calls), (2, []))
        self.assertIn("CLEAN", err)
        for forbidden in ("--ignore-gate", "--no-gate"):
            code, _, _ = call_main(["run", "--config", str(directory / "lock.toml"), "--base", str(base),
                                    "--official", "--freeze-sha", FREEZE, forbidden])
            self.assertEqual(code, 3)



class LayoutTests(unittest.TestCase):
    def test_the_module_stays_standard_library_only_and_does_not_import_pre06(self):
        text = (HERE / "stage2b_campaign.py").read_text(encoding="utf-8")
        # the Stage 2A campaign definition is data (TOML): `prepare` compares the Manifest entries with its lock
        self.assertNotIn("pre06", text.replace("benchmark/campaigns/pre06/campaign.py", "").replace(
            'BENCH / "campaigns" / "pre06" / "campaign.toml"', ""))
        imports = {line.split()[1].split(".")[0] for line in text.splitlines() if line.startswith("import ")}
        self.assertTrue(imports <= set(sys.stdlib_module_names), imports - set(sys.stdlib_module_names))
        self.assertNotIn("os.environ", text.replace("os.environ if environ is None else environ", ""))
        self.assertNotIn("--ignore-", text)

    def test_the_schedule_is_loaded_by_the_comparators_parser_only(self):
        text = (HERE / "stage2b_campaign.py").read_text(encoding="utf-8")
        self.assertIn("mc.load_schedule", text)
        self.assertNotIn("def load_schedule", text)
        self.assertIs(C.mc, sys.modules["migration_compare"])


if __name__ == "__main__":
    unittest.main(verbosity=1)
