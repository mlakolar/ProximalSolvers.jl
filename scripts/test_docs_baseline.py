#!/usr/bin/env python3
"""Focused tests for Git-anchored documentation migration inventories."""
from __future__ import annotations

import contextlib
import copy
import hashlib
import io
import json
from pathlib import Path
import subprocess
import tempfile
import unittest
from unittest.mock import patch

import docs_ledger as ledger


SOURCE = b'module Demo\n"""\nOriginal help.\n"""\nf(x) = x + 1\nend\n'
EXAMPLE = b'@assert 1 + 1 == 2\r\n'


class BaselineAnchoring(unittest.TestCase):
    def setUp(self):
        temporary = tempfile.TemporaryDirectory()
        self.addCleanup(temporary.cleanup)
        self.root = Path(temporary.name)
        self.git("init", "--quiet")
        self.git("config", "user.email", "docs-fixture@example.invalid")
        self.git("config", "user.name", "Documentation fixture")
        self.write("README.md", "# Fixture\n\nOriginal package description.\n")
        self.write("examples/README.md", "# Examples\n\nOriginal example index.\n")
        for index, page in enumerate(ledger.PAGES):
            self.write("docs/src/" + page, f"# Page {index}\n\nOriginal paragraph {index}.\n")
        self.write("docs/src/index.md", "# Fixture docs\n\n~~~@example retained\n@assert 1 + 1 == 2\n~~~\n")
        self.write("src/Demo.jl", SOURCE)
        self.write("examples/demo.jl", EXAMPLE)
        self.git("add", ".")
        self.git("commit", "--quiet", "-m", "Original documentation and implementation")
        self.before = self.git("rev-parse", "HEAD").strip()
        with patch.object(ledger, "ROOT", self.root):
            self.manifest = ledger.inventory(self.before)
        self.manifest["implementation_baseline"] = self.before
        self.manifest["implementation_example_scripts"] = dict(self.manifest["example_scripts"])
        self.manifest["url_basis"] = "Rendered URL explanation, not inventory data."
        self.manifest["implementation_baseline_note"] = "The implementation revision is recorded separately."
        self.save()

    def git(self, *args):
        return subprocess.check_output(["git", *args], cwd=self.root, stderr=subprocess.PIPE, text=True)

    def write(self, path, value):
        target = self.root / path
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_bytes(value if isinstance(value, bytes) else value.encode("utf-8"))

    def save(self):
        self.write("docs/migration/baseline.json", json.dumps(self.manifest))

    def verify(self, previous=None):
        output = io.StringIO()
        with patch.object(ledger, "ROOT", self.root), patch.object(ledger, "MIGRATION", self.root / "docs/migration"):
            with contextlib.redirect_stdout(output), contextlib.redirect_stderr(output):
                result = ledger.verify_baseline(self.before if previous is None else previous)
        return result, output.getvalue()

    def publish_manifest(self):
        self.git("add", "docs/migration/baseline.json")
        self.git("commit", "--quiet", "-m", "Introduce the anchored inventory")
        return self.git("rev-parse", "HEAD").strip()

    def test_first_introduction_reconstructs_original_bytes_and_ignores_explanations(self):
        self.assertEqual(self.manifest["example_scripts"]["examples/demo.jl"],
                         hashlib.sha256(EXAMPLE).hexdigest())
        result, output = self.verify()
        self.assertEqual(result, 0, output)
        self.assertIn("anchored to Git", output)

    def test_first_introduction_rejects_dropped_or_rewritten_inventory(self):
        original = copy.deepcopy(self.manifest)
        for field in ("blocks", "files", "example_scripts", "implementation_example_scripts", "urls", "source_code_sha256"):
            with self.subTest(field=field):
                self.manifest = copy.deepcopy(original)
                value = self.manifest[field]
                if isinstance(value, list):
                    value.pop()
                elif len(value) > 1:
                    value.pop(next(iter(value)))
                else:
                    value[next(iter(value))] = "0" * 64
                self.save()
                result, output = self.verify()
                self.assertEqual(result, 1, output)
                self.assertIn(field, output)

    def test_first_introduction_rejects_rehashed_source_text(self):
        block = self.manifest["blocks"][0]
        block["text"] = "Rewritten history."
        block["sha256"] = ledger.sha(block["text"])
        self.save()
        result, output = self.verify()
        self.assertEqual(result, 1, output)
        self.assertIn("blocks", output)

    def test_a_distinct_implementation_baseline_is_verified(self):
        changed = SOURCE.replace(b"x + 1", b"x + 2")
        self.write("src/Demo.jl", changed)
        self.git("add", "src/Demo.jl")
        self.git("commit", "--quiet", "-m", "Upstream implementation change")
        self.manifest["implementation_baseline"] = self.git("rev-parse", "HEAD").strip()
        self.manifest["source_code_sha256"]["src/Demo.jl"] = ledger.source_code_sha256(changed)
        self.save()
        result, output = self.verify(self.manifest["implementation_baseline"])
        self.assertEqual(result, 0, output)
        # The recorded implementation SHA can precede an event base that changed only docs.
        self.write("README.md", "# Fixture\n\nUpdated upstream documentation.\n")
        self.git("add", "README.md")
        self.git("commit", "--quiet", "-m", "Upstream documentation change")
        event_base = self.git("rev-parse", "HEAD").strip()
        result, output = self.verify(event_base)
        self.assertEqual(result, 0, output)
        self.manifest["source_code_sha256"]["src/Demo.jl"] = ledger.source_code_sha256(SOURCE)
        self.save()
        result, output = self.verify(event_base)
        self.assertEqual(result, 1, output)
        self.assertIn("source_code_sha256", output)

    def test_changed_implementation_cannot_select_its_own_preservation_baseline(self):
        changed = SOURCE.replace(b"x + 1", b"x + 2")
        self.write("src/Demo.jl", changed)
        self.git("add", "src/Demo.jl")
        self.git("commit", "--quiet", "-m", "Implementation changed after the event base")
        self.manifest["implementation_baseline"] = self.git("rev-parse", "HEAD").strip()
        self.manifest["source_code_sha256"]["src/Demo.jl"] = ledger.source_code_sha256(changed)
        self.save()
        result, output = self.verify(self.before)
        self.assertEqual(result, 1, output)
        self.assertIn("source_code_sha256 differs from event base", output)

    def test_approved_upstream_examples_have_separate_historical_and_integration_snapshots(self):
        historical = dict(self.manifest["example_scripts"])
        approved = EXAMPLE + b"# Approved upstream plot.\r\n"
        added = b"@assert 2 + 2 == 4\n"
        self.write("examples/demo.jl", approved)
        self.write("examples/added.jl", added)
        self.git("add", "examples/demo.jl", "examples/added.jl")
        self.git("commit", "--quiet", "-m", "Approved upstream example additions")
        upstream = self.git("rev-parse", "HEAD").strip()
        self.manifest["implementation_baseline"] = upstream
        self.manifest["implementation_example_scripts"] = {
            "examples/demo.jl": hashlib.sha256(approved).hexdigest(),
            "examples/added.jl": hashlib.sha256(added).hexdigest(),
        }
        self.save()
        result, output = self.verify(upstream)
        self.assertEqual(result, 0, output)
        self.assertEqual(self.manifest["example_scripts"], historical)
        approved_manifest = copy.deepcopy(self.manifest)
        # Omitting the new field must not bypass comparison with the event base.
        del self.manifest["implementation_example_scripts"]
        self.save()
        result, output = self.verify(upstream)
        self.assertEqual(result, 1, output)
        self.assertIn("example scripts differ from event base", output)
        # The whole integration inventory is anchored, including upstream additions.
        self.manifest = copy.deepcopy(approved_manifest)
        del self.manifest["implementation_example_scripts"]["examples/added.jl"]
        self.save()
        result, output = self.verify(upstream)
        self.assertEqual(result, 1, output)
        self.assertIn("implementation_example_scripts", output)
        self.manifest = copy.deepcopy(approved_manifest)
        del self.manifest["example_scripts"]
        self.save()
        result, output = self.verify(upstream)
        self.assertEqual(result, 1, output)
        self.assertIn("example_scripts", output)

    def test_changed_examples_cannot_select_their_own_integration_baseline(self):
        changed = EXAMPLE + b"# A change made during the migration.\n"
        self.write("examples/demo.jl", changed)
        self.git("add", "examples/demo.jl")
        self.git("commit", "--quiet", "-m", "Example changed after the event base")
        self.manifest["implementation_baseline"] = self.git("rev-parse", "HEAD").strip()
        self.manifest["implementation_example_scripts"]["examples/demo.jl"] = hashlib.sha256(changed).hexdigest()
        self.save()
        result, output = self.verify(self.before)
        self.assertEqual(result, 1, output)
        self.assertIn("example scripts differ from event base", output)

    def test_invalid_and_missing_refs_fail(self):
        for previous in ("missing-ref", "0" * 40, ""):
            with self.subTest(previous=previous):
                result, output = self.verify(previous)
                self.assertEqual(result, 1, output)
        original = copy.deepcopy(self.manifest)
        for field in ("baseline", "implementation_baseline"):
            for revision in ("missing-ref", "0" * 40):
                with self.subTest(field=field, revision=revision):
                    self.manifest = copy.deepcopy(original)
                    self.manifest[field] = revision
                    self.save()
                    result, output = self.verify()
                    self.assertEqual(result, 1, output)

    def test_every_inventory_must_be_nonempty(self):
        original = copy.deepcopy(self.manifest)
        for field in ("blocks", "files", "example_scripts", "implementation_example_scripts", "urls", "source_code_sha256"):
            with self.subTest(field=field):
                self.manifest = copy.deepcopy(original)
                self.manifest[field] = type(self.manifest[field])()
                self.save()
                result, output = self.verify()
                self.assertEqual(result, 1, output)
                self.assertIn(field + " must be a nonempty", output)

    def test_prior_inventory_cannot_be_regenerated_to_forget_a_block(self):
        previous = self.publish_manifest()
        self.manifest["blocks"].pop()
        self.save()
        result, output = self.verify(previous)
        self.assertEqual(result, 1, output)
        self.assertIn("previous revision", output)
        self.assertIn("blocks", output)

    def test_prior_inventory_rejects_changed_snapshot_refs_and_hashes(self):
        previous = self.publish_manifest()
        original = copy.deepcopy(self.manifest)
        for field in ("baseline", "implementation_baseline", "files", "example_scripts", "implementation_example_scripts",
                      "source_code_sha256", "urls"):
            with self.subTest(field=field):
                self.manifest = copy.deepcopy(original)
                if field in ("baseline", "implementation_baseline"):
                    self.manifest[field] = "0" * 40
                elif field == "urls":
                    self.manifest[field][0]["fragment"] = "Replaced-fragment"
                else:
                    values = self.manifest[field]
                    values[next(iter(values))] = "0" * 64
                self.save()
                result, output = self.verify(previous)
                self.assertEqual(result, 1, output)
                self.assertIn(field, output)

    def test_prior_inventory_needs_only_the_prior_git_revision(self):
        previous = self.publish_manifest()
        self.manifest["url_basis"] = "Updated explanatory wording."
        self.manifest["implementation_baseline_note"] = "Another explanation."
        self.save()
        with patch.object(ledger, "inventory", side_effect=AssertionError("must not reconstruct")), \
                patch.object(ledger, "_implementation_fingerprints", side_effect=AssertionError("must not reload source")), \
                patch.object(ledger, "_example_fingerprints", side_effect=AssertionError("must not reload examples")), \
                patch.object(ledger, "_commit", wraps=ledger._commit) as resolve:
            result, output = self.verify(previous)
        self.assertEqual(result, 0, output)
        resolve.assert_called_once_with(previous)
        self.assertIn("retained from", output)

    def test_malformed_previous_manifest_is_not_treated_as_first_introduction(self):
        self.write("docs/migration/baseline.json", "not JSON")
        previous = self.publish_manifest()
        self.save()
        result, output = self.verify(previous)
        self.assertEqual(result, 1, output)

    def test_extract_reuses_inventory_and_writes_lf_csv(self):
        output = io.StringIO()
        with patch.object(ledger, "ROOT", self.root), patch.object(ledger, "MIGRATION", self.root / "docs/migration"):
            with contextlib.redirect_stdout(output):
                ledger.extract(self.before)
        written = json.loads((self.root / "docs/migration/baseline.json").read_text())
        with patch.object(ledger, "ROOT", self.root):
            self.assertEqual(written, ledger.inventory(self.before))
        self.assertNotIn(b"\r\n", (self.root / "docs/migration/ledger.csv").read_bytes())
        result, output = self.verify()
        self.assertEqual(result, 0, output)


if __name__ == "__main__":
    unittest.main()
