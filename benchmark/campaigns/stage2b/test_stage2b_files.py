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
P14_PORT_SPARSE = "dropzeros!(fill!(x, 0.0))"
OPTIONAL_FIELDS = ("approved", "approval_url", "approval_scope", "port_text", "new_harness_hash",
                   "separate_mapping", "deviation")
APPROVAL_URL = "https://github.com/mlakolar/ProximalSolvers.jl/issues/110#issuecomment-6694764350"
APPROVAL_SCOPE = ("pre-candidate audit and implementation; revalidation against the pinned 0.6 candidate "
                  "is required before official measurement")
ORDERS = {"1": "AB", "2": "BA", "3": "BA", "4": "AB", "5": "BA", "6": "AB", "7": "AB", "8": "BA"}
REFUSAL_CLASSES = ("JULIA", "INPUTS", "TARGET", "CASE", "PHASE", "OPERATION", "THREADS", "MACHINE",
                   "REPETITIONS", "MAPPING", "SCHEMA", "UNDECLARED", "SETTINGS", "STACK", "IDENTITY", "ORDER")
CSV_COLUMNS = ("julia, id, role, phase, class, reason, repetitions, a_ns, b_ns, ratio, abs_diff_ns, "
               "geomean_ratio, ratio_min, ratio_max, measure, target, a_value, b_value, a_accuracy_fraction, "
               "b_accuracy_fraction, a_accuracy_band, b_accuracy_band, a_median_bytes, b_median_bytes, "
               "hardware, aa_ratio_min, aa_ratio_max, screen, mapping_class").split(", ")
LISTS_KEYS = ("not_ok", "invalid_certificates", "incomplete_paths", "errors_and_timeouts",
              "allocation_differences", "missing_diagnostics", "semantic_deviations", "not_comparable", "failed")
# Phrasings of the retired six-and-five-block design. Built to match the old design text and to leave the
# historical Stage 2A wording alone ("five repetitions", "PS_REPETITION = 1..5", "G1-G5").
OLD_BLOCK_COUNTS = re.compile(
    r"(?i)\b(?:five|six|5|6)[ -](?:paired[ -]|fresh-process[ -]|A/A[ -]|A/B[ -])*(?:blocks?|ratios?|series)\b"
    r"|\ball five\b"
    r"|\b(?:five|six)-block\b"
    r"|\b(?:five|six) per(?:-block| Julia)\b"
    r"|\b(?:repetition )?IDs? 1-[56]\b"
    r"|\bA/[AB]:? 1-[56]\b"
    r"|\b(?:six|6) A/A\b|\b(?:five|5) A/B\b")
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


def squash(text):
    """Collapse every run of white space, so that a needle does not depend on where a line was wrapped."""
    return " ".join(text.split())


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
            extra = set(case) - set(REQUIRED_FIELDS) - set(OPTIONAL_FIELDS)
            self.assertFalse(extra, f"{case['label']}: unexpected fields {sorted(extra)}")

    def test_p14_is_class_b_with_both_reset_lines(self):
        p14 = next(c for c in self.cases if c["label"] == "P14")
        self.assertEqual(p14["class"], "B")
        reset = "\n".join(strings(p14["reset"]))
        self.assertIn(P14_HISTORICAL, reset)
        self.assertIn(P14_PORT_SPARSE, reset)
        self.assertIn("fill!(x, 0.0), kept, for the dense Vector", reset)
        # The harness holds the historical line, or, after the approved port, the sparse clear.
        harness = read(os.path.join(BENCH, "cases.jl"))
        self.assertTrue(P14_HISTORICAL in harness or P14_PORT_SPARSE in harness)
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
    INFRASTRUCTURE = ("/scr" + "atch", "sr" + "un", "sb" + "atch", "slu" + "rm_")
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

    # The identities table of the plan (section 2) and the identity keys of case-mapping.toml.
    @staticmethod
    def identity_table(plan):
        start = plan.index("## 2. Identities")
        end = plan.index("\n## ", start + 5)
        return plan[start:end]

    @staticmethod
    def identity_problems(table):
        """Problems of an identities table: a moving name, a short SHA, or a tag without its commit."""
        problems = []
        for line in table.splitlines():
            if not line.startswith("|") or line.startswith("|:") or line.startswith("| Role"):
                continue
            if re.search(r"\b(?:master|main|HEAD|develop|branch)\b", line, re.IGNORECASE):
                problems.append(f"moving name: {line[:60]}")
            for token in re.findall(r"`([0-9a-f]{7,64})`", line):
                if len(token) not in (40, 64):
                    problems.append(f"short or odd hash {token}")
            for tag in re.findall(r"`(v\d+\.\d+\.\d+)`", line):
                if not re.search(r"`[0-9a-f]{40}`", line):
                    problems.append(f"tag {tag} without its commit SHA")
        return problems

    def test_the_directory_names_no_moving_branch_as_an_identity(self):
        plan = read(os.path.join(HERE, "STAGE2B_PLAN.md"))
        self.assertIn("233c11cc284284fbd29df487308b4ee962f875a1", plan)
        for key in ("b0de3f7fc91767b97197ff4b458207e308998943",
                    "7b9b5295302bd177046284b017a8304cf5a99341",
                    "9c5a43bf0b7e3f51f0a401b785c332200ffa5d7e",
                    "1226119eb2cc6144f7345c727f0e7682632f7826",
                    ARCHIVE_SHA256):
            self.assertIn(key, plan)
        table = self.identity_table(plan)
        self.assertEqual(self.identity_problems(table), [])
        # the identity rows of ProximalSolvers and ProximalBase exist and carry full SHAs
        rows = [l for l in table.splitlines() if l.startswith("|")]
        for needle in ("Historical measured ProximalSolvers", "Historical ProximalBase",
                       "Future migrated ProximalSolvers", "Future ProximalBase"):
            self.assertTrue(any(needle in r for r in rows), needle)
        mapping = load_toml(os.path.join(HERE, "case-mapping.toml"))
        for key in ("audited_commit", "measured_source"):
            self.assertRegex(mapping[key], r"^[0-9a-f]{40}$", key)

    def test_the_identity_check_detects_a_moving_or_abbreviated_identity(self):
        good = ("| Role | Identity |\n|:--|:--|\n"
                "| Historical ProximalBase | tag `v0.5.4` at commit `" + "a" * 40 + "`, tree `" + "b" * 40 + "` |\n")
        self.assertEqual(self.identity_problems(good), [])
        for bad in ("| Future ProximalBase | master |\n",
                    "| Future ProximalBase | the main branch at `" + "a" * 40 + "` |\n",
                    "| Historical ProximalSolvers | commit `b0de3f7` |\n",
                    "| Historical ProximalBase | tag `v0.5.4` |\n"):
            self.assertTrue(self.identity_problems(bad), bad)

    def test_the_documents_keep_the_statistical_rules(self):
        plan = read(os.path.join(HERE, "STAGE2B_PLAN.md"))
        spec = read(os.path.join(HERE, "MIGRATION_COMPARE_SPEC.md"))
        for needle in ("whole-stack", "no 5% rule", "never pooled", "not a paired experiment",
                       "not tests"):
            self.assertIn(needle.lower(), (plan + spec).lower(), needle)
        for number in ("G1", "G2", "G3", "G4", "G5", "G6", "G7", "G8"):
            self.assertIn(f"| {number} |", plan)

    def test_readiness_record_is_complete_and_names_the_probed_commit(self):
        text = read(os.path.join(HERE, "READINESS.md"))
        for heading in ("Audit of ProximalSolvers against #527 rows", "Readiness probe results", "Gates"):
            self.assertRegex(text, rf"(?m)^## {re.escape(heading)}\s*$")
        self.assertNotIn("TO BE COMPLETED", text)
        self.assertIn("233c11cc284284fbd29df487308b4ee962f875a1", text)
        for gate in ("G1", "G2", "G3", "G4", "G5", "G6", "G7", "G8"):
            self.assertIn(f"| {gate} |", text)


class SpecTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.spec = read(os.path.join(HERE, "MIGRATION_COMPARE_SPEC.md"))
        start = cls.spec.index("## 4. Refused differences")
        cls.section4 = cls.spec[start:cls.spec.index("\n## ", start + 5)]
        start = cls.spec.index("## 8. Required synthetic tests")
        cls.tests_section = cls.spec[start:cls.spec.index("\n## ", start + 5)]

    def test_section_4_lists_every_refusal_class_once_with_status_2(self):
        classes = re.findall(r"\|\s*`([A-Z_]+)`\s*\|\s*$", self.section4, re.MULTILINE)
        self.assertEqual(len(classes), len(set(classes)))
        for name in REFUSAL_CLASSES:
            self.assertIn(name, classes)
        self.assertEqual(len(classes), 16)
        self.assertIn("status 2", self.section4)

    def test_identity_and_order_refusals_say_what_they_check(self):
        identity = next(l for l in self.section4.splitlines() if l.rstrip().endswith("`IDENTITY` |"))
        for needle in ("40-hex", "tree", "branch name", "short SHA", "tag-only",
                       "9c5a43bf0b7e3f51f0a401b785c332200ffa5d7e", "1226119eb2cc6144f7345c727f0e7682632f7826"):
            self.assertIn(needle, identity)
        order = next(l for l in self.section4.splitlines() if l.rstrip().endswith("`ORDER` |"))
        for needle in ("orders[rep]", "AB, BA, BA, AB, BA, AB, AB, BA", "campaign receipt", "contemporaneous",
                       "another campaign"):
            self.assertIn(needle, order)
        self.assertNotIn("AB, BA, AB, BA, AB, BA", order)
        self.assertIn("no start time stamp", self.spec)

    def test_required_tests_cover_every_refusal_class(self):
        self.assertIn("(16 tests)", self.tests_section)
        self.assertIn("class `IDENTITY`", self.tests_section)
        self.assertIn("class `ORDER`", self.tests_section)
        for needle in ("unfrozen identity", "wrong block order"):
            self.assertIn(needle, self.tests_section)


class SpecRepetitionTests(unittest.TestCase):
    def test_an_equal_but_incomplete_repetition_set_is_a_refusal_not_a_failed_case(self):
        spec = read(os.path.join(HERE, "MIGRATION_COMPARE_SPEC.md"))
        row = next(l for l in spec.splitlines() if l.rstrip().endswith("`REPETITIONS` |"))
        self.assertIn("frozen campaign", row)
        self.assertIn("both lack the same declared ID", row)
        self.assertIn("equal-but-incomplete pair is a refusal, never a per-case FAILED", spec)
        failed = spec[spec.index("1. **FAILED**"):spec.index("2. **NOT COMPARABLE**")]
        self.assertNotIn("both roots", failed)
        self.assertNotRegex(failed, r"(?i)a repetition both")


class CaseMappingProseTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.md = read(os.path.join(HERE, "CASE_MAPPING.md"))
        cls.toml = read(os.path.join(HERE, "case-mapping.toml"))

    def test_probe_groups_in_the_prose_are_those_of_the_saved_results(self):
        with open(os.path.join(HERE, "probes", "results", "reset-1.13.3-master.tsv"), encoding="utf-8") as h:
            rows = dict(line.rstrip("\n").split("\t", 1) for line in h if "\t" in line)
        self.assertEqual(rows["atom.cold_start.used.active"], "2,5,8")
        self.assertEqual(rows["atom.warm_start.start.active"], "3,7")
        self.assertEqual(rows["atom.warm_overlap.used.active"], "3,7,8")
        self.assertIn("used groups 2, 5, 8", self.md)
        self.assertIn("used\n  groups 7, 8", self.md)
        for stale in ("2, 5, 9", "3, 7, 11", "3, 7, 2, 5, 9", "3,17,42,150", "p = 160"):
            self.assertNotIn(stale, self.md + self.toml)

    def test_the_kronu_x_p_read_is_described_as_an_unexercised_site_in_a_reached_method(self):
        self.assertEqual(self.toml.count("UNEXERCISED SITE IN A REACHED METHOD"), 2)   # P10 and D02
        self.assertIn("unexercised site in a reached method", self.md)
        self.assertNotIn("three in `kronu.jl`", self.md)
        self.assertNotIn("`kronu.jl` (3:", self.md)

    def test_the_block_start_sentence_has_no_double_negative(self):
        self.assertIn("the identity start is positive definite, so `:203` does not run", self.md)
        self.assertNotIn("which the identity start is not", self.md)


class MappingApprovalTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.cases = load_toml(os.path.join(HERE, "case-mapping.toml"))["case"]

    def test_class_b_rows_are_approved_with_the_maintainer_url_scope_and_port_text(self):
        rows = [c for c in self.cases if c["class"] == "B"]
        self.assertEqual([c["label"] for c in rows], ["P14"])
        for case in rows:
            self.assertIs(case["approved"], True)
            self.assertEqual(case["approval_url"], APPROVAL_URL)
            self.assertEqual(case["approval_scope"], APPROVAL_SCOPE)
            port = "\n".join(strings(case["port_text"]))
            self.assertIn("dropzeros!(fill!(x, 0.0)) for the SparseIterate of the lasso path", port)
            self.assertIn("fill!(x, 0.0) kept for the dense Vector of the two SLOPE paths", port)
            # the true new harness hash is recorded at the port commit, never written here
            self.assertEqual(case["new_harness_hash"], "recorded at the port commit")

    def test_class_a_rows_say_there_is_nothing_to_approve(self):
        rows = [c for c in self.cases if c["class"] == "A"]
        self.assertEqual(len(rows), 18)
        for case in rows:
            self.assertIs(case["approved"], False, case["label"])
            for key in ("approval_url", "approval_scope", "port_text", "new_harness_hash"):
                self.assertNotIn(key, case, f"{case['label']}: {key}")

    def test_no_class_c_or_d_row_and_no_row_without_the_approved_flag(self):
        for case in self.cases:
            self.assertIn("approved", case, case["label"])
            self.assertIsInstance(case["approved"], bool, case["label"])
            self.assertNotIn("separate_mapping", case)
            self.assertNotIn("deviation", case)

    def test_the_prose_names_the_approval_and_its_limit(self):
        md = read(os.path.join(HERE, "CASE_MAPPING.md"))
        self.assertIn("Approved compatibility-only port", md)
        self.assertNotIn("Proposed compatibility-only port", md)
        self.assertIn("not a finding that any case works", md)
        self.assertIn("pinned candidate", md)


class ScheduleTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.schedule = load_toml(os.path.join(HERE, "schedule.toml"))
        cls.campaign = load_toml(os.path.join(PRE06, "campaign.toml"))
        cls.text = read(os.path.join(HERE, "schedule.toml"))

    def test_eight_repetitions_and_the_exact_order_table(self):
        block = self.schedule["schedule"]
        self.assertEqual(block["reps"], list(range(1, 9)))
        self.assertEqual(block["orders"], ORDERS)
        self.assertEqual(sorted(block["orders"], key=int), [str(i) for i in range(1, 9)])

    def test_identity_arms_and_schema(self):
        block = self.schedule["schedule"]
        self.assertEqual(self.schedule["schema"], 1)
        self.assertEqual(block["id"], "stage2b-8block-v1")
        self.assertEqual(block["campaign_id"], "pb06-migration-stage2b-v1")
        self.assertEqual(block["arms"], ["AB", "AA"])
        self.assertLessEqual(max(block["reps"]), 10)             # the PS_REPETITION cap

    def test_four_ab_four_ba_two_odd_two_even_each_and_early_late_balanced(self):
        orders = {int(k): v for k, v in self.schedule["schedule"]["orders"].items()}
        self.assertEqual(sorted(orders.values()), ["AB"] * 4 + ["BA"] * 4)
        for order in ("AB", "BA"):
            ids = [i for i, o in orders.items() if o == order]
            self.assertEqual(len([i for i in ids if i % 2 == 1]), 2, order)
            self.assertEqual(len([i for i in ids if i % 2 == 0]), 2, order)
            self.assertEqual(len([i for i in ids if i <= 4]), 2, order)
            self.assertEqual(len([i for i in ids if i > 4]), 2, order)
        # order is not aliased with the parity of the repetition ID
        self.assertNotEqual({i % 2 for i, o in orders.items() if o == "AB"}, {1})
        self.assertNotEqual({i % 2 for i, o in orders.items() if o == "BA"}, {0})

    def test_case_filter_is_cases_txt_joined_by_commas(self):
        with open(os.path.join(PRE06, "cases.txt"), encoding="utf-8") as handle:
            ids = handle.read().split("\n")[:-1]
        self.assertEqual(len(ids), 19)
        self.assertEqual(self.schedule["settings"]["case_filter"], ",".join(ids))

    def test_settings_equal_the_stage2a_campaign(self):
        settings, frozen = self.schedule["settings"], self.campaign["settings"]
        self.assertEqual(settings["suite"], frozen["PS_SUITE"])
        self.assertEqual(settings["samples_target"], int(frozen["PS_SAMPLES"]))
        self.assertEqual(settings["seconds_limit"], float(frozen["PS_SECONDS"]))
        self.assertEqual(settings["case_seconds"], float(frozen["PS_CASE_SECONDS"]))
        self.assertEqual(settings["profile_seconds"], float(frozen["PS_PROFILE_SECONDS"]))
        self.assertEqual(settings["julia_threads"], int(frozen["JULIA_NUM_THREADS"]))
        self.assertEqual(settings["blas_threads"], int(frozen["OPENBLAS_NUM_THREADS"]))
        # run.jl records the groups sorted and comma-joined; PS_GROUPS lists the same groups in another order
        self.assertEqual(settings["groups"].split(","), sorted(frozen["PS_GROUPS"].split(",")))
        self.assertEqual(settings["seed_scheme"], "FNV1a64 keyed scenario xor repetition")
        self.assertEqual(self.campaign["protocol"]["repetitions"], 5)    # Stage 2A itself is unchanged

    def test_machine_equals_the_stage2a_machine_policy(self):
        machine, frozen = self.schedule["machine"], self.campaign["machine"]
        self.assertEqual(machine["cpu_model"], frozen["cpu_model"])
        self.assertEqual(machine["logical_cpu"], 6)
        self.assertEqual(machine["smt_sibling"], 7)
        self.assertEqual((machine["logical_cpu"], machine["smt_sibling"]),
                         (frozen["logical_cpu"], frozen["smt_sibling"]))
        self.assertEqual(machine["governor"], frozen["governor"])
        self.assertEqual(machine["epp"], frozen["energy_performance_preference"])
        self.assertEqual(machine["no_turbo"], frozen["no_turbo"])
        self.assertEqual(machine["smt_control"], "on")
        for key, julia in self.campaign["julia"].items():
            self.assertEqual(machine["cpu"][key], julia["cpu_name"], key)

    def test_julia_builds_equal_the_campaign_commits(self):
        self.assertEqual(set(self.schedule["julia"]), {"1.10", "1.13"})
        for key, build in self.schedule["julia"].items():
            frozen = self.campaign["julia"][key]
            self.assertEqual(build["version"], frozen["version"], key)
            self.assertEqual(build["commit"], frozen["commit"], key)
            self.assertRegex(build["commit"], r"^[0-9a-f]{40}$")
        self.assertEqual(self.schedule["julia"]["1.10"]["commit"], "e184dd512e35c5a6e036c9aab5e4de5a3345f62d")
        self.assertEqual(self.schedule["julia"]["1.13"]["commit"], "67ac47b9cd855e02134d41d5428ac9f2a73f2694")

    def test_stack_a_is_the_historical_identity(self):
        stack = self.schedule["stack_a"]
        frozen = self.campaign
        self.assertEqual(stack["harness_hash"], "b7bf3d953ec6e9f9720e74d7895b5cf95a629fd4")
        self.assertEqual(stack["harness_hash"], frozen["proximalsolvers"]["harness_hash"])
        solvers, base = stack["proximalsolvers"], stack["proximalbase"]
        self.assertEqual(solvers["commit"], "b0de3f7fc91767b97197ff4b458207e308998943")
        self.assertEqual(solvers["tree"], "a836d532008782e75f2b2a7e4666fa1df24b34dc")
        self.assertEqual(solvers["version"], frozen["proximalsolvers"]["version"])
        self.assertEqual((solvers["commit"], solvers["tree"]),
                         (frozen["proximalsolvers"]["commit"], frozen["proximalsolvers"]["tree"]))
        self.assertEqual(base["tag"], "v0.5.4")
        self.assertEqual(base["commit"], "9c5a43bf0b7e3f51f0a401b785c332200ffa5d7e")
        self.assertEqual(base["commit"], frozen["proximalbase"]["tag_commit"])
        self.assertEqual(base["tree"], "1226119eb2cc6144f7345c727f0e7682632f7826")
        self.assertEqual(base["tree"], frozen["proximalbase"]["tree"])
        self.assertEqual((base["version"], base["release"]), ("0.5.4", "registered"))

    def test_the_file_says_it_is_a_pre_freeze_draft(self):
        self.assertIn("PRE-FREEZE DRAFT", self.text)
        self.assertIn("F1-B", self.text)
        self.assertIn("No\n# official timing may use it before that freeze", self.text)

    def test_the_order_table_of_the_plan_and_the_spec_equals_the_schedule(self):
        for name in ("STAGE2B_PLAN.md", "MIGRATION_COMPARE_SPEC.md"):
            text = read(os.path.join(HERE, name))
            row = re.search(r"(?m)^(?:  )?\| Order \|((?: (?:AB|BA) \|){8})$", text)
            self.assertIsNotNone(row, name)
            self.assertEqual(row.group(1).replace("|", " ").split(),
                             [ORDERS[str(i)] for i in range(1, 9)], name)
            ids = re.search(r"(?m)^(?:  )?\| Repetition ID \|((?: \d \|){8})$", text)
            self.assertEqual(ids.group(1).replace("|", " ").split(), [str(i) for i in range(1, 9)], name)


class NoOldBlockCountTests(unittest.TestCase):
    OLD = ("five paired blocks", "six A/A blocks", "all five A/B blocks", "IDs 1-5", "repetition IDs 1-6",
           "A/B: 1-5", "A/A: 1-6", "six-block", "the five-block series", "five per Julia version",
           "6 blocks x 2 processes", "5 blocks x 2 processes", "six per-block time ratios",
           "six A/A ratios", "Whether six A/A blocks and five A/B blocks")
    HISTORICAL = ("Stage 2A, five repetitions of the 19 cases", "PS_REPETITION = 1..5", "five repetitions",
                  "G1-G5", "G1-G8", "lines 81-82", "eight A/A blocks and eight A/B blocks", "1-8", "FT25-FT28",
                  "5 repetitions", "tier of 3-5 end-to-end workloads", "10-20 paired blocks")

    def test_the_pattern_matches_the_retired_phrases_and_spares_the_historical_text(self):
        for phrase in self.OLD:
            self.assertIsNotNone(OLD_BLOCK_COUNTS.search(phrase), phrase)
        for phrase in self.HISTORICAL:
            self.assertIsNone(OLD_BLOCK_COUNTS.search(phrase), phrase)

    def test_no_document_keeps_a_retired_block_count(self):
        for name in ("STAGE2B_PLAN.md", "MIGRATION_COMPARE_SPEC.md", "README.md", "READINESS.md",
                     "CASE_MAPPING.md"):
            text = read(os.path.join(HERE, name))
            self.assertEqual([m.group(0) for m in OLD_BLOCK_COUNTS.finditer(text)], [], name)

    def test_the_new_counts_are_stated_where_the_design_is(self):
        plan = read(os.path.join(HERE, "STAGE2B_PLAN.md"))
        spec = read(os.path.join(HERE, "MIGRATION_COMPARE_SPEC.md"))
        readme = read(os.path.join(HERE, "README.md"))
        self.assertIn("eight A/A and eight A/B", plan)
        self.assertIn("Eight fresh-process blocks per Julia version", squash(plan))
        self.assertIn("Eight paired blocks per Julia version", plan)
        self.assertIn("eight A/A and eight A/B", readme)
        self.assertIn("1-8", spec)
        self.assertIn("(eight per Julia version)", plan)
        # the old aliasing sentence is gone; the schedule is said to be balanced instead
        self.assertIsNone(re.search(r"(?<!not )aliased with the parity", plan + spec))
        self.assertNotIn("order stays aliased", plan)
        self.assertIn("balanced overall (four AB, four BA) and over odd and even repetition IDs", squash(plan))
        self.assertIn("two odd and two even", squash(plan))


class PlanDecisionTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.plan = read(os.path.join(HERE, "STAGE2B_PLAN.md"))
        cls.spec = read(os.path.join(HERE, "MIGRATION_COMPARE_SPEC.md"))
        cls.readiness = read(os.path.join(HERE, "READINESS.md"))

    def row(self, text, gate):
        return next(l for l in text.splitlines() if l.startswith(f"| {gate} |"))

    def test_the_archive_identity_is_approved_and_reserved_but_not_a_freeze(self):
        self.assertIn("approved and reserved", self.plan)
        self.assertIn("not yet a freeze, a tag or a release", self.plan)
        self.assertNotIn("Proposed identity", self.plan)
        self.assertNotIn("proposed, needs maintainer approval", self.plan)
        for needle in ("pb06-migration-stage2b-v1", "bench-pb06-migration-v1", "pb06-stage2b-campaign-v1.tar.gz"):
            self.assertIn(needle, self.plan)
        self.assertIn("`bench-pre06-v1`", self.plan)

    def test_g8_is_approved_for_pr_b_and_the_other_gates_stay_unmet(self):
        for text in (self.plan, self.readiness):
            g8 = self.row(text, "G8")
            self.assertIn("Approved for implementation and testing of PR B", g8)
            self.assertIn("candidate", g8)
            self.assertIn("P04", g8)
            self.assertNotIn("**Pending", g8)
            for gate in ("G1", "G2", "G3", "G4", "G5", "G6", "G7"):
                self.assertIn("**Unmet", self.row(text, gate), gate)
        self.assertIn("18 class A", self.plan)
        self.assertIn("official timing stays blocked while G1-G7 are unmet", squash(self.plan + self.readiness))
        self.assertIn("not a finding that any case works", squash(self.plan + self.readiness))

    def test_the_categories_and_the_screens_are_the_approved_ones(self):
        for text in (self.plan, self.spec):
            for needle in ("screened slowdown", "screened speedup", "screen not evaluated"):
                self.assertIn(needle, text.lower())
        self.assertIn("| 3 | Screened slowdown at matched certified accuracy |", self.plan)
        self.assertNotIn("outside the A/A range, slower", self.plan)
        self.assertIn("largest of the eight A/A ratios", squash(self.plan))
        self.assertIn("smallest of the eight A/A ratios", squash(self.plan))
        self.assertIn("no calibrated confidence bound", squash(self.plan))
        self.assertIn("**38 screens**", squash(self.plan))

    def test_the_near_target_flag_is_a_rule_not_a_proposal(self):
        for text in (self.plan, self.spec):
            self.assertRegex(text, r"0\.9 <= v ?/ ?t <= 1")
            for needle in ("missed/invalid", "near target", "margin", "accuracy_fraction"):
                self.assertIn(needle, text)
        self.assertIn("diagnostic only", self.plan)
        self.assertNotIn("its definition is fixed before the pilot", self.plan)
        self.assertNotIn("The definition of the \"near target\" flag", self.plan)

    def test_the_pr_split_names_this_work_as_pr_b_and_keeps_the_rest(self):
        rows = [l for l in self.plan.splitlines() if l.startswith("| ") and "PR" not in l[:4]]
        pr_b = next(l for l in rows if l.startswith("| B "))
        self.assertIn("this work", pr_b)
        self.assertIn("P14", pr_b)
        self.assertIn("migration_compare.py", pr_b)
        for name in ("| A (merged as #215)", "| Migration PR(s)", "| C |"):
            self.assertTrue(any(l.startswith(name) for l in rows), name)

    def test_the_effort_estimate_is_recomputed_for_eight_blocks(self):
        start = self.plan.index("## 17. Planned measurement effort")
        section = self.plan[start:self.plan.index("\n## ", start + 5)]
        self.assertIn("**estimate**", section)
        self.assertIn("16 x 13.0 s + 16 x 16.5 s = 472 s (about 8 min)", section)
        self.assertIn("| 64 | 944 s, about 16 min", section)
        self.assertEqual(16 * 13.0 + 16 * 16.5, 472.0)
        self.assertEqual(2 * 472, 944)
        for old in ("354 s", "295 s", "about 11 min"):
            self.assertNotIn(old, section)

    def test_the_extension_rule_keeps_the_cap_and_the_new_series(self):
        start = self.plan.index("## 11. Pre-specified extension rule")
        section = self.plan[start:self.plan.index("\n## ", start + 5)]
        self.assertIn("new evidence series", section)
        self.assertIn("capped at 10", section)
        self.assertIn("beyond ten blocks", section)
        self.assertIn("eight-block series", section)

    def test_the_freeze_gate_names_the_schedule_file_as_a_draft_until_then(self):
        self.assertIn("`schedule.toml`, a pre-freeze draft until then", self.plan)


class SpecContractTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.spec = read(os.path.join(HERE, "MIGRATION_COMPARE_SPEC.md"))

    def section(self, number):
        match = re.search(rf"(?m)^## {number}\. .*$", self.spec)
        self.assertIsNotNone(match, f"section {number}")
        end = re.search(r"(?m)^## \d+\. ", self.spec[match.end():])
        return self.spec[match.start():match.end() + end.start()] if end else self.spec[match.start():]

    def test_the_schema_sections_exist_with_an_example_each(self):
        titles = {10: "Root layout (schema 4a)", 11: "`stack-identity.toml` (schema 4b)",
                  12: "The receipt (schema 4c)", 13: "`declared-differences.toml` (schema 4d)",
                  14: "Fingerprint files (schema 4e)", 15: "Outputs (schema 4f)"}
        for number, title in titles.items():
            self.assertIn(f"## {number}. {title}", self.spec)
            self.assertGreaterEqual(self.section(number).count("```"), 2, f"example in section {number}")
        for number, title in ((1, "Why a separate tool"), (2, "Inputs"), (3, "Accepted identity differences"),
                              (4, "Refused differences"), (5, "Outputs"), (6, "A `data_hash` match"),
                              (7, "The ordinary tools stay as they are"), (8, "Required synthetic tests"),
                              (9, "No confidence interval")):
            self.assertIn(f"## {number}. {title}", self.spec)       # the numbering of the old sections is stable
        self.assertIn("## 16. Schedule, screens and the near-target flag", self.spec)

    def test_row_4_reads_explicitly(self):
        row = next(l for l in self.section(4).splitlines() if l.rstrip().endswith("`CASE` |"))
        self.assertIn("A declared case missing from either root, including a case absent from both.", row)

    def test_every_refusal_class_has_fields_and_a_rule_in_section_4_1(self):
        start = self.spec.index("### 4.1 Evaluation, fields and messages")
        text = self.spec[start:self.spec.index("\n## ", start)]
        for name in REFUSAL_CLASSES:
            row = next((l for l in text.splitlines() if l.startswith(f"| `{name}` |")), None)
            self.assertIsNotNone(row, name)
            cells = [c.strip() for c in row.strip().strip("|").split("|")]
            self.assertEqual(len(cells), 3, name)
            self.assertTrue(cells[1].startswith("`"), f"{name}: no field values")
            self.assertTrue(cells[2], f"{name}: no rule")
        self.assertIn("`REFUSED:<CLASS> <field>: <detail>`", self.spec)
        self.assertIn("R1. Mapping of `validate.py` issues to classes", text)

    def test_the_cleanup_items_have_their_own_refusal_classes_and_leave_the_visible_lists(self):
        precedence = squash(self.section(5))
        self.assertIn("a missing or extra declared case is a `CASE` refusal in `refusals.json`", precedence)
        self.assertIn("a missing or extra declared repetition is a `REPETITIONS` refusal in `refusals.json`", precedence)
        self.assertIn("a mismatched `data_hash` is an `INPUTS` refusal in `refusals.json`", precedence)
        self.assertIn("None of them produces a comparison, a `report.md` or an entry in `lists.json`", precedence)
        lists = precedence[precedence.index("**Visible lists**"):precedence.index("**Reports.**")]
        for forbidden in ("missing and extra", "changed inputs", "extra cases", "repetitions per root"):
            self.assertNotIn(forbidden, lists)
        bullet = next(l for l in squash(self.section(8)).split("* ") if l.startswith("The visible lists"))
        self.assertNotIn("missing and extra", bullet)
        self.assertNotIn("missing and extra cases", squash(self.spec))

    def test_the_fingerprint_contradiction_is_resolved_in_one_place(self):
        six = squash(self.section(6))
        for needle in ("narrow fail-closed reading", "**Global `INPUTS` refusal:**", "**Global `OPERATION` refusal:**",
                       "**Per-case NOT COMPARABLE**", "A missing fingerprint file is the same",
                       "A fixture mismatch refuses the whole comparison because changed inputs cannot be salvaged per case"):
            self.assertIn(needle, six)
        row2 = next(l for l in self.section(4).splitlines() if l.rstrip().endswith("`INPUTS` |"))
        row6 = next(l for l in self.section(4).splitlines() if l.rstrip().endswith("`OPERATION` |"))
        self.assertIn("fixture", row2)
        self.assertNotIn("solver-configuration", row6)
        self.assertIn("`file/certificates.jl`", row6)
        notcomparable = self.section(5)[self.section(5).index("2. **NOT COMPARABLE**"):
                                        self.section(5).index("3. **COMPARABLE**")]
        self.assertIn("reset-state or solver-configuration fingerprint", notcomparable)
        self.assertNotIn("fixture", notcomparable.replace("fixture and state", ""))

    def test_the_csv_columns_and_the_lists_keys_are_exact(self):
        raw = self.section(15)
        block = raw[raw.index("```\njulia, id"):]
        header = block[4:block.index("\n```")].replace("\n", " ")
        self.assertEqual(re.split(r",\s*", header.strip()), list(CSV_COLUMNS))
        self.assertEqual(len(CSV_COLUMNS), 29)
        positions = [raw.index(f"| `{key}` |") for key in LISTS_KEYS]
        self.assertEqual(positions, sorted(positions))
        out = squash(raw)
        self.assertIn('{"schema": 1, "count": 1, "refusals": [{"class"', out)
        self.assertIn("Line 1 is exactly: `This is a whole-stack migration comparison. Differences cannot be "
                      "attributed solely to ProximalBase. The Stage 2A historical archive is descriptive context, "
                      "not part of the contemporaneous paired ratios.`", out)
        self.assertIn("The screens are descriptive investigation screens, not tests: there is no significance level, "
                      "no noninferiority claim and no no-regression claim, and A/A ranges are not calibrated "
                      "confidence bounds.", out)

    def test_the_receipt_the_identity_and_the_declared_file_say_what_the_brief_requires(self):
        receipt, identity = squash(self.section(12)), squash(self.section(11))
        declared = squash(self.section(13))
        for needle in ("`campaign` occurs exactly once", "`session_id`", "`schedule_id`", "`block`", "`installation`",
                       "`start_utc`", "`end_utc`", "`exit`", "`complete`", "`machine`", "`smt_control`",
                       "overlap", "`ORDER`", "`MACHINE`", "distinct `proximalsolvers_path`", "first `depot_path`"):
            self.assertIn(needle, receipt)
        for needle in ("schema = 1", 'installation = "', "[proximalsolvers]", "[proximalbase]", "release", "tag",
                       "40 lowercase hexadecimal", "branch name", "`IDENTITY`"):
            self.assertIn(needle, identity)
        for needle in ("[[manifest]]", "[harness]", "a_package_hash", "b_package_hash", "port_commit", "changed_lines",
                       "approval_url", "`UNDECLARED`", "`SCHEMA`", "Per stratum"):
            self.assertIn(needle, declared)
        fingerprints = squash(self.section(14))
        for needle in ("julia`, `id`, `rep`, `kind`, `name`, `value`", "`reset/values`", "`reset/active_ids`",
                       "`config/solver`", "`config/options`", "`file/certificates.jl`", "at least one `fixture` row",
                       "SHA-256", "`none`"):
            self.assertIn(needle, fingerprints)

    def test_the_hardware_rule_the_near_target_flag_and_the_screens_are_exact(self):
        text = squash(self.spec)
        self.assertIn("`controlled` only if every process of the receipt carried the frozen machine policy", text)
        self.assertIn("observational", text)
        for needle in ("`accuracy_fraction = v / t`", "`missed/invalid`", "`near target` if `0.9 <= v / t <= 1`",
                       "`margin` if `0 <= v / t < 0.9`"):
            self.assertIn(needle, text)
        for needle in ("**screened slowdown** if `rho_i > 1` for all eight blocks",
                       "**screened speedup** if `rho_i < 1` for all eight",
                       "**inconclusive**", "**screen not evaluated**"):
            self.assertIn(needle, text)
        self.assertIn("exit status 3", squash(self.section(16)))

    def test_the_recorded_hashes_of_the_ordinary_tools_are_the_real_ones(self):
        for name in ("compare.py", "validate.py"):
            with open(os.path.join(BENCH, name), "rb") as handle:
                digest = hashlib.sha256(handle.read()).hexdigest()
            self.assertIn(f"`{name}` `{digest}`", squash(self.spec))

    def test_every_section_8_requirement_of_the_brief_is_listed(self):
        tests = squash(self.section(8))
        for needle in ("(16 tests)", "stage2b_fixtures.py", "a missing ID in one root", "the same missing ID in both roots",
                       "a duplicate process event", "an extra ID", "eight repetition IDs", "overlapping processes",
                       "near-target", "no `--aa`", "`schedule.toml` is read by the tool and by the tests alike"):
            self.assertIn(needle, tests)


class ReadmeTests(unittest.TestCase):
    def test_every_file_of_the_directory_is_indexed_and_the_new_ones_are_described(self):
        readme = read(os.path.join(HERE, "README.md"))
        for name in sorted(os.listdir(HERE)):
            if os.path.isfile(os.path.join(HERE, name)) and not name.endswith(".pyc") and name != "README.md":
                self.assertIn(f"`{name}`", readme, f"{name} is not in the file index")
        for name in ("schedule.toml", "migration_compare.py", "stage2b_fixtures.py", "test_migration_compare.py",
                     "test_p14_reset.jl", "MIGRATION_COMPARE_SPEC.md"):
            self.assertIn(f"[`{name}`]", readme, name)
        self.assertNotIn("(no implementation)", readme)
        self.assertNotIn("preparation only", readme.split("**Status:")[1].split("\n")[0])

    def test_the_run_instructions_say_what_the_default_collection_picks_up(self):
        readme = read(os.path.join(HERE, "README.md"))
        self.assertIn("cd benchmark/campaigns/stage2b\npython3 -B -m unittest -v", readme)
        self.assertIn("does **not** pick up `probes/`", squash(readme))
        self.assertIn("`probes/` has no `__init__.py`", readme)
        self.assertIn("python3 -B -m unittest test_check_reset_probes -v", readme)
        self.assertFalse(os.path.exists(os.path.join(HERE, "probes", "__init__.py")))

    def test_default_collection_finds_the_test_modules_of_this_directory_and_not_the_probes(self):
        suite = unittest.TestLoader().discover(HERE)
        modules = set()

        def walk(tests):
            for test in tests:
                if isinstance(test, unittest.TestSuite):
                    walk(test)
                else:
                    modules.add(type(test).__module__)
        walk(suite)
        self.assertIn("test_stage2b_files", modules)
        self.assertNotIn("test_check_reset_probes", modules)


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
                     "READINESS.md", "MIGRATION_COMPARE_SPEC.md", "schedule.toml", "historical_reference.py",
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


def write_checksums(root):
    """root/checksums.sha256 in the archive's format: every regular file but itself, relative paths."""
    lines = []
    for folder, _, names in os.walk(root):
        for name in names:
            path = os.path.join(folder, name)
            relative = os.path.relpath(path, root).replace(os.sep, "/")
            if relative != "checksums.sha256":
                with open(path, "rb") as handle:
                    lines.append((relative, hashlib.sha256(handle.read()).hexdigest()))
    write(os.path.join(root, "checksums.sha256"), "".join(
        f"{digest}  {relative}\n" for relative, digest in sorted(lines)))


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
        extra = ["--frozen-dir", self.frozen] if "--frozen-dir" not in argv else []
        with contextlib.redirect_stdout(out), contextlib.redirect_stderr(err):
            status = self.module.main(list(argv) + extra)
        return status, out.getvalue(), err.getvalue()

    def pin(self, root):
        """Pin the synthetic archive's own listing (the real constant belongs to the real archive)."""
        self.module.LISTING_SHA256 = hashlib.sha256(
            read(os.path.join(root, "checksums.sha256")).encode()).hexdigest()

    def rechecksum(self, root):
        write_checksums(root)
        self.pin(root)

    def archive(self, mutate=None):
        directory = tempfile.TemporaryDirectory()
        self.addCleanup(directory.cleanup)
        root = os.path.join(directory.name, "pre06-stage2a-campaign-v1")
        build_archive(root, mutate)
        original = self.module.LISTING_SHA256
        self.addCleanup(setattr, self.module, "LISTING_SHA256", original)
        self.rechecksum(root)
        # the "frozen" files of this synthetic world are the archive's own campaign.toml and cases.txt
        self.frozen = os.path.join(directory.name, "frozen")
        for name in ("campaign.toml", "cases.txt"):
            write(os.path.join(self.frozen, name), read(os.path.join(root, name)))
        return root, directory.name

    def test_generation_and_check_round_trip(self):
        root, scratch = self.archive()
        status, text, _ = self.run_main(root)
        self.assertEqual(status, 0)
        committed = os.path.join(scratch, "reference.tsv")
        write(committed, text)
        self.assertEqual(self.run_main(root, "--check", committed)[0], 0)
        self.assertEqual(sum(1 for l in text.splitlines() if l and not l.startswith("#")), 1 + 38)

    def test_success_line_prints_the_sha256_of_the_committed_file(self):
        root, scratch = self.archive()
        committed = os.path.join(scratch, "reference.tsv")
        write(committed, self.run_main(root)[1])
        status, out, _ = self.run_main(root, "--check", committed)
        self.assertEqual(status, 0)
        self.assertIn(hashlib.sha256(read(committed).encode()).hexdigest(), out)

    def test_an_altered_archive_file_is_refused_with_status_1(self):
        root, _ = self.archive()
        path = os.path.join(root, "julia-1.10", "raw", "julia-1.10.13-rep02-metrics.tsv")
        write(path, read(path).replace("ok\t", "ok\t", 1) + "\n")
        status, _, err = self.run_main(root)
        self.assertEqual(status, 1)
        self.assertIn("checksum", err)

    def test_an_unlisted_or_missing_file_is_refused_with_status_1(self):
        root, _ = self.archive()
        write(os.path.join(root, "julia-1.10", "extra.txt"), "x\n")
        status, _, err = self.run_main(root)
        self.assertEqual((status, "not listed" in err), (1, True))
        os.remove(os.path.join(root, "julia-1.10", "extra.txt"))
        os.remove(os.path.join(root, "julia-1.13", "raw", "julia-1.13.3-rep01-metadata.toml"))
        status, _, err = self.run_main(root)
        self.assertEqual((status, "missing" in err), (1, True))

    def test_a_listing_other_than_the_pinned_one_is_refused_with_status_1(self):
        root, _ = self.archive()
        # a consistent, internally valid listing of the same files that is not the pinned one
        write_checksums(root)
        path = os.path.join(root, "checksums.sha256")
        write(path, read(path) + "\n")                   # same entries, different bytes
        status, _, err = self.run_main(root)
        self.assertEqual((status, "pinned listing" in err), (1, True))

    def test_the_script_pins_the_real_archive_listing(self):
        self.assertEqual(self.module.LISTING_SHA256,
                         "a054ab2c5938a1a898a2fb800f2deb1b969dbf0cd1fa0beab4ef4b5adbdd931d")
        source = read(os.path.join(HERE, "historical_reference.py"))
        self.assertIn("pinned", source)
        self.assertIn("provenance only", source)

    def test_a_missing_or_malformed_checksum_file_is_refused_with_status_1(self):
        root, _ = self.archive()
        write(os.path.join(root, "checksums.sha256"), "not a checksum line\n")
        self.assertEqual(self.run_main(root)[0], 1)
        os.remove(os.path.join(root, "checksums.sha256"))
        self.assertEqual(self.run_main(root)[0], 1)

    def test_a_symbolic_link_in_the_root_is_refused_with_status_1(self):
        root, _ = self.archive()
        os.symlink(os.path.join(root, "cases.txt"), os.path.join(root, "link.txt"))
        status, _, err = self.run_main(root)
        self.assertEqual((status, "symbolic link" in err), (1, True))

    def test_a_campaign_toml_that_differs_from_the_frozen_one_is_refused_with_status_1(self):
        root, _ = self.archive()
        path = os.path.join(root, "campaign.toml")
        write(path, read(path) + "# altered\n")
        self.assertEqual(self.run_main(root)[0], 1)      # the checksum no longer matches
        self.rechecksum(root)                            # a consistent listing does not help
        status, _, err = self.run_main(root)
        self.assertEqual((status, "frozen" in err), (1, True))

    def test_a_cases_txt_that_differs_from_the_frozen_one_is_refused_with_status_1(self):
        root, _ = self.archive()
        write(os.path.join(root, "cases.txt"), read(os.path.join(root, "cases.txt")) + "\n")
        self.rechecksum(root)
        self.assertEqual(self.run_main(root)[0], 1)

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
        self.assertEqual(self.run_main(root)[0], 1)      # listed but missing: the binding fails first
        self.rechecksum(root)                            # a consistent listing: the content check aborts
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
