#!/usr/bin/env python3
"""Reject new generated artifacts and oversized blobs before merge.

Only changed paths are examined; already-tracked historical audit files are
grandfathered. Uses the resulting merge tree, so files deleted before a squash
merge do not count. No third-party Python dependencies.
"""
from __future__ import annotations

import argparse
import subprocess
import sys
from pathlib import PurePosixPath

MAX_FILE_BYTES = 1024 * 1024
MAX_CHANGESET_BYTES = 5 * 1024 * 1024

# An exception requires maintainer review, exact path, reason and Git blob SHA.
# Never broadly exempt docs/audit or benchmark.
EXCEPTIONS: dict[str, tuple[str, str]] = {}

ARCHIVE_SUFFIXES = (
    ".tar", ".tar.gz", ".tgz", ".zip", ".7z", ".gz", ".bz2", ".xz",
    ".zst", ".rar", ".jld2", ".h5", ".hdf5", ".parquet", ".arrow",
    ".npy", ".npz", ".sqlite", ".sqlite3", ".db", ".prof", ".bin",
)
GENERATED_FOLDERS = {
    "results", "artifacts", "evidence", "validation", "raw", "raw-data",
    "measurements", "logs", "generated", "output", "outputs", "runs",
}
GENERATED_FILENAMES = {
    "observations.csv", "samples.csv", "raw.csv", "campaign.json",
    "provenance.json", "provenance.toml", "failures.json", "regressions.txt",
    "sha256sums", "environment.json", "verification.json",
}
GENERATED_SUFFIXES = (".log", ".log.gz", ".samples.csv", ".summary.csv")


def git(*args: str) -> bytes:
    return subprocess.check_output(["git", *args], stderr=subprocess.PIPE)


def artifact_reason(path: str) -> str | None:
    name = PurePosixPath(path).name.lower()
    parts = PurePosixPath(path.lower()).parts
    if name.endswith(ARCHIVE_SUFFIXES):
        return "compressed archive, binary benchmark data, or generated artifact"
    if name.endswith(GENERATED_SUFFIXES):
        return "generated log or raw benchmark sample output"
    if parts and parts[0] in ("benchmark", "docs"):
        if len(parts) > 1 and (parts[0] == "benchmark" or parts[1] == "audit"):
            if any(part in GENERATED_FOLDERS for part in parts[1:-1]):
                return "generated benchmark/audit output directory"
            if parts[0] == "docs" and parts[1] == "audit" and name in GENERATED_FILENAMES:
                return "generated audit receipt rather than maintained source"
    return None


def checked_paths(base: str, head: str) -> list[str]:
    output = git("diff", "--name-only", "--diff-filter=ACMR", "-z", base, head)
    return sorted({p.decode("utf-8", "surrogateescape") for p in output.split(b"\x00") if p})


def check(base: str, head: str) -> list[str]:
    problems: list[str] = []
    changed_bytes = 0
    changed_files = 0
    for path in checked_paths(base, head):
        try:
            blob_type = git("cat-file", "-t", f"{head}:{path}").decode().strip()
        except subprocess.CalledProcessError:
            continue
        if blob_type != "blob":
            continue
        size = int(git("cat-file", "-s", f"{head}:{path}"))
        sha = git("rev-parse", f"{head}:{path}").decode().strip()
        reason = artifact_reason(path)
        exception = EXCEPTIONS.get(path)
        if exception and len(exception) == 2 and exception[1] == sha and exception[0].strip():
            print(f"Approved fixture: {path} ({size} bytes): {exception[0]}")
            continue
        if reason:
            problems.append(f"{path}: {reason}")
        if size > MAX_FILE_BYTES:
            problems.append(f"{path}: {size:,} bytes exceeds {MAX_FILE_BYTES:,} byte per-file limit")
        changed_bytes += size
        changed_files += 1
    if changed_bytes > MAX_CHANGESET_BYTES:
        problems.append(
            f"Changed blobs total {changed_bytes:,} bytes across {changed_files} files "
            f"(limit {MAX_CHANGESET_BYTES:,} bytes)."
        )
    print(f"Repository hygiene: checked {changed_files} changed files, "
          f"{changed_bytes:,} changed bytes, base={base}, head={head}.")
    return problems


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--base", help="git ref to compare against (default HEAD^1)")
    parser.add_argument("--head", default="HEAD")
    args = parser.parse_args()
    base = args.base or "HEAD^1"
    try:
        git("rev-parse", "--verify", base)
        git("rev-parse", "--verify", args.head)
        issues = check(base, args.head)
    except subprocess.CalledProcessError as exc:
        print(f"Repository hygiene cannot determine comparison: {exc}", file=sys.stderr)
        return 2
    if issues:
        print("\nRepository hygiene gate FAILED:", file=sys.stderr)
        for issue in issues:
            print(f"  - {issue}", file=sys.stderr)
        print("Keep raw results and archives outside git; preserve a concise PR/issue "
              "summary. An exact-blob, reviewed EXCEPTIONS entry is needed for legitimate fixtures.",
              file=sys.stderr)
        return 1
    print("Repository hygiene gate passed.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
