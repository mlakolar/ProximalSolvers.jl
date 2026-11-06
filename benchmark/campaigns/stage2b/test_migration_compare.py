#!/usr/bin/env python3
"""Offline tests of migration_compare.py (MIGRATION_COMPARE_SPEC.md, sections 2-16).

    python3 -B -m unittest test_migration_compare -v        (from benchmark/campaigns/stage2b)

Standard library only (Python 3.11 or later). The tests build small synthetic campaign roots with
stage2b_fixtures.py (once per variant), copy them per test, change exactly one item and call
`migration_compare.main(argv)` in process. Every timing value is finite, so a comparison that only looked at the
timing would wrongly accept; each test asserts the exit status and, for a refusal, the `REFUSED:<CLASS>` line on
standard error, the entry of `refusals.json` and that `refusals.json` is the only file written.

Test counts (methods; table-driven methods run one sub-test per row):

    positive        PositiveTests         16
    refusal         RefusalTests          22   (one named method per class of section 4, plus six that
                                               check equally incomplete roots, the A/A installations, that
                                               several coinciding defects are all listed, the declared package
                                               tables, unrelated classes together and a mixed root)
    classification  ClassificationTests   22
    output          OutputTests           19
    immutability    ImmutabilityTests      5

The run time is dominated by the validation of the roughly two hundred record files that each call of the tool
reads; the sets are built once per variant, copied by links per test and kept small (five samples per case).
"""

import atexit
import hashlib
import json
import math
import re
import shutil
import tempfile
import unittest
from pathlib import Path

import stage2b_fixtures as F
from stage2b_fixtures import (
    jsonl_append, jsonl_drop, jsonl_edit, jsonl_read, jsonl_write, process_event, toml_append, toml_del,
    toml_load, toml_set, tsv_append, tsv_drop, tsv_edit, tsv_read, tsv_rename_column, tsv_write,
)

# SHA-256 of the protected files at the base of the pull request (the freeze commit of Stage 2B).
COMPARE_SHA256 = "41568ea9b22d9b36f1aa6ba4e478b380284ee66c338f98dfeed40af104ebf6ab"
VALIDATE_SHA256 = "0b761e77ae4b88d339d7df3351e5ea0ff732c8cd32f68fbb89d95d4a26f2fc4b"
SUMMARIZE_SHA256 = "d50b471f3898c90c7b1aa880553f12de0a8eb809475e4abcd0859bb57ed703f1"
EXPECTED_MATCH_SETTINGS = (
    "suite", "groups", "harness_hash", "proximalbase_version", "proximalbase_hash", "julia_threads",
    "blas_threads", "blas", "cpu_model", "samples_target", "seconds_limit", "case_seconds", "profile_seconds",
    "seed_scheme", "case_filter",
)
DISCLAIMER = ("This is a whole-stack migration comparison. Differences cannot be attributed solely to "
              "ProximalBase. The Stage 2A historical archive is descriptive context, not part of the "
              "contemporaneous paired ratios.")
SCREEN_SENTENCE = ("The screens are descriptive investigation screens, not tests: there is no significance level, "
                   "no noninferiority claim and no no-regression claim, and A/A ranges are not calibrated "
                   "confidence bounds.")
ORDERS = {1: "AB", 2: "BA", 3: "BA", 4: "AB", 5: "BA", 6: "AB", 7: "AB", 8: "BA"}
J10, J13 = "1.10", "1.13"
V10, V13 = "1.10.13", "1.13.3"
P01 = "cd/lasso-dense/cd/B/call"
P02 = "cd/lasso-csc/cd/B/call"
P03 = "cd/lasso-dense/cd/B/workspace"
P05 = "sgl/sparse-group/cd/tight/call"
P07 = "gradient/lasso/apg/tight/call"
P09 = "newton/logistic-weighted-offset/prox-newton/tight/call"
P13 = "admm/lasso/admm/construction/setup"
P14 = "paths/lasso/cd/grid8/call"
D04 = "primal_dual/generalized-lasso/condat-vu/tight/call"
FILLED = ["julia", "id", "role", "phase", "class", "reason", "measure", "target", "hardware", "mapping_class"]
UNFILLED = [column for column in F.CSV_COLUMNS[F.CSV_COLUMNS.index("repetitions"):F.CSV_COLUMNS.index("b_median_bytes") + 1]
            if column not in FILLED] + ["aa_ratio_min", "aa_ratio_max", "screen"]
EXTRA_CASE = dict(id="extra/synthetic/solver/variant/call", group="extra", problem="synthetic", solver="solver",
                  variant="variant", phase="call", suite="quick", inputs="fixed", issue="", measure="relative_gap",
                  target=1e-06, role="diagnostic", label="X01", index=40)

_BASES, _WORK = {}, []


def base(variant):
    """The built input set of a variant, built once per test run."""
    if variant not in _BASES:
        if not _WORK:
            _WORK.append(tempfile.mkdtemp(prefix="stage2b-fixtures-"))
            atexit.register(shutil.rmtree, _WORK[0], True)
        directory = Path(_WORK[0]) / variant
        directory.mkdir()
        _BASES[variant] = F.build_campaign(directory, variant)
        F.freeze(_BASES[variant].base)
    return _BASES[variant]


def tearDownModule():
    for path in _WORK:
        shutil.rmtree(path, ignore_errors=True)
    _WORK.clear()
    _BASES.clear()


# --------------------------------------------------------------------------------------------------------------
# Small mutation helpers used by several tests
# --------------------------------------------------------------------------------------------------------------

def mapping_index(c, case_id):
    return c.case_ids.index(case_id)


def set_mapping(c, case_id, key, value):
    toml_set(c.mapping, ("case", mapping_index(c, case_id), key), value)


def set_fingerprint(c, label, jkey, case_id, rep, kind, name, value):
    match = {"julia": c.version(jkey), "id": case_id, "rep": rep, "kind": kind, "name": name}
    tsv_edit(c.fingerprints(label), match, "value", value)


def drop_fingerprint(c, label, jkey, case_id, rep, kind, name=None):
    match = {"julia": c.version(jkey), "id": case_id, "rep": rep, "kind": kind}
    if name is not None:
        match["name"] = name
    tsv_drop(c.fingerprints(label), match)


def swap_block(c, arm, jkey, rep):
    """Run block `rep` in the other order: the two processes exchange their time stamps."""
    events = jsonl_read(c.receipt)
    pair = [e for e in events if process_event(None, arm, c.version(jkey), rep)(e)]
    assert len(pair) == 2
    for key in ("start_utc", "end_utc"):
        pair[0][key], pair[1][key] = pair[1][key], pair[0][key]
    jsonl_write(c.receipt, events)


def receipt_orders(c, arm, jkey):
    """The block order of each repetition ID as the receipt places it."""
    orders = {}
    for rep in c.reps:
        pair = {e["role"]: e["start_utc"] for e in jsonl_read(c.receipt)
                if process_event(None, arm, c.version(jkey), rep)(e)}
        orders[rep] = "AB" if pair["A"] < pair["B"] else "BA"
    return orders


def edit_identity(c, label, keys, value=None, delete=False):
    path = c.root(label) / "stack-identity.toml"
    toml_del(path, keys) if delete else toml_set(path, keys, value)


def floats(cell):
    return [float(item) for item in cell.split(";")]


def banned_outside_sentence(text):
    return [word for word in F.BANNED_WORDS if word in text.replace(SCREEN_SENTENCE, "").lower()]


class MigrationCase(unittest.TestCase):
    """A fresh copy of a built input set per test (`self.c`); `fresh` makes another one."""

    def setUp(self):
        self._tmp = tempfile.TemporaryDirectory(prefix="stage2b-test-")
        self.addCleanup(self._tmp.cleanup)
        self._copies, self._c = 0, None

    @property
    def c(self):
        """The copy of the default (migration) set of this test, made on first use."""
        if self._c is None:
            self.fresh()
        return self._c

    def fresh(self, variant="migration", aa=False):
        self._copies += 1
        work = Path(self._tmp.name) / f"w{self._copies}"
        work.mkdir()
        self._c = base(variant).copy(work, with_aa=aa)
        return self._c

    # ---- assertions ----------------------------------------------------------------------------------------
    def accepted(self, result, code=0):
        self.assertEqual(result.code, code, result.stderr)
        self.assertNotIn("REFUSED", result.stderr)
        self.assertEqual(result.files, ["lists.json", "migration-comparison.csv", "report.md"])
        return result

    def refused(self, result, *classes, fields=(), only=False):
        """Exit status 2, `REFUSED:<CLASS>` on standard error, the class in refusals.json, nothing else written."""
        self.assertEqual(result.code, 2, result.stderr or "no refusal printed")
        self.assertEqual(result.files, ["refusals.json"], "only refusals.json is written after a refusal")
        for name in ("migration-comparison.csv", "report.md", "lists.json"):
            self.assertFalse((result.out / name).exists(), name)
        document = result.refusals_document
        self.assertEqual(document["schema"], 1)
        self.assertEqual(document["count"], len(document["refusals"]))
        self.assertEqual(len(result.lines), document["count"], "one REFUSED line per refusal")
        self.assertEqual([(c, f) for c, f, _ in result.lines],
                         [(item["class"], item["field"]) for item in document["refusals"]])
        keys = [(F.CLASS_ORDER.index(i["class"]), i["field"], i["detail"]) for i in document["refusals"]]
        self.assertEqual(keys, sorted(keys), "refusals are sorted by class row, field and detail")
        for cls in classes:
            self.assertIn(f"REFUSED:{cls} ", result.stderr)
            self.assertIn(cls, result.classes)
        for cls, field in fields:
            self.assertTrue(result.has(cls, field), f"{cls} {field} not in {result.fields(cls)}")
        if only:
            self.assertEqual(set(result.classes), set(classes))
        return result

    def table(self, rows, aa=False, variant="migration"):
        """rows: (name, mutation(c), classes[, fields]). `classes` is a class, a tuple of classes that must all be
        listed, or "A|B" for a refusal of either class; `fields` is a list of (class, field) pairs that must be
        listed. Each row runs on a fresh copy."""
        for name, mutate, expected, *rest in rows:
            with self.subTest(name):
                c = self.fresh(variant=variant, aa=aa)
                mutate(c)
                fields = rest[0] if rest else ()
                if isinstance(expected, str) and "|" in expected:
                    result = self.refused(c.run(aa=aa))
                    self.assertTrue(set(result.classes) & set(expected.split("|")), result.classes)
                else:
                    expected = (expected,) if isinstance(expected, str) else tuple(expected)
                    self.refused(c.run(aa=aa), *expected, fields=fields)


# --------------------------------------------------------------------------------------------------------------
# 1. Positive
# --------------------------------------------------------------------------------------------------------------

class PositiveTests(MigrationCase):

    def test_valid_migration_accepted_with_every_case_comparable(self):
        result = self.accepted(self.c.run())
        self.assertEqual(len(result.rows), 38)
        self.assertEqual({row["class"] for row in result.rows}, {"COMPARABLE"})
        self.assertEqual({row["reason"] for row in result.rows}, {""})

    def test_identical_roots_accepted_and_declare_nothing(self):
        c = self.fresh("identical")
        self.assertEqual(toml_load(c.declared), {"schema": 1})
        for jkey in c.jkeys:
            meta = [toml_load(c.record(label, jkey, 1, "metadata")) for label in ("a", "b")]
            for key in ("harness_hash", "proximalsolvers_sha", "proximalsolvers_hash", "proximalbase_version",
                        "proximalbase_hash"):
                self.assertEqual(meta[0][key], meta[1][key], key)
        result = self.accepted(c.run())
        self.assertEqual({row["class"] for row in result.rows}, {"COMPARABLE"})

    def test_declared_proximalsolvers_change_accepted(self):
        c = self.c
        a, b = (toml_load(c.record(label, J13, 1, "metadata")) for label in ("a", "b"))
        self.assertNotEqual(a["proximalsolvers_sha"], b["proximalsolvers_sha"])
        self.assertNotEqual(a["proximalsolvers_hash"], b["proximalsolvers_hash"])
        identity = [toml_load(c.root(label) / "stack-identity.toml")["proximalsolvers"] for label in ("a", "b")]
        self.assertNotEqual(identity[0]["commit"], identity[1]["commit"])
        self.assertNotEqual(identity[0]["tree"], identity[1]["tree"])
        self.assertIn("proximalsolvers", toml_load(c.declared))
        self.accepted(c.run())

    def test_proximalbase_version_and_tree_change_accepted(self):
        c = self.c
        a, b = (toml_load(c.record(label, J10, 2, "metadata")) for label in ("a", "b"))
        self.assertEqual((a["proximalbase_version"], b["proximalbase_version"]), ("0.5.4", "0.6.0"))
        self.assertNotEqual(a["proximalbase_hash"], b["proximalbase_hash"])
        trees = [toml_load(c.stratum(label, J10) / "environment-inventory.toml")["proximalbase_loaded_tree"]
                 for label in ("a", "b")]
        self.assertNotEqual(trees[0], trees[1])
        self.assertIn("proximalbase", toml_load(c.declared))
        self.assertEqual(toml_load(c.root("b") / "stack-identity.toml")["proximalbase"]["release"], "development")
        self.accepted(c.run())

    def test_declared_manifest_changed_added_removed_accepted(self):
        c = self.fresh("manifest")
        declared = toml_load(c.declared)
        kinds = {(entry["name"], entry["kind"]): entry.get("julia") for entry in declared["manifest"]}
        self.assertEqual(kinds, {("ProximalBase", "changed"): None, ("StatsBase", "changed"): None,
                                 ("NewDep", "added"): [J13], ("OldDep", "removed"): None})
        self.assertIn(("NewDep", "1"), {(e["name"], e["b"]) for e in declared["compat"]})
        self.accepted(c.run())

    def test_reviewed_class_b_harness_change_accepted(self):
        c = self.c
        a, b = (toml_load(c.record(label, J13, 5, "metadata"))["harness_hash"] for label in ("a", "b"))
        self.assertNotEqual(a, b)
        harness = toml_load(c.declared)["harness"]
        self.assertEqual((harness["a_hash"], harness["b_hash"]), (a, b))
        self.assertEqual(harness["cases"], [P14])
        result = self.accepted(c.run())
        self.assertEqual([row["mapping_class"] for row in result.rows if row["id"] == P14], ["B", "B"])
        self.assertEqual({row["mapping_class"] for row in result.rows if row["id"] != P14}, {"A"})

    def test_two_versions_reported_side_by_side_without_pooling(self):
        c = self.c
        result = self.accepted(c.run())
        self.assertEqual({row["julia"] for row in result.rows}, {V10, V13})
        for version in (V10, V13):
            ids = [row["id"] for row in result.rows if row["julia"] == version]
            self.assertEqual(ids, c.case_ids, "one row per declared case, in the declared order")
        self.assertEqual([row["julia"] for row in result.rows], [V10] * 19 + [V13] * 19)
        for jkey in (J10, J13):
            row = result.row(P03, jkey)
            expected = [c.median("b", jkey, P03, rep) / c.median("a", jkey, P03, rep) for rep in c.reps]
            self.assertEqual(floats(row["ratio"]), expected)
            self.assertEqual(len(row["ratio"].split(";")), 8, "eight blocks of this stratum, none pooled")

    def test_eight_blocks_follow_the_receipt_order_of_the_schedule(self):
        c = self.c
        for arm in ("AA", "AB"):
            for jkey in c.jkeys:
                self.assertEqual(receipt_orders(c, arm, jkey), ORDERS)
        self.assertEqual({int(k): v for k, v in c.sched["schedule"]["orders"].items()}, ORDERS)
        self.accepted(c.run())
        # the tool follows the schedule file it is given: a new order for ID 2 in the schedule copy and in the
        # receipt (both arms, both strata) is accepted
        toml_set(c.schedule, ("schedule", "orders", "2"), "AB")
        for arm in ("AA", "AB"):
            for jkey in c.jkeys:
                swap_block(c, arm, jkey, 2)
        self.accepted(c.run())

    def test_independent_aa_installations_accepted_and_screens_evaluated(self):
        c = self.fresh(aa=True)
        a, b = (toml_load(c.root(label) / "stack-identity.toml") for label in ("aa_a", "aa_b"))
        self.assertNotEqual(a["installation"], b["installation"])
        self.assertEqual((a["proximalsolvers"], a["proximalbase"]), (b["proximalsolvers"], b["proximalbase"]))
        paths = [toml_load(c.record(label, J13, 1, "metadata"))["proximalsolvers_path"] for label in ("aa_a", "aa_b")]
        self.assertNotEqual(paths[0], paths[1])
        result = self.accepted(c.run(aa=True))
        self.assertEqual({row["class"] for row in result.rows}, {"COMPARABLE"})
        self.assertNotIn("screen not evaluated", {row["screen"] for row in result.rows})
        self.assertEqual(result.lists["missing_diagnostics"], [])

    def test_full_nineteen_case_mapping_used(self):
        c = self.c
        mapping = toml_load(c.mapping)["case"]
        self.assertEqual(len(mapping), 19)
        result = self.accepted(c.run())
        for version in (V10, V13):
            rows = [row for row in result.rows if row["julia"] == version]
            self.assertEqual([row["id"] for row in rows], [entry["id"] for entry in mapping])
            self.assertEqual([row["role"] for row in rows], ["primary"] * 14 + ["diagnostic"] * 5)
            self.assertEqual([row["phase"] for row in rows], [entry["phase"] for entry in mapping])
            self.assertEqual([row["mapping_class"] for row in rows], [entry["class"] for entry in mapping])
            self.assertEqual([row["measure"] for row in rows], [c.case(row["id"])["measure"] for row in rows])

    def test_seven_repetition_schedule_is_followed(self):
        with tempfile.TemporaryDirectory(prefix="stage2b-seven-") as work:
            c = F.build_campaign(work, "migration", reps=7)
            self.assertEqual(toml_load(c.schedule)["schedule"]["reps"], [1, 2, 3, 4, 5, 6, 7])
            result = self.accepted(c.run())
            self.assertEqual({row["repetitions"] for row in result.rows}, {"1;2;3;4;5;6;7"})
            self.assertEqual(len(result.rows[0]["ratio"].split(";")), 7)
            # the roots built for eight blocks do not fit this schedule
            other = c.run(a=base("migration").root("a"), b=base("migration").root("b"))
            self.refused(other, "REPETITIONS")

    def test_historical_stack_a_tag_commit_with_release_tree_accepted(self):
        c = self.c
        identity = toml_load(c.root("a") / "stack-identity.toml")["proximalbase"]
        self.assertEqual(identity["commit"], "9c5a43bf0b7e3f51f0a401b785c332200ffa5d7e")
        self.assertEqual(identity["tree"], "1226119eb2cc6144f7345c727f0e7682632f7826")
        self.assertEqual((identity["tag"], identity["release"]), ("v0.5.4", "registered"))
        self.accepted(c.run())

    def test_aa_arm_events_are_ignored_without_aa_option(self):
        c = self.c
        jsonl_drop(c.receipt, lambda e: e["event"] == "process" and e["arm"] == "AA")
        self.accepted(c.run())

    def test_receipt_hardware_policy_values_label_the_campaign_as_controlled(self):
        result = self.accepted(self.c.run())
        self.assertEqual({row["hardware"] for row in result.rows}, {"controlled"})
        self.assertIn("controlled", result.report[:1500])

    def test_default_schedule_is_the_file_next_to_the_tool(self):
        c = self.c
        self.assertEqual(c.schedule.read_bytes(), (F.HERE / "schedule.toml").read_bytes())
        self.accepted(c.run(omit=("schedule",)))

    def test_accepted_pair_has_no_warnings_on_standard_error(self):
        result = self.accepted(self.c.run())
        self.assertEqual(result.stderr, "")


# --------------------------------------------------------------------------------------------------------------
# 2. Refusals: one named method per class of section 4, with their subcases
# --------------------------------------------------------------------------------------------------------------

class RefusalTests(MigrationCase):

    def test_julia_refused(self):
        def other_build(c):
            c.retag_stratum("b", J13, "1.13.4")

        def inventory_commit(c):
            toml_set(c.stratum("a", J10) / "environment-inventory.toml", ("commit",), "0" * 40)

        def manifest_version(c):
            toml_set(c.stratum("b", J10) / "Manifest.toml", ("julia_version",), "1.10.12")

        def stratum_missing(c):
            shutil.rmtree(c.stratum("b", J13))

        def stratum_missing_in_both(c):
            for label in ("a", "b"):
                shutil.rmtree(c.stratum(label, J10))

        def stratum_not_in_schedule(c):
            shutil.copytree(c.stratum("b", J13), c.root("b") / "julia-1.11")

        self.table([
            ("different Julia build in the record files", other_build, "JULIA", [("JULIA", "b:julia")]),
            ("inventory commit", inventory_commit, "JULIA"),
            ("Manifest julia_version", manifest_version, "JULIA"),
            ("stratum missing in one root", stratum_missing, "JULIA"),
            ("stratum missing in both roots", stratum_missing_in_both, "JULIA"),
            ("stratum not in the schedule", stratum_not_in_schedule, "JULIA"),
        ])

    def test_inputs_refused(self):
        def data_hash(c):
            c.write_process("b", J13, 3, data_hash={P05: "f" * 64})

        def seed_scheme(c):
            c.set_meta("b", "seed_scheme", "another scheme")

        def fixture_value(c):
            set_fingerprint(c, "b", J13, P05, 3, "fixture", "X", "e" * 64)

        def fixture_name_on_one_side(c):
            drop_fingerprint(c, "b", J10, P01, 2, "fixture", "y")

        def fixture_in_first_stratum_of_a(c):
            set_fingerprint(c, "a", J10, P14, 8, "fixture", "grid", "d" * 64)

        self.table([
            ("data_hash of one case and repetition", data_hash, "INPUTS", [("INPUTS", "ab:data_hash")]),
            ("seed_scheme", seed_scheme, "INPUTS"),
            ("fixture fingerprint value", fixture_value, "INPUTS"),
            ("fixture name on one side only", fixture_name_on_one_side, "INPUTS"),
            ("fixture fingerprint of A", fixture_in_first_stratum_of_a, "INPUTS"),
        ])
        c = self.fresh(aa=True)
        c.write_process("aa_b", J10, 2, data_hash={P01: "c" * 64})
        self.refused(c.run(aa=True), "INPUTS", fields=[("INPUTS", "aa:data_hash")])

    def test_target_refused(self):
        def catalog_target(c):
            c.write_records("b", [J13], catalog={P01: {"target": 1e-07}})

        def catalog_measure(c):
            c.write_records("b", [J10], catalog={P05: {"measure": "kkt_residual"}})

        def mapping_target(c):
            set_mapping(c, P07, "target", "1e-07")

        def mapping_measure(c):
            set_mapping(c, P07, "measure", "kkt_residual, target 1e-06 (synthetic)")

        def metric_target_in_one_row(c):
            tsv_edit(c.record("a", J13, 4, "metrics"), {"id": P02}, "target", "1e-07")

        def metric_measure_in_one_row(c):
            tsv_edit(c.record("b", J13, 4, "metrics"), {"id": P02}, "measure", "kkt_residual")

        self.table([
            ("catalog target of B", catalog_target, "TARGET", [("TARGET", "ab:target")]),
            ("catalog measure of B", catalog_measure, "TARGET"),
            ("mapping target", mapping_target, "TARGET"),
            ("mapping measure", mapping_measure, "TARGET"),
            ("metrics target differs from the catalog", metric_target_in_one_row, "TARGET"),
            ("metrics measure differs from the catalog", metric_measure_in_one_row, "TARGET"),
        ])

    def test_case_refused(self):
        def missing_in_b(c):
            c.write_records("b", [J13], drop=[P05])

        def missing_in_a(c):
            c.write_records("a", [J10], drop=[P09])

        def missing_in_both(c):
            for label in ("a", "b"):
                c.write_records(label, drop=[P14])

        def extra_in_b(c):
            c.write_records("b", [J13], extra=[EXTRA_CASE])

        def extra_in_both(c):
            for label in ("a", "b"):
                c.write_records(label, extra=[EXTRA_CASE])

        self.table([
            ("declared case missing from B", missing_in_b, "CASE", [("CASE", "b:case")]),
            ("declared case missing from A", missing_in_a, "CASE", [("CASE", "a:case")]),
            ("case present in B and not declared", extra_in_b, "CASE", [("CASE", "b:case")]),
            ("case present in both roots and not declared", extra_in_both, "CASE"),
        ])
        c = self.fresh()
        missing_in_both(c)
        result = self.refused(c.run(), "CASE")
        self.assertEqual(set(result.fields("CASE")), {"a:case", "b:case"}, "the absent case is listed for each root")
        c = self.fresh()
        missing_in_b(c)
        self.assertNotIn("a:case", self.refused(c.run(), "CASE").fields("CASE"))

    def test_phase_refused(self):
        def metrics_phase(old, new, label="b"):
            def mutate(c):
                tsv_edit(c.record(label, J13, 3, "metrics"), {"phase": old, "id": {
                    "call": P01, "workspace": P03, "setup": P13}[old]}, "phase", new)
            return mutate

        def unknown_phase(c):
            c.write_records("b", [J13], rename={P01: "cd/lasso-dense/cd/B/bogus"})

        self.table([
            ("call -> workspace in the metrics", metrics_phase("call", "workspace"), "PHASE"),
            ("workspace -> setup in the metrics", metrics_phase("workspace", "setup"), "PHASE"),
            ("setup -> call in the metrics", metrics_phase("setup", "call"), "PHASE"),
            ("call -> workspace in the metrics of A", metrics_phase("call", "workspace", "a"), "PHASE"),
            ("phase that is not call, workspace or setup", unknown_phase, "PHASE"),
        ])

    def test_operation_refused(self):
        def suite(c):
            c.write_records("b", [J13], catalog={P01: {"suite": "extended"}})

        def inputs(c):
            c.write_records("b", [J10], catalog={P05: {"inputs": "fixed"}})

        def catalog_changes_between_repetitions(c):
            c.write_process("b", J13, 3, catalog={P01: {"inputs": "draw"}})

        def certificate_identity(c):
            set_fingerprint(c, "b", J13, D04, 3, "file", "certificates.jl", "9" * 64)

        def solver_renamed(c):
            c.write_records("b", [J13], rename={P01: "cd/lasso-dense/cd2/B/call"})

        self.table([
            ("catalog suite", suite, "OPERATION", [("OPERATION", "ab:catalog")]),
            ("catalog inputs", inputs, "OPERATION"),
            ("catalog changed between repetitions", catalog_changes_between_repetitions, "OPERATION"),
            ("certificate file identity of B", certificate_identity, "OPERATION", [("OPERATION", "ab:certificates")]),
            # problem, solver and variant are parts of the case ID, so a record that validates cannot change
            # them without changing the ID: the case is then missing from the other root (CASE)
            ("solver changed (the case ID changes with it)", solver_renamed, "CASE"),
        ])
        c = self.fresh()
        suite(c)
        result = self.refused(c.run(), "OPERATION")
        self.assertIn("suite", next(i["detail"] for i in result.refusals if i["field"] == "ab:catalog"))

    def test_threads_refused(self):
        def julia_threads(c):
            c.set_meta("b", "julia_threads", 2)

        def blas_threads(c):
            c.set_meta("b", "blas_threads", 2, jkeys=[J13])

        def blas_threads_one_process(c):
            c.set_meta("a", "blas_threads", 4, jkeys=[J10], reps=[5])

        def blas_identity(c):
            c.set_meta("b", "blas", "LBTConfig([LP64] libmkl_rt.so)")

        def blas_identity_one_stratum(c):
            c.set_meta("b", "blas", "LBTConfig([ILP64] libblis.so)", jkeys=[J10])

        self.table([
            ("Julia threads", julia_threads, "THREADS"),
            ("BLAS threads", blas_threads, "THREADS"),
            ("BLAS threads in one process", blas_threads_one_process, "THREADS"),
            ("BLAS identity", blas_identity, "THREADS", [("THREADS", "ab:blas")]),
            ("BLAS identity in one stratum", blas_identity_one_stratum, "THREADS"),
        ])
        c = self.fresh(aa=True)
        c.set_meta("aa_b", "blas", "LBTConfig([LP64] libmkl_rt.so)")
        self.refused(c.run(aa=True), "THREADS", fields=[("THREADS", "aa:blas")])

    def test_machine_refused(self):
        def edit_event(**changes):
            def mutate(c):
                def apply(event):
                    machine = event["machine"]
                    machine.update({k: v for k, v in changes.items()})
                jsonl_edit(c.receipt, process_event("B", "AB", V13, 6), apply)
            return mutate

        def cpu_model(c):
            c.set_meta("b", "cpu_model", "Another CPU")

        def cpu(c):
            c.set_meta("a", "cpu", "skylake", jkeys=[J13])

        def inventory_cpu_model(c):
            toml_set(c.stratum("b", J10) / "environment-inventory.toml", ("cpu_model",), "Another CPU")

        def aa_event_without_aa_option(c):
            jsonl_edit(c.receipt, process_event("A", "AA", V10, 2), lambda e: e["machine"].update(logical_cpu=2))

        def stratum_cpu_in_receipt(c):
            jsonl_edit(c.receipt, process_event("A", "AB", V10, 1), lambda e: e["machine"].update(cpu="raptorlake"))

        self.table([
            ("cpu_model of the records", cpu_model, "MACHINE"),
            ("cpu of the records", cpu, "MACHINE"),
            ("cpu_model of the inventory", inventory_cpu_model, "MACHINE"),
            ("logical CPU of one receipt process", edit_event(logical_cpu=5), "MACHINE",
             [("MACHINE", "receipt:machine")]),
            ("processes disagree on the governor", edit_event(governor="performance"), "MACHINE"),
            ("A/A process of the receipt without the option", aa_event_without_aa_option, "MACHINE"),
            ("cpu of a stratum in the receipt", stratum_cpu_in_receipt, "MACHINE"),
        ])

    def test_repetitions_refused(self):
        def missing_in_b(c):
            c.delete_process("b", J13, 4)

        def missing_in_a(c):
            c.delete_process("a", J10, 7)

        def missing_in_both(c):
            for label in ("a", "b"):
                for jkey in c.jkeys:
                    c.delete_process(label, jkey, 4)

        def extra_id(c):
            c.write_process("b", J13, 9)

        def duplicate_process_event(c):
            event = next(e for e in jsonl_read(c.receipt) if process_event("A", "AB", V13, 2)(e))
            jsonl_append(c.receipt, event)

        def receipt_rep_outside_declared_set(c):
            events = jsonl_read(c.receipt)
            event = dict(next(e for e in events if process_event("A", "AB", V13, 8)(e)), rep=9, block=9)
            jsonl_append(c.receipt, event)

        def missing_in_aa(c):
            c.delete_process("aa_b", J10, 3)

        self.table([
            ("repetition missing from B", missing_in_b, "REPETITIONS", [("REPETITIONS", "b:repetitions")]),
            ("repetition missing from A", missing_in_a, "REPETITIONS"),
            ("the same repetition missing from both roots", missing_in_both, "REPETITIONS"),
            ("an extra repetition ID", extra_id, "REPETITIONS"),
            ("duplicate process event in the receipt", duplicate_process_event, "REPETITIONS",
             [("REPETITIONS", "receipt:repetitions")]),
            ("receipt rep outside the declared set", receipt_rep_outside_declared_set, "REPETITIONS"),
        ])
        c = self.fresh(aa=True)
        missing_in_aa(c)
        self.refused(c.run(aa=True), "REPETITIONS", fields=[("REPETITIONS", "aa_b:repetitions")])
        c = self.fresh()
        missing_in_both(c)
        self.assertTrue({"a:repetitions", "b:repetitions"} <= set(self.refused(c.run(), "REPETITIONS").fields("REPETITIONS")))

    def test_equally_incomplete_roots_refused_not_failed(self):
        c = self.fresh()
        for label in ("a", "b"):
            for jkey in c.jkeys:
                c.delete_process(label, jkey, 4)
        self.refused(c.run(), "REPETITIONS")
        c = self.fresh()
        for label in ("a", "b"):
            c.write_records(label, drop=[P14])
        self.refused(c.run(), "CASE")

    def test_mapping_refused(self):
        def class_b_unapproved(c):
            set_mapping(c, P14, "approved", False)

        def class_c_without_separate_mapping(c):
            set_mapping(c, P01, "class", "C")

        def invalid_class(c):
            set_mapping(c, P01, "class", "E")

        def missing_case(c):
            toml_del(c.mapping, ("case", 5))

        def role(c):
            set_mapping(c, P01, "role", "diagnostic")

        def phase(c):
            set_mapping(c, P01, "phase", "workspace")

        def case_order(c):
            def swap(data):
                data["case"][0], data["case"][1] = data["case"][1], data["case"][0]
            F.toml_edit(c.mapping, swap)

        def duplicate_case(c):
            toml_append(c.mapping, ("case",), dict(toml_load(c.mapping)["case"][0]))

        def unapproved_deviation(c):
            set_mapping(c, P02, "deviation", "synthetic semantic change")

        self.table([
            ("class B without approval", class_b_unapproved, "MAPPING", [("MAPPING", "mapping:approval")]),
            ("class C without a separate mapping", class_c_without_separate_mapping, "MAPPING"),
            ("class other than A, B, C and D", invalid_class, "MAPPING"),
            ("case missing from the mapping", missing_case, "MAPPING"),
            ("role of a primary case", role, "MAPPING", [("MAPPING", "mapping:role")]),
            ("phase against the catalog", phase, "MAPPING"),
            ("cases not in the declared order", case_order, "MAPPING"),
            ("case listed twice", duplicate_case, "MAPPING"),
            ("deviation without approval", unapproved_deviation, "MAPPING"),
        ])

    def test_schema_refused(self):
        def catalog_header(c):
            tsv_rename_column(c.record("a", J13, 2, "catalog"), "issue", "note")

        def metadata_key_missing(c):
            c.del_meta("a", "cpu", jkeys=[J13], reps=[2])

        def metadata_key_extra(c):
            c.set_meta("b", "unknown_key", 1)

        def metadata_start_and_final_disagree(c):
            c.write_process("b", J13, 3, final_meta={"job_id": "another"})

        def declared_schema_version(c):
            toml_set(c.declared, ("schema",), 2)

        def declared_unknown_key(c):
            toml_set(c.declared, ("proximalsolvers", "c_commit"), "0" * 40)

        def receipt_unknown_event(c):
            jsonl_append(c.receipt, {"event": "note", "text": "synthetic"})

        def receipt_line_is_not_an_object(c):
            with c.receipt.open("a", encoding="utf-8") as stream:
                stream.write("[1, 2]\n")

        def receipt_missing_key(c):
            jsonl_edit(c.receipt, process_event("A", "AB", V13, 3), lambda e: e.pop("installation"))

        def receipt_bool_exit(c):
            jsonl_edit(c.receipt, process_event("A", "AB", V13, 3), lambda e: e.update(exit=False))

        def receipt_without_campaign(c):
            jsonl_drop(c.receipt, lambda e: e["event"] == "campaign")

        def fingerprint_value(c):
            set_fingerprint(c, "b", J13, P05, 3, "fixture", "X", "xyz")

        def fingerprint_none_for_fixture(c):
            set_fingerprint(c, "b", J13, P05, 3, "fixture", "X", "none")

        def fingerprint_unknown_kind(c):
            tsv_append(c.fingerprints("a"), [V13, P05, 3, "other", "X", "a" * 64])

        def fingerprint_undeclared_stratum(c):
            tsv_append(c.fingerprints("b"), ["1.11.0", P05, 3, "config", "solver", "a" * 64])

        def fingerprint_header(c):
            tsv_rename_column(c.fingerprints("a"), "kind", "type")

        def mapping_without_approved(c):
            toml_del(c.mapping, ("case", 0, "approved"))

        def manifest_unparseable(c):
            F.write_file(c.stratum("b", J13) / "Manifest.toml", "this is [not toml\n")

        def identity_schema(c):
            edit_identity(c, "b", ("schema",), 2)

        self.table([
            ("catalog header", catalog_header, "SCHEMA"),
            ("metadata key missing", metadata_key_missing, "SCHEMA"),
            ("metadata key not allowed", metadata_key_extra, "SCHEMA"),
            ("start and final metadata disagree", metadata_start_and_final_disagree, "SCHEMA"),
            ("declared-differences schema version", declared_schema_version, "SCHEMA", [("SCHEMA", "declared:schema")]),
            ("declared-differences unknown key", declared_unknown_key, "SCHEMA"),
            ("unknown receipt event", receipt_unknown_event, "SCHEMA", [("SCHEMA", "receipt:schema")]),
            ("receipt line that is not an object", receipt_line_is_not_an_object, "SCHEMA"),
            ("receipt process without a key", receipt_missing_key, "SCHEMA"),
            ("receipt exit that is a boolean", receipt_bool_exit, "SCHEMA"),
            ("receipt without a campaign event", receipt_without_campaign, "SCHEMA"),
            ("bad fingerprint value", fingerprint_value, "SCHEMA", [("SCHEMA", "fingerprints_b:schema")]),
            ("none for a fixture fingerprint", fingerprint_none_for_fixture, "SCHEMA"),
            ("unknown fingerprint kind", fingerprint_unknown_kind, "SCHEMA"),
            ("fingerprint row of an undeclared stratum", fingerprint_undeclared_stratum, "SCHEMA"),
            ("fingerprint header", fingerprint_header, "SCHEMA"),
            ("mapping row without approved", mapping_without_approved, "SCHEMA"),
            ("Manifest.toml that is not parseable", manifest_unparseable, "SCHEMA"),
            ("stack-identity schema version", identity_schema, "SCHEMA"),
        ])

    def test_undeclared_refused(self):
        def manifest_difference_not_declared(c):
            path = c.stratum("b", J13) / "Manifest.toml"
            toml_set(path, ("deps", "StatsBase", 0, "version"), "9.9.9")

        def declared_entry_absent(c):
            toml_append(c.declared, ("manifest",), dict(
                name="StatsBase", uuid=c.stack("a")["deps"]["StatsBase"]["uuid"], kind="changed",
                a_version="1.9.0", b_version="1.10.0", a_tree=c.stack("a")["deps"]["StatsBase"]["tree"],
                b_tree=F.sha1_text("tree", "StatsBase", "1.10.0"), reason="synthetic"))

        def harness_declaration_dropped(c):
            toml_del(c.declared, ("harness",))

        def harness_change_without_approval(c):
            set_mapping(c, P14, "approved", False)

        def harness_declared_with_equal_hashes(c):
            c.set_meta("b", "harness_hash", c.stack("a")["harness"])

        def compat_not_declared(c):
            toml_set(c.stratum("b", J10) / "Project.toml", ("compat", "ProximalBase"), "0.7")

        def compat_declaration_dropped(c):
            toml_del(c.declared, ("compat", 0))

        def proximalsolvers_not_declared(c):
            toml_del(c.declared, ("proximalsolvers",))

        def proximalsolvers_declared_value_wrong(c):
            toml_set(c.declared, ("proximalsolvers", "b_commit"), "1" * 40)

        self.table([
            ("Manifest difference not declared", manifest_difference_not_declared, "UNDECLARED",
             [("UNDECLARED", "declared:manifest")]),
            ("Manifest entry declared and absent", declared_entry_absent, "UNDECLARED"),
            ("harness change without a declaration", harness_declaration_dropped, "UNDECLARED"),
            ("harness change without approval", harness_change_without_approval, "UNDECLARED"),
            ("harness declared with equal hashes", harness_declared_with_equal_hashes, "UNDECLARED",
             [("UNDECLARED", "declared:harness")]),
            ("compat change not declared", compat_not_declared, "UNDECLARED"),
            ("compat declaration dropped", compat_declaration_dropped, "UNDECLARED"),
            ("ProximalSolvers change not declared", proximalsolvers_not_declared, "UNDECLARED",
             [("UNDECLARED", "declared:proximalsolvers")]),
            ("ProximalSolvers declared value wrong", proximalsolvers_declared_value_wrong, "UNDECLARED"),
        ])
        c = self.fresh()
        harness_declaration_dropped(c)
        result = self.refused(c.run(), "UNDECLARED")
        self.assertTrue(any(r["field"] in ("declared:harness", "ab:harness_hash") for r in result.refusals))
        c = self.fresh("manifest")
        toml_del(c.declared, ("manifest", 1))
        self.refused(c.run(), "UNDECLARED", fields=[("UNDECLARED", "declared:manifest")])

    def test_declared_package_tables_must_match_the_observed_differences(self):
        def package_table(c, key):
            a, b = c.stack("a")[key], c.stack("a")[key]
            table = dict(a_commit=a["commit"], b_commit=b["commit"], a_tree=a["tree"], b_tree=b["tree"],
                         a_package_hash=a["hash"], b_package_hash=b["hash"])
            if key == "pb":
                table.update(a_version=a["version"], b_version=b["version"])
            return table

        def equal_inside_table(c):
            toml_set(c.declared, ("proximalsolvers", "b_tree"), toml_load(c.declared)["proximalsolvers"]["a_tree"])

        self.table([
            ("[proximalsolvers] deleted from the migration pair", lambda c: toml_del(c.declared, ("proximalsolvers",)),
             "UNDECLARED", [("UNDECLARED", "declared:proximalsolvers")]),
            ("[proximalbase] deleted from the migration pair", lambda c: toml_del(c.declared, ("proximalbase",)),
             "UNDECLARED", [("UNDECLARED", "declared:proximalbase")]),
            ("a_tree equal to b_tree inside a present table", equal_inside_table, "UNDECLARED",
             [("UNDECLARED", "declared:proximalsolvers")]),
        ])
        for key, table in (("ps", "proximalsolvers"), ("pb", "proximalbase")):
            with self.subTest(f"[{table}] present while the observed values are equal"):
                c = self.fresh("identical")
                toml_set(c.declared, (table,), package_table(c, key))
                self.refused(c.run(), "UNDECLARED", fields=[("UNDECLARED", f"declared:{table}")])

    def test_unrelated_refusal_classes_do_not_hide_each_other(self):
        def threads(c):
            c.set_meta("b", "julia_threads", 2, jkeys=[J13])

        def hash_changed(c):
            c.write_process("b", J13, 3, data_hash={P05: "f" * 64})

        def settings(c):
            c.set_meta("b", "samples_target", 50, jkeys=[J13])

        def unfinished(c):
            c.write_process("b", J13, 5, final_meta={"finished": False})

        def blas(c):
            c.set_meta("b", "blas", "LBTConfig([LP64] libmkl_rt.so)", jkeys=[J13])

        def fixture(c):
            set_fingerprint(c, "b", J13, P05, 3, "fixture", "X", "e" * 64)

        def target_and_suite(c):
            c.write_records("b", [J13], catalog={P01: {"target": 1e-07}, P02: {"suite": "extended"}})

        rows = [
            ("julia_threads and data_hash in one stratum", (hash_changed, threads), ("THREADS", "INPUTS")),
            ("series setting and data_hash in one stratum", (hash_changed, settings), ("SETTINGS", "INPUTS")),
            ("unfinished process and data_hash in one stratum", (hash_changed, unfinished), ("STACK", "INPUTS")),
            ("blas and a fixture mismatch", (fixture, blas), ("THREADS", "INPUTS")),
            ("threads, target and catalog suite", (target_and_suite, threads), ("THREADS", "TARGET", "OPERATION")),
        ]
        for name, mutations, classes in rows:
            with self.subTest(name):
                c = self.fresh()
                for mutate in mutations:
                    mutate(c)
                self.refused(c.run(), *classes)

    def test_mixed_root_lists_stack_and_undeclared(self):
        c = self.c
        c.set_meta("b", "proximalbase_hash", F.sha1_text("another"), jkeys=[J13], reps=[3])
        result = self.refused(c.run(), "STACK", "UNDECLARED", fields=[("STACK", "b:mixed")])
        self.assertIn("UNDECLARED", result.classes)

    def test_settings_refused(self):
        def with_value(key, value):
            return lambda c: c.set_meta("b", key, value)

        def one_process(c):
            c.set_meta("b", "samples_target", 99, jkeys=[J13], reps=[4])

        def suite_in_schedule(c):
            toml_set(c.schedule, ("settings", "suite"), "quick")

        self.table([
            ("samples_target", with_value("samples_target", 50), "SETTINGS", [("SETTINGS", "b:samples_target")]),
            ("seconds_limit", with_value("seconds_limit", 2.0), "SETTINGS"),
            ("groups", with_value("groups", "cd,paths"), "SETTINGS"),
            ("case_filter", with_value("case_filter", "cd/lasso-dense/cd/B/call"), "SETTINGS"),
            ("setting changed in one process only", one_process, "SETTINGS", [("SETTINGS", "b:records")]),
            ("suite of the schedule copy", suite_in_schedule, "SETTINGS"),
        ])

    def test_stack_refused(self):
        def dirty(c):
            c.set_meta("b", "proximalsolvers_dirty", True)

        def loaded_tree_in_inventory(c):
            toml_set(c.stratum("b", J13) / "environment-inventory.toml", ("proximalbase_loaded_tree",), "5" * 40)

        def mixed_stack(c):
            c.set_meta("b", "proximalsolvers_sha", "7" * 40, jkeys=[J10], reps=[3])

        def unfinished_record(c):
            c.write_process("b", J13, 5, final_meta={"finished": False})

        def interrupted_record(c):
            c.record("b", J10, 2, "metadata").unlink()

        def receipt_incomplete(c):
            jsonl_edit(c.receipt, process_event("B", "AB", V13, 3), lambda e: e.update(complete=False))

        def receipt_exit_one(c):
            jsonl_edit(c.receipt, process_event("B", "AB", V13, 3), lambda e: e.update(exit=1))

        def receipt_exit_zero_with_failed_case(c):
            c.set_status("b", J13, P05, "target_missed", reps=[3], receipt=False)

        def receipt_exit_two_without_failed_case(c):
            jsonl_edit(c.receipt, process_event("A", "AB", V10, 4), lambda e: e.update(exit=2))

        self.table([
            ("solver checkout is dirty", dirty, "STACK", [("STACK", "b:dirty")]),
            ("loaded tree of the inventory", loaded_tree_in_inventory, "STACK"),
            ("mixed stack inside one root", mixed_stack, "STACK", [("STACK", "b:mixed")]),
            ("unfinished record", unfinished_record, "STACK"),
            ("interrupted process", interrupted_record, "STACK"),
            ("receipt process not complete", receipt_incomplete, "STACK", [("STACK", "receipt:process")]),
            ("receipt exit status 1", receipt_exit_one, "STACK"),
            ("receipt exit 0 with a non-ok case in the record", receipt_exit_zero_with_failed_case, "STACK"),
            ("receipt exit 2 with every case ok", receipt_exit_two_without_failed_case, "STACK"),
        ])

    def test_identity_refused_and_the_historical_tag_commit_accepted(self):
        def short_sha(c):
            edit_identity(c, "b", ("proximalsolvers", "commit"), "b0de3f7")

        def branch_name(c):
            edit_identity(c, "b", ("proximalbase", "commit"), "master")

        def tree_missing(c):
            edit_identity(c, "b", ("proximalbase", "tree"), delete=True)

        def tag_only_identity(c):
            edit_identity(c, "b", ("proximalbase", "tag"), "v0.6.0")
            edit_identity(c, "b", ("proximalbase", "commit"), delete=True)
            edit_identity(c, "b", ("proximalbase", "tree"), delete=True)

        def registered_without_tag(c):
            edit_identity(c, "b", ("proximalbase", "release"), "registered")

        def identity_file_missing(c):
            (c.root("b") / "stack-identity.toml").unlink()

        def stack_a_proximalbase(c):
            edit_identity(c, "a", ("proximalbase", "commit"), "4" * 40)

        self.table([
            ("short SHA", short_sha, "IDENTITY"),
            ("branch name", branch_name, "IDENTITY", [("IDENTITY", "b:identity")]),
            ("ProximalBase tree missing", tree_missing, "IDENTITY"),
            ("tag-only identity", tag_only_identity, "IDENTITY"),
            ("registered release without a tag", registered_without_tag, "IDENTITY"),
            ("stack-identity.toml missing", identity_file_missing, "IDENTITY"),
            ("Stack A with another ProximalBase commit", stack_a_proximalbase, "IDENTITY", [("IDENTITY", "a:stack_a")]),
        ])
        c = self.fresh(aa=True)
        edit_identity(c, "aa_a", ("proximalbase", "commit"), "4" * 40)
        self.refused(c.run(aa=True), "IDENTITY", fields=[("IDENTITY", "aa_a:stack_a")])
        c = self.fresh()
        identity = toml_load(c.root("a") / "stack-identity.toml")["proximalbase"]
        self.assertEqual((identity["commit"], identity["tree"]), (
            "9c5a43bf0b7e3f51f0a401b785c332200ffa5d7e", "1226119eb2cc6144f7345c727f0e7682632f7826"))
        self.accepted(c.run())

    def test_order_refused(self):
        def swapped(rep, arm="AB", jkey=J13):
            return lambda c: swap_block(c, arm, jkey, rep)

        def block_missing(c):
            jsonl_drop(c.receipt, process_event(None, "AB", V13, 3))

        def overlapping(c):
            events = jsonl_read(c.receipt)
            first, second = [e for e in events if process_event(None, "AB", V10, 4)(e)]
            second["start_utc"] = first["start_utc"]
            second["end_utc"] = first["end_utc"]
            jsonl_write(c.receipt, events)

        def blocks_out_of_time_order(c):
            events = jsonl_read(c.receipt)
            for e in events:
                if process_event(None, "AB", V13, 5)(e):
                    e["start_utc"] = e["start_utc"].replace("T09", "T07")
                    e["end_utc"] = e["end_utc"].replace("T09", "T07")
            jsonl_write(c.receipt, events)

        def campaign_id(c):
            jsonl_edit(c.receipt, lambda e: e["event"] == "campaign", lambda e: e.update(campaign_id="another"))

        def stack_a_from_another_session(c):
            jsonl_edit(c.receipt, process_event("A", "AB"), lambda e: e.update(installation="inst-elsewhere"))

        def elapsed_longer_than_process(c):
            c.write_process("b", J13, 3, elapsed_s=500.0)

        def schedule_order_changed(c):
            toml_set(c.schedule, ("schedule", "orders", "3"), "AB")

        self.table([
            ("block 1 (AB) run in the other order", swapped(1), "ORDER", [("ORDER", "receipt:block")]),
            ("block 2 (BA) run in the other order", swapped(2), "ORDER"),
            ("A/A block run in the other order", swapped(2, "AA", J10), "ORDER"),
            ("block missing from the receipt", block_missing, "ORDER", [("ORDER", "receipt:missing")]),
            ("overlapping processes", overlapping, "ORDER", [("ORDER", "receipt:block")]),
            ("blocks not in increasing time order", blocks_out_of_time_order, "ORDER"),
            ("campaign_id differs from the schedule", campaign_id, "ORDER", [("ORDER", "receipt:campaign")]),
            ("Stack A root from another session", stack_a_from_another_session, "ORDER",
             [("ORDER", "receipt:installation")]),
            ("elapsed_s longer than the receipt process", elapsed_longer_than_process, "ORDER"),
            ("order of the schedule copy changed, receipt unchanged", schedule_order_changed, "ORDER"),
        ], aa=True)
        # a block run B then A in an A-then-B slot, and the reverse, for each of the eight repetition IDs
        c = self.fresh()
        for rep in range(1, 9):
            swapped(rep)(c)
        result = self.refused(c.run(), "ORDER")
        details = [i["detail"] for i in result.refusals if i["field"] == "receipt:block"]
        for rep in range(1, 9):
            self.assertTrue(any(re.search(rf"rep ?{rep}\b", detail) for detail in details), f"repetition {rep}")

    def test_order_aa_installations(self):
        c = self.fresh(aa=True)
        a, b = c.stack("aa_a"), c.stack("aa_b")
        b.update(installation=a["installation"], checkout=a["checkout"], depot=a["depot"])
        c.rebuild_root("aa_b")
        c.write_receipt()
        result = self.refused(c.run(aa=True), "ORDER", fields=[("ORDER", "aa:installation")])
        self.assertNotIn("aa:identity", result.fields("ORDER"))
        c = self.fresh(aa=True)
        c.stack("aa_b")["pb"] = dict(c.stack("aa_b")["pb"], commit=F.sha1_text("other"))
        c.rebuild_root("aa_b")
        self.refused(c.run(aa=True), "ORDER", fields=[("ORDER", "aa:identity")])
        c = self.fresh(aa=True)
        toml_set(c.stratum("aa_b", J10) / "Manifest.toml", ("deps", "StatsBase", 0, "version"), "9.9.9")
        self.refused(c.run(aa=True), "ORDER", fields=[("ORDER", "aa:identity")])

    def test_every_refusal_is_listed_when_several_defects_coincide(self):
        # the defects sit in different strata or files, so none of them hides another
        c = self.c
        c.write_process("b", J13, 3, data_hash={P05: "f" * 64})
        c.set_meta("b", "julia_threads", 2, jkeys=[J10])
        jsonl_edit(c.receipt, process_event("B", "AB", V13, 6), lambda e: e["machine"].update(logical_cpu=5))
        set_mapping(c, P01, "role", "diagnostic")
        c.set_meta("a", "proximalsolvers_dirty", True)
        jsonl_edit(c.receipt, process_event("A", "AB", V13, 3), lambda e: e.update(installation="inst-elsewhere"))
        result = self.refused(c.run(), "INPUTS", "THREADS", "MACHINE", "MAPPING", "STACK", "ORDER")
        self.assertGreaterEqual(result.refusals_document["count"], 6)


# --------------------------------------------------------------------------------------------------------------
# 3. Per-case classification
# --------------------------------------------------------------------------------------------------------------

class ClassificationTests(MigrationCase):

    def assert_empty_numbers(self, row):
        for column in UNFILLED:
            self.assertEqual(row[column], "", f"{row['id']} {column}")
        for column in FILLED:
            self.assertNotEqual(row[column], "", f"{row['id']} {column}")

    def only_class(self, result, version, case_id, expected):
        """Exactly one row changes class: `case_id` in the stratum of `version`."""
        for row in result.rows:
            changed = row["id"] == case_id and row["julia"] == version
            self.assertEqual(row["class"], expected if changed else "COMPARABLE", (row["julia"], row["id"]))

    def test_comparable_case_reports_ratios_and_accuracy(self):
        c = self.c
        row = self.accepted(c.run()).row(P01, J13)
        a = [c.median("a", J13, P01, rep) for rep in c.reps]
        b = [c.median("b", J13, P01, rep) for rep in c.reps]
        ratios = [y / x for x, y in zip(a, b)]
        self.assertEqual((row["class"], row["reason"], row["role"], row["phase"]), ("COMPARABLE", "", "primary", "call"))
        self.assertEqual(row["repetitions"], "1;2;3;4;5;6;7;8")
        self.assertEqual(floats(row["a_ns"]), a)
        self.assertEqual(floats(row["b_ns"]), b)
        self.assertEqual(floats(row["ratio"]), ratios)
        self.assertEqual(floats(row["abs_diff_ns"]), [y - x for x, y in zip(a, b)])
        self.assertAlmostEqual(float(row["geomean_ratio"]), math.exp(sum(map(math.log, ratios)) / 8), places=12)
        self.assertEqual((float(row["ratio_min"]), float(row["ratio_max"])), (min(ratios), max(ratios)))
        self.assertEqual((row["measure"], float(row["target"]), row["mapping_class"]), ("relative_gap", 1e-08, "A"))
        self.assertEqual(floats(row["a_value"]), [0.5e-08] * 8)
        self.assertEqual(floats(row["a_accuracy_fraction"]), [0.5] * 8)
        self.assertEqual(row["a_accuracy_band"], ";".join(["margin"] * 8))
        self.assertEqual(floats(row["a_median_bytes"]), [4096.0] * 8)
        self.assertEqual(row["hardware"], "controlled")
        self.assertEqual(row["screen"], "screen not evaluated")

    def test_class_b_without_approval_is_the_mapping_refusal(self):
        c = self.c
        set_mapping(c, P14, "approved", False)
        self.refused(c.run(), "MAPPING")

    def test_changed_reset_fingerprint_with_equal_data_hash_is_not_comparable(self):
        for name, mutate in (
            ("reset/values hash", lambda c: set_fingerprint(c, "b", J13, P05, 3, "reset", "values", "a" * 64)),
            ("reset/active_ids hash", lambda c: set_fingerprint(c, "b", J13, P05, 3, "reset", "active_ids", "b" * 64)),
            ("hash against none", lambda c: set_fingerprint(c, "b", J13, P05, 3, "reset", "active_ids", "none")),
        ):
            with self.subTest(name):
                c = self.fresh()
                mutate(c)
                result = c.run()
                self.assertEqual(result.code, 1, result.stderr)
                self.only_class(result, V13, P05, "NOT COMPARABLE")
                row = result.row(P05, J13)
                self.assertIn("fingerprint mismatch", row["reason"])
                self.assertIn("rep 3", row["reason"])
                self.assert_empty_numbers(row)
                self.assertEqual(result.row(P05, J10)["class"], "COMPARABLE", "the other stratum is not affected")
                self.assertEqual([i["id"] for i in result.lists["not_comparable"]], [P05])

    def test_changed_config_fingerprint_is_not_comparable(self):
        for name in ("solver", "options"):
            with self.subTest(name):
                c = self.fresh()
                set_fingerprint(c, "b", J10, P09, 5, "config", name, "c" * 64)
                result = c.run()
                self.assertEqual(result.code, 1, result.stderr)
                self.only_class(result, V10, P09, "NOT COMPARABLE")
                row = result.row(P09, J10)
                self.assertIn(f"fingerprint mismatch: config/{name} rep 5", row["reason"])
                self.assert_empty_numbers(row)

    def test_missing_fingerprint_row_is_not_comparable(self):
        rows = (
            ("reset/values of B", "b", "reset", "values", "fingerprint row missing: reset/values B rep 3"),
            ("config/options of B", "b", "config", "options", "fingerprint row missing: config/options B rep 3"),
            ("file/certificates.jl of B", "b", "file", "certificates.jl",
             "fingerprint row missing: file/certificates.jl B rep 3"),
        )
        for name, label, kind, key, reason in rows:
            with self.subTest(name):
                c = self.fresh()
                drop_fingerprint(c, label, J13, P07, 3, kind, key)
                result = c.run()
                self.assertEqual(result.code, 1, result.stderr)
                self.only_class(result, V13, P07, "NOT COMPARABLE")
                row = result.row(P07, J13)
                self.assertIn(reason, row["reason"])
                self.assert_empty_numbers(row)
        with self.subTest("every fixture row of one repetition in B"):
            c = self.fresh()
            drop_fingerprint(c, "b", J13, P01, 3, "fixture")
            result = c.run()
            self.assertEqual(result.code, 1, result.stderr)
            self.only_class(result, V13, P01, "NOT COMPARABLE")

    def test_missing_fingerprint_file_is_not_comparable_not_a_refusal(self):
        c = self.c
        c.fingerprints("b").unlink()
        result = c.run()
        self.assertEqual(result.code, 1, result.stderr)
        self.assertEqual({row["class"] for row in result.rows}, {"NOT COMPARABLE"})
        self.assertTrue(all("fingerprint file missing: B" in row["reason"] for row in result.rows))
        for row in result.rows:
            self.assert_empty_numbers(row)
        missing = result.lists["missing_diagnostics"]
        self.assertIn(("fingerprints", "B"), [(item["what"], item.get("root")) for item in missing])
        self.assertEqual(len(result.lists["not_comparable"]), 38)
        c = self.fresh()
        result = c.run(fingerprints_a=c.work / "does-not-exist.tsv")
        self.assertEqual(result.code, 1, result.stderr)
        self.assertTrue(all("fingerprint file missing: A" in row["reason"] for row in result.rows))

    def test_target_missed_in_b_is_failed_with_no_ratio(self):
        c = self.c
        c.set_status("b", J13, P05, "target_missed", reps=[3])
        result = c.run()
        self.assertEqual(result.code, 1, "a case with exit 2 in the receipt and a non-ok record is FAILED, not refused")
        self.assertEqual(result.files, ["lists.json", "migration-comparison.csv", "report.md"])
        self.only_class(result, V13, P05, "FAILED")
        row = result.row(P05, J13)
        self.assertIn("status: B rep3 target_missed", row["reason"])
        self.assert_empty_numbers(row)
        self.assertEqual([(i["julia"], i["id"]) for i in result.lists["failed"]], [(V13, P05)])
        item = next(i for i in result.lists["not_ok"] if i["id"] == P05)
        self.assertEqual((item["julia"], item["rep"], item["root"], item["status"]), (V13, 3, "B", "target_missed"))
        self.assertIn(P05, result.report)

    def test_failure_in_a_is_reported_for_root_a(self):
        c = self.c
        c.set_status("a", J10, P02, "target_missed", reps=[2])
        result = c.run()
        self.assertEqual(result.code, 1, result.stderr)
        self.only_class(result, V10, P02, "FAILED")
        self.assertIn("status: A rep2 target_missed", result.row(P02, J10)["reason"])

    def test_incomplete_path_is_failed(self):
        c = self.c
        c.set_status("b", J10, P14, "incomplete", reps=[6])
        result = c.run()
        self.assertEqual(result.code, 1, result.stderr)
        self.only_class(result, V10, P14, "FAILED")
        self.assertIn("status: B rep6 incomplete", result.row(P14, J10)["reason"])
        self.assertEqual([(i["id"], i["root"]) for i in result.lists["incomplete_paths"]], [(P14, "B")])
        self.assertEqual(result.lists["invalid_certificates"], [])

    def test_invalid_certificate_is_failed(self):
        c = self.c
        c.set_status("b", J13, P09, "uncertifiable", reps=[1])
        result = c.run()
        self.assertEqual(result.code, 1, result.stderr)
        self.only_class(result, V13, P09, "FAILED")
        self.assertIn("status: B rep1 uncertifiable", result.row(P09, J13)["reason"])
        item = result.lists["invalid_certificates"][0]
        self.assertEqual((item["id"], item["status"], item["accuracy_band"], item["accuracy_fraction"]),
                         (P09, "uncertifiable", "missed/invalid", None))
        self.assertEqual(result.lists["incomplete_paths"], [])

    def test_error_and_timeout_are_failed_and_listed(self):
        c = self.c
        c.set_status("b", J13, P01, "error", reps=[2])
        c.set_status("a", J10, P03, "timeout", reps=[4])
        result = c.run()
        self.assertEqual(result.code, 1, "an empty data_hash of an error row is not an INPUTS refusal")
        self.assertEqual(result.row(P01, J13)["class"], "FAILED")
        self.assertEqual(result.row(P03, J10)["class"], "FAILED")
        listed = {(i["id"], i["status"], i["root"]) for i in result.lists["errors_and_timeouts"]}
        self.assertEqual(listed, {(P01, "error", "B"), (P03, "timeout", "A")})
        detail = next(i for i in result.lists["errors_and_timeouts"] if i["status"] == "error")["detail"]
        self.assertEqual(detail, F.ERROR_TEXT["error"])

    def test_non_positive_median_is_failed(self):
        c = self.c
        record = c.record("b", J13, 3, "samples")
        header, rows = tsv_read(record)
        for row in rows:
            if row[0] == P02:
                row[3] = row[4] = "0"
        tsv_write(record, header, rows)
        for key in ("median_ns", "mean_ns", "sd_ns", "min_ns", "max_ns", "p95_ns"):
            tsv_edit(c.record("b", J13, 3, "metrics"), {"id": P02}, key, "0")
        tsv_edit(c.record("b", J13, 3, "metrics"), {"id": P02}, "gc_share", "0.0")
        result = c.run()
        self.assertEqual(result.code, 1, result.stderr)
        self.only_class(result, V13, P02, "FAILED")
        self.assertIn("median_ns: B rep3 0", result.row(P02, J13)["reason"])

    def test_failed_precedes_not_comparable(self):
        c = self.c
        c.set_status("b", J13, P05, "target_missed", reps=[3])
        set_fingerprint(c, "b", J13, P05, 5, "config", "options", "c" * 64)
        result = c.run()
        row = result.row(P05, J13)
        self.assertEqual(row["class"], "FAILED")
        self.assertNotIn("fingerprint", row["reason"])

    def test_no_ratio_for_failed_or_not_comparable_rows_and_exit_one(self):
        c = self.c
        c.set_status("b", J13, P05, "target_missed", reps=[3])
        set_fingerprint(c, "a", J10, P09, 2, "reset", "values", "d" * 64)
        result = c.run()
        self.assertEqual(result.code, 1)
        classes = {(row["julia"], row["id"]): row["class"] for row in result.rows}
        self.assertEqual({k: v for k, v in classes.items() if v != "COMPARABLE"},
                         {(V13, P05): "FAILED", (V10, P09): "NOT COMPARABLE"})
        for row in result.rows:
            if row["class"] == "COMPARABLE":
                self.assertNotEqual(row["ratio"], "")
            else:
                self.assert_empty_numbers(row)
        self.assertEqual(result.row(P05, J13)["mapping_class"], "A")

    def test_class_c_with_a_separate_approved_mapping_is_not_comparable(self):
        c = self.c
        set_mapping(c, P01, "class", "C")
        set_mapping(c, P01, "approved", True)
        set_mapping(c, P01, "approval_url", "https://example.org/approval")
        set_mapping(c, P01, "separate_mapping", "synthetic separate mapping")
        result = c.run()
        self.assertEqual(result.code, 1, result.stderr)
        for version in (V10, V13):
            row = next(r for r in result.rows if r["id"] == P01 and r["julia"] == version)
            self.assertEqual(row["class"], "NOT COMPARABLE")
            self.assertIn("mapping class C", row["reason"])
            self.assertEqual(row["mapping_class"], "C")
            self.assert_empty_numbers(row)
        items = [i for i in result.lists["semantic_deviations"] if i["id"] == P01]
        self.assertEqual(len(items), 2, "one per case and stratum")
        self.assertEqual(items[0]["class"], "C")
        self.assertEqual(items[0]["approval_url"], "https://example.org/approval")

    def test_approved_semantic_deviation_is_not_comparable(self):
        c = self.c
        set_mapping(c, P02, "deviation", "synthetic change of the reset")
        set_mapping(c, P02, "approved", True)
        set_mapping(c, P02, "approval_url", "https://example.org/approval")
        result = c.run()
        self.assertEqual(result.code, 1, result.stderr)
        row = result.row(P02, J13)
        self.assertEqual(row["class"], "NOT COMPARABLE")
        self.assertIn("semantic deviation: synthetic change of the reset", row["reason"])
        texts = [i["text"] for i in result.lists["semantic_deviations"] if i["id"] == P02]
        self.assertEqual(texts, ["synthetic change of the reset"] * 2)

    def test_hardware_policy_other_than_the_schedule_is_labelled_observational(self):
        c = self.c
        jsonl_edit(c.receipt, lambda e: e["event"] == "process", lambda e: e["machine"].update(governor="performance"))
        result = c.run()
        self.assertEqual(result.code, 0, result.stderr)
        label = "observational: governor=performance, epp=balance_performance, no_turbo=0, smt_control=on"
        self.assertEqual({row["hardware"] for row in result.rows}, {label})
        self.assertIn("observational", result.report[:1500])

    def test_allocation_differences_are_listed_apart_from_timing(self):
        c = self.c
        c.write_process("b", J13, 3, bytes={P01: 8192}, max_bytes={P03: 512})
        result = c.run()
        self.assertEqual(result.code, 0, result.stderr)
        listed = {(i["julia"], i["id"], i["rep"]) for i in result.lists["allocation_differences"]}
        self.assertEqual(listed, {(V13, P01, 3), (V13, P03, 3)})
        item = next(i for i in result.lists["allocation_differences"] if i["id"] == P01)
        self.assertEqual((item["a_median_bytes"], item["b_median_bytes"]), (4096, 8192))
        item = next(i for i in result.lists["allocation_differences"] if i["id"] == P03)
        self.assertEqual((item["a_max_bytes"], item["b_max_bytes"]), (0, 512))
        self.assertEqual(floats(result.row(P01, J13)["b_median_bytes"])[2], 8192.0)

    def test_lists_json_has_the_nine_keys_in_order_even_when_empty(self):
        result = self.accepted(self.c.run())
        self.assertEqual(list(result.lists), list(F.LISTS_KEYS))
        self.assertTrue(all(value == [] for key, value in result.lists.items() if key != "missing_diagnostics"))
        self.assertEqual({i["what"] for i in result.lists["missing_diagnostics"]}, {"aa"})
        self.assertEqual(len(result.lists["missing_diagnostics"]), 2, "one item per stratum without --aa")

    def test_not_ok_list_covers_aa_roots_with_their_root_names(self):
        c = self.fresh(aa=True)
        c.set_status("aa_b", J13, P07, "target_missed", reps=[5])
        result = c.run(aa=True)
        items = [i for i in result.lists["not_ok"] if i["id"] == P07]
        self.assertEqual([(i["root"], i["rep"], i["status"]) for i in items], [("AA_B", 5, "target_missed")])
        self.assertEqual(items[0]["accuracy_band"], "missed/invalid")
        self.assertEqual(result.row(P07, J13)["screen"], "screen not evaluated")
        self.assertEqual(result.row(P07, J13)["class"], "COMPARABLE")
        diagnostics = result.lists["missing_diagnostics"]
        self.assertTrue(any(i["what"] == "aa" and i.get("id") == P07 and i.get("rep") == 5 for i in diagnostics))

    def test_class_of_every_row_is_one_of_the_three_names(self):
        c = self.c
        c.set_status("b", J13, P05, "target_missed", reps=[3])
        result = c.run()
        self.assertTrue({row["class"] for row in result.rows} <= {"COMPARABLE", "NOT COMPARABLE", "FAILED"})

    def test_equal_data_hash_is_never_accepted_as_proof_of_identical_semantics(self):
        c = self.c
        for rep in c.reps:
            set_fingerprint(c, "b", J10, P13, rep, "config", "options", "e" * 64)
        result = c.run()
        self.assertEqual(result.code, 1, result.stderr)
        self.only_class(result, V10, P13, "NOT COMPARABLE")
        reason = result.row(P13, J10)["reason"]
        self.assertIn("fingerprint mismatch: config/options rep 1", reason)
        self.assertIn("fingerprint mismatch: config/options rep 8", reason)


# --------------------------------------------------------------------------------------------------------------
# 4. Output
# --------------------------------------------------------------------------------------------------------------

class OutputTests(MigrationCase):

    def screen_row(self, a, b, aa_a, aa_b, case_id=P01):
        c = self.fresh(aa=True)
        c.set_medians(case_id, J13, a=a, b=b, aa_a=aa_a, aa_b=aa_b)
        result = self.accepted(c.run(aa=True))
        return result.row(case_id, J13)

    def test_no_comparison_after_a_global_refusal(self):
        c = self.c
        c.write_process("b", J13, 3, data_hash={P05: "f" * 64})
        result = self.refused(c.run(), "INPUTS")
        self.assertEqual(result.code, 2)
        self.assertIsNone(result.rows)
        self.assertIsNone(result.report)
        self.assertIsNone(result.lists)

    def test_every_refusal_is_recorded_in_order_with_the_json_format(self):
        c = self.c
        c.write_process("b", J13, 3, data_hash={P05: "f" * 64})
        c.set_meta("b", "blas_threads", 2, jkeys=[J10])
        c.set_meta("b", "cpu_model", "Another CPU", jkeys=[J13])
        set_mapping(c, P14, "approved", False)
        c.set_meta("a", "samples_target", 50, jkeys=[J13])
        c.set_meta("a", "proximalsolvers_dirty", True, jkeys=[J10])
        result = self.refused(c.run(), "INPUTS", "THREADS", "MACHINE", "MAPPING", "SETTINGS", "STACK")
        text = (result.out / "refusals.json").read_text(encoding="utf-8")
        self.assertEqual(text, json.dumps(json.loads(text), indent=2) + "\n")
        self.assertEqual(list(json.loads(text)), ["schema", "count", "refusals"])
        self.assertTrue(all(set(item) == {"class", "field", "detail"} for item in result.refusals))
        keys = [(F.CLASS_ORDER.index(c_), f, d) for c_, f, d in result.lines]
        self.assertEqual(keys, sorted(keys))
        self.assertEqual(len({(i["class"], i["field"], i["detail"]) for i in result.refusals}), len(result.refusals))

    def test_exit_statuses_zero_one_two_and_three(self):
        c = self.c
        self.assertEqual(c.run().code, 0)
        c1 = self.fresh()
        c1.set_status("b", J13, P05, "target_missed", reps=[3])
        self.assertEqual(c1.run().code, 1)
        c2 = self.fresh()
        set_mapping(c2, P01, "role", "diagnostic")
        self.assertEqual(c2.run().code, 2)
        c3 = self.fresh()
        result = c3.run(mapping=c3.work / "absent.toml")
        self.assertEqual(result.code, 3)

    def test_non_empty_out_is_rejected_with_status_3_and_nothing_is_written(self):
        c = self.c
        out = c.work / "occupied"
        out.mkdir()
        (out / "keep.txt").write_text("existing", encoding="utf-8")
        before = (F.tree_snapshot(out), F.tree_snapshot(c.base))
        result = c.run(out=out)
        self.assertEqual(result.code, 3, result.stderr)
        self.assertEqual((F.tree_snapshot(out), F.tree_snapshot(c.base)), before)
        self.assertEqual(sorted(p.name for p in c.work.iterdir()), ["campaign", "occupied"])

    def test_empty_existing_out_directory_is_accepted(self):
        c = self.c
        out = c.work / "empty-out"
        out.mkdir()
        self.accepted(c.run(out=out))

    def test_unreadable_or_invalid_arguments_give_status_3_and_write_nothing(self):
        def invalid_toml(name):
            def mutate(c):
                getattr(c, name).write_text("this = [is not toml\n", encoding="utf-8")
            return mutate

        def binary_receipt(c):
            c.receipt.write_bytes(b"\xff\xfe\x00 not utf-8\n")

        def schedule_reps_not_consecutive(c):
            toml_set(c.schedule, ("schedule", "reps"), [1, 2, 4, 5, 6, 7, 8])

        def schedule_bad_order(c):
            toml_set(c.schedule, ("schedule", "orders", "2"), "XY")

        def schedule_missing_key(c):
            toml_del(c.schedule, ("machine", "logical_cpu"))

        def schedule_too_many_reps(c):
            toml_set(c.schedule, ("schedule", "reps"), list(range(1, 12)))

        rows = [("invalid TOML mapping", invalid_toml("mapping"), {}),
                ("invalid TOML declared differences", invalid_toml("declared"), {}),
                ("invalid TOML schedule", invalid_toml("schedule"), {}),
                ("receipt that is not UTF-8", binary_receipt, {}),
                ("schedule reps not consecutive", schedule_reps_not_consecutive, {}),
                ("schedule order other than AB or BA", schedule_bad_order, {}),
                ("schedule without a key", schedule_missing_key, {}),
                ("schedule with more than ten repetition IDs", schedule_too_many_reps, {})]
        for name, mutate, _ in rows:
            with self.subTest(name):
                c = self.fresh()
                mutate(c)
                result = c.run()
                self.assertEqual(result.code, 3, result.stderr)
                self.assertTrue(not result.out.exists() or not any(result.out.iterdir()), "nothing is written")
        c = self.fresh()
        for omitted in ("mapping", "declared", "receipt", "a", "b", "out"):
            with self.subTest(f"argument {omitted} absent"):
                result = c.run(omit=(omitted,))
                self.assertEqual(result.code, 3, result.stderr)
        for flag in ("mapping", "declared", "receipt", "schedule"):
            with self.subTest(f"{flag} file does not exist"):
                result = c.run(**{flag: c.work / "absent"})
                self.assertEqual(result.code, 3, result.stderr)
                self.assertFalse(result.out.exists() and any(result.out.iterdir()))

    def test_nothing_is_written_outside_out(self):
        for name, prepare, code in (
            ("accepted", lambda c: None, 0),
            ("refused", lambda c: set_mapping(c, P01, "role", "diagnostic"), 2),
            ("not comparable", lambda c: set_fingerprint(c, "b", J13, P05, 3, "config", "solver", "a" * 64), 1),
        ):
            with self.subTest(name):
                c = self.fresh()
                prepare(c)
                out = c.work / "the-output"
                before = (F.tree_snapshot(c.base), F.tree_snapshot(c.work))
                result = c.run(out=out)
                self.assertEqual(result.code, code, result.stderr)
                self.assertEqual(F.tree_snapshot(c.base), before[0], "the input tree is unchanged")
                outside = {k: v for k, v in F.tree_snapshot(c.work).items() if not k.startswith("the-output")}
                self.assertEqual(outside, before[1], "nothing outside --out is created or modified")
                self.assertEqual(sorted(p.name for p in c.work.iterdir()), ["campaign", "the-output"])

    def test_csv_columns_and_row_layout_follow_section_15(self):
        c = self.c
        result = self.accepted(c.run())
        raw = result.csv_text
        self.assertNotIn("\r", raw)
        self.assertEqual(raw.split("\n")[0], ",".join(F.CSV_COLUMNS))
        self.assertEqual(list(result.rows[0]), F.CSV_COLUMNS)
        self.assertEqual(len(result.rows), 38)
        self.assertEqual([(r["julia"], r["id"]) for r in result.rows],
                         [(V10, i) for i in c.case_ids] + [(V13, i) for i in c.case_ids])
        row = result.row(P01, J10)
        for column in ("repetitions", "a_ns", "b_ns", "ratio", "abs_diff_ns", "a_value", "b_value",
                       "a_accuracy_fraction", "b_accuracy_fraction", "a_accuracy_band", "b_accuracy_band",
                       "a_median_bytes", "b_median_bytes"):
            self.assertEqual(len(row[column].split(";")), 8, column)
        for column in ("geomean_ratio", "ratio_min", "ratio_max", "aa_ratio_min", "aa_ratio_max"):
            self.assertNotIn(";", row[column], column)
        self.assertEqual(row["target"], repr(1e-08))

    def test_report_starts_with_the_exact_disclaimer_and_names_the_campaign(self):
        result = self.accepted(self.c.run())
        lines = result.report.split("\n")
        self.assertEqual(lines[0], DISCLAIMER)
        self.assertEqual(lines[1], "")
        self.assertIn(SCREEN_SENTENCE, result.report)
        for text in ("pb06-migration-stage2b-v1", "stage2b-8block-v1", "session-0001", V10, V13,
                     "Historical Stage 2A reference (descriptive; not part of any ratio)"):
            self.assertIn(text, result.report)

    def test_julia_strata_are_not_pooled(self):
        c = self.c
        for rep in c.reps:
            c.write_process("a", J10, rep, median={P01: 1000})
            c.write_process("b", J10, rep, median={P01: 2000})
            c.write_process("a", J13, rep, median={P01: 3000})
            c.write_process("b", J13, rep, median={P01: 3000})
        result = self.accepted(c.run())
        self.assertAlmostEqual(float(result.row(P01, J10)["geomean_ratio"]), 2.0, places=12)
        self.assertAlmostEqual(float(result.row(P01, J13)["geomean_ratio"]), 1.0, places=12)
        self.assertEqual(len([r for r in result.rows if r["id"] == P01]), 2)
        for row in result.rows:
            self.assertIn(row["julia"], (V10, V13))
            self.assertEqual(len(row["ratio"].split(";")), 8)
        report = result.report
        self.assertIn(V10, report)
        self.assertIn(V13, report)
        self.assertLess(report.index(V10), report.index(V13), "strata in schedule order, side by side")

    def test_report_makes_no_significance_or_noninferiority_claim(self):
        c = self.fresh(aa=True)
        c.set_medians(P01, J13, a=[1000] * 8, b=[1100] * 8, aa_a=[1000] * 8, aa_b=[1000] * 8)
        c.set_status("b", J10, P05, "target_missed", reps=[3])
        for kwargs in ({}, {"aa": True}):
            with self.subTest(kwargs):
                result = c.run(**kwargs)
                self.assertIn(result.code, (0, 1))
                self.assertEqual(banned_outside_sentence(result.report), [])
                self.assertIn("screen", result.report)
                self.assertIn(SCREEN_SENTENCE, result.report)

    def test_screen_not_evaluated_without_aa(self):
        result = self.accepted(self.c.run())
        self.assertEqual({row["screen"] for row in result.rows}, {"screen not evaluated"})
        self.assertEqual({row["aa_ratio_min"] for row in result.rows} | {row["aa_ratio_max"] for row in result.rows},
                         {""})
        self.assertIn("screen not evaluated", result.report)
        self.assertEqual(len(result.lists["missing_diagnostics"]), 2)

    def test_screened_slowdown_from_aa_ratios_and_eight_blocks(self):
        row = self.screen_row(a=[1000] * 8, b=[1100] * 8, aa_a=[1000] * 8,
                              aa_b=[1000, 1010, 1020, 1030, 1040, 1050, 1000, 1000])
        self.assertEqual(row["screen"], "screened slowdown")
        self.assertAlmostEqual(float(row["aa_ratio_min"]), 1.0)
        self.assertAlmostEqual(float(row["aa_ratio_max"]), 1.05)
        self.assertGreater(float(row["geomean_ratio"]), float(row["aa_ratio_max"]))

    def test_screened_speedup_from_aa_ratios_and_eight_blocks(self):
        row = self.screen_row(a=[1000] * 8, b=[900] * 8, aa_a=[1000] * 8,
                              aa_b=[960, 970, 980, 1000, 1010, 1020, 1030, 1040])
        self.assertEqual(row["screen"], "screened speedup")
        self.assertAlmostEqual(float(row["aa_ratio_min"]), 0.96)
        self.assertLess(float(row["geomean_ratio"]), float(row["aa_ratio_min"]))

    def test_screen_is_inconclusive_when_the_blocks_or_the_aa_range_do_not_separate(self):
        flat = [1000] * 8
        quiet = [1000, 1010, 1020, 1030, 1040, 1050, 1000, 1000]
        cases = [
            ("one rho equal to one", flat, [1100] * 7 + [1000], flat, quiet),
            ("one rho below one among slowdowns", flat, [900] + [1100] * 7, flat, quiet),
            ("one rho above one among speedups", flat, [900] * 7 + [1100], flat, quiet),
            ("slowdown inside the A/A range", flat, [1100] * 8, flat, [1200] + [1000] * 7),
        ]
        for name, a, b, aa_a, aa_b in cases:
            with self.subTest(name):
                self.assertEqual(self.screen_row(a, b, aa_a, aa_b)["screen"], "inconclusive")

    def test_near_target_bands_at_the_boundaries(self):
        c = self.c
        # a target of 1.0 makes the quotient exact: the boundaries 0.9 and 1 are compared without rounding
        set_mapping(c, P01, "target", "1.0")
        for label in ("a", "b"):
            c.write_records(label, catalog={P01: {"target": 1.0}})
        fractions = [0.9, 0.89, 1.0, 0.0, 0.95, 0.5, 0.9, 0.89]
        bands = ["near target", "margin", "near target", "margin", "near target", "margin", "near target", "margin"]
        for rep, fraction in zip(c.reps, fractions):
            c.write_process("a", J13, rep, catalog={P01: {"target": 1.0}}, value={P01: fraction})
            c.write_process("b", J13, rep, catalog={P01: {"target": 1.0}}, value={P01: fractions[(rep + 1) % 8]})
        result = self.accepted(c.run())
        row = result.row(P01, J13)
        self.assertEqual(row["a_accuracy_band"], ";".join(bands))
        for observed, expected in zip(floats(row["a_accuracy_fraction"]), fractions):
            self.assertEqual(observed, expected)
        self.assertEqual(row["b_accuracy_band"], ";".join(bands[(place + 2) % 8] for place in range(8)))
        self.assertEqual(floats(row["a_value"]), fractions)
        self.assertEqual(row["target"], repr(1.0))
        # a value above the target is missed, whatever the ratio, and an invalid value has no fraction
        c = self.fresh()
        c.write_process("b", J13, 2, status={P01: "target_missed", P03: "uncertifiable"}, value={P01: 1.5e-08})
        jsonl_edit(c.receipt, process_event("B", "AB", V13, 2), lambda event: event.update(exit=2))
        result = c.run()
        by_id = {i["id"]: i for i in result.lists["not_ok"]}
        self.assertEqual(by_id[P01]["accuracy_band"], "missed/invalid")
        self.assertAlmostEqual(by_id[P01]["accuracy_fraction"], 1.5)
        self.assertEqual(by_id[P03]["accuracy_band"], "missed/invalid")
        self.assertIsNone(by_id[P03]["accuracy_fraction"])
        for case_id in (P01, P03):
            self.assertEqual(result.row(case_id, J13)["class"], "FAILED")
            self.assertEqual(result.row(case_id, J13)["a_accuracy_band"], "")

    def test_output_is_deterministic_and_has_no_path_or_clock(self):
        c = self.c
        first, second = c.run(), c.run()
        self.assertEqual(F.tree_snapshot(first.out), F.tree_snapshot(second.out))
        for name in ("migration-comparison.csv", "report.md", "lists.json"):
            text = (first.out / name).read_text(encoding="utf-8")
            self.assertNotIn(str(c.work), text)
            self.assertNotIn("/opt/synthetic", text)
            self.assertNotIn(str(Path.home()), text)
        self.assertEqual(first.stdout, second.stdout)

    def test_refusal_text_names_the_stratum_case_and_values(self):
        c = self.c
        c.write_process("b", J10, 7, data_hash={P09: "f" * 64})
        result = self.refused(c.run(), "INPUTS")
        detail = next(i["detail"] for i in result.refusals if i["field"] == "ab:data_hash")
        for text in (V10, P09, "7", "ffff", F.data_hash(V10, P09, 7)[:4]):
            self.assertIn(text, detail)

    def test_aa_screens_use_the_roles_b_over_a(self):
        row = self.screen_row(a=[1000] * 8, b=[1100] * 8, aa_a=[1000] * 8, aa_b=[1500] * 8)
        self.assertEqual(row["screen"], "inconclusive")
        self.assertAlmostEqual(float(row["aa_ratio_min"]), 1.5)
        self.assertAlmostEqual(float(row["aa_ratio_max"]), 1.5)
        row = self.screen_row(a=[1000] * 8, b=[1100] * 8, aa_a=[1500] * 8, aa_b=[1000] * 8)
        self.assertAlmostEqual(float(row["aa_ratio_max"]), 1000 / 1500)
        self.assertEqual(row["screen"], "screened slowdown")


# --------------------------------------------------------------------------------------------------------------
# 5. Immutability of the ordinary tools
# --------------------------------------------------------------------------------------------------------------

def digest(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


class ImmutabilityTests(MigrationCase):

    def test_compare_py_is_unchanged(self):
        self.assertEqual(digest(F.BENCH / "compare.py"), COMPARE_SHA256)

    def test_validate_py_is_unchanged(self):
        self.assertEqual(digest(F.BENCH / "validate.py"), VALIDATE_SHA256)

    def test_summarize_py_is_unchanged(self):
        self.assertEqual(digest(F.BENCH / "summarize.py"), SUMMARIZE_SHA256)

    def test_validate_settings_are_unchanged_after_in_process_runs(self):
        import validate
        match, series, start, optional = (validate.MATCH_SETTINGS, validate.SERIES_SETTINGS, validate.START_KEYS,
                                          dict(validate.OPTIONAL_SETTINGS))
        self.assertEqual(match, EXPECTED_MATCH_SETTINGS)
        c = self.c
        self.accepted(c.run())
        c = self.fresh()
        set_mapping(c, P01, "role", "diagnostic")
        self.refused(c.run(), "MAPPING")
        c = self.fresh()
        c.set_meta("b", "proximalbase_hash", "1" * 40)
        c.run()
        self.assertIs(validate, F.validate)
        self.assertEqual(validate.MATCH_SETTINGS, EXPECTED_MATCH_SETTINGS)
        self.assertEqual((validate.MATCH_SETTINGS, validate.SERIES_SETTINGS, validate.START_KEYS), (
            match, series, start))
        self.assertEqual(validate.OPTIONAL_SETTINGS, optional)
        self.assertEqual(validate.OPTIONAL_SETTINGS, {"case_filter": ""})

    def test_tool_has_no_ignore_or_bypass_option(self):
        result = F.call_tool(["--help"], self.c.work / "help-out")
        self.assertEqual(result.code, 0)
        options = set(re.findall(r"(?<![\w-])(--[a-z][a-z-]*)", result.stdout))
        self.assertEqual(options, {"--a", "--b", "--mapping", "--declared-differences", "--receipt", "--aa",
                                   "--fingerprints-a", "--fingerprints-b", "--schedule", "--out", "--help"})
        for flag in ("--ignore", "--bypass", "--skip", "--force"):
            self.assertNotIn(flag, result.stdout)
        source = (F.HERE / "migration_compare.py").read_text(encoding="utf-8")
        self.assertIsNone(re.search(r"--(ignore|skip|force|bypass)[a-z-]*", source))
        self.assertIsNone(re.search(r"add_argument\([^)]*ignore", source, re.S))


if __name__ == "__main__":
    unittest.main()
