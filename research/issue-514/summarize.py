#!/usr/bin/env python3
"""Read the raw #514 tables and regenerate the grouped evidence."""
import argparse
from collections import Counter, defaultdict
import csv
import gzip
from hashlib import sha256
import json
from pathlib import Path
from statistics import median

VERSIONS = ("1.10.13", "1.13.4")

def read_tsv(path):
    if path.exists():
        with path.open(newline="") as stream:
            return list(csv.DictReader(stream, delimiter="\t"))
    with gzip.open(str(path) + ".gz", "rt", newline="") as stream:
        return list(csv.DictReader(stream, delimiter="\t"))

def count(rows, key):
    return sum(row[key] == "true" for row in rows)

def grouped(rows, cols):
    groups = defaultdict(list)
    for row in rows:
        groups[tuple(row[c] for c in cols)].append(row)
    return groups

def quantile(data, prob):
    sorted_data = sorted(data)
    x = prob * (len(sorted_data) - 1)
    lo = int(x)
    hi = min(len(sorted_data) - 1, lo + 1)
    return sorted_data[lo] + (x-lo) * (sorted_data[hi]-sorted_data[lo])

def ratio(rows, lhs, rhs):
    return [float(r[rhs])/float(r[lhs]) for r in rows]

def numerical(root):
    all_rows, historical, probes = [], [], []
    parity = []
    for version in VERSIONS:
        for bounds in ("auto", "yes"):
            directory = root / f"{version}-{bounds}"
            r = read_tsv(directory / "solves.tsv")
            vec = read_tsv(directory / "vectors.tsv")
            assert len(r) == len(vec)
            for row, vector in zip(r, vec, strict=True):
                assert all(row[k] == vector[k] for k in ("T", "case", "method", "profile", "arm"))
                raw = bytes.fromhex(vector["x"])
                assert len(raw) == int(row["p"]) * (4 if row["T"] == "Float32" else 8)
                assert sha256(raw).hexdigest() == row["output_sha256"]
            assert all(sum(int(a[k]) for k in ("trial_parity", "mapping_parity")) == int(a["projections"]) for a in r)
            assert all(a["cap_refines"] == "0" and a["stop_refines"] == "0" for a in r if a["arm"] == "B")
            sign_errors = [a for a in r if a["success"] == "true" and (
                (a["membership"] == "inside" and float(a["violation"]) > 0) or
                (a["membership"] == "outside" and float(a["violation"]) == 0)
            )]
            assert not sign_errors, sign_errors
            rb = [a for a in r if a["arm"] == "B" and a["ball"] == "l1"]
            rc = [a for a in r if a["arm"] == "C"]
            assert len(rb) == len(rc)
            pairs = zip(rb, rc, strict=True)
            checks = Counter()
            for b, c in pairs:
                assert all(b[k] == c[k] for k in ("T", "case", "method", "profile"))
                checks["cells"] += 1
                checks["same_trial_hash"] += b["trial_sha256"] == c["trial_sha256"]
                checks["same_mapping_hash"] += b["mapping_sha256"] == c["mapping_sha256"]
                checks["same_output"] += b["output_sha256"] == c["output_sha256"]
                checks["different_success"] += b["success"] != c["success"]
                checks["C_only_success"] += c["success"] == "true" and b["success"] == "false"
                checks["B_only_success"] += b["success"] == "true" and c["success"] == "false"
            parity.append(dict(version=version, bounds=bounds, **checks))
            for a in r:
                all_rows.append(dict(version=version, bounds=bounds, **a))
            for a in read_tsv(directory / "historical.tsv"):
                historical.append(dict(version=version, bounds=bounds, **a))
            for typ in ("Float32", "Float64"):
                for a in read_tsv(directory / f"projections-{typ}.tsv"):
                    probes.append(dict(version=version, bounds=bounds, **a))
    by_arm = []
    for (ball, profile, arm), rows in sorted(grouped(all_rows, ("ball", "profile", "arm")).items()):
        statuses = Counter(r["status"] for r in rows)
        good = [r for r in rows if r["success"] == r["acceptable"] == "true"]
        status = dict(ball=ball, profile=profile, arm=arm, cells=len(rows),
                      success=count(rows,"success"), acceptable_stops=len(good), exact_label=count(rows,"converged"),
                      false=count(rows,"false_success"), exact_exterior_stops=sum(float(r["violation"])>0 for r in good),
                      accepted_exterior=sum(int(r["accepted_exterior"]) for r in rows),
                      trial_parity=sum(int(r["trial_parity"]) for r in rows),
                      mapping_parity=sum(int(r["mapping_parity"]) for r in rows),
                      stop_refines=sum(int(r["stop_refines"]) for r in rows),
                      trial_refines=sum(int(r["cap_refines"]) for r in rows),
                      feasibility_rejects=sum(int(r["feasibility_rejects"]) for r in rows),
                      unresolved_rejects=sum(int(r["unresolved_rejects"]) for r in rows),
                      statuses=dict(statuses))
        by_arm.append(status)
    boundary = []
    for (ball, cap), rows in grouped(probes, ("ball", "cap")).items():
        if float(cap) == 0:
            boundary.extend(rows)
    coverage = dict(cells=len(all_rows), histories=len(historical), probes=len(probes),
                    projection_checks=sum(int(r["trial_parity"])+int(r["mapping_parity"]) for r in all_rows),
                    b_c_parity=parity)
    old = [dict(arm=arm, cells=len(rows), stops=count(rows,"converged"),
                false_exact=count(rows,"false_exact_feasibility"), false_gap=count(rows,"false_gap"))
           for (arm,),rows in sorted(grouped(historical,("arm",)).items())]
    sign = [dict(ball=ball, cells=len(rows), B_unknown=sum(r["B_sign"] == "unknown" for r in rows),
                 C_unknown=sum(r["C_sign"] == "unknown" for r in rows),
                 C_decided_where_B_unresolved=sum(r["B"] == "unresolved" and r["C"] in ("pass","over") for r in rows))
            for (ball,),rows in sorted(grouped(boundary,("ball",)).items())]
    return dict(coverage=coverage, by_arm=by_arm, historical=old, fixed_sign=sign)

def timing(root):
    files = {}
    metadata = {"e2e": (("T", "case", "p", "ball", "method", "a_arm", "b_arm"), "solves"),
                "fixed": (("T", "p", "shape", "ball", "a_arm", "b_arm"), "fixed"),
                "clipping": (("T", "control", "method"), "clipping")}
    for label, (group_keys, file) in metadata.items():
        files[label] = []
        for version in VERSIONS:
            all_rows = []
            for warm in ("forward", "reverse"):
                directory = root / f"{version}-{warm}"
                all_rows.extend(read_tsv(directory / (file + ".tsv")))
            for key, rows in sorted(grouped(all_rows, group_keys).items()):
                row = dict(version=version, **dict(zip(group_keys,key)))
                assert len(rows) == 32, (row,len(rows))
                time_ratios = ratio(rows,"a_ns","b_ns")
                null_ratios = ratio(rows,"aa_a_ns","aa_b_ns")
                order = {}
                for (warm, execution), pair in sorted(grouped(rows,("warm_order","order")).items()):
                    assert len(pair) == 8
                    key_name = warm+"_"+execution
                    order[key_name] = median(ratio(pair,"a_ns","b_ns"))
                for name in ("a_ns","b_ns","a_bytes","b_bytes","a_count","b_count","aa_a_bytes","aa_b_bytes"):
                    row[name] = median(float(r[name]) for r in rows)
                row["ratio"] = median(time_ratios)
                row["ratio_p10"], row["ratio_p90"] = (quantile(time_ratios,q) for q in (0.1,0.9))
                row["aa_ratio"] = median(null_ratios)
                row["aa_p10"], row["aa_p90"] = (quantile(null_ratios,q) for q in (0.1,0.9))
                row["by_order"] = order
                row["repeatable_gt5"] = min(order.values()) > max(1.05, row["aa_p90"])
                if label == "e2e":
                    for name in ("a_status","b_status","a_claimed","b_claimed","a_accurate","b_accurate",
                                 "a_iterations","b_iterations","a_gradients","b_gradients","a_projections",
                                 "b_projections","a_gap","b_gap","a_violation","b_violation"):
                        assert len({r[name] for r in rows}) == 1
                        row[name] = rows[0][name]
                if label == "fixed":
                    assert len({r["output_sha256"] for r in rows}) == 1
                files[label].append(row)
    return files

if __name__ == "__main__":
    cli = argparse.ArgumentParser(description=__doc__)
    cli.add_argument("kind", choices=["numerical","timing"])
    cli.add_argument("directory", type=Path)
    options = cli.parse_args()
    data = numerical(options.directory) if options.kind == "numerical" else timing(options.directory)
    print(json.dumps(data, indent=2, sort_keys=True))
