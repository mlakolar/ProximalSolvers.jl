#!/usr/bin/env python3
"""Analyze the CoordinateDescent comparison using independent process blocks.

For case c and block b, m[s,c,b] is the median of all timed process samples,
and L[c,b] = log(m[current,c,b]) - log(m[legacy,c,b]). A case estimate is
mu[c] = sum_b L[c,b]/N. Its 95% interval is mu +/- t[.975,N-1]*s/sqrt(N),
where s^2 = sum_b (L[c,b]-mu)^2/(N-1). Estimates and endpoints are exponentiated
for current/legacy ratios. N < 2 gives an unavailable interval. Failed matched
cases have no ratio; defaults retain timings from numerical failures when every
timed call completes. Every case and every failure remains in the output.

For a group of C eligible cases, G[b] = sum_c L[c,b]/C. Resample N whole
blocks with replacement 10,000 times using seed 117; each replicate is the mean
of the sampled G[b]. The group interval is the .025 and .975 empirical quantile
(linear interpolation at (B-1)*p). Cases have equal weight, irrespective of time.

A/A observations are Z = |log(m[current])-log(m[current-AA])|, pooled across
cases and blocks within each view/target. For n observations and p = .95, let
k be the smallest integer in 1..n such that
sum_{j=0}^{k-1} binom(n,j)*p^j*(1-p)^(n-j) >= .95. Then q = Z_(k) is an
upper 95% confidence bound for the population 95th percentile, under independent
identically distributed observations (conservative with atoms). A finite bound
exists only if 1-p^n >= .95 (n >= 59); otherwise q = +infinity. The noise floor
is delta = max(log(1.05),q). Correlated cases within blocks do not establish the
iid condition; the nominal pooled order-statistic coverage is conditional on it.

A candidate has its log-interval lower endpoint strictly above delta. The
one-sided p-value for H0: mu <= delta is 1-F_t((mu-delta)/(s/sqrt(N)),N-1).
F_t(t,nu) = 1 - I_{nu/(nu+t^2)}(nu/2,1/2)/2 for t >= 0, and its reflected
value for t < 0. The regularized beta uses a convergent continued fraction.
BH at alpha = .10 uses all estimable case p-values within each view/target:
sort p_(i), find largest i with p_(i) <= .10*i/M, reject ranks 1..i.
Candidates passing BH are screened candidates, never independently confirmed.
An interval overlapping [-delta,delta] is "inconclusive, not a tie".

Calibration: at the sole target T=1e-4, a rung is eligible only when every
process has a valid certificate <= T and completes every timed call. Cost is the
arithmetic mean of process medians. Minimize (cost, setting_index), so exact ties
favor the looser rung. Worst value is the maximum over every process/sample;
overshoot = T/worst_value (infinity at zero). Selection and inference use separate
campaigns. No confirmation setting is selected from confirmation timings.
Calibration requires legacy and current only; current-AA is optional and never
contributes to selection costs or eligibility. Confirmation requires all arms.
The coordinate family comprises indices 1..len(ladder); gap_ladder follows it.
Legacy selects coordinate settings once for both matched views. Current selects
coordinate settings for the primary view and all available rungs for the secondary
best view. Every minimization uses the same (cost, setting_index) rule above.
Confirmation requires --selection FILE and runs the union of selected indices
across families and targets. Shared records have target=NaN and metadata lists
accuracy_targets; each target reuses the appropriate setting_index observations.
For each observed target, the selection file supplies the case population. Each
view pairs its selected current index with the legacy coordinate index by block;
its A/A noise uses only the current and current-AA records at that same index.
Case intervals, bootstrap groups and BH families stay separate by view and target.

Support at each returned level is S={j: |beta_j| > 1e-4*max_k |beta_k|}.
Support differences are |S symmetric_difference S_ref|, by block and level.
The reference is current's tightest calibration rung, only if it certifies to
1e-6 in every process, 100 times tighter than the matched target. Missing
coefficients or references remain unavailable.
"""

import argparse
from collections import Counter, defaultdict
import csv
import hashlib
import json
import math
from pathlib import Path
import random
import re
import statistics
import sys
import tomllib

# The shared helpers describe the original records, without its ten-run limit.
sys.dont_write_bytecode = True
sys.path.insert(0, str(Path(__file__).resolve().parents[2]))
import validate as base_validate
from summarize import markdown, write_csv


ARMS = ("legacy", "current", "current-AA")
TARGETS = (1e-4,)
BOOTSTRAPS = 10_000
SEED = 117
VIEW_ORDER = ("primary", "secondary", "defaults")
VIEW_LABELS = {"primary": "Primary matched view (like-for-like; regression monitor)",
               "secondary": "Secondary matched view (best available)",
               "defaults": "Defaults view"}
VIEW_FAMILIES = {"primary": "coordinate", "secondary": "best", "defaults": "defaults"}
EXTRA_CATALOG = "estimator design lambda order setting_index stopping".split()
number = base_validate.number


def beta_fraction(a, b, x):
    tiny, tolerance = 1e-300, 3e-14
    qab, qap, qam = a + b, a + 1, a - 1
    c, d = 1.0, 1 - qab * x / qap
    d = 1 / (d if abs(d) > tiny else tiny)
    h = d
    for m in range(1, 10001):
        aa = m * (b - m) * x / ((qam + 2 * m) * (a + 2 * m))
        d, c = 1 + aa * d, 1 + aa / c
        d = 1 / (d if abs(d) > tiny else tiny)
        c = c if abs(c) > tiny else tiny
        h *= d * c
        aa = -(a + m) * (qab + m) * x / ((a + 2 * m) * (qap + 2 * m))
        d, c = 1 + aa * d, 1 + aa / c
        d = 1 / (d if abs(d) > tiny else tiny)
        c = c if abs(c) > tiny else tiny
        change = d * c
        h *= change
        if abs(change - 1) <= tolerance:
            return h
    raise ValueError("incomplete beta fraction did not converge")


def regularized_beta(x, a, b):
    if not (0 <= x <= 1 and a > 0 and b > 0):
        raise ValueError("invalid incomplete beta arguments")
    if x in (0, 1):
        return float(x)
    factor = math.exp(math.lgamma(a + b) - math.lgamma(a) - math.lgamma(b)
                      + a * math.log(x) + b * math.log1p(-x))
    if x < (a + 1) / (a + b + 2):
        value = factor * beta_fraction(a, b, x) / a
    else:
        value = 1 - factor * beta_fraction(b, a, 1 - x) / b
    return min(1.0, max(0.0, value))


def t_survival(t, df):
    if df < 1 or math.isnan(t):
        raise ValueError("invalid Student-t arguments")
    if math.isinf(t):
        return 0.0 if t > 0 else 1.0
    tail = regularized_beta(df / (df + t * t), df / 2, 0.5) / 2
    return tail if t >= 0 else 1 - tail


def t_cdf(t, df):
    return t_survival(-t, df)


def t_quantile(p, df):
    if not 0 < p < 1 or df < 1:
        raise ValueError("invalid Student-t quantile arguments")
    if p < 0.5:
        return -t_quantile(1 - p, df)
    lo, hi = 0.0, 1.0
    while t_cdf(hi, df) < p:
        hi *= 2
    for _ in range(80):
        mid = (lo + hi) / 2
        if t_cdf(mid, df) < p:
            lo = mid
        else:
            hi = mid
    return (lo + hi) / 2


def mean_interval(values):
    mu = statistics.mean(values) if values else math.nan
    if len(values) < 2:
        return mu, math.nan, math.nan
    half = t_quantile(.975, len(values) - 1) * statistics.stdev(values) / math.sqrt(len(values))
    return mu, mu - half, mu + half


def one_sided_p(values, delta):
    if len(values) < 2 or not math.isfinite(delta):
        return math.nan
    difference = statistics.mean(values) - delta
    se = statistics.stdev(values) / math.sqrt(len(values))
    if se == 0:
        return 0.0 if difference > 0 else 1.0 if difference < 0 else 0.5
    return t_survival(difference / se, len(values) - 1)


def bh_decisions(pvalues, alpha=.10):
    ordered = sorted((p, key) for key, p in pvalues.items() if math.isfinite(p))
    cutoff = 0
    for rank, (p, _) in enumerate(ordered, 1):
        if not 0 <= p <= 1:
            raise ValueError("p-value outside [0,1]")
        if p <= alpha * rank / len(ordered):
            cutoff = rank
    return {key for _, key in ordered[:cutoff]}


def quantile(values, probability):
    ordered = sorted(values)
    position = (len(ordered) - 1) * probability
    lower, upper = math.floor(position), math.ceil(position)
    return ordered[lower] + (ordered[upper] - ordered[lower]) * (position - lower)


def block_bootstrap(case_logs, resamples=BOOTSTRAPS, seed=SEED):
    if not case_logs:
        return math.nan, math.nan, math.nan
    n = len(case_logs[0])
    if not n or any(len(values) != n for values in case_logs):
        raise ValueError("bootstrap requires the same blocks for every case")
    blocks = [statistics.mean(values[b] for values in case_logs) for b in range(n)]
    mu = statistics.mean(blocks)
    if n < 2:
        return mu, math.nan, math.nan
    rng = random.Random(seed)
    draws = [sum(blocks[rng.randrange(n)] for _ in range(n)) / n for _ in range(resamples)]
    return mu, quantile(draws, .025), quantile(draws, .975)


def order_statistic_rank(n, probability=.95, confidence=.95):
    if n < 1 or not 0 < probability < 1 or not 0 < confidence < 1:
        if n == 0:
            return None
        raise ValueError("invalid order-statistic arguments")
    if -math.expm1(n * math.log(probability)) < confidence:
        return None
    lo, hi = 1, n
    while lo < hi:
        k = (lo + hi) // 2
        # P(Binomial(n,p) <= k-1) = I_(1-p)(n-k+1,k).
        coverage = regularized_beta(1 - probability, n - k + 1, k)
        if coverage >= confidence:
            hi = k
        else:
            lo = k + 1
    return lo


def noise_floor(values):
    if any(not math.isfinite(value) or value < 0 for value in values):
        raise ValueError("invalid A/A observation")
    rank = order_statistic_rank(len(values))
    q = sorted(values)[rank - 1] if rank is not None else math.inf
    return dict(observations=len(values), rank=rank, q=q, delta=max(math.log(1.05), q),
                finite=rank is not None, confidence=.95, percentile=.95,
                validity="Nominal coverage requires iid pooled observations; within-block "
                         "case dependence is not covered by this bound.")


def read_table(path, kind, meta=None):
    if kind != "catalog":
        return base_validate.records(path, kind)
    original = None
    if meta is not None and "external_catalog" in meta:
        original = base_validate.records(path, "catalog")
        name = meta["external_catalog"]
        if not isinstance(name, str) or not name or Path(name).is_absolute():
            raise ValueError("external_catalog must be a relative path")
        external = (path.parent / name).resolve()
        if not external.is_relative_to(path.parent.resolve()):
            raise ValueError("external_catalog leaves the process directory")
        path = external
    with path.open(newline="", encoding="utf-8") as stream:
        reader = csv.DictReader(stream, delimiter="\t")
        required = set(base_validate.HEADERS["catalog"] + EXTRA_CATALOG)
        if not reader.fieldnames or not required <= set(reader.fieldnames):
            raise ValueError(f"wrong catalog header in {path}")
        rows = list(reader)
    if any(None in row or None in row.values() for row in rows):
        raise ValueError(f"wrong catalog field count in {path}")
    if original is not None and original != [
            {key: row[key] for key in base_validate.HEADERS["catalog"]} for row in rows]:
        raise ValueError("external catalog disagrees with base catalog")
    return rows


def check_tables(tables, meta):
    base_validate.check_catalog([{key: row[key] for key in base_validate.HEADERS["catalog"]}
                                 for row in tables["catalog"]], meta)
    catalog = {row["id"]: row for row in tables["catalog"]}
    metrics = {row["id"]: row for row in tables["metrics"]}
    if (not catalog or len(catalog) != len(tables["catalog"]) or
            len(metrics) != len(tables["metrics"]) or catalog.keys() != metrics.keys() or
            len(catalog) != meta["cases"]):
        raise ValueError("catalog/metrics coverage mismatch or duplicate id")
    samples = defaultdict(dict)
    errors = {row["id"]: row for row in tables["errors"]}
    for sample in tables["samples"]:
        case, status = sample["id"], sample["status"]
        index = base_validate.integer(sample["sample"], "sample", 1)
        if case not in catalog or index in samples[case] or int(sample["rep"]) != meta["rep"]:
            raise ValueError("foreign or duplicate sample")
        if status not in base_validate.STATUSES:
            raise ValueError("unknown sample status")
        for key in ("time_ns", "gc_ns", "bytes"):
            if sample[key] or status != "error":
                base_validate.integer(sample[key], key)
        if sample["gc_ns"] and int(sample["gc_ns"]) > int(sample["time_ns"]):
            raise ValueError("GC time exceeds elapsed time")
        value, target = number(sample["value"]), number(catalog[case]["target"])
        if status == "ok" and (not math.isfinite(value) or value < 0 or value > target):
            raise ValueError("invalid ok certificate")
        samples[case][index] = sample
    nonok = {case for case, row in metrics.items() if row["status"] != "ok"}
    if len(errors) != len(tables["errors"]) or errors.keys() != nonok:
        raise ValueError("errors do not cover non-ok cases")
    for case, row in metrics.items():
        entry = catalog[case]
        base_validate.integer(entry["setting_index"], "setting_index")
        if entry["order"] not in ("cyclic", "random") or entry["measure"] not in base_validate.MEASURES:
            raise ValueError("invalid catalog order or measure")
        if entry["phase"] not in ("call", "setup", "workspace") or entry["inputs"] != "fixed":
            raise ValueError("invalid catalog phase or input rule")
        if entry["suite"] not in ("quick", "extended") or (
                meta["suite"] == "quick" and entry["suite"] != "quick"):
            raise ValueError("catalog suite mismatch")
        target = number(entry["target"])
        if not math.isnan(target) and (not math.isfinite(target) or target <= 0):
            raise ValueError("invalid catalog target")
        if row["status"] not in base_validate.STATUSES or int(row["rep"]) != meta["rep"]:
            raise ValueError("unknown metric status or wrong repetition")
        for key in ("group", "phase", "measure", "target"):
            if key == "target":
                equal = base_validate.same_number(number(row[key]), number(entry[key]))
            else:
                equal = row[key] == entry[key]
            if not equal:
                raise ValueError(f"metric {key} disagrees with catalog")
        count = base_validate.integer(row["samples"], "samples")
        if set(samples[case]) != set(range(1, count + 1)):
            raise ValueError("sample coverage mismatch")
        values = list(samples[case].values())
        good = [sample for sample in values if sample["status"] == "ok"]
        if int(row["ok_samples"]) != len(good):
            raise ValueError("ok_samples mismatch")
        if row["status"] == "ok" and (count < 5 or count != len(good)):
            raise ValueError("ok case requires at least five ok samples")
        if any(base_validate.STATUSES.index(sample["status"]) >
               base_validate.STATUSES.index(row["status"]) for sample in values):
            raise ValueError("case status understates sample failure")
        for key, observed in base_validate.sample_statistics(good).items():
            reported = number(row[key])
            if not (base_validate.same_number(reported, observed) or math.isclose(
                    reported, observed, rel_tol=1e-12,
                    abs_tol=.51 if key.endswith(("_ns", "_bytes")) else 1e-12)):
                raise ValueError(f"{key} disagrees with samples")
        finite = [number(sample["value"]) for sample in values
                  if math.isfinite(number(sample["value"]))]
        for key, observed in (("worst_value", max(finite, default=math.nan)),
                              ("median_value", statistics.median(finite) if finite else math.nan)):
            reported = number(row[key])
            if not (base_validate.same_number(reported, observed) or
                    math.isclose(reported, observed, rel_tol=1e-12, abs_tol=1e-15)):
                raise ValueError(f"{key} disagrees with samples")
        if not re.fullmatch(r"[a-fA-F0-9]{64}", row["data_hash"]) and not (
                row["status"] == "error" and not count and not row["data_hash"]):
            raise ValueError("malformed data_hash")
        if case in errors and (int(errors[case]["rep"]) != meta["rep"] or
                               errors[case]["status"] != row["status"]):
            raise ValueError("error record disagrees with metric")
    if meta["ok_cases"] != len(metrics) - len(nonok) or meta["nonok_cases"] != len(nonok):
        raise ValueError("metadata status counts mismatch")
    return catalog, metrics, samples


def load_catalog(root):
    path = root / "catalog.toml"
    if not path.exists():
        path = Path(__file__).with_name("catalog.toml")
    return base_validate.metadata(path) if path.exists() else {"case": []}


def logical_id(entry, definitions):
    for key in ("case_id", "base_id"):
        if key in entry:
            return entry[key]
    matches = [case["id"] for case in definitions.get("case", [])
               if entry["id"] == case["id"] or entry["id"].startswith(case["id"] + "__")
               or entry["id"].startswith(case["id"] + "/")]
    return max(matches, key=len) if matches else entry["id"]


def load_arms(root, blocks, select=False, selection=None):
    root = Path(root)
    if blocks < 1:
        raise ValueError("blocks must be positive")
    definitions = load_catalog(root)
    loaded, configurations, signatures = {}, {}, {}
    processes = []
    arms = ARMS[:2] if select and not (root / "current-AA").exists() else ARMS
    for side in arms:
        folder = root / side
        if not folder.is_dir():
            raise ValueError(f"missing arm: {side}")
        finals = sorted(folder.rglob("*-metadata.toml"))
        starts = sorted(folder.rglob("*-metadata-start.toml"))
        if not finals or {str(path).removesuffix("-metadata-start.toml") for path in starts} != {
                str(path).removesuffix("-metadata.toml") for path in finals}:
            raise ValueError(f"missing or interrupted process in {side}")
        for final in finals:
            prefix = final.name.removesuffix("-metadata.toml")
            match = base_validate.PREFIX.fullmatch(prefix)
            if match is None:
                raise ValueError(f"invalid process filename: {prefix}")
            meta = base_validate.metadata(final)
            rep = int(match[2])
            if rep > blocks:
                raise ValueError(f"extra block in {side}: {rep}")
            base_validate.check_metadata(meta, match[1], rep)
            initial = base_validate.metadata(final.with_name(prefix + "-metadata-start.toml"))
            base_validate.check_metadata(initial, match[1], rep, final=False)
            if any(initial.get(key) != value for key, value in meta.items()
                   if key not in base_validate.FINAL_KEYS):
                raise ValueError("start/final metadata mismatch")
            if meta["side"] != side or meta["view"] not in ("defaults", "ladder", "frozen"):
                raise ValueError("metadata side or view mismatch")
            if (meta["view"] == "ladder") != select and meta["view"] != "defaults":
                raise ValueError("calibration/confirmation view mismatch")
            if meta["view"] == "frozen":
                if selection is None:
                    raise ValueError("frozen confirmation requires --selection FILE")
                if "frozen_sha256" in meta and meta["frozen_sha256"] != selection["sha256"]:
                    raise ValueError("--selection SHA-256 differs from frozen process metadata")
            for key in ("artifact_sha256", "manifest_sha256"):
                if not re.fullmatch(r"[a-fA-F0-9]{64}", meta[key]):
                    raise ValueError(f"malformed {key}")
            for key in ("catalog_sha256", "frozen_sha256"):
                if key in meta and not re.fullmatch(r"[a-fA-F0-9]{64}", meta[key]):
                    raise ValueError(f"malformed {key}")
            identity = "coordinatedescent_version" if side == "legacy" else "highdimensionalmodels_rev"
            if not meta.get(identity):
                raise ValueError(f"missing {identity}")
            if side == "legacy" and meta[identity] != "0.6.1":
                raise ValueError("legacy must be CoordinateDescent 0.6.1")
            if side != "legacy" and not re.fullmatch(r"[a-fA-F0-9]{40}", meta[identity]):
                raise ValueError("HighDimensionalModels revision must be a full commit hash")
            tables = {kind: read_table(final.with_name(prefix + f"-{kind}.tsv"), kind, meta)
                      for kind in base_validate.HEADERS}
            catalog, metrics, samples = check_tables(tables, meta)
            settings_path = final.with_name(prefix + "-settings.toml")
            settings = {row["id"]: row for row in base_validate.metadata(settings_path)["case"]} if settings_path.exists() else {}
            if settings and settings.keys() != catalog.keys():
                raise ValueError("settings do not cover catalog")
            process_targets = tuple(sorted({"record" if math.isnan(number(row["target"])) else
                                            format(number(row["target"]), ".12g") for row in catalog.values()}))
            config_key = (side, meta["view"], process_targets)
            invariant_keys = base_validate.SERIES_SETTINGS + (
                "julia", "artifact_sha256", "manifest_sha256", identity)
            config = {key: meta[key] for key in invariant_keys}
            config.update({key: meta[key] for key in ("catalog_sha256", "frozen_sha256", "gram_control",
                                                    "solver_package_hash", "accuracy_target", "accuracy_targets") if key in meta})
            if config_key in configurations and configurations[config_key] != config:
                raise ValueError(f"series settings changed: {config_key}")
            configurations[config_key] = config
            signature = {case: entry for case, entry in catalog.items()}
            if config_key in signatures and signatures[config_key] != signature:
                raise ValueError(f"catalog changed across blocks: {config_key}")
            signatures[config_key] = signature
            for raw_id, entry in catalog.items():
                case = logical_id(entry, definitions)
                target = number(entry["target"])
                target_key = "record" if math.isnan(target) else format(target, ".12g")
                key = (side, meta["view"], case, int(entry["setting_index"]), target_key, rep)
                if key in loaded:
                    raise ValueError(f"duplicate process record: {key}")
                loaded[key] = dict(entry=entry, metric=metrics[raw_id],
                                   samples=list(samples[raw_id].values()), meta=meta,
                                   folder=final.parent, raw_id=raw_id,
                                   settings=settings.get(raw_id, {}).get("settings"))
            processes.append(dict(side=side, **{key: meta[key] for key in (
                "view", "rep", "julia", "artifact_sha256", "manifest_sha256", identity,
                "proximalbase_version", "blas", "cpu_model", "maxrss_bytes")},
                **{key: meta[key] for key in ("accuracy_target", "accuracy_targets", "not_reached") if key in meta}))
    artifacts = {record["meta"]["artifact_sha256"] for record in loaded.values()}
    if len(artifacts) != 1:
        raise ValueError("artifact_sha256 mismatch between arms")
    catalog_hashes = {record["meta"].get("catalog_sha256") for record in loaded.values()}
    if len(catalog_hashes) > 1:
        raise ValueError("catalog_sha256 mismatch between arms")
    if None not in catalog_hashes:
        catalog_path = root / "catalog.toml"
        if not catalog_path.exists():
            catalog_path = Path(__file__).with_name("catalog.toml")
        with catalog_path.open("rb") as stream:
            if hashlib.file_digest(stream, "sha256").hexdigest() not in catalog_hashes:
                raise ValueError("catalog.toml SHA-256 differs from campaign")
    common_keys = ("suite", "harness_hash", "julia_threads", "blas_threads", "blas", "cpu_model",
                   "samples_target", "seconds_limit", "case_seconds", "profile_seconds", "seed_scheme", "julia")
    for key in common_keys:
        if len({record["meta"][key] for record in loaded.values()}) != 1:
            raise ValueError(f"comparison settings differ: {key}")
    cells = defaultdict(set)
    for side, view, case, setting, target, block in loaded:
        cells[(side, view, case, setting, target)].add(block)
    if any(found != set(range(1, blocks + 1)) for found in cells.values()):
        raise ValueError("missing blocks")
    hashes_by_case = defaultdict(set)
    signatures_by_case = defaultdict(set)
    settings_by_cell = {}
    for key, record in loaded.items():
        side, view, case, setting, target, block = key
        if record["metric"]["data_hash"]:
            hashes_by_case[(view, case, block)].add(record["metric"]["data_hash"])
        fields = ("estimator", "design", "lambda", "order", "measure", "target")
        signatures_by_case[(view, case, target)].add(tuple(record["entry"][field] for field in fields))
        cell = key[:-1]
        if cell in settings_by_cell and settings_by_cell[cell] != record["settings"]:
            raise ValueError("settings changed across blocks")
        settings_by_cell[cell] = record["settings"]
    if any(len(hashes) > 1 for hashes in hashes_by_case.values()):
        raise ValueError("data_hash mismatch between arms or settings")
    if any(len(signatures) > 1 for signatures in signatures_by_case.values()):
        raise ValueError("case definitions differ between arms or settings")
    for key, record in loaded.items():
        side, view, case, setting, target, block = key
        if side == "current" and "current-AA" in arms:
            aa = loaded.get(("current-AA", *key[1:]))
            if aa is None or aa["entry"] != record["entry"] or aa["settings"] != record["settings"]:
                raise ValueError("current/current-AA case or settings mismatch")
            for field in ("manifest_sha256", "highdimensionalmodels_rev", "proximalsolvers_hash",
                          "proximalsolvers_sha", "proximalbase_hash", "proximalbase_version",
                          "solver_package_hash", "catalog_sha256", "frozen_sha256", "gram_control",
                          "accuracy_target", "accuracy_targets"):
                if record["meta"].get(field) != aa["meta"].get(field):
                    raise ValueError(f"current/current-AA {field} mismatch")
    if "current-AA" in arms and {key[1:] for key in cells if key[0] == "current"} != {
            key[1:] for key in cells if key[0] == "current-AA"}:
        raise ValueError("current/current-AA coverage mismatch")
    coverage = {(side, view, case, target) for side, view, case, _, target in cells}
    for side, view, case, target in coverage:
        if view == "frozen":
            continue
        for required in arms:
            if (required, view, case, target) not in coverage:
                raise ValueError(f"missing arm/case coverage: {required}/{view}/{case}/{target}")
    if selection is not None:
        validate_selected_union(loaded, definitions, selection, blocks, processes)
    return loaded, definitions, processes


def process_time(record):
    samples = record["samples"]
    if (record["metric"]["status"] in ("error", "timeout", "incomplete") or len(samples) < 5 or
            any(sample["status"] in ("error", "timeout", "incomplete") for sample in samples)):
        return math.nan
    times = [number(sample["time_ns"]) for sample in samples]
    return statistics.median(times) if all(math.isfinite(t) and t > 0 for t in times) else math.nan


def certified(record, target):
    value = number(record["metric"]["worst_value"])
    return (record["metric"]["status"] in ("ok", "target_missed") and
            math.isfinite(process_time(record)) and math.isfinite(value) and 0 <= value <= target and
            all(sample["status"] in ("ok", "target_missed") and
                math.isfinite(number(sample["value"])) and 0 <= number(sample["value"]) <= target
                for sample in record["samples"]))


def choose_rung(rungs, target):
    eligible = [(statistics.mean(process_time(record) for record in records), index)
                for index, records in rungs.items() if records and
                all(certified(record, target) for record in records)]
    return min(eligible)[1] if eligible else None


def status_text(records):
    return "; ".join(f"{status}={count}" for status, count in sorted(
        Counter(record["metric"]["status"] for record in records).items()))


def finite_max(values):
    return max((value for value in values if math.isfinite(value)), default=math.nan)


def safe_exp(value):
    if math.isnan(value):
        return math.nan
    return math.exp(value) if value < 710 else math.inf


def json_safe(value):
    if isinstance(value, float) and not math.isfinite(value):
        return None
    if isinstance(value, dict):
        return {key: json_safe(item) for key, item in value.items()}
    if isinstance(value, (list, tuple)):
        return [json_safe(item) for item in value]
    return value


def settings_for(definitions, case, side, index):
    entry = next((entry for entry in definitions.get("case", []) if entry["id"] == case), None)
    if entry is None:
        raise ValueError(f"selection requires catalog.toml settings for {case}")
    settings = entry[side]["ladder"] + entry[side].get("gap_ladder", [])
    if not 1 <= index <= len(settings):
        raise ValueError(f"ladder index outside catalog: {case}/{side}/{index}")
    return settings[index - 1]


def rung_family(definitions, case, side, index, record):
    entry = next((entry for entry in definitions.get("case", []) if entry["id"] == case), None)
    if entry is not None and side in entry:
        settings_for(definitions, case, side, index)
        family = "coordinate" if index <= len(entry[side]["ladder"]) else "gap"
    else:
        label = record["entry"].get("family")
        if label is None:
            raise ValueError(f"missing ladder membership for {case}/{side}/{index}")
        family = "gap" if label == "gap" else "coordinate"
    if side == "legacy" and family != "coordinate":
        raise ValueError("legacy has only the coordinate ladder")
    return family


def read_selection(path):
    path = Path(path)
    with path.open("rb") as stream:
        digest = hashlib.file_digest(stream, "sha256").hexdigest()
    rows = base_validate.metadata(path).get("selection", [])
    if not isinstance(rows, list) or not rows:
        raise ValueError("selection file requires [[selection]] entries")
    indexed = {}
    for row in rows:
        side, family = row.get("side"), row.get("family")
        if side not in ("legacy", "current") or family not in (
                ("coordinate",) if side == "legacy" else ("coordinate", "best")):
            raise ValueError("invalid selection side/family")
        target = float(row["target"])
        if target not in TARGETS or not isinstance(row.get("id"), str) or not row["id"]:
            raise ValueError("invalid selection case/target")
        status = row.get("status", "selected")
        if status not in ("selected", "not reached"):
            raise ValueError("invalid selection status")
        if status == "selected":
            base_validate.integer(row.get("setting_index"), "selected setting_index", 1)
        elif "setting_index" in row:
            raise ValueError("not reached selection must omit setting_index")
        if "settings" in row and not isinstance(row["settings"], dict):
            raise ValueError("selection settings must be a table")
        key = (row["id"], side, family, format(target, ".12g"))
        if key in indexed:
            raise ValueError(f"duplicate selection entry: {key}")
        indexed[key] = dict(row, status=status)
    for case, target in {(key[0], key[-1]) for key in indexed}:
        for side, family in (("legacy", "coordinate"), ("current", "coordinate"), ("current", "best")):
            if (case, side, family, target) not in indexed:
                raise ValueError(f"missing selection family: {case}/{side}/{family}/{target}")
    return dict(rows=indexed, sha256=digest)


def selected_entry(selection, case, side, family, target):
    side = "current" if side == "current-AA" else side
    family = "coordinate" if side == "legacy" else family
    key = (case, side, family, target)
    if key not in selection["rows"]:
        raise ValueError(f"missing selection entry: {key}")
    return selection["rows"][key]


def frozen_contexts(loaded, selection, processes):
    targets = {key[4] for key in loaded if key[1] == "frozen" and key[4] != "record"}
    targets.update(format(float(process["accuracy_target"]), ".12g") for process in processes
                   if process["view"] == "frozen" and "accuracy_target" in process)
    targets.update(format(float(target), ".12g") for process in processes if process["view"] == "frozen"
                   for target in process.get("accuracy_targets", []))
    if not targets and any(key[1] == "frozen" and key[4] == "record" for key in loaded):
        targets = {key[-1] for key in selection["rows"]}
    if not targets:
        return []
    contexts = sorted({(case, target) for case, _, _, target in selection["rows"] if target in targets})
    if targets - {target for _, target in contexts}:
        raise ValueError("selection has no cases for a confirmation target")
    return contexts


def shared_frozen_records(loaded):
    targets = {key[4] for key in loaded if key[1] == "frozen"}
    if "record" in targets and targets != {"record"}:
        raise ValueError("cannot mix shared and target-specific frozen records")
    return targets == {"record"}


def validate_selected_union(loaded, definitions, selection, blocks, processes):
    expected = set()
    shared = shared_frozen_records(loaded)
    for case, target in frozen_contexts(loaded, selection, processes):
        for side in ARMS:
            for family in (("coordinate",) if side == "legacy" else ("coordinate", "best")):
                row = selected_entry(selection, case, side, family, target)
                if row["status"] == "not reached":
                    continue
                index = int(row["setting_index"])
                for block in range(1, blocks + 1):
                    key = (side, "frozen", case, index, "record" if shared else target, block)
                    expected.add(key)
                    record = loaded.get(key)
                    if record is None:
                        continue
                    catalog_side = "legacy" if side == "legacy" else "current"
                    if family == "coordinate" and rung_family(definitions, case, catalog_side, index, record) != "coordinate":
                        raise ValueError("coordinate selection points to the gap ladder")
                    if "settings" in row and row["settings"] != record["settings"]:
                        raise ValueError("confirmation settings differ from frozen selection")
    actual = {key for key in loaded if key[1] == "frozen"}
    if expected != actual:
        raise ValueError(f"frozen setting coverage mismatch: missing={sorted(expected - actual)}, "
                         f"extra={sorted(actual - expected)}")


def toml_literal(value):
    if isinstance(value, str):
        return json.dumps(value)
    if isinstance(value, bool):
        return str(value).lower()
    if isinstance(value, (float, int)):
        return repr(value)
    if isinstance(value, list):
        return "[" + ", ".join(toml_literal(item) for item in value) + "]"
    if isinstance(value, dict):
        return "{ " + ", ".join(f"{json.dumps(key)} = {toml_literal(item)}"
                                  for key, item in value.items()) + " }"
    raise ValueError(f"unsupported TOML setting: {value!r}")


def calibration(loaded, definitions, output):
    ladders = defaultdict(lambda: defaultdict(list))
    for (side, view, case, setting, _, block), record in sorted(loaded.items()):
        if view == "ladder" and side != "current-AA":
            ladders[(case, side)][setting].append(record)
    selections, rows = [], []
    for (case, side), rungs in sorted(ladders.items()):
        memberships = {index: rung_family(definitions, case, side, index, records[0])
                       for index, records in rungs.items()}
        for target in TARGETS:
            choices = {}
            for family in (("coordinate",) if side == "legacy" else ("coordinate", "best")):
                allowed = {index: records for index, records in rungs.items()
                           if family == "best" or memberships[index] == "coordinate"}
                selected = choose_rung(allowed, target)
                choices[family] = selected
                result = dict(id=case, side=side, target=target, family=family,
                              status="selected" if selected is not None else "not reached")
                if selected is not None:
                    chosen = rungs[selected][0]
                    result.update(setting_index=selected,
                                  settings=chosen["settings"] or settings_for(definitions, case, side, selected))
                selections.append(result)
            if side == "legacy":
                choices["best"] = choices["coordinate"]
            for index, records in sorted(rungs.items()):
                times = [process_time(record) for record in records]
                worst = finite_max(number(record["metric"]["worst_value"]) for record in records)
                rows.append(dict(id=case, side=side, target=target, setting_index=index,
                                 family=memberships[index],
                                 mean_median_ns=statistics.mean(times), worst_value=worst,
                                 overshoot=target / worst if worst > 0 else math.inf if worst == 0 else math.nan,
                                 eligible=all(certified(record, target) for record in records),
                                 selected=index in choices.values(),
                                 selected_coordinate=index == choices["coordinate"],
                                 selected_best=index == choices["best"], statuses=status_text(records),
                                 stopping=records[0]["entry"]["stopping"]))
    lines = ["# Frozen calibration selections; current-AA uses current settings."]
    for result in selections:
        lines += ["", "[[selection]]"]
        lines += [f"{key} = {toml_literal(value)}" for key, value in result.items()]
    (output / "selection.toml").write_text("\n".join(lines) + "\n", encoding="utf-8")
    return selections, rows


def support_sets(beta, columns=1):
    if columns < 1 or not beta or len(beta) % columns:
        raise ValueError("invalid coefficient dimensions for support")
    p = len(beta) // columns
    result = []
    for level in range(columns):
        values = beta[level * p:(level + 1) * p]
        if not all(math.isfinite(value) for value in values):
            return None
        threshold = 1e-4 * max(abs(value) for value in values)
        result.append({j for j, value in enumerate(values) if abs(value) > threshold})
    return result


def attach_supports(loaded):
    from crosscheck import coefficient_rows, read_array
    by_folder = defaultdict(dict)
    for key, record in loaded.items():
        by_folder[record["folder"]][(record["raw_id"], key[3], key[-1])] = record
    for folder, records in by_folder.items():
        for parent, path, row in coefficient_rows(folder):
            if parent != folder:
                continue
            key = (row["id"], int(row["setting_index"]), int(row["rep"]))
            if key not in records:
                raise ValueError("foreign coefficients in analysis output")
            record = records[key]
            columns = int(row.get("columns", 50 if record["entry"]["estimator"] == "path" else 1))
            record["supports"] = support_sets(read_array(path, finite=False), columns)


def support_columns(loaded, case, records):
    reference = [(key, record) for key, record in loaded.items()
                 if key[0] == "current" and key[1] == "ladder" and key[2] == case]
    if reference:
        tightest = max(key[3] for key, _ in reference)
        reference = [(key, record) for key, record in reference if key[3] == tightest]
    valid_reference = reference and all(certified(record, 1e-6) and record.get("supports") is not None
                                        for _, record in reference)
    refs = {key[-1]: record["supports"] for key, record in reference} if valid_reference else {}
    result = {}
    for side in ARMS:
        supports = [record.get("supports") for record in records[side]]
        result[f"{side}_support_sizes"] = json.dumps(
            [[len(level) for level in levels] if levels is not None else None for levels in supports])
        differences = []
        for record, levels in zip(records[side], supports):
            ref = refs.get(record["meta"]["rep"])
            differences.append([len(left ^ right) for left, right in zip(levels, ref)]
                               if levels is not None and ref is not None and len(levels) == len(ref) else None)
        result[f"{side}_support_reference_differences"] = json.dumps(differences)
    result["support_reference"] = "current tightest rung, certified <= 1e-6" if valid_reference else "unavailable"
    return result


def view_sort(key):
    return (VIEW_ORDER.index(key[0]), *key[1:])


def comparison_series(loaded, selection, processes):
    series = defaultdict(lambda: defaultdict(list))
    indexed = defaultdict(list)
    for (side, view, case, setting, target, block), record in sorted(loaded.items()):
        indexed[(side, view, case, setting, target)].append((block, setting, record))
        if view == "defaults":
            series[(view, target, case)][side].append((block, setting, record))
    if any(key[1] == "frozen" for key in loaded) and selection is None:
        raise ValueError("frozen confirmation requires --selection FILE")
    if selection is not None:
        shared = shared_frozen_records(loaded)
        for case, target in frozen_contexts(loaded, selection, processes):
            for view in ("primary", "secondary"):
                sides = series[(view, target, case)]
                for side in ARMS:
                    row = selected_entry(selection, case, side, VIEW_FAMILIES[view], target)
                    sides[side] = []
                    if row["status"] == "selected":
                        index = int(row["setting_index"])
                        sides[side] = indexed[(side, "frozen", case, index, "record" if shared else target)]
    return series


def inference(loaded, blocks, selection=None, processes=(), aa_optional=False):
    series = comparison_series(loaded, selection, processes)
    noise_values = defaultdict(list)
    for (view, target, _), sides in series.items():
        current = {block: record for block, _, record in sides["current"]}
        aa = {block: record for block, _, record in sides["current-AA"]}
        for block, left in current.items():
            right = aa.get(block)
            if right is None and aa_optional:
                continue
            if right is None:
                raise ValueError("missing current-AA block")
            if (view == "defaults" or (certified(left, float(target)) and certified(right, float(target)))):
                times = process_time(left), process_time(right)
                if all(math.isfinite(t) for t in times):
                    noise_values[(view, target)].append(abs(math.log(times[0]) - math.log(times[1])))
    noises = {key: noise_floor(noise_values[key]) for view, target, _ in series
              for key in [(view, target)]}
    results, logs_by_case = [], {}
    for (view, target, case), sides in sorted(series.items(), key=lambda item: view_sort(item[0])):
        records = {side: [record for _, _, record in sides[side]] for side in ARMS}
        any_record = next((record for items in records.values() for record in items), None)
        row = dict(view=view, family=VIEW_FAMILIES[view], target=target, id=case,
                   estimator=any_record["entry"]["estimator"] if any_record else case.split("/")[0], paired_blocks=0,
                   delta=noises[(view, target)]["delta"], mean_log_ratio=math.nan,
                   ratio=math.nan, ci95_low=math.nan, ci95_high=math.nan, p_value=math.nan,
                   candidate=False, bh_rejected=False, assessment="unavailable", reasons="")
        row.update(support_columns(loaded, case, records))
        reasons = []
        for side in ARMS:
            items = records[side]
            absent_aa = aa_optional and side == "current-AA" and not items
            if not absent_aa and (items or view == "defaults") and (len(items) != blocks or len({b for b, _, _ in sides[side]}) != blocks):
                raise ValueError(f"ambiguous setting per block: {side}/{view}/{case}")
            row[f"{side}_statuses"] = status_text(items) if items else "absent" if absent_aa else "not reached"
            row[f"{side}_mean_median_ns"] = statistics.mean(process_time(record) for record in items) if items else math.nan
            row[f"{side}_worst_value"] = finite_max(number(record["metric"]["worst_value"]) for record in items)
            row[f"{side}_setting_index"] = ",".join(str(index) for index in sorted({i for _, i, _ in sides[side]}))
        for side in ("legacy", "current"):
            if not records[side]:
                reasons.append(f"{side}: not reached during calibration")
            for block, _, record in sides[side]:
                if not math.isfinite(process_time(record)):
                    reasons.append(f"{side}/block{block}: {record['metric']['status']}; timing unavailable")
                elif view != "defaults" and not certified(record, float(target)):
                    reasons.append(f"{side}/block{block}: not reached ({record['metric']['status']})")
        if reasons:
            row["reasons"] = "; ".join(reasons)
            row["assessment"] = "not reached" if any("not reached" in reason for reason in reasons) else "unavailable"
        else:
            logs = [math.log(process_time(right)) - math.log(process_time(left))
                    for left, right in zip(records["legacy"], records["current"])]
            mu, low, high = mean_interval(logs)
            delta = row["delta"]
            row.update(paired_blocks=blocks, mean_log_ratio=mu, ratio=safe_exp(mu),
                       ci95_low=safe_exp(low), ci95_high=safe_exp(high),
                       p_value=one_sided_p(logs, delta), candidate=low > delta,
                       assessment="candidate regression" if low > delta else
                       "shorter time beyond noise band" if high < -delta else "inconclusive, not a tie")
            logs_by_case[(row["view"], target, case)] = logs
        results.append(row)
    families = {(row["view"], row["target"]) for row in results}
    for family in families:
        rows = [row for row in results if (row["view"], row["target"]) == family]
        rejected = bh_decisions({row["id"]: row["p_value"] for row in rows})
        for row in rows:
            row["bh_rejected"] = row["id"] in rejected
            if row["candidate"]:
                row["assessment"] = ("candidate regression; passes BH" if row["bh_rejected"] else
                                     "candidate regression; does not pass BH")
    groups = []
    for view, target in sorted(families, key=view_sort):
        family_rows = [row for row in results if (row["view"], row["target"]) == (view, target)]
        for group in ["all"] + sorted({row["estimator"] for row in family_rows}):
            members = [row for row in family_rows if group == "all" or row["estimator"] == group]
            values = [logs_by_case[(view, target, row["id"])] for row in members
                      if (view, target, row["id"]) in logs_by_case]
            mu, low, high = block_bootstrap(values)
            groups.append(dict(view=view, family=VIEW_FAMILIES[view], target=target, group=group, cases_total=len(members),
                               cases_eligible=len(values), cases_excluded=len(members) - len(values),
                               ratio=safe_exp(mu), ci95_low=safe_exp(low), ci95_high=safe_exp(high),
                               resamples=BOOTSTRAPS, seed=SEED,
                               excluded="; ".join(row["id"] for row in members
                                                  if (view, target, row["id"]) not in logs_by_case)))
    return results, groups, noises


def analyze(root, output, blocks, select=False, selection=None):
    if select and selection is not None:
        raise ValueError("--select and --selection cannot be combined")
    frozen = read_selection(selection) if selection is not None else None
    loaded, definitions, processes = load_arms(root, blocks, select, frozen)
    attach_supports(loaded)
    output = base_validate.fresh_output(output)
    selections, rungs = calibration(loaded, definitions, output) if select else ([], [])
    cases, groups, noises = inference(loaded, blocks, frozen, processes, aa_optional=select)
    aa_present = any(process["side"] == "current-AA" for process in processes)
    case_fields = list(cases[0]) if cases else ["view", "target", "id", "assessment"]
    write_csv(output / "cases.csv", case_fields, cases)
    write_csv(output / "groups.csv", list(groups[0]) if groups else ["view", "target", "group"], groups)
    if select:
        write_csv(output / "rungs.csv", list(rungs[0]) if rungs else ["id", "side", "target"], rungs)
    noise_report = dict(seed=SEED, bootstrap_resamples=BOOTSTRAPS, blocks=blocks, aa_present=aa_present,
                        selection_sha256=frozen["sha256"] if frozen else None,
                        views=[dict(view=view, family=VIEW_FAMILIES[view], target=target,
                                    **info) for (view, target), info in sorted(noises.items(), key=lambda item: view_sort(item[0]))],
                        processes=processes, unavailable_bound="null q/delta means positive infinity")
    (output / "noise.json").write_text(json.dumps(json_safe(noise_report), indent=2, allow_nan=False) + "\n",
                                       encoding="utf-8")
    lines = ["# CoordinateDescent regression analysis", "",
             f"Mode: {'calibration' if select else 'confirmation'}. Blocks: {blocks}.", "",
             "The sole matched-accuracy target is relative duality gap <= 1e-4, or "
             "self-consistency value <= 1e-4 for feasible lasso.", "",
             ("current-AA arm: absent. Calibration uses legacy and current only; no A/A noise is measured."
              if not aa_present else "current-AA arm: present. Calibration selection uses neither A/A timings nor A/A noise."
              if select else "current-AA arm: present (required for confirmation)."), "",
             "Ratios are current/legacy public-API process medians. Case intervals are paired "
             "Student-t intervals across blocks. Group intervals resample whole blocks 10,000 "
             "times with seed 117 and weight eligible cases equally. Excluded cases are listed.", "",
             "Defaults retain completed timings even when accuracy is insufficient. Matched "
             "comparisons require every process to reach the frozen target. Calibration chooses "
             "settings separately from confirmation. Failures remain in the tables.", "",
             "The primary matched view restricts current to its coordinate-change ladder and "
             "is the like-for-like regression monitor. The secondary matched view uses current's "
             "best available qualifying rung across all ladders. Both use legacy's coordinate "
             "selection. Frozen setting indices determine pairing; A/A uses the same current "
             "rung within each view. Groups, noise floors and BH screens are separate.", "",
             "BH uses one-sided tests against the noise floor across all estimable cases within "
             "each view and target at 10%. No result here is an independently confirmed regression. "
             "An overlapping interval is inconclusive, not a tie.", "",
             "The order-statistic noise bound assumes iid pooled A/A observations. Correlation "
             "between cases within blocks limits that nominal coverage claim. Fewer than 59 "
             "observations gives an infinite bound and prevents regression flags.", "",
             "## Noise", "", "| View | Target | A/A observations | Order statistic | q | delta |",
             "|---|---|---:|---:|---:|---:|"]
    for (view, target), info in sorted(noises.items(), key=lambda item: view_sort(item[0])):
        lines.append(f"| {view} | {target} | {info['observations']} | "
                     f"{info['rank']} | {info['q']:.6g} | {info['delta']:.6g} |")
    for view in VIEW_ORDER:
        lines += ["", f"## {VIEW_LABELS[view]}", "",
                  "| Case | Target | Current/legacy [95% interval] | Time ns legacy / current | "
                  "Worst value legacy / current | Status legacy / current / A/A | Assessment / reasons |",
                  "|---|---|---:|---:|---:|---|---|"]
        for row in cases:
            if row["view"] == view:
                lines.append(f"| {markdown(row['id'])} | {row['target']} | {row['ratio']:.6g} "
                             f"[{row['ci95_low']:.6g}, {row['ci95_high']:.6g}] | "
                             f"{row['legacy_mean_median_ns']:.6g} / {row['current_mean_median_ns']:.6g} | "
                             f"{row['legacy_worst_value']:.6g} / {row['current_worst_value']:.6g} | "
                             f"{markdown(row['legacy_statuses'])} / {markdown(row['current_statuses'])} / "
                             f"{markdown(row['current-AA_statuses'])} | {markdown(row['assessment'])}; "
                             f"{markdown(row['reasons'])} |")
    lines += ["", "## Groups", "", "| View | Target | Group | Eligible / total | Ratio [95% interval] | Excluded |",
              "|---|---|---|---:|---:|---|"]
    for row in groups:
        lines.append(f"| {row['view']} | {row['target']} | {row['group']} | {row['cases_eligible']} / "
                     f"{row['cases_total']} | {row['ratio']:.6g} [{row['ci95_low']:.6g}, "
                     f"{row['ci95_high']:.6g}] | {markdown(row['excluded'])} |")
    lines += ["", "## Support diagnostics", "",
              "Entries are arrays by block, then path level. Null means unavailable. The threshold "
              "is 1e-4 times the largest absolute coefficient at that level. Differences count "
              "the symmetric difference from current's tightest calibration rung only if every "
              "process certifies to <= 1e-6, 100 times tighter than the matched target. Otherwise "
              "the reference is unavailable.", "",
              "| View | Case | Support sizes legacy / current | Differences legacy / current | Reference |",
              "|---|---|---|---|---|"]
    for row in cases:
        lines.append(f"| {row['view']} | {markdown(row['id'])} | {row['legacy_support_sizes']} / "
                     f"{row['current_support_sizes']} | {row['legacy_support_reference_differences']} / "
                     f"{row['current_support_reference_differences']} | {row['support_reference']} |")
    if select:
        lines += ["", "## Selection", "", "| Case | Side | Target | Family | Selection |", "|---|---|---:|---|---|"]
        for row in selections:
            lines.append(f"| {markdown(row['id'])} | {row['side']} | {row['target']:.6g} | {row['family']} | "
                         f"{row.get('setting_index', row['status'])} |")
        lines += ["", "## Every ladder rung", "", "| Case | Side | Target | Rung | Family | Time ns | Worst value | "
                  "Overshoot | Eligible | Coordinate selection | Best selection | Status |", "|---|---|---:|---:|---|---:|---:|---:|---|---|---|---|"]
        for row in rungs:
            lines.append(f"| {markdown(row['id'])} | {row['side']} | {row['target']:.6g} | "
                         f"{row['setting_index']} | {row['family']} | {row['mean_median_ns']:.6g} | {row['worst_value']:.6g} | "
                         f"{row['overshoot']:.6g} | {row['eligible']} | {row['selected_coordinate']} | {row['selected_best']} | "
                         f"{markdown(row['statuses'])} |")
    lines += ["", "## Scope", "", "These measurements cover these designs on one machine. Times include the "
              "whole public package call. They do not isolate ProximalSolvers. No intercept or "
              "standardization is used. Support agreement is a diagnostic, not a certificate. "
              "Package identities, artifact and environment hashes, Julia, BLAS, CPU model and "
              "process RSS are recorded in noise.json. Heap bytes and RSS measure different quantities."]
    (output / "REPORT.md").write_text("\n".join(lines) + "\n", encoding="utf-8")
    return cases, groups, selections


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("arms_dir", type=Path)
    parser.add_argument("out", type=Path)
    parser.add_argument("--blocks", type=int, required=True)
    parser.add_argument("--select", action="store_true")
    parser.add_argument("--selection", type=Path, help="frozen family selections for confirmation")
    args = parser.parse_args()
    try:
        analyze(args.arms_dir, args.out, args.blocks, args.select, args.selection)
    except (OSError, ValueError, KeyError, TypeError, OverflowError, csv.Error) as error:
        parser.exit(2, f"{error}\n")


if __name__ == "__main__":
    main()
