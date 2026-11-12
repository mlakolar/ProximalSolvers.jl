"""Serial balanced ABA/BAB measurements in warm, isolated Julia processes.

Usage: python3 measure.py JULIA ENV_A ENV_B OUTPUT_DIRECTORY
Requires JULIA_DEPOT_PATH, JULIA_NUM_THREADS=1 and OPENBLAS_NUM_THREADS=1.
The two environments must resolve the exact audited source pairs.
"""
import csv
import hashlib
import json
import os
from pathlib import Path
import random
import statistics
import subprocess
import sys
import tomllib

julia, env_a, env_b, output = sys.argv[1:]
out = Path(output)
out.mkdir(parents=True, exist_ok=False)
here = Path(__file__).resolve().parent
workers = []
logs = []
metadata = []
identities = {}
harness = {name: hashlib.sha256((here/name).read_bytes()).hexdigest()
           for name in ("measure.py", "worker.jl")}

def identity(root):
    root = Path(root).resolve()
    def git(*args):
        return subprocess.check_output(["git", "-C", str(root), *args], text=True).strip()
    if git("status", "--porcelain", "--untracked-files=no"):
        raise RuntimeError(f"dirty tracked source: {root}")
    digest = hashlib.sha256()
    for path in sorted([root / "Project.toml", *(root / "src").rglob("*.jl")]):
        digest.update(str(path.relative_to(root)).encode()+b"\0")
        digest.update(path.read_bytes()+b"\0")
    return {"commit": git("rev-parse", "HEAD"), "source_sha256": digest.hexdigest()}

try:
    for label, environment in (("A1", env_a), ("A2", env_a), ("B", env_b)):
        log = (out / f"{label}.stderr").open("w")
        logs.append(log)
        worker = subprocess.Popen(
            [julia, "--startup-file=no",
             f"--compiled-modules={os.environ.get('PS_REFRESH_COMPILED_MODULES', 'yes')}",
             f"--project={environment}", str(here / "worker.jl")],
            stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=log, text=True,
            env={**os.environ, "JULIA_NUM_THREADS": "1", "OPENBLAS_NUM_THREADS": "1"})
        workers.append(worker)
        ready = worker.stdout.readline().rstrip()
        if not ready.startswith("READY\t"):
            raise RuntimeError(f"{label} failed warmup: {ready}; see stderr")
        fields = ready.split("\t")
        pb, ps = (Path(path).parent.parent.resolve() for path in fields[-2:])
        expected_pb = ("c123d56ba1948e36a8fdbf183a9eea396a16e0d5" if label == "B"
                       else "2b373c546e247781d9514a7000ef3e010343ca4c")
        for root in (pb, ps):
            identities[str(root)] = identity(root)
        if identity(pb)["commit"] != expected_pb:
            raise RuntimeError(f"wrong loaded PB revision: {pb}")
        project = tomllib.loads((ps / "Project.toml").read_text())
        if project["sources"]["ProximalBase"]["rev"] != expected_pb:
            raise RuntimeError(f"loaded PS pin mismatch: {ps}")
        metadata.append({"label": label, "environment": environment, "ready": ready,
                         "project_sha256": hashlib.sha256(Path(environment, "Project.toml").read_bytes()).hexdigest(),
                         "manifest_sha256": hashlib.sha256(Path(environment, "Manifest.toml").read_bytes()).hexdigest()})
    components = []
    for _ in range(3):
        for worker in workers:
            worker.stdin.write("components\n")
            worker.stdin.flush()
            components.append(worker.stdout.readline().rstrip())
    rows = []
    summaries = []
    for campaign, pair in (("control", (0, 1)), ("paired", (0, 2))):
        for case in range(1, 9):
            orders = [(0, 1, 0)] * 12 + [(1, 0, 1)] * 12
            random.Random(20261111 + case).shuffle(orders)
            ratios = []
            by_source = [[], []]
            diagnostics = set()
            for triplet, order in enumerate(orders, 1):
                triplet_times = []
                for position, source in enumerate(order, 1):
                    worker = workers[pair[source]]
                    worker.stdin.write(f"{case}\n")
                    worker.stdin.flush()
                    values = worker.stdout.readline().rstrip().split("\t")
                    if len(values) != 9:
                        raise RuntimeError(f"invalid worker output: {values}")
                    seconds, allocated = float(values[0]), float(values[1])
                    diagnostics.add(tuple(values[3:]))
                    by_source[source].append((seconds, allocated))
                    triplet_times.append(seconds)
                    rows.append([campaign, case, triplet, position, source, *values])
                edge = statistics.mean((triplet_times[0], triplet_times[2]))
                ratios.append(triplet_times[1]/edge if order[1] else edge/triplet_times[1])
            if len(diagnostics) != 1:
                raise RuntimeError(f"numerical or stopping divergence: {campaign} case {case}")
            diag = next(iter(diagnostics))
            summaries.append({"campaign": campaign, "case": case,
                              "median_B_over_A": statistics.median(ratios),
                              "min_ratio": min(ratios), "max_ratio": max(ratios),
                              "median_seconds": [statistics.median(x[0] for x in group) for group in by_source],
                              "allocation_bytes": [sorted(set(x[1] for x in group)) for group in by_source],
                              "objective64": float(diag[-2]), "kkt64": float(diag[-1]),
                              "identical_numerics_and_stopping": True})
    with (out / "raw.tsv").open("w") as file:
        writer = csv.writer(file, delimiter="\t")
        writer.writerow(["campaign", "case", "triplet", "position", "source", "seconds", "bytes", "gc_seconds",
                         "point_sha256", "minimum_bits", "iterations", "flags_and_residuals", "objective64", "kkt64"])
        writer.writerows(rows)
    if any(identity(root) != before for root, before in identities.items()):
        raise RuntimeError("source changed during measurements")
    if any(hashlib.sha256((here/name).read_bytes()).hexdigest() != digest
           for name, digest in harness.items()):
        raise RuntimeError("harness changed during measurements")
    (out / "summary.json").write_text(json.dumps({"workers": metadata,
        "blas_components_order_A1_A2_B_repeated_three_times": components,
        "compiled_modules": os.environ.get("PS_REFRESH_COMPILED_MODULES", "yes"),
        "affinity": sorted(os.sched_getaffinity(0)),
        "harness_sha256": harness,
        "sources": identities, "summaries": summaries}, indent=2)+"\n")
finally:
    for worker in workers:
        if worker.poll() is None:
            worker.stdin.write("quit\n")
            worker.stdin.flush()
            worker.wait(timeout=60)
    for log in logs:
        log.close()
