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
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path
from unittest import mock

sys.dont_write_bytecode = True
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
        for argv in (["verify"], ["verify", "x", "--bogus"], ["nope"], []):
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
import os, signal, sys
with open(os.environ["MOCK_LOG"], "a") as log:
    log.write("campaign " + " ".join(sys.argv[1:]) + "\n")
rc = int(os.environ.get("STUB_RC", "0"))
ok, pilot = rc in (0, 2), "--allow-pilot" in sys.argv
lines = {"RECORD INTEGRITY": "PASS" if ok else "FAIL"}
if ok:
    lines["NUMERICAL"] = ("FAIL (non-ok primary cases: ['x'])" if rc == 2
                          else "PASS (non-ok primary cases: none)")
    lines["HARDWARE"] = "julia-1.10 controlled, julia-1.13 controlled"
lines["EVIDENCE"] = ("NOT VALID (integrity failure; never Stage 2A baseline evidence)" if not ok
                     else "PILOT / NON-OFFICIAL (never Stage 2A baseline evidence)" if pilot
                     else "OFFICIAL")
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
case "$*" in
  "api repos/"*/commits/*) echo "${GH_COMMIT:-${2##*/}}" ;;
  "api repos/"*/compare/*) echo "${GH_COMPARE:-behind}" ;;
  "issue view 110 "*) echo "Freeze commit: ${GH_ISSUE_SHA:-}" ;;
  "api repos/"*/git/ref/tags/*)
    case ${GH_TAG:-absent} in
      absent) echo 'gh: Not Found (HTTP 404)' >&2; exit 1 ;;
      error) echo 'gh: Bad Gateway (HTTP 502)' >&2; exit 1 ;;
      *) echo '{"ref": "refs/tags/x"}' ;;
    esac ;;
  "release view "*)
    case ${GH_RELEASE:-absent} in
      absent) echo 'release not found' >&2; exit 1 ;;
      error) echo 'error connecting to api.github.com' >&2; exit 1 ;;
      *) echo 'title: x' ;;
    esac ;;
  "release create "*) [ -z "${GH_CREATE_FAIL:-}" ] || { echo 'HTTP 500' >&2; exit 1; } ;;
  *) echo "unexpected: gh $*" >&2; exit 99 ;;
esac
'''

TAR = r'''#!/usr/bin/env bash
echo "tar $*" >> "$MOCK_LOG"
[ -z "${TAR_FAIL:-}" ] || exit 1
exec "$REAL_TAR" "$@"
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
                        REAL_TAR=shutil.which("tar"), GH_ISSUE_SHA=SHA)
        self.evidence = self.tmp / "evidence"
        self.evidence.mkdir()
        self.notes = self.evidence / f"{OFFICIAL}.release-notes.md"

    def run_sh(self, *args, **env):
        self.log.write_text("")
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
                                  ("newline", "pre06-nl", "a\nb")):
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
                self.assertIn("'#'" if file is None else "backslash or newline", result.stderr)

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
                ("two lines", "decided\nreleased", "2")):
            with self.subTest(label):
                result, log = self.run_sh(*release, "--disposition", disposition, STUB_RC=rc)
                self.assert_refused(result, log)
        text = "Maintainer decision 2026-11-05: archive as a failed baseline"
        result, log = self.run_sh(*release, "--disposition", text, STUB_RC="2")
        self.assertEqual(result.returncode, 0, result.stderr)
        create = [line for line in log.splitlines() if line.startswith("gh release create")]
        self.assertEqual(len(create), 1)
        self.assertIn(f"--target {SHA}", create[0])
        self.assertNotIn("--clobber", log)
        notes = self.notes.read_text()
        self.assertIn("NUMERICAL FAILURE", notes)
        self.assertIn(text, notes)
        self.assertIn("not a Julia package release", notes)
        self.notes.unlink()
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
        self.assert_refused(*self.run_sh(*release), "never overwritten")   # notes kept
        self.notes.unlink()
        result, log = self.run_sh(*release)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn(f"--target {SHA}", log)
        verified = [line for line in log.splitlines() if line.startswith("campaign verify")]
        self.assertEqual(len(verified), 1)   # the extracted archive, officially
        self.assertIn("/.release-check.", verified[0])
        self.assertTrue(verified[0].endswith(f"/{OFFICIAL} --archive --freeze-sha {SHA}"))
        self.assertNotIn("--clobber", log)
        notes = self.notes.read_text()
        for text in (CAMPAIGN["campaign_id"], SHA, CAMPAIGN["proximalsolvers"]["commit"],
                     CAMPAIGN["proximalbase"]["tree"], "1.10.13 and 1.13.3", "Evidence: OFFICIAL",
                     "RECORD INTEGRITY: PASS", hashlib.sha256(tarball.read_bytes()).hexdigest(),
                     "issues/110", "not a Julia package release"):
            self.assertIn(text, notes)
        self.assertNotIn("NUMERICAL FAILURE", notes)
        self.assertFalse(list(self.evidence.glob(".release-check.*")))
        self.notes.unlink()
        with tarball.open("ab") as stream:   # an archive changed after packing
            stream.write(b"\0")
        self.assert_refused(*self.run_sh(*release), "does not match its .sha256")

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
        self.assertFalse(tarball.exists() or Path(f"{tarball}.partial").exists())
        self.assertFalse(Path(f"{tarball}.status").exists())
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
