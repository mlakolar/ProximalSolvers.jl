#!/usr/bin/env python3
"""Fast, network-free contract tests for the repository hygiene gate."""
from __future__ import annotations

import os
import subprocess
import tempfile
import unittest
from pathlib import Path

import check_repo_hygiene as h


class GateTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.root = Path(self.tmp.name)
        self.old_cwd = Path.cwd()
        os.chdir(self.root)
        for command in (
            ["git", "init", "-q"],
            ["git", "config", "user.email", "ci@example.test"],
            ["git", "config", "user.name", "CI"],
        ):
            subprocess.run(command, check=True)
        self.write("docs/audit/old/results/legacy.csv", "x" * (2 * 1024 * 1024))
        self.commit("legacy evidence")
        self.base = h.git("rev-parse", "HEAD").decode().strip()

    def tearDown(self):
        os.chdir(self.old_cwd)
        self.tmp.cleanup()

    def write(self, name, contents):
        path = self.root / name
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(contents)

    def commit(self, message):
        subprocess.run(["git", "add", "-A"], check=True)
        subprocess.run(["git", "commit", "-qm", message], check=True)

    def test_grandfathered_and_maintained_benchmarks(self):
        self.write("benchmark/reusable_cases.jl", "using Test\n")
        self.write("test/test_fixtures.jl", "@test true\n")
        self.commit("normal changes")
        self.assertEqual(h.check(self.base, "HEAD"), [])

    def test_generated_files_rejected(self):
        self.write("docs/audit/861/results/summary.csv", "metric,value\n")
        self.write("benchmark/new/logs/run.log", "hi\n")
        self.write("benchmark/fixtures/data.tar.gz", "not actually compressed")
        self.commit("bad artifacts")
        reasons = "\n".join(h.check(self.base, "HEAD"))
        self.assertIn("summary.csv", reasons)
        self.assertIn("run.log", reasons)
        self.assertIn("data.tar.gz", reasons)

    def test_file_limit(self):
        self.write("docs/big.md", "x" * (h.MAX_FILE_BYTES + 1))
        self.commit("large documentation")
        self.assertIn("per-file limit", "\n".join(h.check(self.base, "HEAD")))

    def test_changeset_limit(self):
        for k in range(6):
            self.write(f"test/generated{k}.jl", "x" * 900_000)
        self.commit("six files that exceed combined budget")
        self.assertIn("Changed blobs total", "\n".join(h.check(self.base, "HEAD")))

    def test_removed_artifact_does_not_enter_squash_tree(self):
        self.write("docs/audit/861/evidence.tar.gz", "archive")
        self.commit("temporary archive")
        (self.root / "docs/audit/861/evidence.tar.gz").unlink()
        self.commit("remove archive before squash merge")
        self.assertEqual(h.check(self.base, "HEAD"), [])


if __name__ == "__main__":
    unittest.main()
