#!/usr/bin/env python3
"""Read-only audit of all reachable Git blobs, including historical-only blobs.

Requires a full-history checkout (fetch-depth: 0). Does not rewrite refs,
delete objects, run git gc, or change working files. Writes a JSON receipt.
"""
from __future__ import annotations

import argparse
import json
import subprocess
from pathlib import Path


def git(*args: str, stdin: bytes | None = None) -> bytes:
    return subprocess.run(
        ["git", *args], input=stdin, stdout=subprocess.PIPE,
        stderr=subprocess.PIPE, check=True
    ).stdout


def main() -> None:
    p = argparse.ArgumentParser()
    p.add_argument("--output", type=Path, default=Path("repository-size-audit.json"))
    p.add_argument("--top", type=int, default=25)
    a = p.parse_args()
    # rev-list emits unique reachable object IDs and representative paths.
    objects = {}
    for line in git("rev-list", "--objects", "--all").splitlines():
        sha, _, raw_path = line.partition(b" ")
        objects.setdefault(sha.decode("ascii"), raw_path.decode("utf-8", "replace"))
    ids = list(objects)
    output = git(
        "cat-file", "--batch-check=%(objectname) %(objecttype) %(objectsize)",
        stdin=("\n".join(ids) + "\n").encode("ascii")
    )
    blobs = {}
    for line in output.splitlines():
        sha, typ, size = line.decode("ascii").split()
        if typ == "blob":
            blobs[sha] = {"sha": sha, "size": int(size), "path": objects[sha]}

    current_blob_shas = set()
    current_content_bytes = 0
    for line in git("ls-tree", "-r", "-l", "-z", "HEAD").split(b"\0"):
        if not line:
            continue
        meta, _, _path = line.partition(b"\t")
        mode, typ, sha, size = meta.decode("ascii").split()
        if typ == "blob":
            current_blob_shas.add(sha)
            current_content_bytes += int(size)
    historical_only = [b for sha, b in blobs.items() if sha not in current_blob_shas]
    top_blobs = sorted(blobs.values(), key=lambda b: b["size"], reverse=True)[:a.top]
    top_old = sorted(historical_only, key=lambda b: b["size"], reverse=True)[:a.top]
    object_store = git("count-objects", "-vH").decode("utf-8").strip()
    report = {
        "head": git("rev-parse", "HEAD").decode().strip(),
        "reachable_object_count": len(objects),
        "reachable_blob_count": len(blobs),
        "all_blob_uncompressed_bytes": sum(b["size"] for b in blobs.values()),
        "current_tree_content_bytes": current_content_bytes,
        "historical_only_blob_count": len(historical_only),
        "historical_only_uncompressed_bytes": sum(b["size"] for b in historical_only),
        "git_count_objects": object_store,
        "top_reachable_blobs": top_blobs,
        "top_historical_only_blobs": top_old,
    }
    a.output.parent.mkdir(parents=True, exist_ok=True)
    a.output.write_text(json.dumps(report, indent=2) + "\n")
    print("# Repository history size audit (read-only)")
    print("Head:", report["head"])
    for key in (
        "reachable_object_count", "reachable_blob_count", "all_blob_uncompressed_bytes",
        "current_tree_content_bytes", "historical_only_blob_count",
        "historical_only_uncompressed_bytes"
    ):
        print(f"{key}: {report[key]:,}")
    print("Git object store:")
    print(object_store)
    for label, entries in (
        ("Largest reachable blobs", top_blobs),
        ("Largest historical-only blobs", top_old)
    ):
        print("\n" + label + ":")
        for b in entries:
            print(f"  {b['size']:>12,}  {b['sha'][:12]}  {b['path']}")


if __name__ == "__main__":
    main()
