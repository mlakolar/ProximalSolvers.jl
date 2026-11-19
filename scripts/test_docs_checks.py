#!/usr/bin/env python3
"""Focused regressions for documentation preservation and active Markdown checks."""
from __future__ import annotations

import contextlib
import csv
import hashlib
import io
import json
from pathlib import Path
import subprocess
import tempfile
import unittest
from unittest.mock import patch

import check_docs_layers as layers
import docs_ledger as ledger


SOURCE = b'module Demo\n"""\nOriginal help.\n"""\nf(x) = x + 1\nend\n'
EXAMPLE = b'@assert 1 + 1 == 2\n'
CLAUSE = """# Contracts

### [A contract](@id REQ-01)

**Statement.** Preserve the documented behavior.

**Applies to.** This fixture.

**Code.** `src/Demo.jl`.

**Tests.** This preservation regression.

**Sources.** The baseline fixture.
"""


class DocumentationChecks(unittest.TestCase):
    def setUp(self):
        temporary = tempfile.TemporaryDirectory()
        self.addCleanup(temporary.cleanup)
        self.root = Path(temporary.name)
        self.write("docs/src/contracts/demo.md", CLAUSE)
        for chapter in range(1, 9):
            self.write(f"docs/src/learn/{chapter:02d}-topic.md", "# A chapter\n\n## Exercises\n\nTry the example.\n")
        self.write("docs/migration/clause-registry.json", json.dumps({"version": 1, "clause_ids": ["REQ-01"]}))
        self.write("src/Demo.jl", SOURCE)
        self.write("examples/demo.jl", EXAMPLE)
        self.manifest = {"version": 1, "baseline": "fixture",
                         "files": {"src/Demo.jl": hashlib.sha256(SOURCE).hexdigest()},
                         "source_code_sha256": {"src/Demo.jl": layers.source_code_sha256(SOURCE)},
                         "example_scripts": {"examples/demo.jl": hashlib.sha256(EXAMPLE).hexdigest()},
                         "blocks": []}
        self.save_manifest()

    def write(self, path, value):
        target = self.root / path
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_bytes(value if isinstance(value, bytes) else value.encode("utf-8"))

    def save_manifest(self):
        self.write("docs/migration/baseline.json", json.dumps(self.manifest))

    def ledger_row(self, block, destination, disposition="example"):
        row = {key: "" for key in ledger.FIELDS}
        row.update(block_id=block["id"], sha256=block["sha256"], disposition=disposition,
                   destination=destination, note="Reviewed fixture mapping.")
        with (self.root / "docs/migration/ledger.csv").open("w", newline="") as stream:
            writer = csv.DictWriter(stream, fieldnames=ledger.FIELDS)
            writer.writeheader()
            writer.writerow(row)

    def run_ledger(self):
        output = io.StringIO()
        with patch.object(ledger, "ROOT", self.root), patch.object(ledger, "MIGRATION", self.root / "docs/migration"):
            with contextlib.redirect_stdout(output), contextlib.redirect_stderr(output):
                result = ledger.check()
        return result, output.getvalue()

    def test_docstring_only_changes_are_allowed_but_source_edits_are_not(self):
        self.assertEqual(layers.run_checks(self.root, migration=True)[0], [])
        edited_help = SOURCE.replace(b"Original help.", b"Short help.\n\n# Extended help\nMore help.")
        self.write("src/Demo.jl", edited_help)
        self.assertEqual(layers.run_checks(self.root, migration=True)[0], [])
        self.write("src/Demo.jl", edited_help.replace(b"x + 1", b"x + 2"))
        self.assertTrue(any("Source bytes outside docstring bodies changed" in message
                            for message in layers.run_checks(self.root, migration=True)[0]))
        # The historical baseline must not freeze legitimate future source edits.
        self.assertEqual(layers.run_checks(self.root)[0], [])

    def test_missing_and_byte_changed_examples_fail_only_migration_checks(self):
        self.write("examples/demo.jl", EXAMPLE.replace(b"\n", b"\r\n"))
        self.assertTrue(any("example script bytes changed" in message
                            for message in layers.run_checks(self.root, migration=True)[0]))
        (self.root / "examples/demo.jl").unlink()
        self.assertTrue(any("example script missing" in message
                            for message in layers.run_checks(self.root, migration=True)[0]))
        self.assertEqual(layers.run_checks(self.root)[0], [])

    def test_code_fences_cannot_define_ids_or_exercises(self):
        fake = '\n````julia\n# [Not a heading](@id REQ-01)\n```\n# still code\n````\n'
        self.write("docs/src/contracts/demo.md", CLAUSE + fake)
        self.assertEqual(layers.run_checks(self.root)[0], [])
        self.write("docs/src/learn/03-topic.md", "# Chapter\n\n~~~julia\n## Exercises\n~~~\n")
        self.assertTrue(any("missing active Exercises" in message for message in layers.run_checks(self.root)[0]))
        with patch.object(ledger, "ROOT", self.root):
            self.write("docs/src/fake.md", "```julia\n# [Fake](@id GHOST-01)\n```\n")
            self.assertFalse(ledger.destination_exists("docs/src/fake.md#GHOST-01"))

    def test_retired_clause_keeps_its_id_and_a_real_replacement(self):
        replacement = CLAUSE.replace("REQ-01", "REQ-02")
        retired = "# Contracts\n\n### [Retired rule](@id REQ-01)\n\nRetired. See [REQ-02](@ref).\n\n"
        self.write("docs/migration/clause-registry.json", json.dumps({"clause_ids": ["REQ-01", "REQ-02"]}))
        self.write("docs/src/contracts/demo.md", retired + replacement)
        self.assertEqual(layers.run_checks(self.root)[0], [])
        self.write("docs/src/contracts/demo.md", replacement)
        self.assertTrue(any("Registered clause ID disappeared" in message
                            for message in layers.run_checks(self.root)[0]))

    def test_new_contract_and_evidence_ids_must_enter_the_retained_registry(self):
        additions = {
            "docs/src/contracts/added.md": "REQ-02",
            "docs/src/contracts/evidence/added.md": "EVIDENCE-STRICT-02",
        }
        for path, ident in additions.items():
            with self.subTest(path=path):
                self.write("docs/migration/clause-registry.json", json.dumps({"clause_ids": ["REQ-01"]}))
                self.write(path, CLAUSE.replace("REQ-01", ident))
                self.assertTrue(any("numbered contract ID is not registered: " + ident in message
                                    for message in layers.run_checks(self.root)[0]))
                self.write("docs/migration/clause-registry.json",
                           json.dumps({"clause_ids": ["REQ-01", ident]}))
                self.assertEqual(layers.run_checks(self.root)[0], [])
                (self.root / path).unlink()
                self.assertTrue(any("Registered clause ID disappeared: " + ident in message
                                    for message in layers.run_checks(self.root)[0]))

    def test_previous_registry_prevents_deleting_both_id_and_registry_entry(self):
        def git(*args):
            subprocess.run(["git", "-C", str(self.root), "-c", "user.name=Documentation checks",
                            "-c", "user.email=docs-checks@example.invalid", "-c", "commit.gpgsign=false",
                            *args], check=True, capture_output=True)

        git("init", "--quiet")
        registry = self.root / "docs/migration/clause-registry.json"
        original_registry = registry.read_bytes()
        registry.unlink()
        git("add", ".")
        git("commit", "--quiet", "-m", "Before the registry was introduced")
        registry.write_bytes(original_registry)
        # Absence at a real earlier revision permits the registry's first introduction.
        self.assertEqual(layers.run_checks(self.root, previous_ref="HEAD")[0], [])
        self.assertTrue(any("Cannot resolve --previous-ref" in message
                            for message in layers.run_checks(self.root, previous_ref="missing-ref")[0]))
        git("add", ".")
        git("commit", "--quiet", "-m", "Register the initial clause")
        self.assertEqual(layers.run_checks(self.root, previous_ref="HEAD")[0], [])
        self.write("docs/src/contracts/demo.md", CLAUSE.replace("REQ-01", "REQ-02"))
        self.write("docs/migration/clause-registry.json", json.dumps({"clause_ids": ["REQ-02"]}))
        self.assertEqual(layers.run_checks(self.root)[0], [])
        errors = layers.run_checks(self.root, previous_ref="HEAD")[0]
        self.assertTrue(any("Previously registered clause ID removed from registry: REQ-01" in message
                            for message in errors))
        self.assertTrue(any("Previously registered clause ID disappeared: REQ-01" in message
                            for message in errors))

    def test_docstring_fingerprints_do_not_hide_strings_or_block_comments(self):
        comment = b'#=\n"""\nThis is a comment, not help.\n"""\n=#\n'
        self.assertNotEqual(layers.source_code_sha256(comment + SOURCE),
                            layers.source_code_sha256(comment.replace(b"not help", b"changed") + SOURCE))
        inline_string = b'value = """\nData, not a docstring.\n"""\n'
        self.assertNotEqual(layers.source_code_sha256(inline_string + SOURCE),
                            layers.source_code_sha256(inline_string.replace(b"Data", b"Other data") + SOURCE))
        with self.assertRaisesRegex(ValueError, "unclosed standalone docstring"):
            layers.source_code_sha256(b'"""\nUnclosed help.\n')

    def test_examples_hidden_in_literal_fences_or_html_comments_are_not_preserved(self):
        example = "~~~@example preserved\nvalue = 1\n@assert value == 1\n~~~"
        block = next(ledger.blocks(example, "docs/src/original.md"))
        self.manifest["blocks"] = [block]
        self.save_manifest()
        self.ledger_row(block, "docs/src/moved.md")
        self.write("docs/src/moved.md", example + "\n")
        self.assertEqual(self.run_ledger()[0], 0)
        hidden_examples = {
            "literal fence": "````markdown\n" + example + "\n````\n",
            "HTML comment": "<!--\n" + example + "\n-->\n",
        }
        for context, hidden in hidden_examples.items():
            with self.subTest(context=context):
                self.write("docs/src/moved.md", hidden)
                result, output = self.run_ledger()
                self.assertEqual(result, 1)
                self.assertIn("original active executable block not found", output)

    def test_source_citation_in_a_different_clause_is_not_enough(self):
        block = next(ledger.blocks("An original rule.", "docs/src/original.md"))
        self.manifest["blocks"] = [block]
        self.save_manifest()
        self.ledger_row(block, "docs/src/contracts/demo.md#REQ-01", disposition="merged")
        citation = f"`{block['id']}`."
        second = CLAUSE.replace("REQ-01", "REQ-02").replace("The baseline fixture.", citation)
        self.write("docs/src/contracts/demo.md", CLAUSE + "\n" + second)
        result, output = self.run_ledger()
        self.assertEqual(result, 1)
        self.assertIn("does not cite source block", output)
        self.write("docs/src/contracts/demo.md", CLAUSE.replace("The baseline fixture.", citation) + "\n" + second)
        self.assertEqual(self.run_ledger()[0], 0)

    def test_body_mentions_and_prefix_ids_cannot_replace_exact_sources(self):
        block = next(ledger.blocks("An original rule.", "docs/src/original.md"))
        self.assertEqual(block["id"], "docs/src/original.md:L1")
        self.manifest["blocks"] = [block]
        self.save_manifest()
        self.ledger_row(block, "docs/src/contracts/demo.md#REQ-01", disposition="merged")
        citation = f"`{block['id']}`."
        self.write("docs/src/contracts/demo.md", CLAUSE.replace("The baseline fixture.", citation))
        self.assertEqual(self.run_ledger()[0], 0)
        invalid_citations = {
            "L10 cannot cite L1": CLAUSE.replace("The baseline fixture.", "`docs/src/original.md:L10`."),
            "body only": CLAUSE.replace("Preserve the documented behavior.",
                                        "Preserve the documented behavior. See " + citation),
            "unquoted Sources ID": CLAUSE.replace("The baseline fixture.", block["id"]),
        }
        for context, text in invalid_citations.items():
            with self.subTest(context=context):
                self.write("docs/src/contracts/demo.md", text)
                result, output = self.run_ledger()
                self.assertEqual(result, 1)
                self.assertIn("does not cite source block", output)


if __name__ == "__main__":
    unittest.main()
