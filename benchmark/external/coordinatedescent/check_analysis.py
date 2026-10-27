#!/usr/bin/env python3
"""Run analytic controls and synthetic three-arm records without Julia."""

from array import array
from contextlib import redirect_stdout
import csv
import hashlib
import importlib.util
import io
import json
import math
import os
from pathlib import Path
import random
import shutil
import statistics
import subprocess
import sys
import tempfile
import tomllib

sys.dont_write_bytecode = True
import analysis
import crosscheck


SPEC = importlib.util.spec_from_file_location("issue116_controls", Path(__file__).resolve().parents[2] / "check_analysis.py")
controls = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(controls)
CASE = controls.DEFAULT_CASE


def close(actual, expected, rel=1e-10, absolute=1e-12):
    assert math.isclose(actual, expected, rel_tol=rel, abs_tol=absolute), (actual, expected)


def expect_error(action, text):
    try:
        action()
    except (ValueError, OSError) as error:
        assert text in str(error), str(error)
    else:
        raise AssertionError(f"expected error containing {text!r}")


def write_table(path, rows, fields=None):
    fields = fields or list(rows[0])
    with path.open("w", newline="", encoding="utf-8") as stream:
        writer = csv.DictWriter(stream, fields, delimiter="\t", lineterminator="\n")
        writer.writeheader()
        writer.writerows(rows)


def write_toml(path, values):
    path.write_text("".join(f"{key} = {analysis.toml_literal(value)}\n" for key, value in values.items()),
                    encoding="utf-8")


def add_external_fields(folder, side, view="defaults", setting=0):
    for path in folder.glob("*-catalog.tsv"):
        rows = controls.read_rows(path)
        for row in rows:
            row.update(estimator="lasso", design="A", lambda_="0.1")
            row["lambda"] = row.pop("lambda_")
            row.update(order="cyclic", setting_index=setting, stopping="control", inputs="fixed", family="coordinate")
        write_table(path, rows)
    for path in folder.glob("*-metadata*.toml"):
        meta = analysis.base_validate.metadata(path)
        meta.update(side=side, view=view, artifact_sha256="a" * 64, manifest_sha256="b" * 64,
                    coordinatedescent_version="0.6.1", highdimensionalmodels_rev="c" * 40)
        if side == "legacy":
            meta.update(manifest_sha256="d" * 64, proximalbase_version="0.4.1",
                        proximalbase_hash="e" * 40)
        write_toml(path, meta)


def fixture(root, runs=3, cases=(CASE,), status="ok", view="defaults", target=math.nan,
            current_factor=8, aa_factor=None, accuracy=1e-12):
    root.mkdir()
    for side in analysis.ARMS:
        factor = 4 if side == "legacy" else current_factor
        if side == "current-AA" and aa_factor is not None:
            factor = aa_factor
        folder = root / side
        controls.fixture(folder, runs=runs, factor=factor, cases=cases, status=status,
                         accuracy=accuracy, target=target)
        add_external_fields(folder, side, view, 1 if view == "frozen" else 0)
    return root


def simple_selection(root, cases=(CASE,), targets=(1e-6,)):
    rows = [dict(id=case, side=side, family=family, target=target,
                 status="selected", setting_index=1)
            for case in cases for target in targets
            for side, family in (("legacy", "coordinate"), ("current", "coordinate"), ("current", "best"))]
    path = root / "selection.toml"
    write_toml(path, dict(selection=rows))
    return path


def analytic_controls():
    # Standard Student-t table values, including degrees of freedom beyond #116.
    for df, critical in ((1, 12.7062047364321), (2, 4.30265272969614),
                         (5, 2.57058183563631), (11, 2.20098516008295),
                         (30, 2.04227245630124), (100, 1.98397151844963)):
        close(analysis.t_cdf(critical, df), .975, rel=2e-10)
        close(analysis.t_cdf(-critical, df), .025, rel=2e-9)
        close(analysis.t_quantile(.975, df), critical, rel=2e-9)
        close(analysis.t_cdf(0, df), .5)
    for x in (-100, -1, 0, 1, 100):
        close(analysis.t_cdf(x, 1), .5 + math.atan(x) / math.pi)
    close(analysis.t_survival(math.inf, 3), 0)
    close(analysis.t_survival(-math.inf, 3), 1)
    mu, low, high = analysis.mean_interval([1, 2, 3])
    close(mu, 2)
    close(high - mu, 4.30265272969614 / math.sqrt(3))
    close(mu - low, high - mu)
    assert math.isnan(analysis.mean_interval([1])[1])
    close(analysis.one_sided_p([1, 2, 3], 2), .5)
    close(analysis.one_sided_p([2, 2, 2], 1), 0)
    close(analysis.one_sided_p([2, 2, 2], 3), 1)
    assert math.isnan(analysis.one_sided_p([1], 0))
    # BH thresholds: .02,.04,.06,.08,.10. Largest passing rank is three.
    assert analysis.bh_decisions(dict(a=.01, b=.04, c=.055, d=.09, e=.5)) == {"a", "b", "c"}
    assert analysis.bh_decisions(dict(a=.06, b=.06)) == {"a", "b"}
    assert analysis.bh_decisions(dict(a=.11, b=math.nan)) == set()
    assert analysis.order_statistic_rank(0) is None
    assert analysis.order_statistic_rank(58) is None
    assert analysis.order_statistic_rank(59) == 59
    assert analysis.order_statistic_rank(100) == 99
    for n in (59, 100, 200):
        rank = analysis.order_statistic_rank(n)
        cdf = lambda k: sum(math.comb(n, j) * .95 ** j * .05 ** (n - j) for j in range(k))
        assert cdf(rank) >= .95
        assert rank == 1 or cdf(rank - 1) < .95
    noise = analysis.noise_floor([i / 1000 for i in range(100)])
    close(noise["q"], .098)
    close(noise["delta"], .098)
    close(analysis.noise_floor([0] * 59)["delta"], math.log(1.05))
    assert math.isinf(analysis.noise_floor([0] * 58)["delta"])
    # Both cases move together: block bootstrap must preserve that correlation.
    logs = [[-.2, -.1, 0, .1, .2], [1.8, 1.9, 2, 2.1, 2.2]]
    first = analysis.block_bootstrap(logs)
    assert first == analysis.block_bootstrap(logs)
    close(first[0], 1)
    assert first[1] < 1 < first[2]
    assert first[1] > .7 and first[2] < 1.3
    assert analysis.block_bootstrap([[0] * 12, [2] * 12]) == (1, 1, 1)
    # Fixed-seed coverage control under a known iid, mean-zero normal model.
    rng = random.Random(917)
    covered = 0
    for _ in range(80):
        values = [rng.gauss(0, 1) for _ in range(60)]
        _, lo, hi = analysis.block_bootstrap([values], resamples=600)
        covered += lo <= 0 <= hi
    assert 69 <= covered <= 80, covered
    assert analysis.support_sets([0., 1., 1e-9, -2.]) == [{1, 3}]
    assert analysis.support_sets([0., 0.]) == [set()]
    assert analysis.support_sets([1., 0., 0., 2.], 2) == [{0}, {1}]
    assert analysis.support_sets([math.nan]) is None


def record_controls(root):
    cases = tuple(f"gradient/control{i}/analytic/default/workspace" for i in range(5))
    arms = fixture(root / "valid", runs=12, cases=cases)
    result, groups, _ = analysis.analyze(arms, root / "report", 12)
    assert len(result) == 5
    for row in result:
        close(row["ratio"], 2)
        close(row["ci95_low"], 2)
        close(row["ci95_high"], 2)
        assert row["candidate"] and row["bh_rejected"]
        assert "passes BH" in row["assessment"]
    close(groups[0]["ratio"], 2)
    assert groups[0]["cases_eligible"] == 5
    noise = json.loads((root / "report" / "noise.json").read_text())
    assert noise["views"][0]["observations"] == 60
    close(noise["views"][0]["delta"], math.log(1.05))
    report = (root / "report" / "REPORT.md").read_text()
    assert "Defaults view" in report and "Primary matched view" in report
    assert "independently confirmed" in report
    small = fixture(root / "small", current_factor=4)
    rows, _, _ = analysis.analyze(small, root / "small-report", 3)
    assert rows[0]["assessment"] == "inconclusive, not a tie"
    assert not rows[0]["candidate"] and not rows[0]["bh_rejected"]
    assert json.loads((root / "small-report" / "noise.json").read_text())["views"][0]["q"] is None
    missed = fixture(root / "defaults-missed", status="target_missed", target=1e-6)
    rows, _, _ = analysis.analyze(missed, root / "defaults-missed-report", 3)
    close(rows[0]["ratio"], 2)
    assert "target_missed=3" in rows[0]["current_statuses"]
    missed_matched = fixture(root / "matched-missed", status="target_missed", target=1e-6, view="frozen")
    rows, _, _ = analysis.analyze(missed_matched, root / "matched-missed-report", 3,
                                 selection=simple_selection(missed_matched))
    assert len(rows) == 2 and all(row["assessment"] == "not reached" and math.isnan(row["ratio"]) for row in rows)
    for status in ("error", "timeout", "incomplete", "uncertifiable"):
        failed = fixture(root / f"failed-{status}", status=status)
        rows, groups, _ = analysis.analyze(failed, root / f"failed-{status}-report", 3)
        assert len(rows) == 1 and f"{status}=3" in rows[0]["legacy_statuses"]
        assert groups[0]["cases_total"] == 1
        if status != "uncertifiable":
            assert math.isnan(rows[0]["ratio"]) and groups[0]["cases_eligible"] == 0
    single = fixture(root / "single", runs=1)
    rows, _, _ = analysis.analyze(single, root / "single-report", 1)
    assert math.isnan(rows[0]["ci95_low"]) and not rows[0]["candidate"]
    combined = root / "both-targets"
    combined.mkdir()
    for target in (1e-6, 1e-8):
        source = fixture(root / f"matched-{target}", target=target, view="frozen")
        for side in analysis.ARMS:
            destination = combined / side
            destination.mkdir(exist_ok=True)
            shutil.copytree(source / side, destination / str(target))
    rows, _, _ = analysis.analyze(combined, root / "both-targets-report", 3,
                                 selection=simple_selection(combined, targets=(1e-6, 1e-8)))
    assert len(rows) == 4 and {row["target"] for row in rows} == {"1e-06", "1e-08"}
    assert [row["view"] for row in rows] == ["primary", "primary", "secondary", "secondary"]


def mutate_records(folder, pattern, change):
    for path in folder.glob(pattern):
        rows = controls.read_rows(path)
        change(rows)
        write_table(path, rows)


def integrity_controls(root):
    arms = fixture(root / "integrity")
    def mutation(change, text):
        snapshot = {path: path.read_bytes() for path in arms.rglob("*") if path.is_file()}
        try:
            change()
            expect_error(lambda: analysis.load_arms(arms, 3), text)
        finally:
            for path, data in snapshot.items():
                path.parent.mkdir(parents=True, exist_ok=True)
                path.write_bytes(data)
    mutation(lambda: shutil.rmtree(arms / "current-AA"), "missing arm")
    mutation(lambda: [path.unlink() for path in (arms / "legacy").glob("*-rep03-*")], "missing blocks")
    mutation(lambda: (next((arms / "current").glob("*-rep01-metadata.toml"))).unlink(), "interrupted")
    for key in ("artifact_sha256", "manifest_sha256", "highdimensionalmodels_rev"):
        mutation(lambda key=key: controls.edit_meta(arms / "current-AA", key, "f" * (40 if key.endswith("rev") else 64)),
                 "artifact_sha256 mismatch" if key == "artifact_sha256" else f"{key} mismatch")
    mutation(lambda: mutate_records(arms / "current", "*-metrics.tsv",
                                    lambda rows: rows[0].update(data_hash="f" * 64)), "data_hash mismatch")
    mutation(lambda: mutate_records(arms / "current", "*-metrics.tsv",
                                    lambda rows: rows[0].update(median_ns="999")), "median_ns disagrees")
    mutation(lambda: mutate_records(arms / "current", "*-samples.tsv",
                                    lambda rows: rows.append(rows[0])), "duplicate sample")
    mutation(lambda: controls.edit_meta(arms / "legacy", "cpu_model", "other"), "comparison settings differ")
    expect_error(lambda: analysis.load_arms(arms, 2), "extra block")
    expect_error(lambda: analysis.load_arms(arms, 4), "missing blocks")


def selection_controls(root):
    arms = fixture(root / "calibration", view="ladder")
    definitions = {"case": [dict(id=CASE, legacy=dict(ladder=[dict(tol=1e-4, stopping="loose"),
                                                                    dict(tol=1e-8, stopping="tight")]),
                                 current=dict(ladder=[dict(tol=1e-4, stopping="loose"),
                                                     dict(tol=1e-8, stopping="tight")]))]}
    (arms / "catalog.toml").write_text("case = " + analysis.toml_literal(definitions["case"]) + "\n")
    for side in analysis.ARMS:
        for kind in analysis.base_validate.HEADERS:
            for path in (arms / side).glob(f"*-{kind}.tsv"):
                rows = controls.read_rows(path)
                expanded = []
                for index in (1, 2):
                    for original in rows:
                        parts = original["id"].split("/")
                        parts[-2] += f"__rung{index}"
                        row = dict(original, id="/".join(parts))
                        if kind == "catalog":
                            row["setting_index"] = index
                            row["case_id"] = CASE
                            row["variant"] += f"__rung{index}"
                        if kind == "samples":
                            row["value"] = 1e-7 if index == 1 else 1e-9
                        if kind == "metrics":
                            row.update(worst_value=1e-7 if index == 1 else 1e-9,
                                       median_value=1e-7 if index == 1 else 1e-9)
                        expanded.append(row)
                write_table(path, expanded, list(expanded[0]) if expanded else analysis.base_validate.HEADERS[kind])
        controls.edit_meta(arms / side, "cases", 2)
        controls.edit_meta(arms / side, "ok_cases", 2)
    _, _, selected = analysis.analyze(arms, root / "selection-report", 3, select=True)
    assert len(selected) == 6
    assert all(row["setting_index"] == (1 if row["target"] == 1e-6 else 2) for row in selected)
    assert {(row["side"], row["family"]) for row in selected} == {
        ("legacy", "coordinate"), ("current", "coordinate"), ("current", "best")}
    with (root / "selection-report" / "selection.toml").open("rb") as stream:
        frozen = tomllib.load(stream)
    assert frozen["selection"] == selected
    rungs = controls.read_rows(root / "selection-report" / "rungs.csv", delimiter=",")
    assert len(rungs) == 8
    assert {row["family"] for row in rungs} == {"coordinate"}
    close(float(rungs[0]["overshoot"]), 10)
    loaded, _, _ = analysis.load_arms(arms, 3, select=True)
    record = next(record for key, record in loaded.items() if key[3] == 1)
    assert analysis.choose_rung({1: [record]}, 1e-8) is None
    assert analysis.choose_rung({2: [record], 1: [record]}, 1e-6) == 1
    record["metric"]["status"] = "error"
    assert analysis.choose_rung({1: [record]}, 1e-6) is None
    # One process missing the target invalidates an otherwise good rung.
    good = next(record for key, record in loaded.items() if key[3] == 2)
    assert analysis.choose_rung({1: [good, record]}, 1e-6) is None
    for value in loaded.values():
        value["metric"]["status"] = "error"
    _, rows = analysis.calibration(loaded, definitions, root / "selection-report")
    assert not any(row["eligible"] for row in rows)
    assert "not reached" in (root / "selection-report" / "selection.toml").read_text()
    definitions["case"][0]["current"]["gap_ladder"] = [dict(gaptol=1e-10)]
    assert analysis.settings_for(definitions, CASE, "current", 3) == dict(gaptol=1e-10)


def companion_catalogs(folder):
    for final in folder.glob("*-metadata.toml"):
        meta = analysis.base_validate.metadata(final)
        prefix = final.name.removesuffix("-metadata.toml")
        path = final.with_name(prefix + "-catalog.tsv")
        entries = analysis.read_table(path, "catalog", meta)
        companion = folder / "external" / path.name
        companion.parent.mkdir(exist_ok=True)
        write_table(companion, entries)
        write_table(path, [{key: entry[key] for key in analysis.base_validate.HEADERS["catalog"]}
                           for entry in entries])
        controls.edit_meta(folder, "external_catalog", str(companion.relative_to(folder)), rep=meta["rep"])


def family_calibration(root):
    cases = (CASE, "gradient/coincide/analytic/default/workspace")
    arms = fixture(root, cases=cases, view="ladder")
    definitions = {"case": []}
    for case in cases:
        options = {side: dict(ladder=[dict(family="coordinate", stopping="coordinate-change", gaptol=0., tol=tol)
                                     for tol in (1e-5, 1e-8)]) for side in ("legacy", "current")}
        options["current"]["gap_ladder"] = [dict(family="gap", stopping="relative-gap", gaptol=1e-9, tol=1e-12)]
        definitions["case"].append(dict(id=case, **options))
    write_toml(arms / "catalog.toml", definitions)
    for side in analysis.ARMS:
        folder = arms / side
        side_options = "legacy" if side == "legacy" else "current"
        for final in folder.glob("*-metadata.toml"):
            meta = analysis.base_validate.metadata(final)
            prefix = final.name.removesuffix("-metadata.toml")
            tables = {kind: controls.read_rows(final.with_name(prefix + f"-{kind}.tsv"))
                      for kind in analysis.base_validate.HEADERS}
            expanded = {kind: [] for kind in tables}
            settings = []
            for index in range(1, 3 if side == "legacy" else 4):
                for kind, rows in tables.items():
                    for original in rows:
                        case = original["id"]
                        parts = case.split("/")
                        parts[-2] += f"-setting{index:02d}"
                        row = dict(original, id="/".join(parts))
                        if kind == "catalog":
                            options = analysis.settings_for(definitions, case, side_options, index)
                            row.update(case_id=case, setting_index=index, variant=parts[-2],
                                       family=options["family"], stopping=options["stopping"])
                            settings.append(dict(id=row["id"], case_id=case, setting_index=index, settings=options))
                        elif kind == "samples":
                            if side == "legacy":
                                factor = {1: 4, 2: 8}[index]
                            elif case == cases[0]:
                                factor = {1: 12, 2: 8, 3: 2}[index]
                                if side == "current-AA" and index == 3:
                                    factor = 4
                            else:
                                factor = {1: 4, 2: 8, 3: 16}[index]
                            row["time_ns"] = int(float(row["time_ns"]) * factor / (4 if side == "legacy" else 8))
                            row["value"] = 1e-7 if case == cases[1] and index == 1 else 1e-9
                        expanded[kind].append(row)
            samples = {}
            for row in expanded["samples"]:
                samples.setdefault(row["id"], []).append(row)
            for row in expanded["metrics"]:
                row.update(analysis.base_validate.sample_statistics(samples[row["id"]]))
                value = float(samples[row["id"]][0]["value"])
                row.update(worst_value=value, median_value=value)
            for kind, rows in expanded.items():
                write_table(final.with_name(prefix + f"-{kind}.tsv"), rows,
                            list(rows[0]) if rows else analysis.base_validate.HEADERS[kind])
            write_toml(final.with_name(prefix + "-settings.toml"), dict(case=settings))
        count = len(cases) * (2 if side == "legacy" else 3)
        controls.edit_meta(folder, "cases", count)
        controls.edit_meta(folder, "ok_cases", count)
        companion_catalogs(folder)
    return arms, cases


def frozen_union(source, destination, selection_path, target=None):
    shutil.copytree(source, destination)
    selected = analysis.read_selection(selection_path)
    targets = (target,) if target is not None else analysis.TARGETS
    for side in analysis.ARMS:
        folder = destination / side
        for final in folder.glob("*-metadata.toml"):
            meta = analysis.base_validate.metadata(final)
            prefix = final.name.removesuffix("-metadata.toml")
            path = final.with_name(prefix + "-catalog.tsv")
            entries = analysis.read_table(path, "catalog", meta)
            keep = []
            for entry in entries:
                methods = ("coordinate",) if side == "legacy" else ("coordinate", "best")
                choices = [analysis.selected_entry(selected, entry["case_id"], side, family, format(value, ".12g"))
                           for family in methods for value in targets]
                if any(row["status"] == "selected" and row["setting_index"] == int(entry["setting_index"])
                       for row in choices):
                    keep.append(dict(entry, target=target if target is not None else math.nan))
            ids = {entry["id"] for entry in keep}
            write_table(folder / meta["external_catalog"], keep)
            write_table(path, [{key: entry[key] for key in analysis.base_validate.HEADERS["catalog"]} for entry in keep])
            for kind in ("metrics", "samples", "errors"):
                path = final.with_name(prefix + f"-{kind}.tsv")
                rows = [row for row in controls.read_rows(path) if row["id"] in ids]
                if kind == "metrics":
                    for row in rows:
                        row["target"] = target if target is not None else math.nan
                write_table(path, rows, analysis.base_validate.HEADERS[kind])
            path = final.with_name(prefix + "-settings.toml")
            options = analysis.base_validate.metadata(path)["case"]
            write_toml(path, dict(case=[row for row in options if row["id"] in ids]))
            for suffix in ("-metadata.toml", "-metadata-start.toml"):
                path = final.with_name(prefix + suffix)
                metadata = analysis.base_validate.metadata(path)
                metadata.update(view="frozen", frozen_sha256=selected["sha256"])
                metadata.update(dict(accuracy_target=target) if target is not None else dict(accuracy_targets=list(targets)))
                if suffix == "-metadata.toml":
                    metadata.update(cases=len(keep), ok_cases=len(keep), nonok_cases=0)
                write_toml(path, metadata)
    return destination


def family_controls(root):
    arms, cases = family_calibration(root / "families")
    output = root / "family-selection"
    _, _, rows = analysis.analyze(arms, output, 3, select=True)
    selected = {(row["id"], row["side"], row["family"], row["target"]): row for row in rows}
    assert len(rows) == 12
    for target in analysis.TARGETS:
        assert selected[(cases[0], "current", "coordinate", target)]["setting_index"] == 2
        assert selected[(cases[0], "current", "best", target)]["setting_index"] == 3
        expected = 1 if target == 1e-6 else 2
        assert selected[(cases[1], "current", "coordinate", target)]["setting_index"] == expected
        assert selected[(cases[1], "current", "best", target)]["setting_index"] == expected
        assert selected[(cases[0], "legacy", "coordinate", target)]["setting_index"] == 1
        assert selected[(cases[1], "legacy", "coordinate", target)]["setting_index"] == expected
    rungs = controls.read_rows(output / "rungs.csv", delimiter=",")
    assert len(rungs) == 20 and {row["family"] for row in rungs} == {"coordinate", "gap"}
    assert all(row["family"] == ("gap" if int(row["setting_index"]) == 3 else "coordinate") for row in rungs)
    selection_path = output / "selection.toml"
    confirmation = frozen_union(arms, root / "family-confirmation", selection_path)
    report = root / "family-report"
    results, groups, _ = analysis.analyze(confirmation, report, 3, selection=selection_path)
    by_case = {(row["view"], row["id"]): row for row in results if row["target"] == "1e-06"}
    assert [row["view"] for row in results] == ["primary"] * 4 + ["secondary"] * 4
    close(by_case[("primary", cases[0])]["ratio"], 2)
    close(by_case[("secondary", cases[0])]["ratio"], .5)
    assert by_case[("primary", cases[0])]["current_setting_index"] == "2"
    assert by_case[("secondary", cases[0])]["current_setting_index"] == "3"
    for view in ("primary", "secondary"):
        close(by_case[(view, cases[1])]["ratio"], 1)
        assert by_case[(view, cases[1])]["current_setting_index"] == "1"
        tight = next(row for row in results if row["view"] == view and row["id"] == cases[1] and row["target"] == "1e-08")
        assert tight["current_setting_index"] == "2" and tight["legacy_setting_index"] == "2"
        close(tight["ratio"], 1)
    aggregate = {row["view"]: row for row in groups if row["group"] == "all" and row["target"] == "1e-06"}
    close(aggregate["primary"]["ratio"], math.sqrt(2))
    close(aggregate["secondary"]["ratio"], math.sqrt(.5))
    text = (report / "REPORT.md").read_text()
    assert text.index("## Primary matched view") < text.index("## Secondary matched view")
    selection = analysis.read_selection(selection_path)
    loaded, definitions, processes = analysis.load_arms(confirmation, 3, selection=selection)
    expanded = {}
    for key, record in loaded.items():
        if key[-1] == 1:
            for block in range(1, 61):
                expanded[(*key[:-1], block)] = dict(record, meta=dict(record["meta"], rep=block))
    analysis.validate_selected_union(expanded, definitions, selection, 60, processes)
    results, _, noise = analysis.inference(expanded, 60, selection, processes)
    close(noise[("primary", "1e-06")]["delta"], math.log(1.05))
    close(noise[("secondary", "1e-06")]["q"], math.log(2))
    assert noise[("primary", "1e-06")]["observations"] == 120
    assert noise[("secondary", "1e-06")]["observations"] == 120
    decisions = {(row["view"], row["id"]): row for row in results if row["target"] == "1e-06"}
    assert decisions[("primary", cases[0])]["candidate"] and decisions[("primary", cases[0])]["bh_rejected"]
    assert not decisions[("secondary", cases[0])]["candidate"]
    missing = dict(expanded)
    missing.pop(("current", "frozen", cases[0], 3, "record", 1))
    expect_error(lambda: analysis.validate_selected_union(missing, definitions, selection, 60, processes),
                 "frozen setting coverage mismatch")
    expect_error(lambda: analysis.load_arms(confirmation, 3), "requires --selection")
    family_failure_controls(root, arms, cases, selection, confirmation)
    return confirmation, selection_path


def family_failure_controls(root, arms, cases, selection, confirmation):
    rows = analysis.base_validate.metadata(root / "family-selection" / "selection.toml")["selection"]
    path = root / "incomplete-selection.toml"
    write_toml(path, dict(selection=[row for row in rows if row["family"] != "best"]))
    expect_error(lambda: analysis.read_selection(path), "missing selection family")
    write_toml(path, dict(selection=rows + [rows[0]]))
    expect_error(lambda: analysis.read_selection(path), "duplicate selection entry")
    write_toml(path, dict(selection=rows))
    path.write_text(path.read_text() + "\n")
    changed = analysis.read_selection(path)
    expect_error(lambda: analysis.load_arms(confirmation, 3, selection=changed), "SHA-256 differs")
    loaded, definitions, processes = analysis.load_arms(confirmation, 3, selection=selection)
    invalid = dict(selection, rows={key: dict(value) for key, value in selection["rows"].items()})
    invalid["rows"][(cases[0], "current", "coordinate", "1e-06")]["setting_index"] = 3
    expect_error(lambda: analysis.validate_selected_union(loaded, definitions, invalid, 3, processes),
                 "coordinate selection points to the gap ladder")
    calibration, definitions, _ = analysis.load_arms(arms, 3, select=True)
    for key, record in calibration.items():
        if key[0] == "current" and key[2] == cases[0] and key[3] in (1, 2):
            record["metric"]["worst_value"] = "1e-5"
            for sample in record["samples"]:
                sample["value"] = "1e-5"
    output = root / "family-not-reached-selection"
    output.mkdir()
    selected, _ = analysis.calibration(calibration, definitions, output)
    assert all(row["status"] == "not reached" for row in selected
               if row["id"] == cases[0] and row["side"] == "current" and row["family"] == "coordinate")
    assert all(row["status"] == "selected" for row in selected
               if row["id"] == cases[0] and row["side"] == "current" and row["family"] == "best")
    path = output / "selection.toml"
    incomplete = frozen_union(arms, root / "family-not-reached-confirmation", path)
    results, groups, _ = analysis.analyze(incomplete, root / "family-not-reached-report", 3, selection=path)
    for row in results:
        if row["id"] == cases[0]:
            if row["view"] == "primary":
                assert row["assessment"] == "not reached" and math.isnan(row["ratio"])
            else:
                close(row["ratio"], .5)
    assert all(row["cases_eligible"] == (1 if row["view"] == "primary" else 2)
               for row in groups if row["group"] == "all")


def optional_aa_controls(root):
    arms, _ = family_calibration(root / "optional-aa")
    _, _, with_aa = analysis.analyze(arms, root / "optional-aa-present", 3, select=True)
    shutil.rmtree(arms / "current-AA")
    report = root / "optional-aa-absent"
    _, _, without_aa = analysis.analyze(arms, report, 3, select=True)
    assert without_aa == with_aa
    assert "current-AA arm: absent" in (report / "REPORT.md").read_text()
    noise = json.loads((report / "noise.json").read_text())
    assert not noise["aa_present"] and noise["views"] == []
    confirmation = fixture(root / "aa-required")
    shutil.rmtree(confirmation / "current-AA")
    expect_error(lambda: analysis.load_arms(confirmation, 3), "missing arm: current-AA")
    calibration_defaults = fixture(root / "optional-aa-defaults")
    shutil.rmtree(calibration_defaults / "current-AA")
    rows, _, _ = analysis.analyze(calibration_defaults, root / "optional-aa-defaults-report", 3, select=True)
    assert rows[0]["current-AA_statuses"] == "absent" and not rows[0]["candidate"]


def schema_controls(root):
    arms = fixture(root / "schema")
    write_toml(arms / "catalog.toml", {"case": [dict(id=CASE)]})
    catalog_hash = crosscheck.sha256(arms / "catalog.toml")
    for side in analysis.ARMS:
        folder = arms / side
        controls.edit_meta(folder, "catalog_sha256", catalog_hash)
        for path in folder.glob("*-catalog.tsv"):
            rows = controls.read_rows(path)
            for row in rows:
                row.update(case_id=CASE, family="coordinate", gram_policy="public-default-auto")
            rep = int(path.name.split("-rep")[1].split("-")[0])
            external = folder / "external" / f"catalog-block{rep}.tsv"
            external.parent.mkdir(exist_ok=True)
            write_table(external, rows)
            controls.edit_meta(folder, "external_catalog", str(external.relative_to(folder)), rep=rep)
            write_table(path, [{key: row[key] for key in analysis.base_validate.HEADERS["catalog"]}
                               for row in rows])
            settings = dict(id=CASE, case_id=CASE, setting_index=0,
                            settings=dict(opt_tol=1e-7, stopping="control"))
            write_toml(path.with_name(path.name.removesuffix("-catalog.tsv") + "-settings.toml"),
                       dict(case=[settings]))
        coef = folder / "coef"
        coef.mkdir()
        rows = []
        for rep in range(1, 4):
            descriptor = raw_file(coef, f"control{rep}.f64", [0., 2., 1e-10], [3, 1])
            rows.append(dict(id=CASE, case_id=CASE, setting_index=0, rep=rep,
                             file="coef/" + descriptor["file"], rows=3, columns=1,
                             dtype="Float64", sha256=descriptor["sha256"]))
        write_table(coef / "manifest.tsv", rows)
    rows, _, _ = analysis.analyze(arms, root / "schema-report", 3)
    assert json.loads(rows[0]["current_support_sizes"]) == [[1], [1], [1]]
    assert rows[0]["support_reference"] == "unavailable"
    base = next((arms / "current").glob("*-catalog.tsv"))
    expect_error(lambda: analysis.read_table(base, "catalog", dict(external_catalog="/outside.tsv")),
                 "relative path")
    expect_error(lambda: analysis.read_table(base, "catalog", dict(external_catalog="../outside.tsv")),
                 "leaves the process directory")
    expect_error(lambda: analysis.read_table(base, "catalog", dict(external_catalog="external/missing.tsv")),
                 "No such file")
    companion = arms / "current" / "external" / "catalog-block1.tsv"
    original = companion.read_bytes()
    entries = controls.read_rows(companion)
    entries[0]["issue"] = "other"
    write_table(companion, entries)
    base = next((arms / "current").glob("*-rep01-catalog.tsv"))
    expect_error(lambda: analysis.read_table(base, "catalog", dict(external_catalog="external/catalog-block1.tsv")),
                 "disagrees with base catalog")
    companion.write_bytes(original)
    settings_path = next((arms / "current-AA").glob("*-settings.toml"))
    meta = analysis.base_validate.metadata(settings_path)
    meta["case"][0]["settings"]["opt_tol"] = 1e-8
    write_toml(settings_path, meta)
    expect_error(lambda: analysis.load_arms(arms, 3), "settings changed across blocks")


def certificate_controls():
    x, y, n, p = [1., 0., 0., 1.], [3., 4.], 2, 2
    for estimator in ("lasso", "path", "weighted_lasso"):
        close(crosscheck.certificate(x, y, [2., 3.], n, p, estimator, .5), 0)
        close(crosscheck.certificate(x, y, [0., 0.], n, p, estimator, .5), .5625)
    close(crosscheck.certificate(x, y, [1., 3.], n, p, "weighted_lasso", .5, [2, 1]), 0)
    close(crosscheck.certificate(x, y, [3., 4.], n, p, "lasso", 0), 0)
    close(crosscheck.certificate(x, y, [3., 3.], n, p, "weighted_lasso", .5, [0, 1]), 0)
    close(crosscheck.certificate(x, y, [2.4, 3.2], n, p, "group_lasso", .5,
                                groups=[[0, 1]], group_weights=[1]), 0)
    close(crosscheck.certificate(x, y, [0., 0.], n, p, "group_lasso", .5,
                                groups=[[0, 1]], group_weights=[1]), .64)
    for estimator in ("sqrt_lasso", "scaled_lasso"):
        close(crosscheck.certificate(x, y, [0., 0.], n, p, estimator, 1), 0)
        close(crosscheck.certificate(x, y, [0., 0.], n, p, estimator, .1), 1 - .1 * math.sqrt(2) * 5 / 4)
        close(crosscheck.certificate(x, y, [0., 1.], n, p, estimator, .5), 0)
        assert math.isnan(crosscheck.certificate(x, y, y, n, p, estimator, 1))
    # Restoring the quadratic constant gives exactly the original L1 gap.
    close(crosscheck.certificate(x, y, [2., 3.], n, p, "quadratic", .5), 0)
    close(crosscheck.certificate(x, y, [0., 0.], n, p, "quadratic", .5), .5625)
    for beta in ([0., 0.], [1., 2.], [2., 3.]):
        close(crosscheck.certificate(x, y, beta, n, p, "quadratic", .5),
              crosscheck.certificate(x, y, beta, n, p, "lasso", .5))
    close(crosscheck.certificate(x, y, [0., 0.], n, p, "feasible_lasso", 1), 0)
    close(crosscheck.certificate(x, y, [0., 0.], n, p, "feasible_lasso", .1), (1 - .1 * math.sqrt(2)) ** 2)
    assert math.isnan(crosscheck.certificate(x, y, y, n, p, "feasible_lasso", 1))


def raw_file(root, name, values, shape, dtype="Float64"):
    path = root / name
    data = array("q" if dtype == "Int64" else "d", values)
    if sys.byteorder != "little":
        data.byteswap()
    path.write_bytes(data.tobytes())
    return dict(file=name, sha256=hashlib.sha256(path.read_bytes()).hexdigest(), shape=shape, dtype=dtype)


def crosscheck_controls(root):
    artifact = root / "artifact"
    artifact.mkdir()
    x = raw_file(artifact, "X.f64", [1., 0., 0., 1.], [2, 2])
    y = raw_file(artifact, "y.f64", [3., 4.], [2])
    weights = raw_file(artifact, "weights.f64", [1., 1.], [2])
    indices = raw_file(artifact, "group_indices.i64", [1, 2], [2], "Int64")
    offsets = raw_file(artifact, "group_offsets.i64", [1, 3], [2], "Int64")
    group_weights = raw_file(artifact, "group_weights.f64", [1.], [1])
    grid = raw_file(artifact, "lambda_path.f64", [.5, 1.], [2])
    design = dict(id="A", n=2, p=2, groups=[[1, 2]], lambda_path=[.5, 1.],
                  files=dict(X=x, y=y, weights=weights, fixed_loadings=weights,
                             group_indices=indices, group_offsets=offsets,
                             group_weights=group_weights, lambda_path=grid))
    cases = []
    estimators = ("lasso", "weighted_lasso", "path", "quadratic", "group_lasso",
                  "sqrt_lasso", "scaled_lasso", "feasible_lasso")
    names = tuple(f"gradient/{estimator}/analytic/default/workspace" for estimator in estimators)
    for case, estimator in zip(names, estimators):
        cases.append(dict(id=case, lambda_values=[.5, 1.] if estimator == "path" else
                          [.5 if estimator == "quadratic" else 1.]))
    write_toml(artifact / "manifest.toml", dict(schema_version=1, byte_order="little",
                                              storage_order="column-major", design=[design], case=cases))
    arms = fixture(root / "crosscheck-arms", runs=1, cases=names)
    for side in analysis.ARMS:
        folder = arms / side
        controls.edit_meta(folder, "artifact_sha256", crosscheck.sha256(artifact / "manifest.toml"))
        for path in folder.glob("*-catalog.tsv"):
            rows = controls.read_rows(path)
            for row, estimator in zip(rows, estimators):
                row["estimator"] = estimator
                row["measure"] = "self_consistency" if estimator == "feasible_lasso" else "relative_gap"
            write_table(path, rows)
        coef = folder / "coef"
        coef.mkdir()
        entries = []
        for case, estimator in zip(names, estimators):
            beta = [2., 3.] if estimator == "quadratic" else [0., 0.]
            if estimator == "path":
                beta *= 2
            descriptor = raw_file(coef, f"{estimator}.f64", beta, [len(beta)])
            entries.append(dict(id=case, setting_index=0, rep=1, file=descriptor["file"], sha256=descriptor["sha256"]))
        write_table(coef / "manifest.tsv", entries)
        metrics_path = next(folder.glob("*-metrics.tsv"))
        rows = controls.read_rows(metrics_path)
        artifact_reader = crosscheck.Artifact(artifact)
        catalog = controls.read_rows(next(folder.glob("*-catalog.tsv")))
        for row, entry, estimator in zip(rows, catalog, estimators):
            row["measure"] = entry["measure"]
            xdata, ydata, n, p, _, levels, w, g, wg = crosscheck.case_parameters(artifact_reader, entry)
            beta = [2., 3.] if estimator == "quadratic" else [0., 0.]
            row["worst_value"] = max(crosscheck.certificate(xdata, ydata, beta, n, p, estimator, lam, w, g, wg)
                                     for lam in levels)
        write_table(metrics_path, rows)
        catalog_path = next(folder.glob("*-catalog.tsv"))
        companion = folder / "external" / catalog_path.name
        companion.parent.mkdir()
        write_table(companion, catalog)
        write_table(catalog_path, [{key: entry[key] for key in analysis.base_validate.HEADERS["catalog"]}
                                  for entry in catalog])
        controls.edit_meta(folder, "external_catalog", str(companion.relative_to(folder)))
    with redirect_stdout(io.StringIO()) as stream:
        assert crosscheck.crosscheck(artifact, arms)
    assert "coefficients=24" in stream.getvalue() and "levels=27" in stream.getvalue()
    companion = next((arms / "current" / "external").glob("*-catalog.tsv"))
    saved_catalog = companion.read_bytes()
    entries = controls.read_rows(companion)
    entries[0]["issue"] = "other"
    write_table(companion, entries)
    expect_error(lambda: crosscheck.crosscheck(artifact, arms), "disagrees with base catalog")
    companion.write_bytes(saved_catalog)
    metric = next((arms / "legacy").glob("*-metrics.tsv"))
    original = metric.read_bytes()
    rows = controls.read_rows(metric)
    rows[0]["worst_value"] = 99
    write_table(metric, rows)
    with redirect_stdout(io.StringIO()):
        assert not crosscheck.crosscheck(artifact, arms)
    metric.write_bytes(original)
    raw = artifact / "X.f64"
    original = raw.read_bytes()
    raw.write_bytes(b"\0" * len(original))
    expect_error(lambda: crosscheck.Artifact(artifact), "SHA-256 mismatch")
    raw.write_bytes(original)
    coef_path = arms / "current" / "coef" / "lasso.f64"
    original = coef_path.read_bytes()
    coef_path.write_bytes(b"\1" * len(original))
    expect_error(lambda: crosscheck.coefficient_rows(arms / "current"), "SHA-256 mismatch")
    coef_path.write_bytes(original)
    expect_error(lambda: crosscheck.checked_path(artifact, "../outside"), "outside")
    return artifact, arms


def cli_controls(root, artifact, arms):
    scripts = Path(__file__).resolve().parent
    env = dict(os.environ, PYTHONDONTWRITEBYTECODE="1")
    def run(script, *args):
        return subprocess.run([sys.executable, str(scripts / script), *map(str, args)],
                              capture_output=True, text=True, env=env, check=False)
    for script in ("analysis.py", "crosscheck.py"):
        assert run(script, "--help").returncode == 0
    assert run("analysis.py", root / "valid", root / "cli-report", "--blocks", 12).returncode == 0
    frozen = root / "family-confirmation"
    selection = root / "family-selection" / "selection.toml"
    result = run("analysis.py", frozen, root / "cli-family-report", "--blocks", 3, "--selection", selection)
    assert result.returncode == 0, result.stderr
    result = run("analysis.py", frozen, root / "cli-missing-selection", "--blocks", 3)
    assert result.returncode == 2 and "requires --selection" in result.stderr
    result = run("analysis.py", root / "absent", root / "cli-invalid", "--blocks", 3)
    assert result.returncode == 2 and "missing arm" in result.stderr
    result = run("crosscheck.py", artifact, arms)
    assert result.returncode == 0, result.stdout + result.stderr
    isolated = subprocess.run([sys.executable, "-I", str(scripts / "crosscheck.py"), str(artifact), str(arms)],
                              capture_output=True, text=True, env=env, check=False)
    assert isolated.returncode == 0, isolated.stdout + isolated.stderr


def main():
    if len(sys.argv) != 1:
        raise SystemExit("check_analysis.py takes no arguments")
    analytic_controls()
    certificate_controls()
    with tempfile.TemporaryDirectory(prefix="cd-analysis-controls-") as temporary:
        root = Path(temporary)
        record_controls(root)
        integrity_controls(root)
        selection_controls(root)
        family_controls(root)
        optional_aa_controls(root)
        schema_controls(root)
        artifact, arms = crosscheck_controls(root)
        cli_controls(root, artifact, arms)
    print("ANALYSIS_CONTROLS_PASSED optional-calibration-AA,required-confirmation-AA,"
          "selection-families,primary-secondary,union-rungs,target-pairing,same-rung-AA,"
          "t-CDF,paired-intervals,block-bootstrap,known-mean-coverage,"
          "order-statistic-bound,BH,selection-ties,not-reached,failures,all-failed,"
          "missing-arms,missing-blocks,artifact-hashes,independent-certificates,CLI")


if __name__ == "__main__":
    main()
