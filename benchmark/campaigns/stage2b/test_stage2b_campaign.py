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
    return {"schema": 1, "campaign": {"id": "pb06-migration-stage2b-pilot-v1", "session_id": session},
            "schedule": {"id": "stage2b-pilot-v1"}, "pilot": {"arms": list(arms)}}


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

    def test_a_passing_gate_without_the_real_hooks_is_not_implemented_here(self):
        directory = fresh("gate-ok")
        C.write_toml(directory / "lock.toml", self.lock)
        code, _, err = call_main(["run", "--config", str(directory / "lock.toml"), "--base", str(directory / "b"),
                                  "--official", "--freeze-sha", FREEZE], facts=lambda *a: self.facts)
        self.assertEqual(code, 3)
        self.assertIn("not implemented in this task", err)
        self.assertFalse((directory / "b").exists())

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

    def test_a_valid_pilot_without_the_real_hooks_is_not_implemented_here(self):
        directory = fresh("pilot-ok")
        C.write_toml(directory / "p.toml", pilot_config())
        code, _, err = call_main(["pilot", "--config", str(directory / "p.toml"), "--base", str(directory / "x-pilot")])
        self.assertEqual(code, 3)
        self.assertIn("not implemented in this task", err)

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
        self.assertEqual(commands[0]["env"], env)
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
        document, status = C.verify(base, fresh("v") / "verification.json")
        self.assertEqual((status, document["state"], document["problems"]), (0, "verified", []))
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
        document, status = C.verify(base, fresh("v") / "v.json")
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
        host = Host(camp, plan.sched, base)
        outcome = C.execute(plan, host.hooks())
        self.assertEqual(outcome.exit_code, 1)
        self.assertEqual(len(host.calls), 4, "no retry")
        self.assertEqual([n["failed_cases"] for n in outcome.nonok], [[case_id], [case_id]])
        self.assertEqual(self.state(base)["state"], "completed")
        self.assertEqual(json.loads((base / "logs" / "completion.json").read_text())["outcome"], "non_ok")
        self.assertEqual({e["exit"] for e in self.receipt(base)[1:3]}, {2})
        document, status = C.verify(base, fresh("v") / "v.json")
        self.assertEqual((status, document["state"], document["problems"]), (1, "verified_non_ok", []))
        code, _, err = call_main(["verify", "--base", str(base), "--out", str(fresh("v") / "v.json")])
        self.assertEqual(code, 1)

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
        document, status = C.verify(base, fresh("v") / "v.json")
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
        self.assertEqual(set(self.document), {"schema", "problems", "campaign_state", "campaign_outcome",
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
                writable(path).write_text(json.dumps(data))
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
            document, status = C.verify(base, fresh("v") / "v.json")
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
            for name in ("comparator.json", "completion.json"):
                pass
            path = writable(b / "logs" / "completion.json")
            record = json.loads(path.read_text())
            record.update(processes=32, receipt_sha256=C.sha256_file(b / "receipt.jsonl"))
            path.write_text(json.dumps(record))
        base = self.mutated(drop)
        document = self.failed(base, "the root is missing", replay=False)
        self.assertTrue(any("arm AA" in p and "is missing" in p for p in document["problems"]))
        self.assertTrue(any("counts 32 processes, expected 64" in p for p in document["problems"]))

    def test_a_schedule_edited_to_drop_the_arm_disagrees_with_the_recorded_campaign(self):
        def edit(b):
            edit_text(b / "schedule.toml", lambda t: t.replace('arms = ["AB", "AA"]', 'arms = ["AB"]'))
        self.failed(self.mutated(edit), "logs/campaign.json: arms", replay=False)

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
            path = writable(b / "logs" / "completion.json")
            record = json.loads(path.read_text())
            record.update(schema=99, campaign_id="other", session_id="session-x", schedule_id="elsewhere")
            path.write_text(json.dumps(record))
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
        document, status = C.verify(base, fresh("v") / "v.json")
        self.assertEqual((status, document["problems"]), (0, []))
        bad = clone(base)
        edit_text(bad / "pilot-config.toml", lambda t: t.replace("stage2b-pilot-v1", "stage2b-pilot-v2"))
        refresh_all(bad)
        document, status = C.verify(bad, fresh("v") / "v.json", replay=False)
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
            self.assertEqual(code, 3)
            self.assertIn("not implemented in this task", err)
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
        code, _, _ = call_main(["verify", "--base", str(base), "--out", str(fresh("pe-v") / "v.json")])
        self.assertEqual(code, 0)
        code, _, err = call_main(["pilot", "--config", str(directory / "p.toml"), "--base", str(base)],
                                 hooks=hooks_that_never_run())
        self.assertEqual(code, 2, "a finished base is never reused")


class LayoutTests(unittest.TestCase):
    def test_the_module_stays_standard_library_only_and_does_not_import_pre06(self):
        text = (HERE / "stage2b_campaign.py").read_text(encoding="utf-8")
        self.assertNotIn("pre06", text.replace("benchmark/campaigns/pre06/campaign.py", ""))
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
