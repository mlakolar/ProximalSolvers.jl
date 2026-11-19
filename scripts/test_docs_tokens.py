#!/usr/bin/env python3
"""Negative migration regressions for lost constants, names and qualifications."""
from __future__ import annotations

import contextlib
import csv
import hashlib
import io
import json
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

import docs_ledger as ledger
from docs_tokens import check_token_coverage, distinctive_tokens, normalized_token


class TokenPreservation(unittest.TestCase):
    def setUp(self):
        temporary = tempfile.TemporaryDirectory()
        self.addCleanup(temporary.cleanup)
        self.root = Path(temporary.name)
        self.source = "docs/src/original.md"
        self.target = "docs/src/contracts/rule.md#RULE-01"
        self.example = b"@assert 1 + 1 == 2\n"
        self.write("examples/demo.jl", self.example)

    def write(self, name, text):
        path = self.root / name
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_bytes(text if isinstance(text, bytes) else text.encode("utf-8"))

    def baseline(self, text):
        self.block = next(ledger.blocks(text, self.source))
        self.manifest = {"baseline": "immutable-fixture", "blocks": [self.block],
                         "example_scripts": {"examples/demo.jl": hashlib.sha256(self.example).hexdigest()}}
        self.rows = [{key: "" for key in ledger.FIELDS}]
        self.rows[0].update(block_id=self.block["id"], sha256=self.block["sha256"],
                            destination=self.target, disposition="merged", note="Reviewed fixture.")
        self.write("docs/migration/baseline.json", json.dumps(self.manifest))
        with (self.root / "docs/migration/ledger.csv").open("w", newline="") as stream:
            writer = csv.DictWriter(stream, fieldnames=ledger.FIELDS)
            writer.writeheader()
            writer.writerows(self.rows)

    def clause(self, text):
        self.write("docs/src/contracts/rule.md", "# [A numerical rule](@id RULE-01)\n\n"
                   f"**Statement.** {text}\n\n**Sources.** `{self.block['id']}`.\n")

    def check(self):
        return check_token_coverage(self.root, self.manifest, self.rows)

    def waiver(self, token, replacement, reason="The exponent is written as an exact integer in the target rule."):
        return {"token": normalized_token(token), "blocks": [self.block["id"]],
                "target": self.target, "replacement": replacement, "reason": reason}

    def write_waivers(self, entries):
        self.write("docs/migration/token-waivers.txt", "\n".join(json.dumps(entry) for entry in entries) + "\n")

    def test_deleted_constant_identifier_issue_error_and_path_are_detected(self):
        distinctive = {
            "constant": "`2^53 * floatmin(T)`",
            "function": "`_stop_check!`",
            "issue": "#378",
            "message": '`ArgumentError("start from a point where f is finite")`',
            "path": "`private/tfocs_backtrack.m`",
            "unit": "17 ms",
            "exponent": "1.57e-162",
        }
        for category, text in distinctive.items():
            with self.subTest(category=category):
                self.baseline("A documented rule uses " + text + ".")
                self.clause("Preserve the rest of the explanation.")
                errors, report = self.check()
                self.assertTrue(errors, report)
                self.assertTrue(any(self.block["id"] in error and "missing distinctive token" in error for error in errors))
                for record in report["tokens"]:
                    self.assertEqual(record["blocks"][0]["destinations"], [self.target])
                self.clause("The migrated statement retains " + text + ".")
                self.assertEqual(self.check()[0], [])

    def test_a_global_number_or_identifier_prefix_cannot_replace_a_lost_condition(self):
        self.baseline("Require `n eps(T) <= 1/8` and `_stop_check!` at `2^53`.")
        self.clause("Other rules use `n`, `eps(T)`, `1/8`, `_stop_check!extra` and `2^530`.")
        missing = {record["token"] for record in self.check()[1]["tokens"] if record["status"] == "missing"}
        self.assertIn("n eps(T)<=1/8", missing)
        self.assertIn("_stop_check!", missing)
        self.assertIn("2^53", missing)
        self.clause("The full condition remains `n eps(T)<=1/8`, `_stop_check!`, and `2 ^ 53`.")
        self.assertEqual(self.check()[0], [])

    def test_metadata_comments_tests_source_code_and_serialized_archives_cannot_self_satisfy(self):
        self.baseline("The callback is `_stop_check!`.")
        self.clause("This rule accidentally lost its callback name.\n\n<!-- `_stop_check!` -->")
        self.write("test/fixture.jl", 'callback = "_stop_check!"\n')
        self.write("scripts/test_fixture.py", 'callback = "_stop_check!"\n')
        self.write("docs/src/fixtures/fixture.md", "`_stop_check!`\n")
        self.write("docs/src/generated/copy.md", "`_stop_check!`\n")
        self.write("docs/build/index.html", "<code>_stop_check!</code>")
        self.write("src/Demo.jl", '#=\n"""\n`_stop_check!`\n"""\n=#\n_stop_check!(m) = true\n')
        self.write("docs/migration/unused.txt", "`_stop_check!`\n")
        self.write("docs/src/archive.md", "# Serialized baseline\n\n```json\n" + json.dumps(self.manifest) + "\n```\n")
        errors, report = self.check()
        self.assertTrue(any("_stop_check!" in error for error in errors))
        self.assertEqual(report["summary"]["retained"], 0)
        self.assertNotIn("src/Demo.jl", report["documents"])

    def test_displayed_historical_evidence_and_real_docstrings_are_scanned(self):
        self.baseline("The old floor is `2^53 * floatmin(T)` and the hook is `_stop_check!`.")
        self.clause("See the historical evidence for the former floor.")
        self.write("docs/src/contracts/evidence/history.md", "# Historical rule\n\n"
                   "This is the baseline wording, not a current guarantee: `2^53 * floatmin(T)`.\n")
        self.write("src/Demo.jl", '"""\nThe model calls `_stop_check!`.\n"""\nf(x) = x\n')
        errors, report = self.check()
        self.assertEqual(errors, [])
        found = {record["token"]: record.get("found_in") for record in report["tokens"]}
        self.assertEqual(found["_stop_check!"], "src/Demo.jl")
        self.assertEqual(found["2^53*floatmin(T)"], "docs/src/contracts/evidence/history.md")
        self.write("src/Demo.jl", '"""\n<!-- `_stop_check!` -->\n"""\nf(x) = x\n')
        self.assertTrue(any("_stop_check!" in error for error in self.check()[0]))

    def test_actual_literate_and_gallery_output_cannot_satisfy_authored_coverage(self):
        self.baseline("The callback is `_stop_check!`.")
        self.clause("The maintained statement lost the callback name.")
        # docs/make.jl writes both paths under its gitignored GENERATED directory.
        self.write("docs/src/examples/problems/lasso.md", "Generated tutorial: `_stop_check!`.\n")
        self.write("docs/src/examples/index.md", "Generated gallery: `_stop_check!`.\n")
        errors, report = self.check()
        self.assertTrue(any("_stop_check!" in error for error in errors))
        self.assertEqual(report["summary"]["retained"], 0)
        self.assertFalse(any(path.startswith("docs/src/examples/") for path in report["documents"]))
        # The maintained examples index is a separate authored input.
        self.write("examples/README.md", "The callback is `_stop_check!`.\n")
        self.assertEqual(self.check()[0], [])

    def test_raw_html_comments_are_hidden_but_ordinary_fences_display_them(self):
        self.baseline("The callback is `_stop_check!`.")
        for comment in ("<!-- `_stop_check!` -->",
                        "<!--\n`_stop_check!`\n-->",
                        "<!-- `_stop_check!`"):
            with self.subTest(comment=comment):
                self.clause("The callback name was lost.\n\n```@raw html\n" + comment + "\n```\n")
                self.assertTrue(any("_stop_check!" in error for error in self.check()[0]))
                self.clause("This fence displays its HTML literally.\n\n```html\n" + comment + "\n```\n")
                self.assertEqual(self.check()[0], [])
        self.clause("The callback remains visible.\n\n```@raw html\n"
                    "<span>_stop_check!</span><!-- another comment -->\n```\n")
        self.assertEqual(self.check()[0], [])

    def test_path_sentence_period_before_a_bullet_is_not_a_filename_suffix(self):
        self.baseline("Run the template <problem>_solvers.jl.")
        self.clause("The template is `<problem>_solvers.jl`.\n\n- Some scripts compare solvers.")
        self.assertEqual(self.check()[0], [])
        # A real suffix must not satisfy the old path merely by sharing a prefix.
        for suffix in (".extra", "_extra", "-extra", "/extra"):
            with self.subTest(suffix=suffix):
                self.clause("The different template is `<problem>_solvers.jl" + suffix + "`.\n")
                missing = {record["token"] for record in self.check()[1]["tokens"]
                           if record["status"] == "missing"}
                self.assertIn("_solvers.jl", missing)

    def test_case_symbols_and_argument_types_are_not_silently_translated(self):
        self.baseline("The threshold is `64 eps(T)` and the named value is `lambda_max`.")
        self.clause("The replacement mistakenly says `64 eps(Float64)` and `Lambda_max`.")
        missing = {record["token"] for record in self.check()[1]["tokens"] if record["status"] == "missing"}
        self.assertIn("64eps(T)", missing)
        self.assertIn("lambda_max", missing)
        self.clause("The threshold is `64eps(T)` and the named value is `lambda_max`.")
        self.assertEqual(self.check()[0], [])

    def test_waiver_must_be_exact_complete_and_supported_by_its_target_clause(self):
        self.baseline("The limit is `2^53`.")
        self.clause("The limit is `9007199254740992`.")
        valid = self.waiver("2^53", "9007199254740992")
        self.write_waivers([valid])
        errors, report = self.check()
        self.assertEqual(errors, [])
        self.assertEqual(report["summary"]["waived"], 1)
        self.assertEqual(report["tokens"][0]["waiver"]["reason"], valid["reason"])
        variants = {
            "missing reason": {**valid, "reason": " "},
            "unknown token": {**valid, "token": "2^54"},
            "wrong source": {**valid, "blocks": ["docs/src/original.md:L10"]},
            "duplicate sources": {**valid, "blocks": [self.block["id"], self.block["id"]]},
            "missing clause": {**valid, "target": "docs/src/contracts/rule.md#LOST-01"},
            "absent replacement": {**valid, "replacement": "9007199254740993"},
            "noncanonical spelling": {**valid, "token": "2 ^ 53"},
            "extra field": {**valid, "allow_all": True},
        }
        for context, invalid in variants.items():
            with self.subTest(context=context):
                self.write_waivers([invalid])
                self.assertTrue(any("token-waivers.txt:1" in error for error in self.check()[0]))
        self.write_waivers([valid, valid])
        self.assertTrue(any("duplicate waiver" in error for error in self.check()[0]))
        self.write_waivers([valid])
        self.clause("Both `2^53` and `9007199254740992` are now present.")
        self.assertTrue(any("stale waiver" in error for error in self.check()[0]))

    def test_waiver_replacement_in_another_clause_or_a_comment_is_not_enough(self):
        self.baseline("The limit is `2^53`.")
        self.clause("The limit is omitted. <!-- 9007199254740992 -->\n\n"
                    "# [Another rule](@id RULE-02)\n\n9007199254740992\n")
        self.write_waivers([self.waiver("2^53", "9007199254740992")])
        self.assertTrue(any("replacement is absent from target clause" in error for error in self.check()[0]))
        self.write("docs/migration/token-waivers.txt", "{not valid JSON}\n")
        self.assertTrue(any("token-waivers.txt:1" in error for error in self.check()[0]))

    def test_full_ledger_enforces_tokens_but_future_structural_mode_does_not(self):
        self.baseline("The guard is `2^53`.")
        self.clause("A rewrite silently loses its guard constant.")
        output = io.StringIO()
        with patch.object(ledger, "ROOT", self.root), patch.object(ledger, "MIGRATION", self.root / "docs/migration"):
            with contextlib.redirect_stdout(output), contextlib.redirect_stderr(output):
                self.assertEqual(ledger.check(), 1)
                self.assertEqual(ledger.check(structural=True), 0)
                self.assertEqual(ledger.check(report_only=True), 0)
        self.assertIn("missing distinctive token '2^53'", output.getvalue())

    def test_bare_numbers_do_not_count_as_independent_semantic_evidence(self):
        self.assertEqual(distinctive_tokens("Use `0`, `1`, `2`, and a variable `T`."), {})
        tokens = distinctive_tokens("The range includes 2^53, floatmin(T), 64 eps(T), 1e-4 and #378.")
        for token in ("2^53", "floatmin(T)", "64eps(T)", "1e-4", "#378"):
            self.assertIn(token, tokens)


if __name__ == "__main__":
    unittest.main()
