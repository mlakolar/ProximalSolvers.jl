"""Verify the complete recorded protocol grid and reproducible summaries."""
import csv
import itertools
import subprocess
import sys
import tempfile
from pathlib import Path

FIELDS = ("family", "p", "kappa", "seed", "lambda_fraction", "round", "method", "initialization")


def expected_identities(phase):
    seeds, rounds = (range(1, 11), range(1, 4)) if phase == "main" else (range(11, 16), range(1, 3))
    expected = set()
    for family, p, kappa, seed, fraction, repetition in itertools.product(
        ("ls", "logistic", "huber", "poisson", "quartic"),
        (100, 500), (1.0, 100.0, 10000.0), seeds, (0.05, 0.005), rounds,
    ):
        initializations = ("tiny", "reference", "large", "extreme")
        if family == "quartic":
            initializations += ("unit",)
        if phase == "confirmation":
            initializations = ("unit" if family == "quartic" else "reference",)
        methods = [("adaPGM", init) for init in initializations] + [("PG", "default"), ("APG", "default")]
        for method, initialization in methods:
            expected.add((family, p, kappa, seed, fraction, repetition, method, initialization))
    return expected


def validate_grid(rows, phase):
    identities = [
        (r["family"], int(r["p"]), float(r["kappa"]), int(r["seed"]),
         float(r["lambda_fraction"]), int(r["round"]), r["method"], r["initialization"])
        for r in rows
    ]
    actual = set(identities)
    assert len(actual) == len(identities), "duplicate experiment identity"
    expected = expected_identities(phase)
    assert actual == expected, f"{phase}: {len(expected - actual)} missing, {len(actual - expected)} unexpected identities"


def main():
    root = Path(__file__).resolve().parent
    evidence = root / "evidence" / "20261025"
    with tempfile.TemporaryDirectory() as td:
        for phase in ("main", "confirmation"):
            files = sorted(evidence.glob(f"{phase}-[1-4].csv"))
            assert len(files) == 4
            rows = []
            for file in files:
                with file.open() as handle:
                    rows.extend(csv.DictReader(handle))
            validate_grid(rows, phase)
            out = Path(td) / phase
            subprocess.run([sys.executable, str(root / "summarize.py"), *map(str, files),
                            "--phase", phase, "--expected", str(len(expected_identities(phase))),
                            "--out", str(out)], check=True, capture_output=True)
            summaries = sorted((evidence / f"{phase}-summary").iterdir())
            assert {p.name for p in summaries} == {"gate.json", "primary.json", "strata.csv", "initializations.json", "conditioning.json"}
            for saved in summaries:
                assert saved.read_bytes() == (out / saved.name).read_bytes(), f"summary differs: {saved}"
            print(f"{phase}: {len(rows)} exact identities; all summaries reproduced")
    print("EVIDENCE_CHECKS_PASSED")


if __name__ == "__main__":
    main()
