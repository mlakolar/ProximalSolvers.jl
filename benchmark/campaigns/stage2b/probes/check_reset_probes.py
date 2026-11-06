#!/usr/bin/env python3
"""Check the output of probes/reset_semantics.jl on one or two ProximalBase versions.

The probe prints `key<TAB>value` lines. This checker turns them into per-case reset
verdicts for the Stage 2B comparability mapping (CASE_MAPPING.md). It reads files only.

  check_reset_probes.py --a reset-054.tsv [--b reset-master.tsv]

Every probe file is checked on its own (`--a`, and `--b` when given), then compared:

* the ported reset of the P14 path (`dropzeros!(fill!(x, 0.0))`) must leave an empty
  working set and zero values, and must leave the same state on A and on B;
* the AtomIterate reset of P04 and P05 (`copyto!(x, start)`) must restore values and
  the active-group layout, twice in a row, from a cold start and from warm starts;
* the historical P14 reset (`fill!(x, 0.0)`) is reported, not required: when it keeps
  active coordinates the case needs the reviewed port (class B);
* an `ERROR` value in a required observation, a missing key or a malformed line is a
  failure, never skipped.

Exit status: 0 when every required invariant holds, 1 when one fails, 2 on a usage or
format error. The report is printed on stdout; the last line is the verdict.
"""

import argparse
import sys

ATOM_CASES = ("cold_start", "warm_start", "warm_overlap")

SPARSE_REQUIRED_TRUE = (
    "sparse.fill0_dropzeros.all_values_zero",
    "sparse.fill0_dropzeros.matches_fresh_workingset",
)
ATOM_REQUIRED_TRUE = tuple(
    f"atom.{case}.{what}"
    for case in ATOM_CASES
    for what in (
        "after.matches_start_values",
        "after.matches_start_active",
        "repeat.matches_start_active",
        "repeat.matches_start_values",
    )
)
SETUP_KEYS = ("setup.has_svd_cache_fn", "setup.svd_cache_call", "setup.field.V",
              "setup.field.s2", "setup.field.sUtY")
# Observations that must be equal on A and on B after the ported reset.
SAME_ON_A_AND_B = (
    "sparse.fill0_dropzeros.nactive",
    "sparse.fill0_dropzeros.active",
    "sparse.fresh.nactive",
    "sparse.fresh.active",
) + tuple(f"atom.{c}.after.active" for c in ATOM_CASES) + tuple(
    f"atom.{c}.after.nactive" for c in ATOM_CASES
)


class ProbeError(Exception):
    pass


def parse(text, name):
    """Parse probe output. Duplicate keys, blank keys and lines without a tab are errors."""
    out = {}
    for number, line in enumerate(text.splitlines(), 1):
        if not line.strip():
            continue
        if "\t" not in line:
            raise ProbeError(f"{name}:{number}: no tab in line {line!r}")
        key, value = line.split("\t", 1)
        if not key:
            raise ProbeError(f"{name}:{number}: empty key")
        if key in out:
            raise ProbeError(f"{name}:{number}: duplicate key {key!r}")
        out[key] = value
    return out


def check_one(obs, name):
    """Return (failures, facts) for one probe file."""
    failures, facts = [], {}

    def need(key):
        if key not in obs:
            failures.append(f"{name}: missing observation {key}")
            return None
        if obs[key].startswith("ERROR"):
            failures.append(f"{name}: {key} raised: {obs[key]}")
            return None
        return obs[key]

    for key in ("probe.proximalbase_version", "probe.julia"):
        need(key)
    for key in SPARSE_REQUIRED_TRUE + ATOM_REQUIRED_TRUE:
        value = need(key)
        if value is not None and value != "true":
            failures.append(f"{name}: {key} is {value!r}, required 'true'")
    for key in ("sparse.fill0_dropzeros.nactive", "sparse.fresh.nactive"):
        value = need(key)
        if key.endswith("fill0_dropzeros.nactive") and value not in (None, "0"):
            failures.append(f"{name}: the ported reset leaves {value} active coordinates")

    historical = obs.get("sparse.fill0.matches_fresh_workingset")
    facts["P14 historical reset fill!(x, 0.0) reproduces the empty working set"] = historical
    facts["P14 active coordinates kept by the historical reset"] = obs.get("sparse.fill0.nactive")
    facts["P14 reviewed port needed"] = (
        "yes" if historical == "false" else "no" if historical == "true" else "unknown")
    facts["P04/P05 AtomIterate reset reproduces values and layout"] = (
        "yes" if all(obs.get(k) == "true" for k in ATOM_REQUIRED_TRUE) else "no")
    facts["P13 private cache interface present"] = (
        "yes" if all(obs.get(k) in ("true", "ok") for k in SETUP_KEYS) else "no")
    facts["QUIC LogDetLoss throws on an asymmetric matrix"] = (
        "yes" if obs.get("quic.logdet.asymmetric_matrix", "").startswith("ERROR") else "no")
    facts["symmetric owner is an AbstractMatrix"] = obs.get("owner.is_abstractmatrix", "unknown")
    facts["symmetric owner has field p"] = obs.get("owner.has_p_field", "unknown")
    return failures, facts


def compare(a, b):
    failures = []
    for key in SAME_ON_A_AND_B:
        if key not in a or key not in b:
            failures.append(f"cannot compare {key}: missing on A or on B")
        elif a[key] != b[key]:
            failures.append(f"{key} differs: A={a[key]!r} B={b[key]!r}")
    # A comparison across Julia versions would pool different inputs: refuse it.
    if a.get("probe.julia") != b.get("probe.julia"):
        failures.append(
            f"A ran on Julia {a.get('probe.julia')}, B on Julia {b.get('probe.julia')}: "
            "compare probes of one Julia version only")
    return failures


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__.split("\n\n")[0])
    parser.add_argument("--a", required=True, help="probe output on stack A (ProximalBase 0.5.4)")
    parser.add_argument("--b", help="probe output on stack B (the 0.6 candidate)")
    args = parser.parse_args(argv)
    try:
        sides = {}
        for label, path in (("A", args.a), ("B", args.b)):
            if path is None:
                continue
            with open(path, encoding="utf-8") as handle:
                sides[label] = parse(handle.read(), path)
    except (OSError, ProbeError) as err:
        print(f"usage or format error: {err}", file=sys.stderr)
        return 2
    failures = []
    for label, obs in sides.items():
        problems, facts = check_one(obs, f"{label} ({obs.get('probe.proximalbase_version')})")
        failures += problems
        print(f"## {label}: ProximalBase {obs.get('probe.proximalbase_version')}, "
              f"Julia {obs.get('probe.julia')}")
        for key, value in facts.items():
            print(f"  {key}: {value}")
    if "B" in sides:
        failures += compare(sides["A"], sides["B"])
    for failure in failures:
        print(f"FAIL {failure}")
    print("RESET PROBE: FAIL" if failures else "RESET PROBE: PASS")
    return 1 if failures else 0


if __name__ == "__main__":
    sys.exit(main())
