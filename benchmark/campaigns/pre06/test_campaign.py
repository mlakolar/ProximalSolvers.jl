"""Offline tests of campaign.py (verify, record checks) and archive.sh.

Run in this directory: python3 -B -m unittest -v
No Julia, network, gh or evidence is needed; `gh`, `tar` and campaign.py are replaced by
stubs for archive.sh, and verify_julia/check_freeze_checkout by fakes for verify().
"""

import argparse
import contextlib
import hashlib
import io
import json
import os
import shutil
import stat
import subprocess
import sys
import tarfile
import tempfile
import unittest
from pathlib import Path
from unittest import mock

sys.dont_write_bytecode = True
os.umask(0o022)   # archive.sh refuses group- or other-writable roots and parents
HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
import campaign as C   # noqa: E402

CAMPAIGN, IDS = C.load_campaign()
OFFICIAL = CAMPAIGN["archive"]["name"]
TAG = CAMPAIGN["archive"]["release_tag"]
VERSIONS = sorted(CAMPAIGN["julia"])
SHA = "a" * 40
ARCHIVE = HERE / "archive.sh"


class Scratch(unittest.TestCase):
    def setUp(self):
        tmp = tempfile.TemporaryDirectory()
        self.addCleanup(tmp.cleanup)
        self.tmp = Path(tmp.name)


def make_root(parent, name=OFFICIAL):
    """A synthetic evidence root: nested lists, raw and metadata files, a stale top list."""
    root = parent / name
    for version in VERSIONS:
        julia = root / f"julia-{version}"
        (julia / "raw").mkdir(parents=True)
        (julia / "logs").mkdir()
        (julia / "raw" / f"julia-{version}-rep01-metrics.tsv").write_text(f"metrics {version}\n")
        (julia / "raw" / f"julia-{version}-rep01-metadata.toml").write_text("rep = 1\n")
        (julia / "logs" / "rep01.out").write_text("out\n")
        (julia / "receipt.jsonl").write_text("{}\n")
        (julia / "checksums.sha256").write_text(f"{'0' * 64}  receipt.jsonl\n")
    for name in ("campaign.toml", "cases.txt"):
        shutil.copyfile(HERE / name, root / name)
    (root / "README.md").write_text("archive\n")
    (root / "checksums.sha256").write_text("stale\n")
    return root


def archive_sh(*args, env=None):
    return subprocess.run(["bash", str(ARCHIVE), *map(str, args)], capture_output=True,
                          text=True, env=env)


def report(name, mode="official", nonok=False):
    rows = [dict(id=IDS[0], role="primary", rep=1, status="error")] if nonok else []
    return dict(julia=name, failures=[], mode=mode, nonok=rows,
                nonok_primary=[IDS[0]] if nonok else [], hardware="controlled",
                record_integrity="valid")


def evidence(out):
    """The EVIDENCE line of verify's output."""
    lines = [line for line in out.splitlines() if line.startswith("EVIDENCE: ")]
    assert len(lines) == 1, out
    return lines[0]


NOT_VALID = "EVIDENCE: NOT VALID (integrity failure; never Stage 2A baseline evidence)"
PILOT = "EVIDENCE: PILOT / NON-OFFICIAL (never Stage 2A baseline evidence)"


def verify(root, reports=None, freeze_sha=SHA, allow_pilot=False, archive=True):
    """campaign.verify() on `root` with fake per-version reports; (exit code, stdout)."""
    reports = reports or {}
    fake = lambda julia_dir, *_: reports.get(julia_dir.name, report(julia_dir.name))  # noqa
    args = argparse.Namespace(root=str(root), freeze_sha=freeze_sha, allow_pilot=allow_pilot,
                              archive=archive)
    out = io.StringIO()
    with mock.patch.object(C, "verify_julia", fake), \
            mock.patch.object(C, "check_freeze_checkout", lambda *_: (HERE, SHA)), \
            contextlib.redirect_stdout(out):
        code = C.verify(args)
    return code, out.getvalue()


class ArchiveChecksums(Scratch):
    def packed_root(self):
        root = make_root(self.tmp / str(len(list(self.tmp.iterdir()))))
        result = archive_sh("checksums", root)
        self.assertEqual(result.returncode, 0, result.stderr)
        return root

    def test_list_covers_nested_lists_once_and_is_deterministic(self):
        root = self.packed_root()
        first = (root / "checksums.sha256").read_bytes()
        self.assertEqual(archive_sh("checksums", root).returncode, 0)
        self.assertEqual((root / "checksums.sha256").read_bytes(), first)
        names = [line.split("  ", 1)[1] for line in first.decode().splitlines()]
        self.assertEqual(len(names), len(set(names)))
        self.assertNotIn("checksums.sha256", names)
        for version in VERSIONS:
            self.assertEqual(names.count(f"julia-{version}/checksums.sha256"), 1)
        self.assertFalse(any(name.startswith("./") for name in names))
        self.assertEqual(names, sorted(names, key=str.encode))
        files = {str(p.relative_to(root)) for p in root.rglob("*") if p.is_file()}
        self.assertEqual(set(names), files - {"checksums.sha256"})
        self.assertEqual(C.read_checksums(root / "checksums.sha256"),
                         {name: C.sha256(root / name) for name in names})
        self.assertEqual(verify(root)[0], 0)

    def test_verify_rejects_changed_archives(self):
        def byte(root):
            path = root / "julia-1.10" / "checksums.sha256"
            path.write_bytes(path.read_bytes()[:-2] + b"x\n")

        mutations = {
            "byte in nested list": byte,
            "nested list deleted": lambda root: (root / "julia-1.13" / "checksums.sha256").unlink(),
            "unlisted file": lambda root: (root / "julia-1.10" / "extra.txt").write_text("x\n"),
            "raw record changed": lambda root: (
                root / "julia-1.13" / "raw" / "julia-1.13-rep01-metrics.tsv").write_text("y\n"),
            "duplicate path": lambda root: (root / "checksums.sha256").write_text(
                (root / "checksums.sha256").read_text()
                + (root / "checksums.sha256").read_text().splitlines()[0] + "\n"),
            "malformed line": lambda root: (root / "checksums.sha256").write_text(
                (root / "checksums.sha256").read_text() + "not a checksum line\n"),
            "dot-slash path": lambda root: (root / "checksums.sha256").write_text(
                (root / "checksums.sha256").read_text().replace("  README.md", "  ./README.md")),
            "no list": lambda root: (root / "checksums.sha256").unlink(),
        }
        for label, mutate in mutations.items():
            with self.subTest(label):
                root = self.packed_root()
                mutate(root)
                for allow_pilot in (False, True):
                    code, out = verify(root, allow_pilot=allow_pilot, reports={} if not allow_pilot
                                       else {f"julia-{v}": report(f"julia-{v}", "pilot")
                                             for v in VERSIONS})
                    self.assertEqual(code, 1)
                    self.assertIn("RECORD INTEGRITY: FAIL", out)


class VerifyModes(Scratch):
    def root(self, name=OFFICIAL, versions=VERSIONS):
        root = make_root(self.tmp, name)
        for version in set(VERSIONS) - set(versions):
            shutil.rmtree(root / f"julia-{version}")
        self.assertEqual(archive_sh("checksums", root).returncode, 0)
        return root

    def test_official(self):
        root = self.root()
        code, out = verify(root)
        self.assertEqual(code, 0)
        self.assertTrue(out.rstrip().endswith("EVIDENCE: OFFICIAL"))
        self.assertIn("\nHARDWARE: julia-1.10 controlled, julia-1.13 controlled\n", out)
        self.assertEqual(verify(root, freeze_sha=None)[0], 1)
        self.assertEqual(verify(root, archive=False, freeze_sha=None)[0], 1)
        nonok = {"julia-1.13": report("julia-1.13", nonok=True)}
        code, out = verify(root, nonok)
        self.assertEqual(code, 2)
        self.assertIn("NUMERICAL: FAIL", out)
        self.assertEqual(evidence(out), "EVIDENCE: OFFICIAL")
        failing = {"julia-1.13": dict(report("julia-1.13"), failures=["checksum mismatch: x"])}
        for label, reports, kwargs in (("failing version", failing, {}),
                                       ("no freeze SHA", {}, dict(freeze_sha=None)),
                                       ("mixed", {"julia-1.13": report("julia-1.13", "pilot")},
                                        dict(allow_pilot=True))):
            with self.subTest(label):
                code, out = verify(root, reports, **kwargs)
                self.assertEqual((code, evidence(out)), (1, NOT_VALID))
        # official evidence keeps the official gate even with --allow-pilot
        self.assertEqual(verify(root, allow_pilot=True)[0], 0)
        self.assertEqual(verify(root, allow_pilot=True, freeze_sha=None)[0], 1)

    def test_pilot_rehearsal(self):
        pilot = {f"julia-{v}": report(f"julia-{v}", "pilot") for v in VERSIONS}
        root = self.root("pre06-pilot-archive")
        code, out = verify(root, pilot, allow_pilot=True)
        self.assertEqual(code, 0)
        self.assertEqual(evidence(out), PILOT)
        self.assertEqual(verify(root, pilot, allow_pilot=True, freeze_sha=None)[0], 0)
        self.assertEqual(verify(root, pilot)[0], 1)                       # official gate
        self.assertEqual(verify(root, pilot, archive=False)[0], 1)        # no --allow-pilot
        self.assertEqual(verify(root, pilot, archive=False, allow_pilot=True)[0], 0)
        code, out = verify(root, dict(pilot, **{"julia-1.10": report("julia-1.10", "pilot",
                                                                      True)}), allow_pilot=True)
        self.assertEqual((code, evidence(out)), (2, PILOT))
        mixed = dict(pilot, **{"julia-1.13": report("julia-1.13")})
        unknown = dict(pilot, **{"julia-1.13": report("julia-1.13", "rehearsal")})
        failing = dict(pilot, **{"julia-1.13": dict(report("julia-1.13", "pilot"),
                                                    failures=["x"])})
        for label, reports, kwargs in (("mixed", mixed, dict(allow_pilot=True)),
                                       ("unknown", unknown, dict(allow_pilot=True)),
                                       ("failing", failing, dict(allow_pilot=True)),
                                       ("official gate", pilot, {})):
            with self.subTest(label):
                code, out = verify(root, reports, **kwargs)
                self.assertEqual((code, evidence(out)), (1, NOT_VALID))

    def test_pilot_rehearsal_root_and_versions(self):
        pilot = {f"julia-{v}": report(f"julia-{v}", "pilot") for v in VERSIONS}
        for name in (OFFICIAL, "pre06-rehearsal-archive"):
            with self.subTest(name):
                root = self.root(name)
                self.assertEqual(verify(root, pilot, allow_pilot=True)[0], 1)
                shutil.rmtree(root)
        one = self.root("pre06-pilot-one", versions=["1.13"])
        self.assertEqual(verify(one, pilot, allow_pilot=True)[0], 1)
        self.assertEqual(verify(self.root(versions=["1.10"]))[0], 1)

    def receipt(self, change, start=None):
        """verify_julia on a julia-1.13 holding only a start event (changed by `change`)."""
        julia = self.tmp / "julia-1.13"
        julia.mkdir(exist_ok=True)
        (julia / "receipt.jsonl").write_text(json.dumps(dict(start or self.START, **change))
                                             + "\n")
        (julia / "result.json").write_text('{"status": "completed", "reason": null}')
        (julia / "checksums.sha256").write_text("".join(
            f"{C.sha256(julia / n)}  {n}\n" for n in ("receipt.jsonl", "result.json")))
        found = C.verify_julia(julia, CAMPAIGN, IDS, SHA)
        self.assertEqual(found["record_integrity"], "invalid")   # no Manifest etc.
        return "".join(found["failures"])

    START = dict(event="start", mode="official", campaign_id=CAMPAIGN["campaign_id"],
                 julia_version="1.13", cases_sha256=CAMPAIGN["cases"]["sha256"],
                 case_filter=",".join(IDS), pinned_sha=CAMPAIGN["proximalsolvers"]["commit"],
                 freeze_head=SHA, campaign_py_sha256=C.sha256(HERE / "campaign.py"),
                 repetitions=CAMPAIGN["protocol"]["repetitions"],
                 settings=dict(CAMPAIGN["settings"]), no_exploratory=False,
                 freeze_sha_expected=SHA, root=f"/evidence/{OFFICIAL}",
                 argv=["campaign.py", "run", "--julia-version", "1.13", "--root",
                       f"/evidence/{OFFICIAL}", "--freeze-sha", SHA])

    def test_pilot_receipt_claiming_official_fails_evidence_checks(self):
        claims = {"pilot settings": dict(settings=dict(CAMPAIGN["settings"], PS_SAMPLES="5")),
                  "pilot repetitions": dict(repetitions=1),
                  "no freeze SHA": dict(freeze_sha_expected=None),
                  "no exploratory": dict(no_exploratory=True)}
        for label, change in claims.items():
            with self.subTest(label):
                self.assertIn("official evidence with other settings", self.receipt(change))

    def test_receipt_root_and_argv_agree_with_mode(self):
        official = "official evidence with another root name or a --pilot command line"
        pilot = "pilot evidence without a pilot root name and a --pilot command line"
        self.assertNotIn(official, self.receipt({}))   # a genuine official start
        self.assertIn(official, self.receipt(dict(root="/evidence/pre06-pilot-root")))
        self.assertIn(official, self.receipt(dict(argv=self.START["argv"] + ["--pilot"])))
        genuine = dict(mode="pilot", root="/evidence/pre06-pilot-root",
                       argv=["campaign.py", "run", "--pilot", "--root", "/evidence/pre06-pilot-root"])
        self.assertNotIn(pilot, self.receipt(genuine))
        self.assertIn(pilot, self.receipt(dict(genuine, root=f"/evidence/{OFFICIAL}")))
        self.assertIn(pilot, self.receipt(dict(genuine, argv=self.START["argv"])))

    def test_unreadable_checksum_lists_fail_closed(self):
        root = self.root()
        nested = root / "julia-1.10" / "checksums.sha256"
        nested.write_bytes(b"\xff\xfe not utf-8\n")
        with self.assertRaises(C.Stop):
            C.read_checksums(nested)
        (root / "checksums.sha256").write_bytes(b"\xff\xfe not utf-8\n")
        code, out = verify(root)
        self.assertEqual((code, evidence(out)), (1, NOT_VALID))
        self.assertIn("unreadable: UnicodeDecodeError", out)
        julia = self.tmp / "julia-1.13"
        self.receipt({})
        (julia / "checksums.sha256").write_bytes(b"\xff\n")
        found = C.verify_julia(julia, CAMPAIGN, IDS, SHA)
        self.assertIn("unreadable: UnicodeDecodeError", "".join(found["failures"]))

    def test_usage_errors_exit_1(self):
        for argv in (["verify"], ["verify", "x", "--bogus"], ["nope"], [],
                     ["verify", "x", "--allow-pilo"], ["verify", "x", "--archiv"],
                     ["run", "--pilo", "--julia-version", "1.13", "--julia", "j", "--pinned",
                      "p", "--work", "w", "--root", "r"]):
            with self.subTest(argv):
                result = subprocess.run([sys.executable, "-B", str(HERE / "campaign.py"), *argv],
                                        capture_output=True, text=True)
                self.assertEqual(result.returncode, 1, result.stderr)
                self.assertIn("error:", result.stderr)

    def test_attempts_limit(self):
        root = self.root()
        for n in (1, 2):
            attempt = root / "attempts" / f"julia-1.13-attempt{n}"
            attempt.mkdir(parents=True)
            (attempt / "result.json").write_text('{"status": "stopped"}')
        self.assertEqual(archive_sh("checksums", root).returncode, 0)
        self.assertEqual(verify(root)[0], 1)


def write_toml(path, values):
    path.write_text("".join(f"{key} = {json.dumps(value)}\n" for key, value in values.items()))


def make_repetition(raw, rep=1, version="1.13", statuses=None, nonok=None, **final):
    """The six record files of one complete repetition, as run.jl writes them."""
    full = CAMPAIGN["julia"][version]["version"]
    expected = C.expected_metadata(CAMPAIGN, version, dict(CAMPAIGN["settings"]), IDS, "/pinned")
    statuses = statuses or {}
    prefix = raw / f"julia-{full}-rep{rep:02d}"
    raw.mkdir(exist_ok=True)
    write_toml(Path(f"{prefix}-metadata-start.toml"), dict(expected, rep=rep))
    count = sum(status != "ok" for status in statuses.values())
    write_toml(Path(f"{prefix}-metadata.toml"), dict(dict(
        expected, rep=rep, finished=True, cases=len(IDS), elapsed_s=1.5,
        nonok_cases=count if nonok is None else nonok), **final))
    catalog = C.expected_catalog(CAMPAIGN)
    Path(f"{prefix}-catalog.tsv").write_text("\t".join(C.CATALOG_FIELDS) + "\n" + "".join(
        "\t".join(repr(row[f]) if f == "target" else row[f] for f in C.CATALOG_FIELDS) + "\n"
        for row in catalog.values()))
    Path(f"{prefix}-metrics.tsv").write_text(
        "id\tstatus\tmedian_ns\tworst_value\ttarget\tdata_hash\n" + "".join(
            f"{case}\t{statuses.get(case, 'ok')}\t100\t1e-10\t{row['target']!r}\th-{case}\n"
            for case, row in catalog.items()))
    for suffix in ("-samples.tsv", "-errors.tsv"):
        Path(f"{prefix}{suffix}").write_text("id\n")
    return expected


class Records(Scratch):
    def check(self, exit_code, **fixture):
        raw = self.tmp / "raw"
        shutil.rmtree(raw, ignore_errors=True)
        expected = make_repetition(raw, **fixture)
        return C.check_repetition(raw, "1.13", 1, expected, CAMPAIGN, exit_code)

    def test_exit_codes_and_nonok(self):
        metrics = self.check(0)
        self.assertTrue(all(row["status"] == "ok" for row in metrics.values()))
        nonok, issues = C.outcomes(CAMPAIGN, {1: metrics}, [])
        self.assertEqual((nonok, issues, C.exit_status([dict(failures=[], nonok=nonok)])),
                         ([], [], 0))
        metrics = self.check(2, statuses={IDS[0]: "error", IDS[-1]: "inaccurate"})
        nonok, _ = C.outcomes(CAMPAIGN, {1: metrics}, [])
        self.assertEqual({row["id"] for row in nonok}, {IDS[0], IDS[-1]})
        self.assertEqual(C.exit_status([dict(failures=[], nonok=nonok)]), 2)
        refused = {"exit 0 with non-ok": (0, dict(statuses={IDS[0]: "error"})),
                   "exit 2 all ok": (2, {}),
                   "metadata/metrics disagree": (2, dict(nonok=1)),
                   "exit 1": (1, {}), "exit 3": (3, {}), "exit 139": (139, {}),
                   "not finished": (0, dict(finished=False)),
                   "nonok not int": (0, dict(nonok=False))}
        for label, (code, fixture) in refused.items():
            with self.subTest(label), self.assertRaises(C.Stop):
                self.check(code, **fixture)

    def test_interrupted_repetition(self):
        raw = self.tmp / "raw"
        expected = make_repetition(raw)
        (raw / "julia-1.13.3-rep01-metadata.toml").unlink()
        with self.assertRaises(C.Stop):
            C.check_repetition(raw, "1.13", 1, expected, CAMPAIGN, 0)

    def test_seal_repetition(self):
        raw = self.tmp / "raw"
        make_repetition(raw, 1)
        sealed = {}
        self.assertEqual(len(C.seal_repetition(raw, "1.13.3", 1, sealed)), len(C.RAW_SUFFIXES))
        make_repetition(raw, 2)
        with self.assertRaises(C.Stop):   # rep01 changed after its repetition
            first = raw / "julia-1.13.3-rep01-samples.tsv"
            first.write_text(first.read_text() + "x\n")
            C.seal_repetition(raw, "1.13.3", 2, dict(sealed))
        first.write_text("id\n")
        (raw / "stray.tsv").write_text("x\n")
        with self.assertRaises(C.Stop):
            C.seal_repetition(raw, "1.13.3", 2, dict(sealed))
        (raw / "stray.tsv").unlink()
        self.assertEqual(len(C.seal_repetition(raw, "1.13.3", 2, sealed)), len(C.RAW_SUFFIXES))

    def test_fixed_inputs(self):
        fixed = next(e["id"] for e in CAMPAIGN["case"] if e["inputs"] == "fixed")
        draw = next(e["id"] for e in CAMPAIGN["case"] if e["inputs"] != "fixed")
        reps = {rep: {case: dict(data_hash="same") for case in IDS} for rep in (1, 2, 3)}
        C.check_fixed_inputs(CAMPAIGN, reps)
        reps[3][draw] = dict(data_hash="other")
        C.check_fixed_inputs(CAMPAIGN, reps)
        reps[2][fixed] = dict(data_hash="other")
        with self.assertRaises(C.Stop):
            C.check_fixed_inputs(CAMPAIGN, reps)

    def test_exit_status(self):
        self.assertEqual(C.exit_status([]), 1)
        self.assertEqual(C.exit_status([dict(failures=["x"], nonok=[]), dict(failures=[])]), 1)
        self.assertEqual(C.exit_status([dict(failures=[], nonok=[1]), dict(failures=[])]), 2)
        self.assertEqual(C.exit_status([dict(failures=[], nonok=[]), dict(failures=[])]), 0)


STUB = r'''
import hashlib, os, signal, sys
from pathlib import Path
with open(os.environ["MOCK_LOG"], "a") as log:
    log.write("campaign " + " ".join(sys.argv[1:]) + "\n")
rc = int(os.environ.get("STUB_RC", "0"))
root = Path(sys.argv[2])   # verify ROOT ...: its archive list must match its files
listed = dict(reversed(line.split("  ", 1)) for line in
              (root / "checksums.sha256").read_text().splitlines())
files = {str(p.relative_to(root)) for p in root.rglob("*") if p.is_file()}
if files - {"checksums.sha256"} != set(listed) or any(
        hashlib.sha256((root / name).read_bytes()).hexdigest() != digest
        for name, digest in listed.items()):
    rc = 1
mutate = os.environ.get("STUB_MUTATE")   # a change after the first verify (before tar)
mark = os.environ["MOCK_LOG"] + ".mutated"   # outside the root
if mutate and not os.path.exists(mark):
    open(mark, "w").close()
    with open(mutate, "a") as stream:
        stream.write("changed after verify\n")
ok, pilot = rc in (0, 2), "--allow-pilot" in sys.argv
lines = {"RECORD INTEGRITY": "PASS" if ok else "FAIL"}
if ok:
    lines["NUMERICAL"] = ("FAIL (non-ok primary cases: ['x'])" if rc == 2
                          else "PASS (non-ok primary cases: none)")
    lines["HARDWARE"] = "julia-1.10 controlled, julia-1.13 controlled"
lines["EVIDENCE"] = ("NOT VALID (integrity failure; never Stage 2A baseline evidence)" if not ok
                     else "PILOT / NON-OFFICIAL (never Stage 2A baseline evidence)" if pilot
                     else "OFFICIAL")
plant = os.environ.get("STUB_PLANT_" + ("SECOND" if "extracted" in sys.argv[2] else "FIRST"))
if plant:   # "dir|PATH" or "link|PATH|TARGET"
    kind, path, *target = plant.split("|")
    os.mkdir(path) if kind == "dir" else os.symlink(target[0], path)
if "extracted" in sys.argv[2] and os.environ.get("STUB_EXTRACTED_HARDWARE"):
    lines["HARDWARE"] = os.environ["STUB_EXTRACTED_HARDWARE"]   # pack's tarball verify only
for key, value in lines.items():   # STUB_RECORD_INTEGRITY, STUB_NUMERICAL, ... override
    value = os.environ.get("STUB_" + key.replace(" ", "_"), value)
    if not os.environ.get("STUB_SILENT"):
        print(f"{key}: {value}")
sys.stdout.flush()
if os.environ.get("STUB_SIGNAL"):
    os.kill(os.getpid(), signal.SIGTERM)
sys.exit(rc)
'''

GH = r'''#!/usr/bin/env bash
echo "gh $*" >> "$MOCK_LOG"
state="$MOCK_LOG.tag"   # the remote tag: the commit it points to
case "$*" in
  "api -X POST repos/"*/git/refs*)
    [ -z "${GH_POST_FAIL:-}" ] || { echo 'gh: Server Error (HTTP 500)' >&2; exit 1; }
    [ -z "${GH_RACE:-}" ] || echo "${GH_RACE}" > "$state"   # created by someone else first
    [ ! -e "$state" ] || { echo 'gh: Reference already exists (HTTP 422)' >&2; exit 1; }
    for a in "$@"; do case $a in sha=*) echo "${a#sha=}" > "$state" ;; esac; done
    [ -z "${GH_MOVE_AFTER_POST:-}" ] || echo "$GH_MOVE_AFTER_POST" > "$state"
    echo '{"ref": "refs/tags/x"}' ;;
  "api repos/"*/commits/*) echo "${GH_COMMIT:-${2##*/}}" ;;
  "api repos/"*/compare/*) echo "${GH_COMPARE:-behind}" ;;
  "issue view 110 "*)
    [ -z "${GH_SWAP:-}" ] || printf 'swapped bytes\n' > "$GH_SWAP"
    [ -z "${GH_MKDIR_AT:-}" ] || mkdir "$GH_MKDIR_AT"
    [ -z "${GH_LINK_AT:-}" ] || ln -s "$GH_LINK_TO" "$GH_LINK_AT"
    [ -z "${GH_SWAP_STAGED:-}" ] || for f in "$GH_SWAP_STAGED"/.archive-stage.*/*.tar.gz; do
      printf 'x' >> "$f"; done
    echo "Freeze commit: ${GH_ISSUE_SHA:-}" ;;
  "api repos/"*/git/ref/tags/*--jq*)   # the re-read after the POST
    [ -z "${GH_REREAD_FAIL:-}" ] || { echo 'gh: Bad Gateway (HTTP 502)' >&2; exit 1; }
    [ -e "$state" ] || { echo 'gh: Not Found (HTTP 404)' >&2; exit 1; }
    echo "commit $(cat "$state")" ;;
  "api repos/"*/git/ref/tags/*)
    case ${GH_TAG:-absent} in
      absent) [ -e "$state" ] || { echo 'gh: Not Found (HTTP 404)' >&2; exit 1; }
              echo '{"ref": "refs/tags/x"}' ;;
      error) echo 'gh: Bad Gateway (HTTP 502)' >&2; exit 1 ;;
      *) echo '{"ref": "refs/tags/x"}' ;;
    esac ;;
  "release view "*)
    case ${GH_RELEASE:-absent} in
      absent) echo 'release not found' >&2; exit 1 ;;
      error) echo 'error connecting to api.github.com' >&2; exit 1 ;;
      *) echo 'title: x' ;;
    esac ;;
  "release create "*)
    [ -z "${GH_SWAP_STAGE:-}" ] || for d in "$GH_SWAP_STAGE"/.archive-stage.*; do
      mv "$d" "$d.real"; ln -s "$GH_VICTIM" "$d"; done
    for a in "$@"; do case $a in *.tar.gz) echo "uploaded $(sha256sum "$a")" >> "$MOCK_LOG" ;; esac; done
    [ -z "${GH_CREATE_FAIL:-}" ] || { echo 'HTTP 500' >&2; exit 1; }
    case " $* " in *" --verify-tag "*) ;; *) echo 'tag would be created by gh' >&2; exit 1 ;; esac
    [ -e "$state" ] || { echo "tag doesn't exist" >&2; exit 1; }
    [ -z "${GH_LOCK_PARENT:-}" ] || chmod 0555 "$GH_LOCK_PARENT"
    echo "https://github.com/mlakolar/ProximalSolvers.jl/releases/tag/x" ;;   # like gh
  *) echo "unexpected: gh $*" >&2; exit 99 ;;
esac
'''

TAR = r'''#!/usr/bin/env bash
echo "tar $*" >> "$MOCK_LOG"
[ -z "${TAR_FAIL:-}" ] || exit 1
if [ -n "${TAR_CREATE_FROM:-}" ]; then   # -czf OUT: write the given (crafted) archive
  for ((i = 1; i < $#; i++)); do
    if [ "${!i}" = -czf ]; then j=$((i + 1)); cp "$TAR_CREATE_FROM" "${!j}"; exit 0; fi
  done
fi
exec "$REAL_TAR" "$@"
'''


def link_evidence(parent, kind):
    """A synthetic root (official name) whose evidence is partly not regular files or
    directories; returns the path to pass as ROOT."""
    root = make_root(parent / "evidence")
    outside = parent / "outside"
    outside.mkdir()
    if kind == "linked julia-<V>":
        shutil.move(root / "julia-1.10", outside / "julia-1.10")
        os.symlink(outside / "julia-1.10", root / "julia-1.10")
    elif kind == "linked raw":
        shutil.move(root / "julia-1.13" / "raw", outside / "raw")
        os.symlink(outside / "raw", root / "julia-1.13" / "raw")
    elif kind == "linked file":
        shutil.move(root / "julia-1.13" / "receipt.jsonl", outside / "receipt.jsonl")
        os.symlink(outside / "receipt.jsonl", root / "julia-1.13" / "receipt.jsonl")
    elif kind == "fifo":
        os.mkfifo(root / "julia-1.10" / "logs" / "pipe")
    elif kind == "root is a link":
        shutil.move(root, outside / root.name)
        (parent / "links").mkdir()
        root = parent / "links" / OFFICIAL
        os.symlink(outside / OFFICIAL, root)
    return root


LINK_KINDS = ("linked julia-<V>", "linked raw", "linked file", "fifo", "root is a link")


def plain_checksums(root):
    """The archive list an attacker would write: regular files only, links not followed."""
    lines = []
    for directory, _, files in os.walk(root):
        for name in files:
            path = Path(directory) / name
            if path.is_file() and not path.is_symlink() and path != root / "checksums.sha256":
                lines.append(f"{C.sha256(path)}  {path.relative_to(root)}\n")
    (root / "checksums.sha256").write_text("".join(sorted(lines, key=lambda l: l[66:])))


class Links(Scratch):
    def test_checksums_verify_and_pack_refuse_links_and_special_files(self):
        for kind in LINK_KINDS:
            with self.subTest(kind):
                base = self.tmp / kind.replace(" ", "_").replace("<V>", "V")
                base.mkdir()
                root = link_evidence(base, kind)
                result = archive_sh("checksums", root)
                self.assertEqual(result.returncode, 1)
                self.assertIn("symbolic link" if kind == "root is a link"
                              else "not regular files or directories", result.stderr)
                if kind != "root is a link":
                    self.assertFalse((root / "checksums.sha256").exists())
                plain_checksums(root.resolve())
                code, out = verify(root)
                self.assertEqual((code, evidence(out)), (1, NOT_VALID))
                self.assertIn("symbolic link" if kind == "root is a link"
                              else "not regular files or directories", out)

    def test_per_version_verification_refuses_links(self):
        for kind in ("linked julia-<V>", "linked raw", "linked file", "fifo"):
            with self.subTest(kind):
                base = self.tmp / kind.replace(" ", "_").replace("<V>", "V")
                base.mkdir()
                root = link_evidence(base, kind)
                julia = root / ("julia-1.10" if kind in ("linked julia-<V>", "fifo")
                                else "julia-1.13")
                found = C.verify_julia(julia, CAMPAIGN, IDS, SHA)
                self.assertEqual(found["record_integrity"], "invalid")
                self.assertIn("is not a directory" if kind == "linked julia-<V>"
                              else "not regular files or directories", found["failures"][0])

    def test_pack_refuses_links(self):
        script = ArchiveScript("test_syntax")
        script.setUp()
        self.addCleanup(script.doCleanups)
        for kind in LINK_KINDS:
            with self.subTest(kind):
                base = self.tmp / kind.replace(" ", "_").replace("<V>", "V")
                base.mkdir()
                root = link_evidence(base, kind)
                result, log = script.run_sh("pack", root, SHA)
                self.assertEqual(result.returncode, 1)
                self.assertNotIn("campaign verify", log)
                self.assertNotIn("tar ", log)
                self.assertFalse(list(base.rglob("*.tar.gz*")))


class LinkedRootSpellings(Scratch):
    def test_every_spelling_of_a_linked_root_is_refused(self):
        real = make_root(self.tmp / "real")
        link = self.tmp / "link"
        os.symlink(real, link)
        script = ArchiveScript("test_syntax")
        script.setUp()
        self.addCleanup(script.doCleanups)
        for form in (str(link), f"{link}/", f"{link}//", f"{link}/.", f"{link}/./"):
            with self.subTest(form):
                result = archive_sh("checksums", form)
                self.assertEqual(result.returncode, 1)
                self.assertRegex(result.stderr, "symbolic link|must name an evidence directory")
                result, log = script.run_sh("pack", form, SHA)
                self.assertEqual(result.returncode, 1)
                self.assertNotIn("campaign verify", log)
        self.assertEqual(archive_sh("checksums", f"{real}/../{real.name}/").returncode, 0)


README = HERE / "README.md"


def readme_lines(first, last):
    """The README lines from the one starting with `first` to the next containing `last`."""
    lines = README.read_text().splitlines()
    start = next(k for k, line in enumerate(lines) if line.startswith(first))
    end = next(k for k in range(start, len(lines)) if last in lines[k])
    return "\n".join(lines[start:end + 1]) + "\n"


class ReadmeRetrieval(Scratch):
    def snippet(self, text, cwd, **env):
        return subprocess.run(["bash", "-c", "set -euo pipefail\n" + text], cwd=cwd,
                              capture_output=True, text=True, env=dict(os.environ, **env))

    def test_lists_before_extracting(self):
        text = readme_lines("listing=$(", "--no-same-owner -xzf")
        source = make_root(self.tmp / "source")
        archives = self.tmp / "archives"
        archives.mkdir()
        crafted_tarball(archives / "symlink.tar.gz", source, "symlink")
        with tarfile.open(archives / "full.tar.gz", "w:gz") as tar:   # a link, then bulk
            info = tarfile.TarInfo(f"{OFFICIAL}/evil")
            info.type, info.linkname = tarfile.SYMTYPE, "/etc"
            tar.addfile(info)
            data = os.urandom(300_000)
            info = tarfile.TarInfo(f"{OFFICIAL}/big")
            info.size = len(data)
            tar.addfile(info, io.BytesIO(data))
        full = (archives / "full.tar.gz").read_bytes()
        (archives / "truncated.tar.gz").write_bytes(full[:len(full) // 2])
        with tarfile.open(archives / "plain.tar.gz", "w:gz") as tar:   # regular files only
            info = tarfile.TarInfo(f"{OFFICIAL}/big")
            info.size = len(data)
            tar.addfile(info, io.BytesIO(data))
        plain = (archives / "plain.tar.gz").read_bytes()
        (archives / "truncated-plain.tar.gz").write_bytes(plain[:len(plain) // 2])
        with tarfile.open(archives / "good.tar.gz", "w:gz") as tar:
            tar.add(source, arcname=OFFICIAL)
        for name, env, ok in (("truncated", {}, False), ("truncated-plain", {}, False),
                              ("symlink", {}, False),
                              ("good", {}, True), ("good", dict(TAR_OPTIONS="--exclude=raw"), True)):
            with self.subTest(name, **env):
                work = Path(tempfile.mkdtemp(dir=self.tmp))
                shutil.copyfile(archives / f"{name}.tar.gz", work / "x.tar.gz")
                result = self.snippet(text, work, ASSET="x.tar.gz", **env)
                self.assertEqual(result.returncode == 0, ok, result.stderr)
                self.assertEqual((work / OFFICIAL).exists(), ok)   # nothing extracted if refused
                if ok:
                    self.assertTrue((work / OFFICIAL / "julia-1.13" / "raw").is_dir())

    def test_verify_gate(self):
        text = readme_lines("has() {", "esac || {")
        passing = "RECORD INTEGRITY: PASS\nNUMERICAL: PASS (x)\nHARDWARE: h\nEVIDENCE: OFFICIAL"
        failing = "RECORD INTEGRITY: PASS\nNUMERICAL: FAIL (x)\nHARDWARE: h\nEVIDENCE: OFFICIAL"
        for code, out, ok in ((0, passing, True), (2, failing, True), (2, "usage: x", False),
                              (2, "", False), (0, failing, False), (2, passing, False),
                              (0, passing.replace("OFFICIAL", "PILOT / NON-OFFICIAL"), False),
                              (1, "RECORD INTEGRITY: FAIL", False), (3, passing, False)):
            with self.subTest(code=code, out=out):
                result = self.snippet(f'code={code}\nout=$(printf "%b" "$OUT")\n{text}',
                                      self.tmp, OUT=out)
                self.assertEqual(result.returncode == 0, ok, result.stderr)


def crafted_tarball(path, root, kind):
    """`root` packed as tar.gz plus one member of the given kind."""
    with tarfile.open(path, "w:gz") as tar:
        tar.add(root, arcname=root.name)
        name = f"{root.name}/julia-1.10/extra"
        info = tarfile.TarInfo({"absolute path": "/tmp/" + name, "dot-dot": f"{root.name}/../x",
                                "other root": "other/x", "dot": f"{root.name}/./x",
                                "empty component": f"{root.name}//x",
                                "duplicate": f"{root.name}/README.md"}.get(kind, name))
        info.type = {"symlink": tarfile.SYMTYPE, "hard link": tarfile.LNKTYPE,
                     "fifo": tarfile.FIFOTYPE, "device": tarfile.CHRTYPE}.get(kind, tarfile.REGTYPE)
        info.linkname = {"symlink": "/etc/passwd", "hard link": f"{root.name}/README.md"}.get(kind, "")
        data = b"x\n" if info.type == tarfile.REGTYPE else b""
        info.size = len(data)
        tar.addfile(info, io.BytesIO(data) if data else None)


TARBALL_KINDS = {  # kind: the guard of check_members that refuses it
    "symlink": "not a regular file or directory", "hard link": "not a regular file or directory",
    "fifo": "not a regular file or directory", "device": "not a regular file or directory",
    "absolute path": "member path outside", "dot-dot": "member path outside",
    "other root": "member path outside", "dot": "member path outside",
    "empty component": "member path outside",
    "duplicate": "duplicate members"}
LN = r'''#!/usr/bin/env bash
dest=${!#}
case ${LN_MODE:-}:$dest in
  swap:*.tar.gz)   # before the tarball install: another process replaces the .sha256
    rm -f "$dest.sha256"; echo theirs > "$dest.sha256"; echo theirs > "$dest" ;;
  fake:*.sha256) echo other > "$dest"; exit 0 ;;   # "succeeds" without installing the file
esac
exec "$REAL_LN" "$@"
'''
NOT_VALID_LINE = NOT_VALID.removeprefix("EVIDENCE: ")
PILOT_LINE = PILOT.removeprefix("EVIDENCE: ")
ISSUE_URL = "https://github.com/mlakolar/ProximalSolvers.jl/issues/110#issuecomment-"


class ArchiveScript(Scratch):
    def setUp(self):
        super().setUp()
        self.stub, bin_ = self.tmp / "stub", self.tmp / "bin"
        self.stub.mkdir()
        bin_.mkdir()
        (self.stub / "campaign.py").write_text(STUB)
        shutil.copyfile(HERE / "campaign.toml", self.stub / "campaign.toml")
        for name, text in (("gh", GH), ("tar", TAR)):
            (bin_ / name).write_text(text)
            (bin_ / name).chmod(0o755)
        self.log = self.tmp / "mock.log"
        self.env = dict(os.environ, PATH=f"{bin_}:{os.environ['PATH']}",
                        CAMPAIGN=str(self.stub / "campaign.py"), MOCK_LOG=str(self.log),
                        REAL_TAR=shutil.which("tar"), GH_ISSUE_SHA=SHA,
                        ARCHIVE_SH_ALLOW_STUB="1")
        self.evidence = self.tmp / "evidence"
        self.evidence.mkdir()
        self.notes = self.evidence / f"{OFFICIAL}.release-notes.md"
        self.remote_tag = Path(f"{self.log}.tag")

    def reset_remote(self):
        """The maintainer removed the tag by hand (and moved the kept notes away)."""
        self.remote_tag.unlink(missing_ok=True)
        self.notes.unlink(missing_ok=True)

    def run_sh(self, *args, stdout_full=False, **env):
        self.log.write_text("")
        if stdout_full:   # every write to stdout fails (ENOSPC)
            with open("/dev/full", "w") as full:
                result = subprocess.run(["bash", str(ARCHIVE), *map(str, args)], stdout=full,
                                        stderr=subprocess.PIPE, text=True,
                                        env=dict(self.env, **env))
        else:
            result = archive_sh(*args, env=dict(self.env, **env))
        return result, self.log.read_text()

    def pack(self, rc=0, name=OFFICIAL, *flags, **env):
        root = make_root(self.evidence, name)
        result, log = self.run_sh("pack", root, SHA, *flags, STUB_RC=str(rc), **env)
        return root, Path(f"{root}.tar.gz"), result, log

    def assert_refused(self, result, log, message=None):
        self.assertEqual(result.returncode, 1, result.stderr)
        self.assertNotIn("release create", log)
        if message:
            self.assertIn(message, result.stderr)

    def test_syntax(self):
        self.assertEqual(subprocess.run(["bash", "-n", str(ARCHIVE)]).returncode, 0)

    @unittest.skipUnless(shutil.which("shellcheck"), "shellcheck is not installed")
    def test_shellcheck(self):
        self.assertEqual(subprocess.run(["shellcheck", str(ARCHIVE)]).returncode, 0)

    def test_pack_ok(self):
        root, tarball, result, log = self.pack(0)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn(f"campaign verify {root} --archive --freeze-sha {SHA}\n", log)
        self.assertNotIn("--allow-pilot", log)
        self.assertIn("tar -C", log)
        digest = hashlib.sha256(tarball.read_bytes()).hexdigest()
        self.assertEqual(Path(f"{tarball}.sha256").read_text(), f"{digest}  {tarball.name}\n")
        status = Path(f"{tarball}.status").read_text()
        for line in ("verify_rc: 0", "numerical_status: all cases certified ok",
                     "RECORD INTEGRITY: PASS", "NUMERICAL: PASS", "HARDWARE: julia-1.10",
                     "EVIDENCE: OFFICIAL", f"archive_sha256: {digest}", "mode: official"):
            self.assertIn("\n" + line, "\n" + status)
        self.assertTrue((self.evidence / f"{OFFICIAL}.verify.out").is_file())
        self.assertFalse(list(root.rglob("*verify.out")))
        self.assertFalse(list(self.evidence.glob(".archive-stage.*")))   # one stage, removed
        members = subprocess.run(["tar", "-tzf", str(tarball)], capture_output=True,
                                 text=True).stdout.split()
        self.assertIn(f"{OFFICIAL}/julia-1.10/checksums.sha256", members)
        self.assertIn(f"{OFFICIAL}/checksums.sha256", members)
        again, _ = self.run_sh("pack", root, SHA)   # never overwrites
        self.assertNotEqual(again.returncode, 0)
        self.assertEqual(Path(f"{tarball}.sha256").read_text(), f"{digest}  {tarball.name}\n")

    def test_pack_blocked(self):
        rehearsal = ("--pilot-rehearsal",)
        cases = {  # label: (verify exit code, pack flags, stub environment)
            "integrity": (1, (), {}), "other code": (3, (), {}),
            "signal": (0, (), dict(STUB_SIGNAL="1")),
            "rc 2 without result lines": (2, (), dict(STUB_SILENT="1")),
            "rc 0 integrity FAIL": (0, (), dict(STUB_RECORD_INTEGRITY="FAIL")),
            "rc 0 numerical FAIL": (0, (), dict(STUB_NUMERICAL="FAIL (x)")),
            "rc 2 numerical PASS": (2, (), dict(STUB_NUMERICAL="PASS (x)")),
            "official labelled pilot": (0, (), dict(STUB_EVIDENCE=PILOT_LINE)),
            "official labelled not valid": (2, (), dict(STUB_EVIDENCE=NOT_VALID_LINE)),
            "pilot labelled official": (0, rehearsal, dict(STUB_EVIDENCE="OFFICIAL")),
            "pilot labelled not valid": (0, rehearsal, dict(STUB_EVIDENCE=NOT_VALID_LINE)),
        }
        for number, (label, (rc, flags, env)) in enumerate(cases.items()):
            with self.subTest(label):
                root, tarball, result, log = self.pack(rc, f"pilot-{number}", *flags, **env)
                self.assertEqual(result.returncode, 1, result.stderr)
                self.assertIn("campaign verify", log)
                if label in ("integrity", "other code", "signal"):   # blocked by the code
                    self.assertIn(f"verify exited with {143 if label == 'signal' else rc}",
                                  result.stderr)
                self.assertNotIn("tar ", log)
                self.assertFalse(tarball.exists() or Path(f"{tarball}.status").exists())
        result, log = self.run_sh("pack", root, SHA)   # the verify.out of a blocked pack
        self.assertEqual(result.returncode, 1)
        self.assertIn("never overwritten", result.stderr)
        self.assertNotIn("campaign verify", log)

    def test_pack_refuses_unlistable_names(self):
        for label, name, file in (("hash in archive path", "pre06#x", None),
                                  ("backslash", "pre06-bs", "a\\b"),
                                  ("newline", "pre06-nl", "a\nb"),
                                  ("carriage return", "pre06-cr", "a\rb")):
            with self.subTest(label):
                root = make_root(self.evidence, name)
                if file:
                    (root / "julia-1.13" / file).write_text("x\n")
                result, log = self.run_sh("pack", root, SHA)
                self.assertEqual(result.returncode, 1)
                self.assertNotIn("campaign verify", log)
                if file is None:   # refused before anything is written
                    self.assertEqual((root / "checksums.sha256").read_text(), "stale\n")
                else:
                    self.assertFalse((root / "checksums.sha256").exists())
                self.assertIn("'#'" if file is None else "cannot be listed", result.stderr)

    def test_pack_rc2_and_release_disposition(self):
        root, tarball, result, log = self.pack(2)
        self.assertEqual(result.returncode, 2)
        self.assertIn("NUMERICAL FAILURE", result.stderr)
        self.assertTrue(tarball.is_file())
        self.assertIn("numerical_status: NUMERICAL FAILURE: valid archived evidence, "
                      "not a healthy reference", Path(f"{tarball}.status").read_text())
        release = ("release", root, SHA, "--tag", TAG)
        result, log = self.run_sh(*release, STUB_RC="2")
        self.assert_refused(result, log, "--disposition")
        self.assertTrue(tarball.is_file())
        result, log = self.run_sh(*release, "--disposition", ISSUE_URL + "1", STUB_RC="0")
        self.assert_refused(result, log, "exits 0; packed with 2")
        for label, disposition, rc in (
                ("URL of another issue", ISSUE_URL.replace("/110#", "/111#") + "1", "2"),
                ("URL of another repository", "https://github.com/x/y/issues/110#issuecomment-1",
                 "2"),
                ("URL without comment id", ISSUE_URL, "2"),
                ("two lines", "decided\nreleased", "2"), ("blank", " \t ", "2"),
                ("empty", "", "2")):
            with self.subTest(label):
                result, log = self.run_sh(*release, "--disposition", disposition, STUB_RC=rc)
                self.assert_refused(result, log)
        text = "Maintainer decision 2026-11-05: archive as a failed baseline"
        result, log = self.run_sh(*release, "--disposition", text, STUB_RC="2")
        self.assertEqual(result.returncode, 0, result.stderr)
        create = [line for line in log.splitlines() if line.startswith("gh release create")]
        self.assertEqual(len(create), 1)
        self.assertIn("--verify-tag", create[0])
        self.assertNotIn("--clobber", log)
        notes = self.notes.read_text()
        self.assertIn("NUMERICAL FAILURE", notes)
        self.assertIn(text, notes)
        self.assertIn("not a Julia package release", notes)
        self.reset_remote()
        result, log = self.run_sh(*release, "--disposition", ISSUE_URL + "123", STUB_RC="2")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn(ISSUE_URL + "123", self.notes.read_text())

    def test_release_ok_and_refusals(self):
        root, tarball, result, _ = self.pack(0)
        self.assertEqual(result.returncode, 0, result.stderr)
        release = ("release", root, SHA, "--tag", TAG)
        refusals = {"tag exists": dict(GH_TAG="exists"), "tag lookup error": dict(GH_TAG="error"),
                    "release exists": dict(GH_RELEASE="exists"),
                    "release lookup error": dict(GH_RELEASE="error"),
                    "GitHub resolves another commit": dict(GH_COMMIT="b" * 40),
                    "diverged from master": dict(GH_COMPARE="diverged"),
                    "ahead of master": dict(GH_COMPARE="ahead"),
                    "not on #110": dict(GH_ISSUE_SHA="b" * 40),
                    "verify now fails": dict(STUB_RC="1"), "verify now 2": dict(STUB_RC="2"),
                    "verify now labelled pilot": dict(STUB_EVIDENCE=PILOT_LINE),
                    "verify now other hardware": dict(STUB_HARDWARE="julia-1.10 observational"),
                    "verify now other numerical line": dict(STUB_NUMERICAL="PASS (other)")}
        for label, env in refusals.items():
            with self.subTest(label):
                self.assert_refused(*self.run_sh(*release, **env))
        with self.subTest("packed 0, verify now 2, with a disposition"):
            self.assert_refused(*self.run_sh(*release, "--disposition", ISSUE_URL + "1",
                                             STUB_RC="2"), "exits 2; packed with 0")
        for label, args in {"wrong tag": ("--tag", "bench-pre06-v2"),
                            "short sha": ("--tag", TAG)}.items():
            with self.subTest(label):
                sha = SHA[:12] if label == "short sha" else SHA
                self.assert_refused(*self.run_sh("release", root, sha, *args))
        status = Path(f"{tarball}.status")
        original = status.read_text()
        for label, old, new in (("campaign_id", "campaign_id: pre06-stage2a-v1",
                                 "campaign_id: pre06-stage2a-v0"),
                                ("freeze_sha", f"freeze_sha: {SHA}", f"freeze_sha: {'b' * 40}")):
            with self.subTest(f"status {label}"):
                status.write_text(original.replace(old, new))
                self.assert_refused(*self.run_sh(*release), "is of another" if label ==
                                    "campaign_id" else "packed at another freeze")
        status.write_text(original)
        result, log = self.run_sh(*release, GH_CREATE_FAIL="1")
        self.assertEqual(result.returncode, 1)
        self.assertIn("gh release create failed", result.stderr)
        self.assertIn(f"tag {TAG} now exists", result.stderr)   # left to the maintainer
        self.assertEqual(self.remote_tag.read_text().strip(), SHA)
        self.assert_refused(*self.run_sh(*release), "never overwritten")   # notes kept
        self.notes.unlink()
        self.assert_refused(*self.run_sh(*release), "already exists")   # the tag: no resume
        self.reset_remote()
        result, log = self.run_sh(*release)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("--verify-tag", log)
        verified = [line for line in log.splitlines() if line.startswith("campaign verify")]
        self.assertEqual(len(verified), 1)   # the extracted archive, officially
        self.assertIn("/.archive-stage.", verified[0])
        self.assertTrue(verified[0].endswith(f"/{OFFICIAL} --archive --freeze-sha {SHA}"))
        self.assertNotIn("--clobber", log)
        notes = self.notes.read_text()
        for text in (CAMPAIGN["campaign_id"], SHA, CAMPAIGN["proximalsolvers"]["commit"],
                     CAMPAIGN["proximalbase"]["tree"], "1.10.13 and 1.13.3", "Evidence: OFFICIAL",
                     "RECORD INTEGRITY: PASS", hashlib.sha256(tarball.read_bytes()).hexdigest(),
                     "issues/110", "not a Julia package release"):
            self.assertIn(text, notes)
        self.assertNotIn("NUMERICAL FAILURE", notes)
        self.assertFalse(list(self.evidence.glob(".archive-stage.*")))
        self.notes.unlink()
        with tarball.open("ab") as stream:   # an archive changed after packing
            stream.write(b"\0")
        self.assert_refused(*self.run_sh(*release), "does not match its .sha256")

    def test_release_refuses_crafted_tarballs_before_extracting(self):
        root, tarball, result, _ = self.pack(0)
        self.assertEqual(result.returncode, 0, result.stderr)
        status = Path(f"{tarball}.status")
        packed = status.read_text()
        for kind, guard in TARBALL_KINDS.items():
            with self.subTest(kind):
                tarball.unlink()
                crafted_tarball(tarball, root, kind)
                digest = hashlib.sha256(tarball.read_bytes()).hexdigest()
                Path(f"{tarball}.sha256").write_text(f"{digest}  {tarball.name}\n")
                status.write_text("".join(f"archive_sha256: {digest}\n" if line.startswith(
                    "archive_sha256: ") else line for line in packed.splitlines(True)))
                result, log = self.run_sh("release", root, SHA, "--tag", TAG)
                self.assert_refused(result, log, "not extracted")
                self.assertIn(guard, result.stderr)
                self.assertNotIn("-xzf", log)
                self.assertNotIn("campaign verify", log)
                self.assertNotIn("gh ", log)
                self.assertFalse(list(self.evidence.glob(".archive-stage.*")))

    def test_pack_refuses_a_tarball_with_links(self):
        for number, (kind, guard) in enumerate(TARBALL_KINDS.items()):
            with self.subTest(kind):
                name = f"pilot-{kind.replace(' ', '-')}"   # the crafted root has the same name
                crafted = self.tmp / f"crafted-{number}.tar.gz"
                crafted_tarball(crafted, make_root(self.tmp / f"source-{number}", name), kind)
                root, tarball, result, log = self.pack(0, name, TAR_CREATE_FROM=str(crafted))
                self.assertEqual(result.returncode, 1, result.stderr)
                self.assertIn("not packed", result.stderr)
                self.assertIn(guard, result.stderr)
                self.assertFalse(tarball.exists() or Path(f"{tarball}.status").exists())
                self.assertFalse(list(self.evidence.glob(".archive-stage.*")))

    def test_pack_stores_hard_links_as_files(self):
        root = make_root(self.evidence)
        os.link(root / "README.md", root / "julia-1.10" / "README-copy.md")
        result, log = self.run_sh("pack", root, SHA)
        self.assertEqual(result.returncode, 0, result.stderr)
        listing = subprocess.run(["tar", "-tvzf", f"{root}.tar.gz"], capture_output=True,
                                 text=True).stdout.splitlines()
        self.assertTrue(listing and all(line[0] in "-d" for line in listing))

    def test_release_uploads_the_verified_copy(self):
        root, tarball, result, _ = self.pack(0)
        self.assertEqual(result.returncode, 0, result.stderr)
        packed = tarball.read_bytes()
        verified = hashlib.sha256(packed).hexdigest()
        result, log = self.run_sh("release", root, SHA, "--tag", TAG, GH_SWAP=str(tarball))
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(tarball.read_bytes(), b"swapped bytes\n")   # swapped during a lookup
        uploaded = [line.split() for line in log.splitlines() if line.startswith("uploaded ")]
        self.assertEqual(len(uploaded), 1)
        self.assertEqual(uploaded[0][1], verified)   # the verified bytes, from the staged copy
        self.assertIn("/.archive-stage.", uploaded[0][2])
        self.assertTrue(uploaded[0][2].endswith("/" + tarball.name))
        self.assertIn(verified, self.notes.read_text())
        self.reset_remote()
        tarball.write_bytes(packed)
        result, log = self.run_sh("release", root, SHA, "--tag", TAG,
                                  GH_SWAP_STAGED=str(self.evidence))
        self.assert_refused(result, log, "changed after verification")

    def test_tag_is_created_at_the_freeze_then_used(self):
        root, tarball, result, _ = self.pack(0)
        self.assertEqual(result.returncode, 0, result.stderr)
        release = ("release", root, SHA, "--tag", TAG)
        result, log = self.run_sh(*release)
        self.assertEqual(result.returncode, 0, result.stderr)
        lines = log.splitlines()
        post = [n for n, line in enumerate(lines) if line.startswith("gh api -X POST")]
        reread = [n for n, line in enumerate(lines) if "/git/ref/tags/" in line and "--jq" in line]
        create = [n for n, line in enumerate(lines) if line.startswith("gh release create")]
        self.assertEqual((len(post), len(reread), len(create)), (1, 1, 1))
        self.assertLess(post[0], reread[0])
        self.assertLess(reread[0], create[0])
        self.assertIn(f"ref=refs/tags/{TAG} -f sha={SHA}", lines[post[0]])
        self.assertIn("--verify-tag", lines[create[0]])
        self.assertNotIn("--target", lines[create[0]])
        self.assertIn(f"/.archive-stage.", lines[create[0]])
        self.assertIn(f"/{tarball.name} ", lines[create[0]])
        self.assertIn("releases/tag/x", result.stdout)   # gh's own output, printed after
        for label, env, message, tag_left in (
                ("created meanwhile at another commit", dict(GH_RACE="b" * 40),
                 "cannot create tag", "b" * 40),
                ("POST fails", dict(GH_POST_FAIL="1"), "cannot create tag", None),
                ("moved after the POST", dict(GH_MOVE_AFTER_POST="c" * 40),
                 f"is 'commit {'c' * 40}'", "c" * 40),
                ("re-read fails", dict(GH_REREAD_FAIL="1"), "cannot re-read", SHA),
                ("create fails", dict(GH_CREATE_FAIL="1"), "gh release create failed", SHA)):
            with self.subTest(label):
                self.reset_remote()
                result, log = self.run_sh(*release, **env)
                self.assertEqual(result.returncode, 1, result.stderr)
                self.assertIn(message, result.stderr)
                self.assertEqual(sum(line.startswith("gh release create") for line in
                                     log.splitlines()), 1 if label == "create fails" else 0)
                if label in ("created meanwhile at another commit", "POST fails"):
                    self.assertIn(f"Check whether tag {TAG} exists", result.stderr)
                    self.assertIn("tags are never moved or deleted automatically", result.stderr)
                if tag_left == SHA:   # created by this run: reported, never removed
                    self.assertIn(f"tag {TAG} now exists", result.stderr)
                self.assertEqual(self.remote_tag.read_text().strip() if tag_left else None,
                                 tag_left)

    def test_closed_stdout_after_the_upload(self):
        root, tarball, result, _ = self.pack(0)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.log.write_text("")
        piped = subprocess.run(
            ["bash", "-c", 'bash "$0" release "$1" "$2" --tag "$3" | true; '
             'echo "${PIPESTATUS[0]}"', str(ARCHIVE), str(root), SHA, TAG],
            capture_output=True, text=True, env=self.env)
        self.assertEqual(piped.stdout.strip(), "0", piped.stderr)
        self.assertIn("release create", self.log.read_text())

    def test_destinations_that_become_directories_or_links(self):
        for number, (dest, when, kind) in enumerate(
                (d, w, k) for d, w in ((".verify.out", "FIRST"), (".tar.gz.sha256", "SECOND"),
                                       (".tar.gz.status", "SECOND"), (".tar.gz", "SECOND"))
                for k in ("dir", "link")):
            with self.subTest(dest=dest, kind=kind):
                root = make_root(self.evidence, f"pilot-d{number}")
                inside = root / "julia-1.13"
                before = sorted(p.name for p in inside.iterdir())
                path = f"{root}{dest}"
                plant = f"dir|{path}" if kind == "dir" else f"link|{path}|{inside}"
                result, log = self.run_sh("pack", root, SHA, **{f"STUB_PLANT_{when}": plant})
                self.assertEqual(result.returncode, 1, result.stderr)
                self.assertIn("cannot install", result.stderr)
                self.assertEqual(sorted(p.name for p in inside.iterdir()), before)
                if kind == "dir":
                    self.assertEqual(list(Path(path).iterdir()), [])
                for suffix in (".tar.gz", ".tar.gz.sha256", ".tar.gz.status"):
                    target = Path(f"{root}{suffix}")
                    self.assertTrue(not target.exists() or suffix == dest, suffix)
        root, tarball, result, _ = self.pack(0)   # release: the notes destination
        self.assertEqual(result.returncode, 0, result.stderr)
        inside = root / "julia-1.13"
        before = sorted(p.name for p in inside.iterdir())
        for kind, env in (("dir", dict(GH_MKDIR_AT=str(self.notes))),
                          ("link", dict(GH_LINK_AT=str(self.notes), GH_LINK_TO=str(inside)))):
            with self.subTest(notes=kind):
                result, log = self.run_sh("release", root, SHA, "--tag", TAG, **env)
                self.assert_refused(result, log, "cannot install")
                self.assertNotIn("POST", log)   # no tag created
                self.assertEqual(sorted(p.name for p in inside.iterdir()), before)
                if kind == "dir":
                    self.assertEqual(list(self.notes.iterdir()), [])
                    self.notes.rmdir()
                else:
                    self.notes.unlink()

    def test_rollback_removes_only_this_runs_files(self):
        root = make_root(self.evidence)   # the reviewer's scenario: a foreign tarball
        tarball = Path(f"{root}.tar.gz")
        stub = self.stub / "campaign.py"
        original = stub.read_text()
        stub.write_text(original.replace("sys.stdout.flush()", "sys.stdout.flush()\n"
                        "if 'extracted' in sys.argv[2]:\n"
                        f"    open({str(tarball)!r}, 'x').write('foreign')"))
        result, log = self.run_sh("pack", root, SHA)
        self.assertEqual(result.returncode, 1)
        self.assertEqual(tarball.read_text(), "foreign")
        self.assertFalse(Path(f"{tarball}.sha256").exists() or Path(f"{tarball}.status").exists())
        stub.write_text(original)
        Path(f"{root}.verify.out").unlink()
        tarball.unlink()
        bin_ = self.tmp / "lnmock"   # a sidecar replaced by someone else before the rollback
        bin_.mkdir()
        (bin_ / "ln").write_text(LN)
        (bin_ / "ln").chmod(0o755)
        env = dict(PATH=f"{bin_}:{self.env['PATH']}", REAL_LN=shutil.which("ln"))
        result, log = self.run_sh("pack", root, SHA, LN_MODE="swap", **env)
        self.assertEqual(result.returncode, 1)
        self.assertEqual(Path(f"{tarball}.sha256").read_text(), "theirs\n")   # kept: not ours
        self.assertFalse(Path(f"{tarball}.status").exists())                 # ours: removed
        self.assertEqual(tarball.read_text(), "theirs\n")
        for path in (tarball, Path(f"{tarball}.sha256"), Path(f"{root}.verify.out")):
            path.unlink()
        result, log = self.run_sh("pack", root, SHA, LN_MODE="fake", **env)
        self.assertEqual(result.returncode, 1)
        self.assertIn("is not the file installed", result.stderr)
        self.assertFalse(tarball.exists())

    def test_checksums_destination_becomes_dir_or_link(self):
        bin_ = self.tmp / "hashmock"   # sha256sum plants something at ROOT/checksums.sha256
        bin_.mkdir()
        (bin_ / "sha256sum").write_text(
            '#!/usr/bin/env bash\n'
            'if [ ! -e "$PLANT" ] && [ ! -L "$PLANT" ]; then\n'
            '  if [ -n "${PLANT_TO:-}" ]; then ln -s "$PLANT_TO" "$PLANT"; else mkdir "$PLANT"; fi\n'
            f'fi\nexec {shutil.which("sha256sum")} "$@"\n')
        (bin_ / "sha256sum").chmod(0o755)
        for number, (command, kind) in enumerate((c, k) for c in ("checksums", "pack")
                                                 for k in ("dir", "link")):
            with self.subTest(command=command, kind=kind):
                root = make_root(self.evidence, f"pilot-c{number}")
                inside = root / "julia-1.13"
                before = sorted(p.name for p in inside.iterdir())
                plant = root / "checksums.sha256"
                env = dict(PATH=f"{bin_}:{self.env['PATH']}", PLANT=str(plant))
                if kind == "link":
                    env["PLANT_TO"] = str(inside)
                args = ("checksums", root) if command == "checksums" else ("pack", root, SHA)
                result, log = self.run_sh(*args, **env)
                self.assertEqual(result.returncode, 1, result.stderr)
                self.assertIn("cannot install", result.stderr)
                self.assertNotIn("campaign verify", log)
                self.assertEqual(sorted(p.name for p in inside.iterdir()), before)
                if kind == "dir":
                    self.assertEqual(list(plant.iterdir()), [])
                self.assertFalse(list(self.evidence.glob(".archive-stage.*")))
                self.assertFalse(Path(f"{root}.tar.gz").exists())

    def test_pack_summary_never_changes_the_exit_code(self):
        for number, rc in enumerate((0, 2)):
            with self.subTest(rc=rc, stdout="closed pipe"):
                root = make_root(self.evidence, f"pilot-p{number}")
                piped = subprocess.run(
                    ["bash", "-c", 'bash "$0" pack "$1" "$2" | true; echo "${PIPESTATUS[0]}"',
                     str(ARCHIVE), str(root), SHA], capture_output=True, text=True,
                    env=dict(self.env, STUB_RC=str(rc)))
                self.assertEqual(piped.stdout.strip(), str(rc), piped.stderr)
                self.assertTrue(Path(f"{root}.tar.gz").is_file())
                self.assertTrue(Path(f"{root}.tar.gz.status").is_file())
            with self.subTest(rc=rc, stdout="/dev/full"):
                root = make_root(self.evidence, f"pilot-f{number}")
                result, _ = self.run_sh("pack", root, SHA, stdout_full=True, STUB_RC=str(rc))
                self.assertEqual(result.returncode, rc, result.stderr)
                self.assertTrue(Path(f"{root}.tar.gz").is_file())

    def swap_mock(self, tool):
        """`tool` that, once, renames SWAP_ROOT and links that name to SWAP_TO: on its
        first call with an argument ending in checksums.sha256 (rm) or naming SWAP_ROOT
        (realpath, right after printing the resolution)."""
        bin_ = self.tmp / f"{tool}-swap"
        if bin_.exists():
            return f"{bin_}:{self.env['PATH']}"
        bin_.mkdir()
        real = shutil.which(tool)
        swap = ('if [ ! -e "$MOCK_LOG.swapped" ]; then touch "$MOCK_LOG.swapped"; '
                'mv "$SWAP_ROOT" "$SWAP_ROOT.moved"; ln -s "$SWAP_TO" "$SWAP_ROOT"; fi')
        if tool == "rm":
            body = (f'for a in "$@"; do case $a in *checksums.sha256) {swap} ;; esac; done\n'
                    f'exec {real} "$@"\n')
        else:
            body = (f'{real} "$@" || exit\n'
                    f'for a in "$@"; do [ "$a" != "$SWAP_ROOT" ] || {{ {swap}; }}; done\n')
        (bin_ / tool).write_text("#!/usr/bin/env bash\n" + body)
        (bin_ / tool).chmod(0o755)
        return f"{bin_}:{self.env['PATH']}"

    def test_checksums_is_pinned_to_the_root(self):
        other = self.tmp / "other"   # another directory with its own list
        other.mkdir()
        (other / "checksums.sha256").write_text("maintainer's list\n")
        for number, (tool, command) in enumerate(
                (t, c) for t in ("rm", "realpath") for c in ("checksums", "pack")):
            with self.subTest(tool=tool, command=command):
                root = make_root(self.evidence, f"pilot-s{number}")
                Path(f"{self.log}.swapped").unlink(missing_ok=True)
                args = ("checksums", root) if command == "checksums" else ("pack", root, SHA)
                result, log = self.run_sh(*args, PATH=self.swap_mock(tool),
                                          SWAP_ROOT=str(root), SWAP_TO=str(other))
                self.assertTrue(Path(f"{self.log}.swapped").exists())   # the swap happened
                self.assertEqual((other / "checksums.sha256").read_text(), "maintainer's list\n")
                self.assertEqual(sorted(p.name for p in other.iterdir()), ["checksums.sha256"])
                moved = Path(f"{root}.moved")
                if tool == "rm" and command == "checksums":   # acted inside the original only
                    self.assertEqual(result.returncode, 0, result.stderr)
                    names = [line.split("  ", 1)[1] for line in
                             (moved / "checksums.sha256").read_text().splitlines()]
                    self.assertIn("julia-1.13/raw/julia-1.13-rep01-metrics.tsv", names)
                else:
                    self.assertEqual(result.returncode, 1, result.stderr)
                if tool == "rm" and command == "checksums":   # the scan is pinned too
                    shutil.rmtree(moved)
                    root = make_root(self.evidence, f"pilot-s{number}-link")
                    os.symlink(other, root / "julia-1.13" / "link")
                    Path(f"{self.log}.swapped").unlink()
                    result, log = self.run_sh("checksums", root, PATH=self.swap_mock(tool),
                                              SWAP_ROOT=str(root), SWAP_TO=str(other))
                    self.assertTrue(Path(f"{self.log}.swapped").exists())
                    self.assertEqual(result.returncode, 1)
                    self.assertIn("not regular files or directories", result.stderr)
                    self.assertEqual((other / "checksums.sha256").read_text(),
                                     "maintainer's list\n")
                    moved = Path(f"{root}.moved")
                if tool == "realpath":   # swapped between resolution and use: refused (the
                    # precondition's stat sees the swapped-in link itself, mode 777)
                    self.assertRegex(result.stderr, "changed after its resolution|is a "
                                     "symbolic link|group or others can write")
                    self.assertEqual((moved / "checksums.sha256").read_text(), "stale\n")

    def test_cleanup_never_follows_a_swapped_stage(self):
        victim = self.tmp / "victim"
        (victim / "sub").mkdir(parents=True)
        (victim / "secret").write_text("x")
        (victim / "secret").chmod(0o400)
        (victim / "sub").chmod(0o500)
        self.addCleanup((victim / "sub").chmod, 0o700)
        root, tarball, result, _ = self.pack(0)
        self.assertEqual(result.returncode, 0, result.stderr)
        result, log = self.run_sh("release", root, SHA, "--tag", TAG,
                                  GH_SWAP_STAGE=str(self.evidence), GH_VICTIM=str(victim))
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("is now a symbolic link; left in place", result.stderr)
        self.assertEqual(stat.S_IMODE((victim / "secret").stat().st_mode), 0o400)
        self.assertEqual(stat.S_IMODE((victim / "sub").stat().st_mode), 0o500)
        self.assertEqual(sorted(p.name for p in victim.iterdir()), ["secret", "sub"])

    def tool_mock(self, tool, body):
        bin_ = self.tmp / f"{tool}-mock"
        bin_.mkdir(exist_ok=True)
        (bin_ / tool).write_text(f"#!/usr/bin/env bash\nREAL={shutil.which(tool)}\n{body}")
        (bin_ / tool).chmod(0o755)
        return f"{bin_}:{self.env['PATH']}"

    def test_private_directories_are_required(self):
        # stat reports uid 4242 for paths matching STAT_OTHER, or STAT_RAW verbatim
        stat_path = self.tool_mock("stat", 'out=$("$REAL" "$@") || exit\n'
                                   '[ -z "${STAT_RAW:-}" ] || { echo "$STAT_RAW"; exit 0; }\n'
                                   'case ${!#} in ${STAT_OTHER:-/nonexistent}) echo "4242 ${out#* }" ;;'
                                   ' *) echo "$out" ;; esac\n')
        cases = {  # label: (parent mode, root mode, extra environment, message)
            "parent 0775": (0o775, 0o755, {}, "group or others can write"),
            "parent 0757": (0o757, 0o755, {}, "group or others can write"),
            "parent 0777": (0o777, 0o755, {}, "group or others can write"),
            "parent 1777 (sticky, like /tmp)": (0o1777, 0o755, {}, "group or others can write"),
            "parent of another uid": (0o755, 0o755, dict(STAT_OTHER="*/parent-*"),
                                      "is owned by uid 4242"),
            "root 0775": (0o755, 0o775, {}, "group or others can write"),
            "root 0777": (0o755, 0o777, {}, "group or others can write"),
            "root of another uid": (0o755, 0o755, dict(STAT_OTHER=f"*/{OFFICIAL}"),
                                    "is owned by uid 4242"),
            "unparseable stat": (0o755, 0o755, dict(STAT_RAW="x y"), "unexpected stat output"),
        }
        for number, (label, (parent_mode, root_mode, env, message)) in enumerate(cases.items()):
            for command in ("checksums", "pack", "release"):
                with self.subTest(label, command=command):
                    parent = self.tmp / f"parent-{number}-{command}"
                    root = make_root(parent)   # its list: "stale"
                    parent.chmod(parent_mode)
                    root.chmod(root_mode)
                    args = (command, root) if command == "checksums" else (
                        (command, root, SHA) if command == "pack" else
                        (command, root, SHA, "--tag", TAG))
                    result, log = self.run_sh(*args, PATH=stat_path, **env)
                    self.assertEqual(result.returncode, 1, result.stderr)
                    self.assertIn(message, result.stderr)
                    self.assertEqual((root / "checksums.sha256").read_text(), "stale\n")
                    self.assertEqual(sorted(p.name for p in parent.iterdir()), [OFFICIAL])
                    self.assertNotIn("campaign verify", log)
        for number, (parent_mode, root_mode) in enumerate(((0o700, 0o755), (0o755, 0o700))):
            with self.subTest(accepted=(oct(parent_mode), oct(root_mode))):
                parent = self.tmp / f"private-{number}"
                root = make_root(parent)
                parent.chmod(parent_mode)
                root.chmod(root_mode)
                result, _ = self.run_sh("checksums", root, PATH=stat_path)
                self.assertEqual(result.returncode, 0, result.stderr)
                self.assertNotEqual((root / "checksums.sha256").read_text(), "stale\n")

    def test_trusted_ancestry(self):
        stat_path = self.tool_mock("stat", 'out=$("$REAL" "$@") || exit\n'
                                   'case ${!#} in ${STAT_OTHER:-/nonexistent}) echo "4242 ${out#* }" ;;'
                                   ' ${STAT_ROOT:-/nonexistent}) echo "0 ${out#* }" ;;'
                                   ' *) echo "$out" ;; esac\n')
        refused = {  # label: (grandparent mode, environment, message)
            "grandparent 0775": (0o775, {}, "writable by group or others and not sticky"),
            "grandparent 0777": (0o777, {}, "writable by group or others and not sticky"),
            "grandparent 0757": (0o757, {}, "writable by group or others and not sticky"),
            "grandparent of another uid": (0o755, dict(STAT_OTHER="*/grand-3"),
                                           "neither root nor you"),
            "sticky grandparent of another uid": (0o1777, dict(STAT_OTHER="*/grand-4"),
                                                  "neither root nor you"),
        }
        for number, (label, (mode, env, message)) in enumerate(refused.items()):
            for command in ("checksums", "pack", "release"):
                with self.subTest(label, command=command):
                    grand = self.tmp / f"grand-{number}"
                    parent = grand / f"parent-{command}"
                    root = make_root(parent)
                    grand.chmod(mode)
                    self.addCleanup(grand.chmod, 0o755)
                    args = ("checksums", root) if command == "checksums" else (
                        (command, root, SHA) if command == "pack" else
                        (command, root, SHA, "--tag", TAG))
                    result, log = self.run_sh(*args, PATH=stat_path, **env)
                    self.assertEqual(result.returncode, 1, result.stderr)
                    self.assertIn(message, result.stderr)
                    self.assertIn(str(grand), result.stderr)   # names the ancestor
                    self.assertEqual((root / "checksums.sha256").read_text(), "stale\n")
                    self.assertEqual(sorted(p.name for p in parent.iterdir()), [OFFICIAL])
                    self.assertNotIn("campaign verify", log)
        accepted = {"sticky grandparent 1777": (0o1777, {}),
                    "sticky group-writable grandparent 1775": (0o1775, {}),
                    "root-owned grandparent 0755": (0o755, dict(STAT_ROOT="*/grand-r2")),
                    "grandparent 0700": (0o700, {})}
        for number, (label, (mode, env)) in enumerate(accepted.items()):
            with self.subTest(label):
                grand = self.tmp / f"grand-r{number}"
                root = make_root(grand / "parent")
                grand.chmod(mode)
                result, _ = self.run_sh("checksums", root, PATH=stat_path, **env)
                self.assertEqual(result.returncode, 0, result.stderr)
                self.assertNotEqual((root / "checksums.sha256").read_text(), "stale\n")

    def test_parent_is_proven_before_root_is_resolved(self):
        grand = self.tmp / "grand"
        parent = grand / "parent"
        root = make_root(parent)
        logged = self.tool_mock("realpath", 'echo "realpath $*" >> "$MOCK_LOG"\n'
                                'exec "$REAL" "$@"\n')
        grand.chmod(0o775)   # a replaceable ancestor: refused before ROOT is looked at
        result, log = self.run_sh("checksums", root, PATH=logged)
        grand.chmod(0o755)
        self.assertEqual(result.returncode, 1)
        self.assertIn("not sticky", result.stderr)
        resolved = [line for line in log.splitlines() if line.startswith("realpath ")]
        self.assertEqual(resolved, [f"realpath -e -- {parent}"])
        other = self.tmp / "other"   # ROOT swapped for a link right after the parent check
        other.mkdir()
        make_root(other)
        bin_ = self.tmp / "realpath-parent-swap"
        bin_.mkdir()
        (bin_ / "realpath").write_text(
            f"#!/usr/bin/env bash\n{shutil.which('realpath')} \"$@\" || exit\n"
            'if [ "${!#}" = "$SWAP_PARENT" ] && [ ! -e "$MOCK_LOG.swapped" ]; then\n'
            '  touch "$MOCK_LOG.swapped"; mv "$SWAP_ROOT" "$SWAP_ROOT.moved"\n'
            '  ln -s "$SWAP_TO" "$SWAP_ROOT"; fi\n')
        (bin_ / "realpath").chmod(0o755)
        for command in ("checksums", "pack"):
            with self.subTest(command=command):
                Path(f"{self.log}.swapped").unlink(missing_ok=True)
                shutil.rmtree(Path(f"{root}.moved"), ignore_errors=True)
                if root.is_symlink():
                    root.unlink()
                root = make_root(parent) if not root.exists() else root
                args = ("checksums", root) if command == "checksums" else ("pack", root, SHA)
                result, log = self.run_sh(*args, PATH=f"{bin_}:{self.env['PATH']}",
                                          SWAP_PARENT=str(parent), SWAP_ROOT=str(root),
                                          SWAP_TO=str(other / OFFICIAL))
                self.assertTrue(Path(f"{self.log}.swapped").exists())
                self.assertEqual(result.returncode, 1, result.stderr)
                self.assertIn("is a symbolic link", result.stderr)
                self.assertEqual((other / OFFICIAL / "checksums.sha256").read_text(), "stale\n")
                self.assertNotIn("campaign verify", log)

    def test_setgid_parent_is_accepted(self):
        parent = self.tmp / "setgid"
        root = make_root(parent)
        parent.chmod(0o2755)
        result, _ = self.run_sh("checksums", root)
        self.assertEqual(result.returncode, 0, result.stderr)
        result, log = self.run_sh("pack", root, SHA)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertTrue(Path(f"{root}.tar.gz").is_file())
        self.assertFalse(list(parent.glob(".archive-stage.*")))

    def test_the_stage_must_be_private(self):
        mktemp_path = self.tool_mock("mktemp", 'out=$("$REAL" "$@") || exit\n'
                                     '[ -z "${LOOSE:-}" ] || chmod 0755 "$out"\necho "$out"\n')
        stat_path = self.tool_mock("stat", 'out=$("$REAL" "$@") || exit\n'
                                   'case ${!#} in ${STAT_OTHER:-/nonexistent}) echo "4242 ${out#* }" ;;'
                                   ' *) echo "$out" ;; esac\n')
        for number, (label, env) in enumerate((
                ("mode 0755", dict(PATH=mktemp_path, LOOSE="1")),
                ("another uid", dict(PATH=stat_path, STAT_OTHER="*/.archive-stage.*")))):
            for command in ("checksums", "pack"):
                with self.subTest(label, command=command):
                    root = make_root(self.evidence, f"pilot-t{number}-{command}")
                    args = ("checksums", root) if command == "checksums" else ("pack", root, SHA)
                    result, log = self.run_sh(*args, **env)
                    self.assertEqual(result.returncode, 1, result.stderr)
                    self.assertIn("the staging directory", result.stderr)
                    self.assertEqual((root / "checksums.sha256").read_text(), "stale\n")
                    self.assertNotIn("campaign verify", log)
                    self.assertFalse(list(self.evidence.glob(".archive-stage.*")))

    def test_empty_and_dot_roots_are_refused(self):
        work = self.tmp / "work" / "cwd"
        work.mkdir(parents=True)
        (work / "checksums.sha256").write_text("user data\n")
        (work / "f").write_text("x\n")
        (work / "sub").mkdir()
        for root in ("", "/", "//", ".", "./", "..", "../", "./.", "././", "sub/..",
                     "./sub/../", "sub/../..", "../.", "/./", "/../", "//./", "//../", "///",
                     "/" + str(work), "//" + str(work) + "/", "/" + str(work.parent),
                     "//" + str(work) + "/sub/.."):
            for command in (("checksums", root), ("pack", root, SHA),
                            ("release", root, SHA, "--tag", TAG)):
                with self.subTest(root=root, command=command[0]):
                    result = subprocess.run(["bash", str(ARCHIVE), *command], cwd=work,
                                            capture_output=True, text=True, env=self.env)
                    self.assertEqual(result.returncode, 1)
                    self.assertRegex(result.stderr, "must name an evidence directory|the "
                                     "current directory or one of its ancestors")
                    self.assertEqual((work / "checksums.sha256").read_text(), "user data\n")
                    self.assertEqual(sorted(p.name for p in work.parent.iterdir()), ["cwd"])
                    self.assertEqual(sorted(p.name for p in work.iterdir()),
                                     ["checksums.sha256", "f", "sub"])
                    self.assertEqual(list((work / "sub").iterdir()), [])

    def test_pack_never_writes_through_planted_files(self):
        victim = self.tmp / "victim.txt"
        victim.write_text("precious\n")
        def plant(kind, path):
            if kind == "symlink":
                os.symlink(victim, path)
            elif kind == "dangling symlink":
                os.symlink(self.tmp / "missing", path)
            elif kind == "hard link":
                os.link(victim, path)
            else:
                path.write_text("planted\n")
        number = 0
        for kind in ("regular file", "symlink", "hard link"):   # the old .partial name
            with self.subTest(f".partial {kind}"):
                number += 1
                root = make_root(self.evidence, f"pilot-b{number}")
                plant(kind, Path(f"{root}.tar.gz.partial"))
                result, log = self.run_sh("pack", root, SHA)
                self.assertEqual(result.returncode, 0, result.stderr)
                self.assertEqual(victim.read_text(), "precious\n")
        for suffix in (".tar.gz", ".tar.gz.sha256", ".tar.gz.status", ".verify.out"):
            for kind in ("symlink", "dangling symlink", "hard link", "regular file"):
                with self.subTest(f"{suffix} {kind}"):
                    number += 1
                    root = make_root(self.evidence, f"pilot-b{number}")
                    plant(kind, Path(f"{root}{suffix}"))
                    result, log = self.run_sh("pack", root, SHA)
                    self.assertEqual(result.returncode, 1)
                    self.assertIn("never overwritten", result.stderr)
                    self.assertNotIn("campaign verify", log)
                    self.assertEqual(victim.read_text(), "precious\n")
                    self.assertFalse((self.tmp / "missing").exists())

    def test_pack_installs_without_clobbering(self):
        # a destination that appears after the start (here: beside a slow verify) is kept
        root = make_root(self.evidence)
        status = Path(f"{root}.tar.gz.status")
        stub = self.stub / "campaign.py"
        stub.write_text(stub.read_text().replace(   # the second verify creates the status
            "sys.stdout.flush()", "sys.stdout.flush()\nif 'extracted' in sys.argv[2]:\n"
            f"    open({str(status)!r}, 'x').write('theirs')"))
        result, log = self.run_sh("pack", root, SHA)
        self.assertEqual(result.returncode, 1)
        self.assertIn("cannot install", result.stderr)
        self.assertEqual(status.read_text(), "theirs")
        self.assertFalse(Path(f"{root}.tar.gz").exists())

    def test_pack_archive_reproduces_the_verified_tree(self):
        root, tarball, result, log = self.pack(0, TAR_OPTIONS="--exclude=raw")
        self.assertEqual(result.returncode, 0, result.stderr)
        members = subprocess.run(["tar", "-tzf", str(tarball)], capture_output=True,
                                 text=True).stdout.split()
        self.assertIn(f"{OFFICIAL}/julia-1.13/raw/julia-1.13-rep01-metrics.tsv", members)
        self.assertEqual(sum(line.startswith("campaign verify") for line in log.splitlines()), 2)
        name = "pilot-changed"
        changed = self.evidence / name / "julia-1.13" / "raw" / "julia-1.13-rep01-metrics.tsv"
        root, tarball, result, log = self.pack(0, name, STUB_MUTATE=str(changed))
        self.assertEqual(result.returncode, 1)
        self.assertIn("verify of the tarball exits 1, of the root 0", result.stderr)
        self.assertFalse(tarball.exists() or Path(f"{tarball}.status").exists())
        self.assertFalse(list(self.evidence.glob(".archive-stage.*")))

    def test_pack_result_lines_of_the_tarball_must_agree(self):
        root, tarball, result, log = self.pack(0, STUB_EXTRACTED_HARDWARE="julia-1.10 observational")
        self.assertEqual(result.returncode, 1)
        self.assertIn("disagree on HARDWARE", result.stderr)
        self.assertFalse(tarball.exists())

    def test_root_named_like_an_option(self):
        root, tarball, result, log = self.pack(0, "--exclude=raw")
        self.assertEqual(result.returncode, 0, result.stderr)
        members = subprocess.run(["tar", "-tzf", str(tarball)], capture_output=True,
                                 text=True).stdout.split()
        self.assertIn("--exclude=raw/julia-1.13/raw/julia-1.13-rep01-metrics.tsv", members)

    def test_read_only_directories_and_failing_stdout(self):
        root = make_root(self.evidence)
        raw = root / "julia-1.10" / "raw"
        raw.chmod(0o555)
        self.addCleanup(raw.chmod, 0o755)
        result, log = self.run_sh("pack", root, SHA)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertFalse(list(self.evidence.glob(".archive-stage.*")))
        result, log = self.run_sh("release", root, SHA, "--tag", TAG, stdout_full=True)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("release create", log)
        self.assertFalse(list(self.evidence.glob(".archive-stage.*")))

    def test_unremovable_stage_after_upload_only_warns(self):
        root, tarball, result, _ = self.pack(0)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.addCleanup(self.evidence.chmod, 0o755)
        result, log = self.run_sh("release", root, SHA, "--tag", TAG,
                                  GH_LOCK_PARENT=str(self.evidence))
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("release create", log)
        self.assertIn("warning: could not remove", result.stderr)

    def test_release_ignores_a_campaign_override(self):
        root, tarball, result, _ = self.pack(0)
        self.assertEqual(result.returncode, 0, result.stderr)
        result, log = self.run_sh("release", root, SHA, "--tag", TAG, ARCHIVE_SH_ALLOW_STUB="")
        self.assert_refused(result, log, "release ignores CAMPAIGN")
        self.assertNotIn("campaign verify", log)   # the real campaign.py ran, and refused

    def test_checksums_refuses_escaped_lines(self):
        bin_ = self.tmp / "escaping"
        bin_.mkdir()
        (bin_ / "sha256sum").write_text(f"#!/usr/bin/env bash\n{shutil.which('sha256sum')} "
                                        f"\"$@\" | sed '1s/^/\\\\/'\n")
        (bin_ / "sha256sum").chmod(0o755)
        root = make_root(self.evidence)
        result, log = self.run_sh("checksums", root, PATH=f"{bin_}:{self.env['PATH']}")
        self.assertEqual(result.returncode, 1)
        self.assertIn("escaped a file name", result.stderr)
        self.assertFalse((root / "checksums.sha256").exists())
        self.assertFalse(list(self.evidence.glob(".checksums.*")))
        self.assertFalse(list(self.evidence.glob(".archive-stage.*")))

    def test_release_names(self):
        root, tarball, result, _ = self.pack(0, "pre06-stage2a-campaign-v1-copy")
        self.assertEqual(result.returncode, 0, result.stderr)
        result, log = self.run_sh("release", root, SHA, "--tag", TAG)
        self.assert_refused(result, log, "is not the official archive")
        self.assertNotIn("gh ", log)
        root, tarball, result, _ = self.pack(0)
        self.assertEqual(result.returncode, 0, result.stderr)
        toml = self.stub / "campaign.toml"
        toml.write_text(toml.read_text().replace(f'asset = "{OFFICIAL}.tar.gz"',
                                                 'asset = "other.tar.gz"'))
        result, log = self.run_sh("release", root, SHA, "--tag", TAG)
        self.assert_refused(result, log, "campaign.toml: asset")

    def test_pilot_rehearsal_never_released(self):
        root, tarball, result, log = self.pack(0, "pre06-pilot-archive", "--pilot-rehearsal")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("--allow-pilot", log)
        status = Path(f"{tarball}.status").read_text()
        self.assertIn("mode: pilot-rehearsal\n", status)
        self.assertIn("EVIDENCE: PILOT / NON-OFFICIAL", status)
        result, log = self.run_sh("release", root, SHA, "--tag", TAG)
        self.assertEqual(result.returncode, 1)
        self.assertNotIn("gh ", log)
        # a rehearsal packed under the official name is refused by its status
        shutil.rmtree(self.evidence)
        self.evidence.mkdir()
        root, tarball, result, _ = self.pack(0, OFFICIAL, "--pilot-rehearsal")
        self.assertEqual(result.returncode, 0, result.stderr)
        result, log = self.run_sh("release", root, SHA, "--tag", TAG)
        self.assertEqual(result.returncode, 1)
        self.assertIn("pilot rehearsal is never released", result.stderr)
        self.assertNotIn("gh ", log)

    def test_failures_stop(self):
        root, tarball, result, log = self.pack(0, TAR_FAIL="1")
        self.assertEqual(result.returncode, 1)
        self.assertIn("tar failed", result.stderr)
        self.assertFalse(tarball.exists() or Path(f"{tarball}.status").exists())
        self.assertFalse(list(self.evidence.glob(".archive-stage.*")))
        if os.geteuid() == 0:
            self.skipTest("root reads unreadable files")
        root = make_root(self.evidence, "unreadable")
        secret = root / "julia-1.10" / "raw" / "julia-1.10-rep01-metrics.tsv"
        secret.chmod(0)
        self.addCleanup(secret.chmod, 0o644)
        result, log = self.run_sh("pack", root, SHA)
        self.assertEqual(result.returncode, 1)
        self.assertIn("checksum generation failed", result.stderr)
        self.assertNotIn("campaign verify", log)
        self.assertNotIn("tar ", log)
        self.assertFalse((root / "checksums.sha256").exists())
        self.assertFalse(list(self.evidence.glob(".checksums.*")))


if __name__ == "__main__":
    unittest.main()
