#!/usr/bin/env python3
"""Offline tests of the Stage 2B preparation files (#110).

    python3 -B -m unittest test_stage2b_files -v        (from benchmark/campaigns/stage2b)

Standard library only (tomllib, Python 3.11 or later). No git, no network, no Julia: the tests read the
files of this directory and of ../pre06/ and build small synthetic archives in a temporary directory.
"""

import ast
import contextlib
import csv
import hashlib
import importlib.util
import io
import os
import re
import tempfile
import tomllib
import unittest

HERE = os.path.dirname(os.path.abspath(__file__))
PRE06 = os.path.join(HERE, "..", "pre06")
BENCH = os.path.join(HERE, "..", "..")

REQUIRED_FIELDS = (
    "label", "id", "role", "family", "phase", "inputs", "seed_key", "objective", "penalty",
    "initial_state", "working_set", "reset", "solver_options", "certificate", "measure", "target",
    "work_counters", "sensitive_paths_06", "class", "class_reason", "verification_needed",
    "equivalence_check",
)
P14_HISTORICAL = "reset!() = (fill!(x, 0.0); reset_solver_rng!(method); nothing)"
P14_PORT = "reset!() = (dropzeros!(fill!(x, 0.0)); reset_solver_rng!(method); nothing)"
ARCHIVE_SHA256 = "1edd64330606d739acf1d7b4ba0643a4fb6a1366bad4c82393e2ba1ffdcc723e"
HASH = re.compile(r"[0-9a-f]{64}")


def read(path):
    with open(path, encoding="utf-8") as handle:
        return handle.read()


def load_toml(path):
    with open(path, "rb") as handle:
        return tomllib.load(handle)


def strings(value):
    """A field is a string or an array of strings; return the list of its strings."""
    if isinstance(value, str):
        return [value]
    assert isinstance(value, list), f"expected a string or an array of strings, got {type(value)}"
    assert all(isinstance(item, str) for item in value), "array with a non-string item"
    return value


def stage2b_files():
    for folder, _, names in os.walk(HERE):
        if "__pycache__" in folder:
            continue
        for name in sorted(names):
            if name.endswith(".pyc"):
                continue
            yield os.path.join(folder, name)


class CaseMappingTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.mapping = load_toml(os.path.join(HERE, "case-mapping.toml"))
        cls.campaign = load_toml(os.path.join(PRE06, "campaign.toml"))
        cls.cases = cls.mapping["case"]

    def test_ids_equal_cases_txt_byte_for_byte_and_in_order(self):
        with open(os.path.join(PRE06, "cases.txt"), "rb") as handle:
            raw = handle.read()
        ids = [case["id"] for case in self.cases]
        self.assertEqual(len(ids), 19)
        self.assertEqual(("\n".join(ids) + "\n").encode("utf-8"), raw)
        self.assertEqual(hashlib.sha256(raw).hexdigest(), self.campaign["cases"]["sha256"])

    def test_labels_roles_and_phases_equal_campaign_toml(self):
        expected = self.campaign["case"]
        self.assertEqual([c["label"] for c in self.cases], [c["label"] for c in expected])
        self.assertEqual([c["role"] for c in self.cases], [c["role"] for c in expected])
        self.assertEqual([c["phase"] for c in self.cases], [c["phase"] for c in expected])
        roles = [c["role"] for c in self.cases]
        self.assertEqual((roles.count("primary"), roles.count("diagnostic")), (14, 5))
        self.assertEqual([c["label"] for c in self.cases],
                         [f"P{i:02d}" for i in range(1, 15)] + [f"D{i:02d}" for i in range(1, 6)])
        for case, base in zip(self.cases, expected):
            self.assertEqual(float(case["target"]), float(base["target"]), case["label"])
            self.assertTrue(case["measure"].startswith(base["measure"]), case["label"])

    def test_every_required_field_is_present_and_nonempty_and_class_is_valid(self):
        for case in self.cases:
            for field in REQUIRED_FIELDS:
                self.assertIn(field, case, f"{case.get('label')}: missing {field}")
                items = strings(case[field])
                self.assertTrue(items, f"{case['label']}: empty {field}")
                for item in items:
                    self.assertTrue(item.strip(), f"{case['label']}: blank text in {field}")
            self.assertIn(case["class"], ("A", "B", "C", "D"), case["label"])
            extra = set(case) - set(REQUIRED_FIELDS)
            self.assertFalse(extra, f"{case['label']}: unexpected fields {sorted(extra)}")

    def test_p14_is_class_b_with_both_reset_lines(self):
        p14 = next(c for c in self.cases if c["label"] == "P14")
        self.assertEqual(p14["class"], "B")
        reset = "\n".join(strings(p14["reset"]))
        self.assertIn(P14_HISTORICAL, reset)
        self.assertIn(P14_PORT, reset)
        # The historical line is the one in the harness (or, after the reviewed port, the port is).
        harness = read(os.path.join(BENCH, "cases.jl"))
        self.assertTrue(P14_HISTORICAL in harness or P14_PORT in harness)
        self.assertEqual([c["label"] for c in self.cases if c["class"] == "B"], ["P14"])

    def test_no_class_a_row_has_an_empty_verification_needed(self):
        for case in self.cases:
            if case["class"] == "A":
                items = strings(case["verification_needed"])
                self.assertTrue(items and all(item.strip() for item in items), case["label"])

    def test_no_class_c_or_d_without_evidence(self):
        # There is no evidence for a class C or D yet; the mapping must not claim one.
        self.assertEqual({c["class"] for c in self.cases}, {"A", "B"})

    def test_mapping_cites_the_audited_commit_and_never_a_moving_branch(self):
        self.assertEqual(self.mapping["audited_commit"], "7b9b5295302bd177046284b017a8304cf5a99341")
        self.assertEqual(self.mapping["measured_source"], "b0de3f7fc91767b97197ff4b458207e308998943")
        text = read(os.path.join(HERE, "case-mapping.toml"))
        self.assertNotRegex(text, r"origin/master|HEAD~|\bmaster@")


class HistoricalReferenceTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        lines = [l for l in read(os.path.join(HERE, "historical-reference.tsv")).splitlines()]
        cls.comments = [l for l in lines if l.startswith("#")]
        body = [l for l in lines if l and not l.startswith("#")]
        cls.rows = list(csv.DictReader(body, delimiter="\t"))
        cls.campaign = load_toml(os.path.join(PRE06, "campaign.toml"))

    def test_header_comments_state_the_archive_digest(self):
        self.assertTrue(self.comments)
        self.assertTrue(any(ARCHIVE_SHA256 in line for line in self.comments))
        self.assertTrue(any("bench-pre06-v1" in line for line in self.comments))

    def test_two_strata_of_19_rows_with_five_medians_and_hashes(self):
        self.assertEqual(len(self.rows), 38)
        self.assertEqual({r["julia"] for r in self.rows}, {"1.10.13", "1.13.3"})
        cases = {c["label"]: c for c in self.campaign["case"]}
        for julia in ("1.10.13", "1.13.3"):
            labels = [r["label"] for r in self.rows if r["julia"] == julia]
            self.assertEqual(labels, [c["label"] for c in self.campaign["case"]])
        for row in self.rows:
            base = cases[row["label"]]
            self.assertEqual((row["id"], row["role"], row["phase"], row["inputs"]),
                             (base["id"], base["role"], base["phase"], base["inputs"]))
            medians = [int(x) for x in row["rep_median_ns"].split(";")]
            hashes = row["data_hash_per_rep"].split(";")
            self.assertEqual(len(medians), 5)
            self.assertEqual(len(hashes), 5)
            self.assertTrue(all(HASH.fullmatch(h) for h in hashes))
            self.assertAlmostEqual(float(row["mean_of_medians_ns"]), sum(medians) / 5, places=6)
            self.assertEqual(row["status"], "ok")
            self.assertEqual(int(row["ok_samples_total"]), 500)

    def test_fixed_input_cases_have_one_hash_and_draw_cases_five(self):
        for row in self.rows:
            distinct = len(set(row["data_hash_per_rep"].split(";")))
            self.assertEqual(int(row["distinct_hashes"]), distinct)
            self.assertEqual(distinct, 1 if row["inputs"] == "fixed" else 5, row["label"])
        fixed = {r["label"] for r in self.rows if r["inputs"] == "fixed"}
        self.assertEqual(fixed, {"P01", "P02", "P03", "P11", "P12", "D01"})

    def test_julia_versions_have_different_input_hashes(self):
        first = {}
        for row in self.rows:
            first.setdefault(row["label"], {})[row["julia"]] = row["data_hash_per_rep"].split(";")[0]
        for label, by_julia in first.items():
            self.assertNotEqual(by_julia["1.10.13"], by_julia["1.13.3"], label)


class TextHygieneTests(unittest.TestCase):
    # Pieces are concatenated so that this file does not trip over its own patterns.
    INFRASTRUCTURE = ("/scr" + "atch", "mkolar_" + "1314", "dis" + "covery", "ti" + "tan",
                      "sr" + "un", "sb" + "atch")
    CLOSING = re.compile(
        r"\b(?:close[sd]?|closing|fix(?:e[sd]|ing)?|resolve[sd]?|resolving)\b"
        r"(?:[ \t:,(]+[\w./-]+){0,3}?[ \t:,(]*[\w.-]*/?[\w.-]*#(?:110|527)\b", re.IGNORECASE)
    TAG = "bench-pre06-v1"
    MUTATING = re.compile(r"\b(?:upload|re-?upload|replac\w+|delet\w+|modif\w+|overwrit\w+|re-?tag\w*|"
                          r"force-?push\w*|publish\w*|edit\w*|move[sd]?|amend\w*)\b", re.IGNORECASE)
    NEGATION = re.compile(r"\b(?:never|not|no|without|read-only|unchanged|untouched)\b", re.IGNORECASE)

    def texts(self):
        for path in stage2b_files():
            try:
                yield path, read(path)
            except UnicodeDecodeError:
                self.fail(f"{path} is not UTF-8 text")

    def test_no_github_closing_keyword_next_to_the_issue_numbers(self):
        for path, text in self.texts():
            self.assertIsNone(self.CLOSING.search(text), f"{path}: closing keyword near an issue number")
        # the pattern itself catches the usual forms, negations included (built from pieces so that
        # this file does not contain the keywords next to the numbers)
        kw = ("clo" + "ses", "Fi" + "xes", "does not clo" + "se", "reso" + "lved:", "Clo" + "se")
        for sample in (f"{kw[0]} #110", f"{kw[1]} mlakolar/ProximalBase.jl#527", f"{kw[2]} #110",
                       f"{kw[3]} #527", f"{kw[4]} #110"):
            self.assertIsNotNone(self.CLOSING.search(sample), sample)
        for sample in ("Part of #110", "Related: mlakolar/ProximalBase.jl#527",
                       "fixed-input cases (#108)", "closed form, see the plan"):
            self.assertIsNone(self.CLOSING.search(sample), sample)

    def test_no_infrastructure_strings(self):
        for path, text in self.texts():
            lowered = text.lower()
            for needle in self.INFRASTRUCTURE:
                self.assertNotIn(needle, lowered, f"{path}: infrastructure string {needle!r}")

    def test_the_published_stage2a_tag_appears_only_in_a_read_only_context(self):
        found = False
        for path, text in self.texts():
            for number, line in enumerate(text.splitlines(), 1):
                if self.TAG not in line:
                    continue
                found = True
                stripped = line.replace(self.TAG, "TAG")
                if self.MUTATING.search(stripped):
                    self.assertRegex(stripped, self.NEGATION,
                                     f"{path}:{number}: tag in a possibly mutating sentence")
        self.assertTrue(found, "the tag should be named, in a read-only context, at least once")

    def test_no_agent_attribution_or_review_history(self):
        for path, text in self.texts():
            if path == os.path.abspath(__file__) or path.endswith(".pyc"):
                continue
            self.assertNotRegex(text, r"(?i)co-authored-by|generated with|round \d+|reviewer found",
                                f"{path}: attribution or review history")

    def test_the_directory_names_no_moving_branch_as_an_identity(self):
        plan = read(os.path.join(HERE, "STAGE2B_PLAN.md"))
        self.assertIn("233c11cc284284fbd29df487308b4ee962f875a1", plan)
        for key in ("b0de3f7fc91767b97197ff4b458207e308998943",
                    "7b9b5295302bd177046284b017a8304cf5a99341",
                    "9c5a43bf0b7e3f51f0a401b785c332200ffa5d7e",
                    "1226119eb2cc6144f7345c727f0e7682632f7826",
                    ARCHIVE_SHA256):
            self.assertIn(key, plan)

    def test_the_documents_keep_the_statistical_rules(self):
        plan = read(os.path.join(HERE, "STAGE2B_PLAN.md"))
        spec = read(os.path.join(HERE, "MIGRATION_COMPARE_SPEC.md"))
        for needle in ("whole-stack", "no 5% rule", "never pooled", "not a paired experiment",
                       "not tests"):
            self.assertIn(needle.lower(), (plan + spec).lower(), needle)
        for number in ("G1", "G2", "G3", "G4", "G5", "G6", "G7", "G8"):
            self.assertIn(f"| {number} |", plan)

    def test_readiness_stub_has_the_headed_sections(self):
        text = read(os.path.join(HERE, "READINESS.md"))
        for heading in ("Audit of ProximalSolvers against #527 rows", "Readiness probe results", "Gates"):
            self.assertRegex(text, rf"(?m)^## {re.escape(heading)}\s*\n\s*\nTO BE COMPLETED")
        self.assertIn("233c11cc284284fbd29df487308b4ee962f875a1", text)


class SelfContainedTests(unittest.TestCase):
    def test_this_file_needs_no_git_network_or_julia(self):
        tree = ast.parse(read(os.path.abspath(__file__)))
        imported = set()
        for node in ast.walk(tree):
            if isinstance(node, ast.Import):
                imported |= {alias.name.split(".")[0] for alias in node.names}
            elif isinstance(node, ast.ImportFrom) and node.module:
                imported.add(node.module.split(".")[0])
        self.assertFalse(imported & {"subprocess", "socket", "urllib", "http", "requests", "shutil"})

    def test_all_deliverables_exist(self):
        for name in ("README.md", "STAGE2B_PLAN.md", "CASE_MAPPING.md", "case-mapping.toml",
                     "READINESS.md", "MIGRATION_COMPARE_SPEC.md", "historical_reference.py",
                     "historical-reference.tsv", "test_stage2b_files.py"):
            self.assertTrue(os.path.isfile(os.path.join(HERE, name)), name)


def load_reference_module():
    spec = importlib.util.spec_from_file_location("historical_reference",
                                                  os.path.join(HERE, "historical_reference.py"))
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def write(path, text):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "w", encoding="utf-8", newline="") as handle:
        handle.write(text)


METRICS_HEADER = ("id group phase rep status samples ok_samples median_ns mean_ns sd_ns min_ns max_ns "
                  "p95_ns gc_share median_bytes mean_bytes min_bytes max_bytes measure target "
                  "worst_value median_value data_hash").split()
SUMMARY_HEADER = ("julia id group phase measure target runs timing_runs mean_ns sd_between_runs_ns "
                  "ci95_low_ns ci95_high_ns mean_bytes median_bytes max_bytes worst_value status_ok "
                  "status_target_missed status_uncertifiable status_incomplete status_timeout "
                  "status_error").split()


def build_archive(root, mutate=None):
    """A small synthetic archive with the layout the reader expects (19 cases, 5 repetitions)."""
    versions = {"1.10": "1.10.13", "1.13": "1.13.3"}
    cases = [{"label": f"P{i:02d}", "id": f"grp{i}/prob/solver/var/call", "role": "primary",
              "phase": "call", "inputs": "fixed" if i % 3 == 0 else "draw", "measure": "relative_gap",
              "target": 1e-6} for i in range(1, 15)]
    cases += [{"label": f"D{i:02d}", "id": f"dgrp{i}/prob/solver/var/call", "role": "diagnostic",
               "phase": "call", "inputs": "draw", "measure": "relative_gap", "target": 1e-6}
              for i in range(1, 6)]
    toml = ['campaign_id = "pre06-stage2a-v1"', "[proximalsolvers]", 'commit = "' + "b" * 40 + '"',
            'harness_hash = "' + "c" * 40 + '"', "[proximalbase]", 'version = "0.5.4"']
    for key, version in versions.items():
        toml += [f'[julia."{key}"]', f'version = "{version}"']
    for case in cases:
        toml += ["[[case]]"] + [f'{k} = {v!r}'.replace("'", '"') if isinstance(v, str) else f"{k} = {v}"
                                for k, v in case.items()]
    write(os.path.join(root, "campaign.toml"), "\n".join(toml) + "\n")
    write(os.path.join(root, "cases.txt"), "".join(c["id"] + "\n" for c in cases))
    for key, version in versions.items():
        summary = []
        for case in cases:
            medians = [1000 + 10 * rep + len(case["id"]) for rep in range(1, 6)]
            summary.append({"julia": version, "id": case["id"], "group": "g", "phase": "call",
                            "measure": "relative_gap", "target": "1e-06", "runs": 5, "timing_runs": 5,
                            "mean_ns": sum(medians) / 5, "sd_between_runs_ns": 1, "ci95_low_ns": 1,
                            "ci95_high_ns": 2, "mean_bytes": 8, "median_bytes": 8, "max_bytes": 8,
                            "worst_value": "1e-09", "status_ok": 5, "status_target_missed": 0,
                            "status_uncertifiable": 0, "status_incomplete": 0, "status_timeout": 0,
                            "status_error": 0})
        for rep in range(1, 6):
            stem = os.path.join(root, f"julia-{key}", "raw", f"julia-{version}-rep{rep:02d}")
            rows = []
            for case in cases:
                digest = hashlib.sha256((case["id"] + (version if case["inputs"] == "draw" else "")
                                         + (str(rep) if case["inputs"] == "draw" else "")).encode()).hexdigest()
                rows.append({"id": case["id"], "group": "g", "phase": "call", "rep": rep, "status": "ok",
                             "samples": 100, "ok_samples": 100, "median_ns": 1000 + 10 * rep + len(case["id"]),
                             "mean_ns": 1, "sd_ns": 1, "min_ns": 1, "max_ns": 1, "p95_ns": 1, "gc_share": 0,
                             "median_bytes": 8, "mean_bytes": 8, "min_bytes": 8, "max_bytes": 8,
                             "measure": "relative_gap", "target": "1.0e-6", "worst_value": "1e-09",
                             "median_value": "1e-09", "data_hash": digest})
            meta = {"finished": True, "rep": rep, "julia": version, "cases": 19, "ok_cases": 19,
                    "nonok_cases": 0, "harness_hash": "c" * 40, "proximalsolvers_sha": "b" * 40,
                    "proximalbase_version": "0.5.4"}
            if mutate:
                mutate(key, rep, rows, meta, summary)
            write(stem + "-metrics.tsv", "\t".join(METRICS_HEADER) + "\n" + "".join(
                "\t".join(str(row[k]) for k in METRICS_HEADER) + "\n" for row in rows))
            write(stem + "-metadata.toml", "".join(
                f'{k} = {json_value(v)}\n' for k, v in meta.items()))
        write(os.path.join(root, f"julia-{key}", "summary", "summary.csv"),
              ",".join(SUMMARY_HEADER) + "\n" + "".join(
                  ",".join(str(row[k]) for k in SUMMARY_HEADER) + "\n" for row in summary))


def json_value(value):
    if isinstance(value, bool):
        return "true" if value else "false"
    if isinstance(value, int):
        return str(value)
    return '"' + str(value) + '"'


class HistoricalReferenceScriptTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.module = load_reference_module()

    def run_main(self, *argv):
        out, err = io.StringIO(), io.StringIO()
        with contextlib.redirect_stdout(out), contextlib.redirect_stderr(err):
            status = self.module.main(list(argv))
        return status, out.getvalue(), err.getvalue()

    def archive(self, mutate=None):
        directory = tempfile.TemporaryDirectory()
        self.addCleanup(directory.cleanup)
        root = os.path.join(directory.name, "pre06-stage2a-campaign-v1")
        build_archive(root, mutate)
        return root, directory.name

    def test_generation_and_check_round_trip(self):
        root, scratch = self.archive()
        status, text, _ = self.run_main(root)
        self.assertEqual(status, 0)
        committed = os.path.join(scratch, "reference.tsv")
        write(committed, text)
        self.assertEqual(self.run_main(root, "--check", committed)[0], 0)
        self.assertEqual(sum(1 for l in text.splitlines() if l and not l.startswith("#")), 1 + 38)

    def test_check_fails_with_status_1_on_a_changed_tsv(self):
        root, scratch = self.archive()
        text = self.run_main(root)[1]
        committed = os.path.join(scratch, "reference.tsv")
        write(committed, text.replace("ok\n", "OK\n", 1))
        self.assertEqual(self.run_main(root, "--check", committed)[0], 1)
        self.assertEqual(self.run_main(root, "--check", os.path.join(scratch, "missing.tsv"))[0], 1)

    def test_a_path_that_is_not_a_directory_is_refused(self):
        root, scratch = self.archive()
        status, _, err = self.run_main(os.path.join(root, "campaign.toml"))
        self.assertEqual(status, 2)
        self.assertIn("not a directory", err)

    def test_summary_mean_mismatch_aborts(self):
        def mutate(key, rep, rows, meta, summary):
            summary[0]["mean_ns"] = float(summary[0]["mean_ns"]) + 1
        root, _ = self.archive(mutate)
        status, _, err = self.run_main(root)
        self.assertEqual(status, 2)
        self.assertIn("mean", err)

    def test_a_non_ok_status_aborts(self):
        def mutate(key, rep, rows, meta, summary):
            if key == "1.13" and rep == 3:
                rows[4]["status"] = "target_missed"
        root, _ = self.archive(mutate)
        status, _, err = self.run_main(root)
        self.assertEqual(status, 2)
        self.assertIn("status", err)

    def test_fewer_ok_samples_abort(self):
        def mutate(key, rep, rows, meta, summary):
            if key == "1.10" and rep == 2:
                rows[0]["ok_samples"] = 99
        self.assertEqual(self.run_main(self.archive(mutate)[0])[0], 2)

    def test_a_missing_repetition_aborts(self):
        root, _ = self.archive()
        os.remove(os.path.join(root, "julia-1.10", "raw", "julia-1.10.13-rep05-metrics.tsv"))
        self.assertEqual(self.run_main(root)[0], 2)

    def test_a_fixed_input_case_with_two_hashes_aborts(self):
        def mutate(key, rep, rows, meta, summary):
            if rep == 2:
                rows[2]["data_hash"] = "0" * 64     # P03 is a fixed-input case in the fixture
        status, _, err = self.run_main(self.archive(mutate)[0])
        self.assertEqual(status, 2)
        self.assertIn("distinct hashes", err)

    def test_a_changed_harness_hash_aborts(self):
        def mutate(key, rep, rows, meta, summary):
            meta["harness_hash"] = "d" * 40
        self.assertEqual(self.run_main(self.archive(mutate)[0])[0], 2)


if __name__ == "__main__":
    unittest.main()
