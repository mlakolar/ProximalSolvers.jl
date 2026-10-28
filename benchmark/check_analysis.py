#!/usr/bin/env python3
"""Run analytic controls and synthetic record-integrity checks without Julia."""

import csv
import hashlib
import json
import math
import os
from pathlib import Path
import subprocess
import sys
import tempfile

from compare import FIELDS, compare
from summarize import mean_interval, summarize
from validate import HEADERS, SERIES_SETTINGS, STATUSES, validate


VERSION = "1.10.0"
DEFAULT_CASE = "gradient/control/analytic/default/workspace"
FIXTURE_HEADERS = {
    "catalog": "id group problem solver variant phase suite inputs issue measure target".split(),
    "metrics": ("id group phase rep status samples ok_samples median_ns mean_ns sd_ns "
                "min_ns max_ns p95_ns gc_share median_bytes mean_bytes min_bytes "
                "max_bytes measure target worst_value median_value data_hash").split(),
    "samples": "id rep sample time_ns gc_ns bytes value status".split(),
    "errors": "id rep status exception stack".split(),
}


def write_rows(path, kind, rows):
    with path.open("w", newline="", encoding="utf-8") as stream:
        writer = csv.DictWriter(stream, FIXTURE_HEADERS[kind], delimiter="\t", lineterminator="\n")
        writer.writeheader()
        writer.writerows(rows)


def read_rows(path, delimiter="\t"):
    with path.open(newline="", encoding="utf-8") as stream:
        return list(csv.DictReader(stream, delimiter=delimiter))


def write_meta(path, values):
    def literal(value):
        if isinstance(value, bool):
            return str(value).lower()
        return json.dumps(value) if isinstance(value, str) else str(value)
    path.write_text("".join(f"{key} = {literal(value)}\n" for key, value in values.items()),
                    encoding="utf-8")


def select(value, rep, case):
    return value(rep, case) if callable(value) else value


def fixture(folder, factor=4, runs=3, allocated=0, cases=(DEFAULT_CASE,), status="ok",
            accuracy=1e-9, version=VERSION, measure="relative_gap", target=1e-6):
    folder.mkdir(exist_ok=True)
    for rep in range(1, runs + 1):
        prefix = folder / f"julia-{version}-rep{rep:02d}"
        catalog, metrics, samples, errors = [], [], [], []
        for case in cases:
            group, problem, solver, variant, phase = case.split("/")
            catalog.append(dict(id=case, group=group, problem=problem, solver=solver,
                                variant=variant, phase=phase, suite="quick", inputs="draw",
                                issue="", measure=measure, target=target))
            outcome = select(status, rep, case)
            value = select(accuracy, rep, case) * rep
            if outcome == "target_missed":
                value = target * 2
            elif outcome in ("uncertifiable", "error"):
                value = math.nan
            base = select(factor, rep, case) * 100 * rep
            allocation = select(allocated, rep, case)
            count = 0 if outcome == "error" else 5
            for index in range(1, count + 1):
                samples.append(dict(id=case, rep=rep, sample=index,
                                    time_ns=int(base * (index + 1) / 4), gc_ns=0,
                                    bytes=allocation, value=value, status=outcome))
            good = outcome == "ok"
            # The five times are base times (1/2, 3/4, 1, 5/4, 3/2).
            metrics.append(dict(
                id=case, group=group, phase=phase, rep=rep, status=outcome,
                samples=count, ok_samples=5 if good else 0,
                median_ns=base if good else math.nan, mean_ns=base if good else math.nan,
                sd_ns=base * math.sqrt(1 / 8) if good else math.nan,
                min_ns=base / 2 if good else math.nan, max_ns=base * 1.5 if good else math.nan,
                p95_ns=base * 1.45 if good else math.nan, gc_share=0 if good else math.nan,
                median_bytes=allocation if good else math.nan,
                mean_bytes=allocation if good else math.nan,
                min_bytes=allocation if good else math.nan, max_bytes=allocation if good else math.nan,
                measure=measure, target=target, worst_value=value, median_value=value,
                data_hash=hashlib.sha256(f"{case}:{rep}".encode()).hexdigest(),
            ))
            if not good:
                errors.append(dict(id=case, rep=rep, status=outcome,
                                   exception="control" if outcome == "error" else "", stack=""))
        for kind, rows in (("catalog", catalog), ("metrics", metrics),
                           ("samples", samples), ("errors", errors)):
            write_rows(Path(str(prefix) + f"-{kind}.tsv"), kind, rows)
        meta = dict(
            julia=version, rep=rep, suite="quick", groups="gradient", harness_hash="a" * 40,
            proximalsolvers_path="/synthetic/package", proximalsolvers_sha="b" * 40,
            proximalsolvers_dirty=False, proximalsolvers_hash="c" * 40,
            proximalbase_version="0.5.4", proximalbase_hash="d" * 40,
            expected_package_root="/synthetic/package", julia_threads=1, blas_threads=1,
            blas="control", cpu="control", cpu_model="control", samples_target=5,
            seconds_limit=1.0, case_seconds=60.0, profile_seconds=0.0,
            seed_scheme="control", job_id="none",
        )
        write_meta(Path(str(prefix) + "-metadata-start.toml"), meta)
        meta.update(cases=len(catalog), ok_cases=sum(row["status"] == "ok" for row in metrics),
                    nonok_cases=len(errors), elapsed_s=1.0, maxrss_bytes=0, finished=True)
        write_meta(Path(str(prefix) + "-metadata.toml"), meta)


def edit_rows(folder, kind, change, rep=None):
    pattern = f"*-rep{rep:02d}-{kind}.tsv" if rep else f"*-{kind}.tsv"
    for path in sorted(folder.glob(pattern)):
        rows = read_rows(path)
        change(rows)
        write_rows(path, kind, rows)


def edit_meta(folder, key, value, rep=None):
    import tomllib
    for path in folder.glob("*-metadata*.toml"):
        if rep is not None and f"-rep{rep:02d}-" not in path.name:
            continue
        with path.open("rb") as stream:
            meta = tomllib.load(stream)
        meta[key] = value
        write_meta(path, meta)


def expect_error(action, message):
    try:
        action()
    except ValueError as error:
        assert message in str(error), str(error)
        return str(error)
    raise AssertionError(f"Expected ValueError containing {message!r}")


def invalid_mutation(folder, change, message, expected=3):
    saved = {path: path.read_bytes() for path in folder.iterdir() if path.is_file()}
    try:
        change()
        result = validate(folder, expected)
        assert result["valid"] is False, message
        assert any(message in issue for issue in result["issues"]), result["issues"]
    finally:
        for path in folder.iterdir():
            if path.is_file() and path not in saved:
                path.unlink()
        for path, contents in saved.items():
            path.write_bytes(contents)
    assert validate(folder, expected)["valid"]


def analytic_controls(root):
    assert HEADERS == FIXTURE_HEADERS
    for runs, critical in ((1, None), (3, 4.303), (5, 2.776), (10, 2.262)):
        before, after = root / f"before{runs}", root / f"after{runs}"
        fixture(before, runs=runs, allocated=64)
        fixture(after, factor=2, runs=runs, allocated=16, accuracy=2e-9)
        checked = validate(before, runs)
        assert checked["valid"], checked["issues"]
        assert checked["counts"] == dict(processes=runs, measurements=runs, samples=5 * runs,
                                           ok_samples=5 * runs, nonok_cases=0)
        assert checked["status_counts"] == {status: runs if status == "ok" else 0 for status in STATUSES}
        assert checked["nonok_cases"] == []
        summary = root / f"summary{runs}"
        assert summarize(before, summary, runs)
        row = read_rows(summary / "summary.csv", ",")[0]
        average = 200 * (runs + 1)
        assert float(row["mean_ns"]) == average
        assert float(row["mean_bytes"]) == 64
        assert float(row["worst_value"]) == 1e-9 * runs
        assert int(row["status_ok"]) == runs and int(row["timing_runs"]) == runs
        if runs == 1:
            assert math.isnan(float(row["ci95_low_ns"]))
            assert math.isnan(float(row["ci95_high_ns"]))
        else:
            sd = 400 * math.sqrt(runs * (runs + 1) / 12)
            half = critical * sd / math.sqrt(runs)
            assert math.isclose(float(row["sd_between_runs_ns"]), sd)
            assert math.isclose(float(row["ci95_low_ns"]), max(0, average - half))
            assert math.isclose(float(row["ci95_high_ns"]), average + half)
        output = root / f"comparison{runs}"
        rows = compare(before, after, output, runs)
        assert len(rows) == 1
        row = rows[0]
        assert math.isclose(row["paired_time_ratio"], 0.5)
        assert row["before_median_bytes"] == 64 and row["after_median_bytes"] == 16
        assert row["median_bytes_change"] == -48 and row["unexpected_allocation"] is False
        assert math.isclose(row["before_worst_value"], runs * 1e-9)
        assert math.isclose(row["after_worst_value"], runs * 2e-9)
        assert math.isclose(row["worst_value_change"], runs * 1e-9)
        if runs == 1:
            assert math.isnan(row["ci95_low"]) and math.isnan(row["ci95_high"])
            assert row["timing_assessment"] == "single run; exploratory"
        else:
            assert math.isclose(row["ci95_low"], 0.5) and math.isclose(row["ci95_high"], 0.5)
            assert row["timing_assessment"] == "faster"
        # Vary the ratios so the logarithmic interval has a nonzero known width.
        varying = root / f"varying{runs}"
        fixture(varying, factor=lambda rep, case: 2 ** rep, runs=runs)
        row = compare(before, varying, root / f"varying-out{runs}", runs)[0]
        mu = ((runs + 1) / 2 - 2) * math.log(2)
        assert math.isclose(row["paired_time_ratio"], math.exp(mu))
        if runs > 1:
            half = critical * math.sqrt(runs * (runs + 1) / 12) * math.log(2) / math.sqrt(runs)
            assert math.isclose(row["ci95_low"], math.exp(mu - half))
            assert math.isclose(row["ci95_high"], math.exp(mu + half))
            assert row["timing_assessment"] == ("inconclusive" if mu - half <= 0 <= mu + half else "slower")
        report = (output / "REPORT.md").read_text()
        for sentence in ("Single-run ratios are exploratory", "containing one is inconclusive",
                         "Excluded cases are not ties"):
            assert sentence in report
    assert math.isnan(mean_interval([1.0]))
    record = root / "record-target"
    fixture(record, target=math.nan)
    assert validate(record, 3)["valid"]
    assert len(compare(record, record, root / "record-out", 3)) == 1
    assert summarize(record, root / "record-summary", 3)
    # Empty fields and explicit NaN both encode unavailable values.
    edit_rows(record, "catalog", lambda rows: rows[0].update(target=""), rep=2)
    assert validate(record, 3)["valid"]


def allocation_controls(root):
    cases = tuple(f"gradient/control/analytic/default/{phase}" for phase in ("workspace", "call", "setup"))
    before, after = root / "zero-bytes", root / "new-bytes"
    fixture(before, cases=cases)
    fixture(after, cases=cases, allocated=lambda rep, case: 16 * rep)
    rows = compare(before, after, root / "allocation-out", 3)
    assert len(rows) == 3
    for row in rows:
        assert row["before_median_bytes"] == 0 and row["after_median_bytes"] == 32
        assert row["after_max_bytes"] == 48
        assert row["unexpected_allocation"] is (row["phase"] == "workspace")


def sample_controls(root):
    folder = root / "asymmetric"
    fixture(folder)
    def skew_samples(rows):
        base = 400 * int(rows[0]["rep"])
        for index, row in enumerate(rows):
            row.update(time_ns=base if index < 4 else 100 * base,
                       gc_ns=base // 10 if index < 3 else 0, bytes=0 if index < 4 else 64)
    def skew_metrics(rows):
        base = 400 * int(rows[0]["rep"])
        rows[0].update(median_ns=base, mean_ns=20.8 * base, sd_ns=39.6 * base,
                       min_ns=base, max_ns=100 * base, p95_ns=80.2 * base,
                       gc_share=0.3 / 104, median_bytes=0, mean_bytes=12.8, min_bytes=0, max_bytes=64)
    edit_rows(folder, "samples", skew_samples)
    edit_rows(folder, "metrics", skew_metrics)
    assert validate(folder, 3)["valid"]
    output = root / "asymmetric-summary"
    assert summarize(folder, output, 3)
    row = read_rows(output / "summary.csv", ",")[0]
    assert float(row["mean_ns"]) == 800 and float(row["mean_bytes"]) == 0
    assert float(row["max_bytes"]) == 64
    # Integer-nanosecond rounding does not invalidate recomputable statistics.
    edit_rows(folder, "metrics", lambda rows: rows[0].update(
        sd_ns=round(float(rows[0]["sd_ns"])), p95_ns=round(float(rows[0]["p95_ns"]))))
    assert validate(folder, 3)["valid"]
    partial = root / "partial-samples"
    fixture(partial, status="target_missed")
    def partial_samples(rows):
        for row in rows[:4]:
            row.update(status="ok", value=1e-9)
    def partial_metrics(rows):
        base = 400 * int(rows[0]["rep"])
        rows[0].update(ok_samples=4, median_ns=0.875 * base, mean_ns=0.875 * base,
                       sd_ns=base * math.sqrt(5 / 64), min_ns=0.5 * base,
                       max_ns=1.25 * base, p95_ns=1.2125 * base, gc_share=0,
                       median_bytes=0, mean_bytes=0, min_bytes=0, max_bytes=0, median_value=1e-9)
    edit_rows(partial, "samples", partial_samples)
    edit_rows(partial, "metrics", partial_metrics)
    checked = validate(partial, 3)
    assert checked["valid"], checked["issues"]
    assert checked["counts"]["ok_samples"] == 12 and checked["status_counts"]["target_missed"] == 3
    assert summarize(partial, root / "partial-summary", 3)
    row = read_rows(root / "partial-summary" / "summary.csv", ",")[0]
    assert float(row["mean_ns"]) == 700 and int(row["timing_runs"]) == 3
    assert int(row["status_target_missed"]) == 3
    assert compare(partial, partial, root / "partial-out", 3) == []
    thrown = root / "thrown-sample"
    fixture(thrown, status="error")
    for rep in range(1, 4):
        path = thrown / f"julia-{VERSION}-rep{rep:02d}-samples.tsv"
        write_rows(path, "samples", [dict(id=DEFAULT_CASE, rep=rep, sample=1, time_ns="",
                                         gc_ns="", bytes="", value="", status="error")])
    edit_rows(thrown, "metrics", lambda rows: rows[0].update(samples=1))
    checked = validate(thrown, 3)
    assert checked["valid"], checked["issues"]
    assert checked["counts"]["samples"] == 3 and checked["status_counts"]["error"] == 3
    assert compare(thrown, thrown, root / "thrown-out", 3) == []
    construction = root / "construction-error"
    fixture(construction, status="error")
    edit_rows(construction, "metrics", lambda rows: rows[0].update(data_hash=""))
    assert validate(construction, 3)["valid"]
    assert compare(construction, construction, root / "construction-out", 3) == []


def failure_controls(root):
    good = "gradient/good/analytic/default/call"
    mixed = "gradient/mixed/analytic/default/call"
    cases = (good, mixed)
    before, after = root / "mixed-before", root / "mixed-after"
    fixture(before, cases=cases, status=lambda rep, case: (
        "target_missed" if case == mixed and rep == 2 else
        "uncertifiable" if case == mixed and rep == 3 else "ok"))
    fixture(after, cases=cases, status=lambda rep, case: (
        "uncertifiable" if case == mixed and rep == 1 else "ok"))
    checked = validate(before, 3)
    assert checked["valid"] and checked["counts"]["nonok_cases"] == 2
    assert checked["status_counts"]["ok"] == 4
    assert checked["status_counts"]["target_missed"] == 1
    assert checked["status_counts"]["uncertifiable"] == 1
    assert checked["case_status_counts"] == [
        dict(julia=VERSION, id=good, status_counts={status: 3 if status == "ok" else 0 for status in STATUSES}),
        dict(julia=VERSION, id=mixed, status_counts={status: 1 if status in (
            "ok", "target_missed", "uncertifiable") else 0 for status in STATUSES})]
    assert [(row["rep"], row["status"]) for row in checked["nonok_cases"]] == [
        (2, "target_missed"), (3, "uncertifiable")]
    out = root / "mixed-out"
    rows = compare(before, after, out, 3)
    assert [row["id"] for row in rows] == [good]
    coverage = json.loads((out / "coverage.json").read_text())
    assert coverage["excluded"] == [dict(julia=VERSION, id=mixed,
                                         before=["rep02: target_missed", "rep03: uncertifiable"],
                                         after=["rep01: uncertifiable"])]
    summary = root / "mixed-summary"
    assert summarize(before, summary, 3)
    row = next(row for row in read_rows(summary / "summary.csv", ",") if row["id"] == mixed)
    assert math.isnan(float(row["mean_ns"])) and int(row["timing_runs"]) == 1
    assert int(row["runs"]) == 3 and int(row["status_target_missed"]) == 1
    assert int(row["status_uncertifiable"]) == 1
    for status in STATUSES[1:]:
        failed_before, failed_after = root / f"failed-before-{status}", root / f"failed-after-{status}"
        fixture(failed_before, status=status)
        fixture(failed_after, status=status)
        edit_rows(failed_before, "metrics", lambda rows: rows[0].update(median_ns=""))
        checked = validate(failed_before, 3)
        assert checked["valid"], checked["issues"]
        assert checked["status_counts"][status] == 3 and checked["counts"]["ok_samples"] == 0
        output = root / f"failed-out-{status}"
        assert compare(failed_before, failed_after, output, 3) == []
        assert {path.name for path in output.iterdir()} == {"REPORT.md", "comparison.csv", "coverage.json"}
        assert (output / "comparison.csv").read_text().strip() == ",".join(FIELDS)
        excluded = json.loads((output / "coverage.json").read_text())["excluded"]
        reasons = [f"rep{rep:02d}: {status}" for rep in range(1, 4)]
        assert excluded == [dict(julia=VERSION, id=DEFAULT_CASE, before=reasons, after=reasons)]
        assert "No eligible cases" in (output / "REPORT.md").read_text()
        assert summarize(failed_before, root / f"failed-summary-{status}", 3)


def integrity_controls(root):
    folder = root / "integrity"
    fixture(folder)
    prefix = folder / f"julia-{VERSION}-rep01"
    final = Path(str(prefix) + "-metadata.toml")
    invalid_mutation(folder, final.unlink, "interrupted process")
    for kind in HEADERS:
        path = Path(str(prefix) + f"-{kind}.tsv")
        invalid_mutation(folder, path.unlink, "No such file")
        invalid_mutation(folder, lambda path=path: path.write_text("wrong\theader\n"), "wrong")
    invalid_mutation(folder, lambda: final.write_text("not valid toml ["), "invalid metadata")
    invalid_mutation(folder, lambda: edit_meta(folder, "finished", False), "not finished")
    invalid_mutation(folder, lambda: edit_meta(folder, "julia_threads", 2), "one Julia and one BLAS thread")
    invalid_mutation(folder, lambda: edit_meta(folder, "blas_threads", 2), "one Julia and one BLAS thread")
    for key in ("harness_hash", "proximalsolvers_hash", "proximalbase_hash", "proximalsolvers_sha"):
        invalid_mutation(folder, lambda key=key: edit_meta(folder, key, "bad"), "provenance hash")
    invalid_mutation(folder, lambda: edit_rows(folder, "metrics", lambda rows: rows.append(rows[0])),
                     "metrics do not cover")
    invalid_mutation(folder, lambda: edit_rows(folder, "metrics", lambda rows: rows[0].update(rep=9)),
                     "wrong metric repetition")
    invalid_mutation(folder, lambda: edit_rows(folder, "metrics", lambda rows: rows[0].update(samples=4)),
                     "sample coverage mismatch")
    invalid_mutation(folder, lambda: edit_rows(folder, "metrics", lambda rows: rows[0].update(ok_samples=4)),
                     "ok_samples disagrees")
    for key in ("median_ns", "mean_ns", "sd_ns", "min_ns", "max_ns", "p95_ns", "gc_share",
                "median_bytes", "mean_bytes", "min_bytes", "max_bytes"):
        invalid_mutation(folder, lambda key=key: edit_rows(folder, "metrics", lambda rows: rows[0].update({key: 999})),
                         f"{key} disagrees")
    for key in ("worst_value", "median_value"):
        invalid_mutation(folder, lambda key=key: edit_rows(folder, "metrics", lambda rows: rows[0].update({key: 1})),
                         f"{key} disagrees")
    for kind in ("metrics", "samples"):
        invalid_mutation(folder, lambda kind=kind: edit_rows(folder, kind, lambda rows: rows[0].update(status="unknown")),
                         "unknown")
    invalid_mutation(folder, lambda: edit_rows(folder, "samples", lambda rows: rows.append(rows[0])), "duplicate sample")
    invalid_mutation(folder, lambda: edit_rows(folder, "samples", lambda rows: rows[0].update(bytes=-1)), "invalid integer bytes")
    invalid_mutation(folder, lambda: edit_rows(folder, "metrics", lambda rows: rows[0].update(data_hash="a" * 40)),
                     "malformed data_hash")
    invalid_mutation(folder, lambda: edit_rows(folder, "catalog", lambda rows: rows[0].update(issue="#999"), rep=2),
                     "catalog changed")
    invalid_mutation(folder, lambda: edit_meta(folder, "seconds_limit", 2.0, rep=2), "series settings changed")
    invalid_mutation(folder, lambda: edit_meta(folder, "expected_package_root", "/other/package"), "loaded package root")
    missing_process = folder / f"julia-{VERSION}-rep03-metadata-start.toml"
    invalid_mutation(folder, lambda: [path.unlink() for path in folder.glob(f"julia-{VERSION}-rep03-*")], "process coverage")
    assert missing_process.exists()
    assert not validate(folder, 2)["valid"]
    assert not validate(folder, 4)["valid"]
    assert not validate(folder, 0)["valid"]
    assert not validate(root / "absent")["valid"]
    assert not validate(folder, 3, ["9.9.9"])["valid"]
    fixture(folder, version="1.11.0")
    assert validate(folder, 3, [VERSION, "1.11.0"])["valid"]
    assert validate(folder, 3)["counts"]["processes"] == 6
    assert not validate(folder, 3, [VERSION])["valid"]


def compatibility_controls(root):
    before, after = root / "compatible-before", root / "compatible-after"
    fixture(before)
    fixture(after)
    edit_meta(after, "proximalsolvers_hash", "e" * 40)
    edit_meta(after, "proximalsolvers_sha", "f" * 40)
    edit_meta(after, "proximalsolvers_dirty", True)
    assert len(compare(before, after, root / "changed-solver", 3)) == 1
    for key in SERIES_SETTINGS:
        if key.startswith("proximalsolvers_") or key in ("julia_threads", "blas_threads"):
            continue
        folder = root / f"incompatible-{key}"
        fixture(folder)
        replacements = dict(suite="extended", groups="gradient,cd", harness_hash="e" * 40,
                            proximalbase_version="0.5.5", proximalbase_hash="e" * 40,
                            blas="other", cpu_model="other", samples_target=10,
                            seconds_limit=2.0, case_seconds=30.0, profile_seconds=1.0, seed_scheme="other")
        edit_meta(folder, key, replacements[key])
        assert validate(folder, 3)["valid"]
        message = expect_error(lambda: compare(before, folder, root / f"reject-{key}", 3), "series settings differ")
        assert key in message
    folder = root / "hash-mismatch"
    fixture(folder)
    edit_rows(folder, "metrics", lambda rows: rows[0].update(data_hash="e" * 64), rep=2)
    assert validate(folder, 3)["valid"]
    message = expect_error(lambda: compare(before, folder, root / "reject-hash", 3), "data_hash mismatch")
    assert repr((VERSION, DEFAULT_CASE, 2)) in message
    for field, value in (("measure", "kkt_residual"), ("target", 1e-5)):
        folder = root / f"different-{field}"
        fixture(folder, **{field: value})
        assert validate(folder, 3)["valid"]
        expect_error(lambda: compare(before, folder, root / f"reject-{field}", 3), "certificate definitions differ")
    unmatched = root / "unmatched"
    other = "gradient/other/analytic/default/workspace"
    fixture(unmatched, cases=(other,))
    output = root / "reject-unmatched"
    expect_error(lambda: compare(before, unmatched, output, 3), "Case coverage differs")
    coverage = json.loads((output / "coverage.json").read_text())
    assert coverage["before_only"] == [[VERSION, DEFAULT_CASE, rep] for rep in range(1, 4)]
    assert coverage["after_only"] == [[VERSION, other, rep] for rep in range(1, 4)]
    assert coverage["excluded"] == [
        dict(julia=VERSION, id=DEFAULT_CASE, before=[], after=[f"rep{rep:02d}: missing case" for rep in range(1, 4)]),
        dict(julia=VERSION, id=other, before=[f"rep{rep:02d}: missing case" for rep in range(1, 4)], after=[])]
    occupied = root / "occupied"
    occupied.mkdir()
    sentinel = occupied / "keep.txt"
    sentinel.write_text("preserve\n")
    expect_error(lambda: summarize(before, occupied, 3), "fresh output directory")
    expect_error(lambda: compare(before, after, occupied, 3), "fresh output directory")
    assert {path.name for path in occupied.iterdir()} == {"keep.txt"}
    assert sentinel.read_text() == "preserve\n"


def cli_controls(root):
    scripts = Path(__file__).resolve().parent
    env = dict(os.environ, PYTHONDONTWRITEBYTECODE="1")
    def run(script, *args):
        return subprocess.run([sys.executable, str(scripts / script), *map(str, args)],
                              capture_output=True, text=True, env=env, check=False)
    for name in ("validate.py", "summarize.py", "compare.py"):
        assert run(name, "--help").returncode == 0
    valid = root / "failed-before-target_missed"
    report = root / "cli-validation.json"
    result = run("validate.py", valid, report, "--expected-runs", 3)
    assert result.returncode == 0, result.stderr
    checked = json.loads(report.read_text())
    assert checked["valid"] and checked["status_counts"]["target_missed"] == 3
    result = run("validate.py", root / "missing", report)
    assert result.returncode == 2 and json.loads(report.read_text())["valid"] is False
    result = run("validate.py", valid, root / "nonexistent" / "out.json", "--expected-runs", 3)
    assert result.returncode == 3 and "Cannot write validation JSON" in result.stderr
    result = run("compare.py", valid, valid, root / "cli-failed", "--expected-runs", 3)
    assert result.returncode == 0, result.stderr
    result = run("summarize.py", valid, root / "cli-summary", "--expected-runs", 3)
    assert result.returncode == 0, result.stderr
    result = run("compare.py", root / "missing", valid, root / "cli-invalid", "--expected-runs", 3)
    assert result.returncode == 2 and "Invalid results" in result.stderr


def main():
    if len(sys.argv) != 1:
        raise SystemExit("check_analysis.py takes no arguments")
    with tempfile.TemporaryDirectory(prefix="ps-analysis-control-") as temporary:
        root = Path(temporary)
        analytic_controls(root)
        allocation_controls(root)
        sample_controls(root)
        failure_controls(root)
        integrity_controls(root)
        compatibility_controls(root)
        cli_controls(root)
    print("ANALYSIS_CONTROLS_PASSED repetitions=1,3,5,10; medians,t-intervals,paired-ratios,"
          "allocations,statuses,all-failed,interrupted,corruption,coverage,provenance,"
          "series-settings,data-hashes,certificates,fresh-output,CLI")


if __name__ == "__main__":
    main()
