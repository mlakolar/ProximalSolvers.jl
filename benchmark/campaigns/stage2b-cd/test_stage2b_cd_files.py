#!/usr/bin/env python3
"""Offline tests of the definition files of the CD-only successor campaign (#333, under #110).

    python3 -B benchmark/campaigns/stage2b-cd/test_stage2b_cd_files.py

Standard library only (Python 3.11 or later) and `git`, with the history of this repository: the identities of
`[stack_a]` and of the lock are recomputed from git at the pinned commits (the Stack A harness-port commit lives on
the branch archive/stage2b-cd-stack-a-port); a missing commit fails, it is never skipped. No Julia, no network.

Checks: schedule <-> case list <-> mapping consistency; the Stage 2A sampling settings; the `[stack_a]` identities
(parent, changed files, tree, package hash, harness hash); the harness of Stack B at 9f86a808 equals the port's;
the lock (when present) against git and against its environment files; and the byte-unchanged frozen files of the
original Stage 2B campaign, the four harness files and the Stage 2A campaign definition, pinned by SHA-256 as they
are on master at 9f86a808.
"""

import hashlib
import subprocess
import sys
import tarfile
import tempfile
import tomllib
import unittest
import unittest.mock
from pathlib import Path

HERE = Path(__file__).resolve().parent
STAGE2B = HERE.parent / "stage2b"
REPO = HERE.parents[2]
sys.dont_write_bytecode = True
sys.path.insert(0, str(STAGE2B))

import migration_compare as mc            # noqa: E402  (the comparator's own loader reads the schedule)
import stage2b_campaign as C              # noqa: E402

RULING = "https://github.com/mlakolar/ProximalSolvers.jl/issues/330#issuecomment-6910364487"
STACK_A_BASE = "b0de3f7fc91767b97197ff4b458207e308998943"     # Stage 2A measured source
STACK_B_PS = "9f86a808bfac968f5421b9efeb6d0aecd7c1c775"       # master after #307
HARNESS_FILES = ("problems.jl", "certificates.jl", "cases.jl", "run.jl")
HARNESS_HASH = "164fab53cac906e52e5a75e8b93658c1d174c14e"     # the harness of STACK_B_PS, on both stacks
PACKAGE_HASH_A = "f37fc61f300ad597a33c7ab5f448d38c865db854"   # Stage 2A package hash of b0de3f7
STAGE2B_ORDERS = {1: "AB", 2: "BA", 3: "BA", 4: "AB", 5: "BA", 6: "AB", 7: "AB", 8: "BA"}
SAMPLING = {"samples_target": 100, "seconds_limit": 3.0, "case_seconds": 60.0, "profile_seconds": 0.0,
            "julia_threads": 1, "blas_threads": 1, "seed_scheme": "FNV1a64 keyed scenario xor repetition"}
CLASS_REASON = "identical harness bytes on both stacks; inputs/starts/targets/options/timing definitions identical"

# SHA-256 of the files that this PR must leave byte-for-byte as they are on master (9f86a808).
FROZEN = {
    "benchmark/campaigns/stage2b/schedule.toml": "215b4d3d313b8d66146fe90a97d5ee749c6bf70ecaa32b5abaf98a8b53303921",
    "benchmark/campaigns/stage2b/case-mapping.toml": "8f1192a17041d648cd1131eda676377729901879b098ed9577b8cc512d5b1908",
    "benchmark/campaigns/stage2b/CASE_MAPPING.md": "fca63d8451e6225c55c883e730f38b13515f3e1b5fec68e4ffde1c9fcb41497e",
    "benchmark/campaigns/stage2b/historical-reference.tsv":
        "1aeab77a511fc6517ab7fa0e1292f13f16311f07b3bfc787b6bfc0d11163a92e",
    "benchmark/campaigns/stage2b/STAGE2B_PLAN.md": "8e17804eb64e16fea4cacc295301bfac870a2ba740a20bdeaed8dde04927e690",
    "benchmark/campaigns/stage2b/MIGRATION_COMPARE_SPEC.md":
        "05ce614e701e26b6760091e776d855e8135df39926f7440068e6a9a183c307f9",
    "benchmark/problems.jl": "b047b47275907a31e0f3ed1de7629ed3f965534dd2d1fcafd03c52dd0092fa51",
    "benchmark/certificates.jl": "ce09cbcbcaa1091f6ca362e0689340c1a367b3968542fd1d3c7ca9465f5770e1",
    "benchmark/cases.jl": "b48f3e012eab0438d2ce3e5172ca2cd1eb740952f8ab61d976ff10e4f50b8aa5",
    "benchmark/run.jl": "99eb11d9447dddeafe626274c937f32d39fe138aae0b3f992be25cc457360d14",
}


def git(*args):
    result = subprocess.run(["git", "-C", str(REPO), *args], capture_output=True, text=True)
    if result.returncode != 0:
        raise AssertionError(f"git {' '.join(args)} failed: {result.stderr.strip()}")
    return result.stdout.strip()


def export_commit(commit, directory):
    """The tree of `commit` extracted with git archive (never the working tree)."""
    archive = Path(directory) / f"{commit}.tar"
    subprocess.run(["git", "-C", str(REPO), "archive", "--format=tar", "-o", str(archive), commit], check=True)
    target = Path(directory) / commit
    target.mkdir()
    with tarfile.open(archive) as tar:
        tar.extractall(target, filter="data")
    return target


def sha256(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def load(name):
    return tomllib.loads((HERE / name).read_text(encoding="utf-8"))


class Files(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.tmp = tempfile.TemporaryDirectory(prefix="stage2b-cd-files-")
        cls.addClassCleanup(cls.tmp.cleanup)
        cls.sched = mc.load_schedule(HERE / "schedule.toml")
        cls.raw = load("schedule.toml")
        cls.mapping = load("case-mapping.toml")
        cls.original = mc.load_schedule(STAGE2B / "schedule.toml")
        cls.cases = cls.sched["cases"]


class ScheduleTests(Files):
    def test_the_identities_and_the_design_of_the_original_schedule(self):
        s, o = self.sched, self.original
        self.assertEqual((s["id"], s["campaign_id"]), ("stage2b-cd-8block-v1", "stage2b-cd-minimal-core-v1"))
        self.assertNotEqual((s["id"], s["campaign_id"]), (o["id"], o["campaign_id"]))
        self.assertEqual((s["reps"], s["orders"], self.raw["schedule"]["arms"]),
                         (o["reps"], STAGE2B_ORDERS, ["AB", "AA"]))
        self.assertEqual(s["strata"], o["strata"], "the same two exact Julia builds")

    def test_the_sampling_settings_are_those_of_stage_2a(self):
        settings = self.sched["settings"]
        stage2a = tomllib.loads((REPO / "benchmark/campaigns/pre06/campaign.toml").read_text(encoding="utf-8"))
        for key, value in SAMPLING.items():
            self.assertEqual(settings[key], value, key)
            self.assertIs(type(settings[key]), type(value), key)
        self.assertEqual(settings["suite"], "extended")
        self.assertEqual(settings["groups"], "cd", "the string run.jl records for PS_GROUPS=cd")
        env = stage2a.get("env", stage2a.get("settings", {}))
        for key, name in (("samples_target", "PS_SAMPLES"), ("seconds_limit", "PS_SECONDS"),
                          ("case_seconds", "PS_CASE_SECONDS"), ("profile_seconds", "PS_PROFILE_SECONDS")):
            if name in env:
                self.assertEqual(float(env[name]), float(settings[key]), name)

    def test_the_case_filter_is_21_distinct_cd_ids_joined_byte_for_byte(self):
        filter_text = self.sched["settings"]["case_filter"]
        self.assertEqual(len(self.cases), 21)
        self.assertEqual(len(set(self.cases)), 21)
        self.assertEqual(",".join(self.cases), filter_text)
        self.assertEqual(self.cases, sorted(self.cases), "the catalog order of the harness sorts by ID")
        for cid in self.cases:
            group, problem, solver, variant, phase = cid.split("/")
            self.assertEqual((group, solver, phase), ("cd", "cd", "call"), cid)
        self.assertIn("cd/lasso-dense/cd/R/call", self.cases)
        self.assertFalse(set(self.cases) & set(self.original["cases"]), "no ID of the original 19 is reused")

    def test_the_machine_is_the_discovery_epyc_7513(self):
        m = self.sched["machine"]
        self.assertEqual(m["cpu_model"], "AMD EPYC 7513 32-Core Processor")
        self.assertEqual(m["cpu"], {"1.10": "znver3", "1.13": "znver3"})
        self.assertEqual(set(m["cpu"]), set(self.sched["strata"]))
        self.assertNotEqual(m["logical_cpu"], 0)
        self.assertEqual(m["smt_sibling"], -1, "one thread per core: no sibling (the value the pilot writes)")
        self.assertEqual((m["governor"], m["epp"], m["no_turbo"], m["smt_control"]),
                         ("unavailable", "unavailable", "unavailable", "notsupported"))


class MappingTests(Files):
    def test_one_class_a_approved_row_per_case_in_schedule_order(self):
        rows = self.mapping["case"]
        self.assertEqual([r["id"] for r in rows], self.cases)
        self.assertEqual([r["label"] for r in rows], [f"C{i:02d}" for i in range(1, 22)])
        for row in rows:
            self.assertEqual((row["class"], row["approved"], row["approval_url"], row["class_reason"]),
                             ("A", True, RULING, CLASS_REASON), row["id"])
            for field in ("family", "inputs", "seed_key", "objective", "penalty", "initial_state", "working_set",
                          "reset", "solver_options", "certificate", "work_counters", "sensitive_paths_06",
                          "verification_needed", "equivalence_check", "measure", "target", "phase", "role"):
                self.assertTrue(row.get(field), (row["id"], field))
        self.assertEqual({r["phase"] for r in rows}, {"call"})

    def test_the_targets_follow_the_precision_and_the_release_case_has_none(self):
        for row in self.mapping["case"]:
            cid = row["id"]
            expected = "NaN" if cid.endswith("/R/call") else "1e-05" if "-f32/" in cid else "1e-08"
            self.assertEqual(row["target"], expected, cid)
            self.assertEqual(row["measure"].split(",")[0], "relative_gap")

    def test_the_comparator_accepts_the_mapping_against_a_catalog_of_the_same_rows(self):
        rows = []
        refusals = []
        mapping = mc.read_mapping(self.mapping, refusals)
        self.assertEqual(refusals, [])
        cat = {r["id"]: {"phase": r["phase"], "measure": r["measure"].split(",")[0], "target": r["target"]}
               for r in mapping}
        root = {"strata": {mm: {"version": info["version"], "cat": cat} for mm, info in self.sched["strata"].items()}}
        mc.check_mapping(mapping, root, self.sched, rows)
        self.assertEqual(rows, [], "roles are the comparator's positional labels (first 14 primary, rest diagnostic)")

    def test_the_header_names_the_successor_and_the_harness(self):
        self.assertEqual(self.mapping["campaign_definition"], self.sched["campaign_id"])
        self.assertEqual((self.mapping["harness_commit"], self.mapping["harness_hash"]), (STACK_B_PS, HARNESS_HASH))


class StackATests(Files):
    @classmethod
    def setUpClass(cls):
        super().setUpClass()
        cls.stack = cls.sched["stack_a"]
        cls.ps = cls.stack["proximalsolvers"]
        cls.port = cls.ps["commit"]

    def test_the_port_is_a_harness_only_child_of_the_stage_2a_source(self):
        self.assertEqual(git("rev-parse", f"{self.port}^{{commit}}"), self.port)
        self.assertEqual(git("rev-parse", f"{self.port}^"), STACK_A_BASE)
        self.assertEqual(git("rev-list", "--parents", "-n", "1", self.port).split(), [self.port, STACK_A_BASE])
        changed = set(git("diff", "--name-only", STACK_A_BASE, self.port).split("\n"))
        self.assertTrue(changed <= {f"benchmark/{name}" for name in HARNESS_FILES}, changed)
        self.assertTrue(changed, "the port changes at least one harness file")
        for name in HARNESS_FILES:
            self.assertEqual(git("rev-parse", f"{self.port}:benchmark/{name}"),
                             git("rev-parse", f"{STACK_B_PS}:benchmark/{name}"), name)
        self.assertEqual(git("rev-parse", f"{self.port}^{{tree}}"), self.ps["tree"])
        self.assertEqual(self.ps["version"], "0.3.2")

    def test_the_identities_are_recomputed_from_git(self):
        root = export_commit(self.port, self.tmp.name)
        self.assertEqual(C.package_fingerprint(root), self.ps["package_hash"])
        self.assertEqual(self.ps["package_hash"], PACKAGE_HASH_A)
        self.assertEqual(C.harness_hash(root / "benchmark"), self.stack["harness_hash"])
        self.assertEqual(self.stack["harness_hash"], HARNESS_HASH)
        tomllib.loads((root / "Project.toml").read_text(encoding="utf-8"))
        # the solver source is that of Stage 2A: nothing outside the four files differs from b0de3f7
        self.assertEqual(git("diff", "--stat", STACK_A_BASE, self.port, "--", ":(exclude)benchmark"), "")

    def test_the_harness_of_stack_b_equals_the_ports(self):
        root = export_commit(STACK_B_PS, self.tmp.name)
        self.assertEqual(C.harness_hash(root / "benchmark"), self.stack["harness_hash"])
        self.assertNotEqual(C.package_fingerprint(root), self.ps["package_hash"], "the packages differ by design")

    def test_the_proximalbase_block_is_the_registered_0_5_4_of_the_original_campaign(self):
        self.assertEqual(self.stack["proximalbase"], self.original["stack_a"]["proximalbase"])
        self.assertEqual((self.stack["proximalbase"]["version"], self.stack["proximalbase"]["release"]),
                         ("0.5.4", "registered"))

    def test_the_stack_a_block_is_not_the_original_one(self):
        self.assertNotEqual(self.stack["harness_hash"], self.original["stack_a"]["harness_hash"])
        self.assertNotEqual(self.ps["commit"], self.original["stack_a"]["proximalsolvers"]["commit"])
        self.assertNotEqual(self.ps["tree"], self.original["stack_a"]["proximalsolvers"]["tree"])
        self.assertEqual(self.ps["package_hash"], self.original["stack_a"]["proximalsolvers"]["package_hash"])


class LockTests(Files):
    @classmethod
    def setUpClass(cls):
        super().setUpClass()
        cls.lock = C.load_lock(HERE / "lock.toml", strata=list(cls.sched["strata"]))
        cls.b = cls.lock["stack_b"]

    def test_the_lock_names_the_campaign_and_stack_b_by_full_identities(self):
        self.assertEqual(self.lock["campaign"]["id"], self.sched["campaign_id"])
        ps, pb = self.b["proximalsolvers"], self.b["proximalbase"]
        self.assertEqual(ps["commit"], STACK_B_PS)
        self.assertEqual(git("rev-parse", f"{STACK_B_PS}^{{tree}}"), ps["tree"])
        self.assertEqual(self.b["harness_hash"], HARNESS_HASH)
        self.assertEqual((pb["version"], pb["release"], pb["commit"]),
                         ("0.6.0-DEV", "development", "50db4b1ef376cbe01831c3dd019b6be0027db0b6"))
        self.assertEqual(pb["tree"], "4556e470aea2da876ea3b5a5998618f4c17326b1")
        with unittest.mock.patch.object(C, "CAMPAIGN_DIR", HERE):
            self.assertEqual(C.static_candidate_problems(self.b), [], "the static checks of the official gate")

    def test_the_package_hash_of_stack_b_is_recomputed_from_git(self):
        root = export_commit(STACK_B_PS, self.tmp.name)
        self.assertEqual(C.package_fingerprint(root), self.b["proximalsolvers"]["package_hash"])

    def test_the_environment_files_match_their_digests_and_use_relative_paths(self):
        for mm, env in self.b["environments"].items():
            for key in ("project", "manifest"):
                path = REPO / env[key]
                self.assertTrue(path.is_file(), env[key])
                self.assertEqual(sha256(path), env[f"{key}_sha256"], env[key])
                self.assertTrue(env[key].startswith("benchmark/campaigns/stage2b-cd/freeze/stack-b/"), env[key])
            manifest = tomllib.loads((REPO / env["manifest"]).read_text(encoding="utf-8"))
            ps = manifest["deps"]["ProximalSolvers"][0]
            self.assertEqual(ps["path"], "../../../installations/ab-b/ProximalSolvers.jl")
            pb = manifest["deps"]["ProximalBase"][0]
            self.assertEqual((pb["repo-rev"], pb["git-tree-sha1"], pb["version"]),
                             (self.b["proximalbase"]["commit"], self.b["proximalbase"]["tree"], "0.6.0-DEV"))
            self.assertEqual(manifest["julia_version"], self.sched["strata"][mm]["version"])


class UnchangedFilesTests(unittest.TestCase):
    def test_the_frozen_files_are_byte_for_byte_those_of_master(self):
        # The frozen files of the original campaign must be unchanged in this checkout. The harness files are pinned
        # at the commit the lock names (the next test): master may move on after 9f86a808 (#326 changed cases.jl),
        # and the campaign runs the harness of the pinned checkouts, never that of this checkout.
        for relative, digest in FROZEN.items():
            if relative.startswith("benchmark/campaigns/"):
                self.assertEqual(sha256(REPO / relative), digest, relative)

    def test_the_pinned_digests_are_those_of_the_commit_the_lock_names(self):
        for relative, digest in FROZEN.items():
            blob = subprocess.run(["git", "-C", str(REPO), "show", f"{STACK_B_PS}:{relative}"], capture_output=True)
            self.assertEqual(blob.returncode, 0, relative)
            self.assertEqual(hashlib.sha256(blob.stdout).hexdigest(), digest, relative)

    def test_nothing_under_pre06_or_src_differs_from_the_commit_the_lock_names(self):
        # src/ and the root project files are not compared with this checkout: master may move on after
        # 9f86a808 (#326), including its ProximalBase pin. The environment of Stack B is bound by the commit,
        # tree and package hash of the lock (recomputed from git above) and by the freeze/stack-b/ files.
        for path in ("benchmark/campaigns/pre06",):
            result = subprocess.run(["git", "-C", str(REPO), "diff", "--quiet", STACK_B_PS, "--", path])
            self.assertEqual(result.returncode, 0, path)


if __name__ == "__main__":
    unittest.main(verbosity=1)
