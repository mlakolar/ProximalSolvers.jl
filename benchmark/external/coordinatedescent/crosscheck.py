#!/usr/bin/env python3
"""Independently recompute certificates from hashed, column-major Float64 data.

For r=y-X beta, z=X'r/n, P=||r||^2/(2n)+lambda sum_j w_j|beta_j|,
t=min(1,min_{z_j!=0} lambda*w_j/|z_j|), theta=t*r/n and
D=y'theta-n||theta||^2/2. The weighted-L1 certificate is
max(P-D,0)/max(|P|,floatmin). Zero weights or lambda use the KKT residual.
Group lasso replaces the penalty with lambda sum_g w_g||beta_g|| and the
dual scale with min_g lambda*w_g/||z_g||. Uncovered free coordinates force
t=0 if their correlation is nonzero.

Square-root lasso uses P=||r||/sqrt(n)+lambda sum_j w_j|beta_j|,
theta=t*r/(sqrt(n)||r||), t=min(1,min_j lambda*w_j/|X_j'r/(sqrt(n)||r||)|),
and D=y'theta. Scaled lasso uses this profiled, weighted objective. A residual
norm <= 1e-12 is uncertifiable. Quadratic L1 uses the same least-squares
relative duality gap, restoring y'y/(2n) to the quadratic objective for
A=X'X/n and b=-X'y/n. Its matched targets remain relative gaps.
Feasible lasso recomputes w_j=sqrt(sum_i X_ij^2*r_i^2/n) and uses the
weighted-L1 gap at those loadings (self-consistency, not a convex certificate
for the entire outer iteration). Returned penalty objects are never used.

Each solve forms its residual without a Gram matrix, then makes one pass over
columns for correlations and, when needed, residual loadings. Raw arrays use
compact binary buffers. Every raw and coefficient checksum is checked before
use; every archived coefficient record is matched to its process metric.
Paths certify all levels and use their maximum value. Comparisons use relative
tolerance 1e-6 or absolute tolerance 1e-12. Uncertifiable recomputations match
only nonfinite recorded values; missing coefficients for finite values fail.
The final-sample-only archive can validate worst_value only when that final
sample actually attains it. A discrepancy is reported, never silently ignored.
"""

import argparse
from array import array
from collections import Counter
import csv
import hashlib
import math
from pathlib import Path
import sys

sys.dont_write_bytecode = True
sys.path.insert(0, str(Path(__file__).resolve().parent))
from analysis import ARMS, base_validate, logical_id, number, read_table


def checked_path(root, name):
    path = (root / name).resolve()
    if not path.is_relative_to(root.resolve()):
        raise ValueError(f"file outside artifact/output directory: {name}")
    return path


def sha256(path):
    with path.open("rb") as stream:
        return hashlib.file_digest(stream, "sha256").hexdigest()


def read_array(path, dtype="Float64", shape=None, finite=True):
    code = "q" if str(dtype).lower() in ("int64", "i64", "<i8") else "d"
    if str(dtype).lower() not in ("float64", "f64", "<f8", "int64", "i64", "<i8"):
        raise ValueError(f"unsupported array type: {dtype}")
    if path.stat().st_size % 8:
        raise ValueError(f"invalid raw file length: {path}")
    data = array(code)
    with path.open("rb") as stream:
        data.fromfile(stream, path.stat().st_size // 8)
    if sys.byteorder != "little":
        data.byteswap()
    if shape is not None and math.prod(shape) != len(data):
        raise ValueError(f"raw shape mismatch: {path}")
    if finite and code == "d" and any(not math.isfinite(value) for value in data):
        raise ValueError(f"nonfinite raw data: {path}")
    return data


def named_tables(value, label="id"):
    if isinstance(value, list):
        return {str(row.get(label, row.get("label", row.get("name", "")))): row for row in value}
    return value or {}


def file_descriptors(value):
    found = []
    if isinstance(value, dict):
        name = value.get("file", value.get("path", value.get("filename")))
        if isinstance(name, str) and "sha256" in value:
            found.append(dict(value, file=name))
        for key, child in value.items():
            if isinstance(child, dict) and "sha256" in child and not any(
                    field in child for field in ("file", "path", "filename")):
                found.extend(file_descriptors(dict(child, file=key)))
            else:
                found.extend(file_descriptors(child))
        # Also accept flat per-design descriptors such as X_file/X_sha256.
        for key, name in value.items():
            if key.endswith("_file") and isinstance(name, str) and key[:-5] + "_sha256" in value:
                stem = key[:-5]
                found.append(dict(file=name, sha256=value[stem + "_sha256"],
                                  shape=value.get(stem + "_shape"),
                                  dtype=value.get(stem + "_dtype", "Float64")))
    elif isinstance(value, list):
        for child in value:
            found.extend(file_descriptors(child))
    return found


class Artifact:
    def __init__(self, root):
        self.root = Path(root)
        manifest = self.root / "manifest.toml"
        self.manifest = base_validate.metadata(manifest)
        if self.manifest.get("byte_order", "little") != "little" or self.manifest.get(
                "storage_order", "column-major") != "column-major":
            raise ValueError("unsupported artifact byte/storage order")
        self.hash = sha256(manifest)
        self.designs = named_tables(self.manifest.get("design", self.manifest.get("designs")))
        self.cases = named_tables(self.manifest.get("case", self.manifest.get("cases")))
        self.files = {}
        self.cache = {}
        for descriptor in file_descriptors(self.manifest):
            name = descriptor["file"]
            path = checked_path(self.root, name)
            if sha256(path).lower() != str(descriptor["sha256"]).lower():
                raise ValueError(f"raw SHA-256 mismatch: {name}")
            shape = descriptor.get("shape")
            if shape is not None and (not shape or any(int(d) <= 0 for d in shape) or
                                      path.stat().st_size != 8 * math.prod(shape)):
                raise ValueError(f"raw shape mismatch: {name}")
            if name in self.files and self.files[name]["sha256"] != descriptor["sha256"]:
                raise ValueError(f"conflicting raw descriptors: {name}")
            self.files[name] = descriptor
        raw = {str(path.relative_to(self.root)) for pattern in ("*.f64", "*.i64", "*.bin")
               for path in self.root.rglob(pattern)}
        if not self.files or raw - self.files.keys():
            raise ValueError(f"raw files missing SHA-256 descriptors: {sorted(raw - self.files.keys())}")

    def data(self, descriptor, shape=None, dtype="Float64"):
        if isinstance(descriptor, str):
            name = descriptor
        elif isinstance(descriptor, dict):
            name = descriptor.get("file", descriptor.get("path", descriptor.get("filename")))
        else:
            raise ValueError("missing raw array descriptor")
        if name not in self.files:
            raise ValueError(f"array has no checked SHA-256: {name}")
        info = self.files[name]
        return read_array(checked_path(self.root, name), info.get("dtype", dtype), info.get("shape") or shape)

    def design(self, label):
        if label not in self.cache:
            meta = self.designs[label]
            n, p = int(meta["n"]), int(meta["p"])
            files = meta.get("files", meta)
            x = self.data(files.get("X", files.get("x", files.get("X_file"))), [n, p])
            y = self.data(files.get("y", files.get("y_file")), [n])
            if len(x) != n * p or len(y) != n:
                raise ValueError("design dimensions disagree with raw arrays")
            self.cache[label] = (n, p, x, y, meta)
        return self.cache[label]


def residual(x, y, beta, n):
    r = list(y)
    for j, coefficient in enumerate(beta):
        if coefficient:
            offset = j * n
            for i in range(n):
                r[i] -= x[offset + i] * coefficient
    return r


def column_statistics(x, r, n, p, loadings=False):
    z, weights = [], []
    for j in range(p):
        offset = j * n
        z.append(math.fsum(x[offset + i] * r[i] for i in range(n)) / n)
        if loadings:
            weights.append(math.sqrt(math.fsum((x[offset + i] * r[i]) ** 2 for i in range(n)) / n))
    return z, weights


def relative_gap(primal, dual, scale, terms):
    if not all(math.isfinite(v) for v in (primal, dual, scale)):
        return math.nan
    gamma = terms * sys.float_info.epsilon / (1 - terms * sys.float_info.epsilon)
    if primal - dual < -16 * gamma * (abs(primal) + abs(dual) + scale):
        return math.nan
    return max(primal - dual, 0.0) / max(abs(primal), sys.float_info.min)


def l1_certificate(r, y, z, beta, lam, weights, n):
    if len(weights) != len(beta) or lam < 0 or any(w < 0 or not math.isfinite(w) for w in weights):
        raise ValueError("invalid L1 penalty")
    if lam == 0 or any(w == 0 for w in weights):
        return max((abs(-zj + lam * w * math.copysign(1, bj)) if bj else
                    max(abs(zj) - lam * w, 0.0)
                    for zj, bj, w in zip(z, beta, weights)), default=0.0)
    penalty = lam * math.fsum(w * abs(b) for w, b in zip(weights, beta))
    r2 = math.fsum(v * v for v in r)
    primal = r2 / (2 * n) + penalty
    t = min([1.0] + [lam * w / abs(v) for v, w in zip(z, weights) if v])
    dual = t * math.fsum(a * b for a, b in zip(y, r)) / n - t * t * r2 / (2 * n)
    scale = math.fsum(v * v for v in y) / (2 * n) + penalty
    return relative_gap(primal, dual, scale, max(n, len(beta)))


def group_certificate(r, y, z, beta, lam, groups, weights, n):
    indices = [j for group in groups for j in group]
    if (len(groups) != len(weights) or len(set(indices)) != len(indices) or
            any(j < 0 or j >= len(beta) for j in indices) or lam < 0 or
            any(w < 0 or not math.isfinite(w) for w in weights)):
        raise ValueError("invalid group penalty")
    norms = [math.sqrt(math.fsum(z[j] ** 2 for j in group)) for group in groups]
    penalty = lam * math.fsum(w * math.sqrt(math.fsum(beta[j] ** 2 for j in group))
                              for group, w in zip(groups, weights))
    t = min([1.0] + [lam * w / a for a, w in zip(norms, weights) if a])
    covered = set(indices)
    if any(v and j not in covered for j, v in enumerate(z)):
        t = 0.0
    r2 = math.fsum(v * v for v in r)
    primal = r2 / (2 * n) + penalty
    dual = t * math.fsum(a * b for a, b in zip(y, r)) / n - t * t * r2 / (2 * n)
    scale = math.fsum(v * v for v in y) / (2 * n) + penalty
    return relative_gap(primal, dual, scale, max(n, len(beta)))


def sqrt_certificate(r, y, z, beta, lam, weights, n, fit_floor=1e-12):
    norm = math.sqrt(math.fsum(v * v for v in r))
    if norm <= fit_floor:
        return math.nan
    if len(weights) != len(beta) or lam < 0 or any(w < 0 or not math.isfinite(w) for w in weights):
        raise ValueError("invalid square-root penalty")
    penalty = lam * math.fsum(w * abs(b) for w, b in zip(weights, beta))
    t = min([1.0] + [lam * w * norm / (math.sqrt(n) * abs(v))
                     for v, w in zip(z, weights) if v])
    primal = norm / math.sqrt(n) + penalty
    dual = t * math.fsum(a * b for a, b in zip(y, r)) / (math.sqrt(n) * norm)
    # Scale and fit floor use the unnormalized objective, as in the runner.
    scale = math.sqrt(math.fsum(v * v for v in y)) / math.sqrt(n) + penalty
    return relative_gap(primal, dual, scale, max(n, len(beta)))


def certificate(x, y, beta, n, p, estimator, lam, weights=None, groups=None, group_weights=None):
    if len(beta) != p or not all(math.isfinite(v) for v in beta):
        return math.nan
    r = residual(x, y, beta, n)
    z, recomputed = column_statistics(x, r, n, p, estimator == "feasible_lasso")
    if estimator == "group_lasso":
        return group_certificate(r, y, z, beta, lam, groups, group_weights, n)
    if estimator in ("sqrt_lasso", "scaled_lasso"):
        return sqrt_certificate(r, y, z, beta, lam, weights or [1.0] * p, n)
    if estimator == "feasible_lasso":
        if lam <= 0 or any(w <= 0 for w in recomputed):
            return math.nan
        weights = recomputed
    if estimator not in ("lasso", "weighted_lasso", "path", "quadratic", "feasible_lasso"):
        raise ValueError(f"unsupported estimator: {estimator}")
    return l1_certificate(r, y, z, beta, lam, weights if weights is not None else [1.0] * p, n)


def case_parameters(artifact, entry):
    case_id = logical_id(entry, {"case": list(artifact.cases.values())})
    case = artifact.cases.get(case_id, {})
    n, p, x, y, design = artifact.design(entry["design"])
    estimator = entry["estimator"]
    if case and any(str(case[field]) != str(entry[field]) for field in ("estimator", "design", "order")
                    if field in case):
        raise ValueError("artifact/catalog case definition mismatch")
    value = case.get("lambda_values", case.get("lambda_value", case.get("lambda")))
    if isinstance(value, str) or value is None:
        maximum = design.get("lambda_max", design.get("lambda_max_value"))
        if maximum is None:
            maximum = max(abs(math.fsum(x[j * n + i] * y[i] for i in range(n))) / n for j in range(p))
        if estimator == "path":
            value = case.get("lambdas", case.get("lambda_grid", design.get("lambda_path", design.get("lambda_grid"))))
        else:
            value = float(entry["lambda"]) * maximum
    if estimator == "path" and not isinstance(value, (list, dict)):
        value = case.get("lambdas", case.get("lambda_grid", design.get("lambda_path", design.get("lambda_grid"))))
    if isinstance(value, dict):
        value = list(artifact.data(value))
    if estimator == "path" and (not isinstance(value, list) or not value):
        raise ValueError(f"missing explicit path grid: {case_id}")
    if isinstance(value, list):
        lambdas = [float(v) for v in value]
    else:
        lambdas = [float(value)]
    if any(not math.isfinite(v) or v < 0 for v in lambdas):
        raise ValueError("invalid artifact lambda")
    if estimator != "path" and len(lambdas) != 1:
        raise ValueError("single solve requires one lambda")
    files = design.get("files", {})
    if estimator == "path" and "lambda_path" in files:
        grid = list(artifact.data(files["lambda_path"]))
        if grid != lambdas:
            raise ValueError("case path differs from artifact raw grid")
    if estimator == "weighted_lasso":
        weights = case.get("fixed_loadings", case.get("loadings", files.get("fixed_loadings", design.get("loadings"))))
    else:
        weights = case.get("weights", files.get("weights", design.get("loadings")))
    if isinstance(weights, (str, dict)):
        weights = list(artifact.data(weights, [p]))
    if estimator in ("weighted_lasso", "scaled_lasso") and weights is None:
        raise ValueError(f"missing fixed loadings: {case_id}")
    groups = case.get("groups", design.get("groups"))
    indices_spec = case.get("group_indices", files.get("group_indices"))
    offsets_spec = case.get("group_offsets", files.get("group_offsets"))
    if indices_spec is not None and offsets_spec is not None:
        indices = artifact.data(indices_spec, [p], "Int64")
        offsets = artifact.data(offsets_spec, dtype="Int64")
        if (offsets[0] != 1 or offsets[-1] != p + 1 or any(a >= b for a, b in zip(offsets, offsets[1:]))):
            raise ValueError("invalid group offsets")
        raw_groups = [list(indices[a - 1:b - 1]) for a, b in zip(offsets, offsets[1:])]
        if groups is not None and groups != raw_groups:
            raise ValueError("group indices disagree with manifest groups")
        groups = raw_groups
    if isinstance(groups, (str, dict)):
        labels = artifact.data(groups, [p], "Int64")
        groups = [[j + 1 for j, label in enumerate(labels) if label == group]
                  for group in sorted(set(labels))]
    if groups is not None:
        groups = [[int(j) - 1 for j in group] for group in groups]
    if estimator == "group_lasso" and groups is None:
        raise ValueError(f"missing group indices: {case_id}")
    group_weights = case.get("group_weights", design.get("group_weights", files.get("group_weights", [1.0] * len(groups or []))))
    if isinstance(group_weights, (str, dict)):
        group_weights = list(artifact.data(group_weights, [len(groups or [])]))
    return (x, y, n, p, estimator, lambdas, weights, groups, group_weights)


def coefficient_rows(root):
    result = []
    manifests = sorted(root.rglob("coef/manifest.tsv"))
    for manifest in manifests:
        with manifest.open(newline="", encoding="utf-8") as stream:
            reader = csv.DictReader(stream, delimiter="\t")
            if not reader.fieldnames or not {"id", "setting_index", "rep", "sha256"} <= set(reader.fieldnames):
                raise ValueError(f"wrong coefficient manifest header: {manifest}")
            for row in reader:
                if None in row or None in row.values():
                    raise ValueError("wrong coefficient manifest field count")
                name = row.get("file", row.get("path", row.get("filename")))
                if name is None:
                    name = f"{row['id']}__{row['setting_index']}__rep{int(row['rep']):02d}.f64"
                path = checked_path(manifest.parent, name)
                if not path.exists() and str(name).startswith("coef/"):
                    path = checked_path(manifest.parent.parent, name)
                if sha256(path).lower() != row["sha256"].lower():
                    raise ValueError(f"coefficient SHA-256 mismatch: {path}")
                result.append((manifest.parent.parent, path, row))
    listed = {path for _, path, _ in result}
    raw = {path.resolve() for path in root.rglob("coef/**/*.f64")}
    if raw - listed:
        raise ValueError("coefficient files missing from SHA-256 manifest")
    return result


def crosscheck(artifact_root, arms_root):
    artifact, arms_root = Artifact(artifact_root), Path(arms_root)
    counts, issues = Counter(), []
    for side in ARMS:
        folder = arms_root / side
        if not folder.is_dir():
            issues.append(f"missing arm: {side}")
            continue
        finals = sorted(folder.rglob("*-metadata.toml"))
        if not finals:
            issues.append(f"no process records: {side}")
        metrics = {}
        for final in finals:
            prefix = final.name.removesuffix("-metadata.toml")
            meta = base_validate.metadata(final)
            if meta["artifact_sha256"].lower() != artifact.hash.lower():
                raise ValueError(f"artifact manifest SHA-256 mismatch: {final}")
            catalog = {row["id"]: row for row in read_table(final.with_name(prefix + "-catalog.tsv"), "catalog", meta)}
            for metric in read_table(final.with_name(prefix + "-metrics.tsv"), "metrics"):
                entry = catalog[metric["id"]]
                key = (final.parent.resolve(), metric["id"], int(entry["setting_index"]), int(metric["rep"]))
                if key in metrics:
                    raise ValueError("ambiguous coefficient/metric identity; separate views into output directories")
                metrics[key] = (entry, metric)
        seen = set()
        for parent, path, row in coefficient_rows(folder):
            key = (parent.resolve(), row["id"], int(row["setting_index"]), int(row["rep"]))
            if key in seen or key not in metrics:
                raise ValueError(f"duplicate or foreign coefficient: {path}")
            seen.add(key)
            entry, metric = metrics[key]
            x, y, n, p, estimator, lambdas, weights, groups, group_weights = case_parameters(artifact, entry)
            expected_measure = "self_consistency" if estimator == "feasible_lasso" else "relative_gap"
            if metric["measure"] != expected_measure:
                issues.append(f"certificate measure mismatch: {side}/{entry['id']}: "
                              f"{metric['measure']} != {expected_measure}")
            if row.get("dtype", "Float64") != "Float64":
                raise ValueError("coefficients must be Float64")
            beta = read_array(path, finite=False)
            if "rows" in row and (int(row["rows"]) != p or
                                  int(row["rows"]) * int(row["columns"]) != len(beta)):
                issues.append(f"coefficient manifest shape mismatch: {path}")
            grid_matches = (estimator != "path" or "lambda_values" not in row or
                            [float(value) for value in row["lambda_values"].split(",") if value] == lambdas)
            if estimator == "path" and (not grid_matches or len(beta) != p * len(lambdas)):
                if (metric["status"] == "incomplete" and math.isnan(number(metric["worst_value"])) and
                        ("value" not in row or math.isnan(number(row["value"])))):
                    counts["incomplete_archives"] += 1
                    counts["coefficients"] += 1
                    continue
                issues.append(f"coefficient path grid/shape mismatch: {path}")
                continue
            if len(beta) != p * len(lambdas):
                issues.append(f"coefficient/path shape mismatch: {path}")
                continue
            values = [certificate(x, y, beta[level * p:(level + 1) * p], n, p,
                                  estimator, lam, weights, groups, group_weights)
                      for level, lam in enumerate(lambdas)]
            observed = max(values) if all(math.isfinite(v) for v in values) else math.nan
            recorded = number(metric["worst_value"])
            counts["coefficients"] += 1
            counts["levels"] += len(values)
            if (math.isnan(observed) and math.isnan(recorded)) or math.isclose(
                    observed, recorded, rel_tol=1e-6, abs_tol=1e-12):
                counts["matched"] += 1
            else:
                issues.append(f"{side}/{entry['id']}/rep{metric['rep']}: "
                              f"recomputed={observed:.17g}, worst_value={recorded:.17g}")
            if "value" in row:
                final_value = number(row["value"])
                if not ((math.isnan(observed) and math.isnan(final_value)) or math.isclose(
                        observed, final_value, rel_tol=1e-6, abs_tol=1e-12)):
                    issues.append(f"coefficient final-sample value mismatch: {path}")
        for key, (entry, metric) in metrics.items():
            if key not in seen:
                if math.isfinite(number(metric["worst_value"])):
                    issues.append(f"missing coefficients for finite certificate: {side}/{entry['id']}/rep{metric['rep']}")
                elif metric["status"] == "ok":
                    issues.append(f"ok record has no certificate: {side}/{entry['id']}")
                else:
                    counts["failed_without_coefficients"] += 1
    for issue in issues:
        print(f"MISMATCH {issue}")
    print(f"CROSSCHECK raw_files={len(artifact.files)} coefficients={counts['coefficients']} "
          f"levels={counts['levels']} matched={counts['matched']} "
          f"incomplete_archives={counts['incomplete_archives']} "
          f"failed_without_coefficients={counts['failed_without_coefficients']} mismatches={len(issues)}")
    return not issues


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("artifact", type=Path)
    parser.add_argument("arms_dir", type=Path)
    args = parser.parse_args()
    try:
        valid = crosscheck(args.artifact, args.arms_dir)
    except (OSError, ValueError, KeyError, TypeError, OverflowError, csv.Error) as error:
        parser.exit(2, f"CROSSCHECK FAILED: {error}\n")
    raise SystemExit(0 if valid else 2)


if __name__ == "__main__":
    main()
