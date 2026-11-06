# Stage 2A campaign `pre06-stage2a-v1`

The F1 freeze of the historical pre-0.6 baseline of [#110](https://github.com/mlakolar/ProximalSolvers.jl/issues/110).
The design, including what each gate means, is [`STAGE2_PLAN.md`](STAGE2_PLAN.md); this file
says how to run, verify, archive and retrieve the campaign. The campaign is frozen by the
commit that merges these files, once that commit is recorded on #110 (the *freeze SHA*);
until then nothing here is frozen and no official measurement may be taken.

> **Scope.** Every primary case is sub-millisecond on the measured machine. Stage 2A is a
> historical correctness-and-timing snapshot of one declared stack, **not** a statistical
> per-case noninferiority or no-regression certificate. No per-case time or ratio from it
> is a performance verdict on its own (STAGE2_PLAN.md §5–§6).

| File | Content |
|---|---|
| `cases.txt` | The 19 exact case IDs in the approved order: 14 primary, then 5 diagnostic. SHA-256 `20b79478b085ca6bab43d3c5fe536477f639af62f5524c02e7304079188e1037`. |
| `campaign.toml` | Campaign ID, case roles and catalog fields, pinned source and dependency identities, Julia builds and dependency locks, settings, repetitions, machine and affinity policy, exit-code and retry policy, archive destination. |
| `campaign.py` | The execution receipt (Python 3.11+, standard library only, Linux only). It wraps the pinned checkout's `setup.jl`, `run.jl`, `local.jl`, `validate.py` and `summarize.py`, and changes nothing they measure. |
| `archive.sh` | Archive checksums, packing and the GitHub Release (bash, Linux); see "Archive". |
| `test_campaign.py` | Offline tests of `verify`, the record checks and `archive.sh` (`python3 -B -m unittest -v` in this directory; no Julia, network or `gh`). |
| `STAGE2_PLAN.md` | The governing design. `cases-proposed.txt` is the F0 selection that `cases.txt` copies byte for byte. |

## Pins

| | Identity |
|---|---|
| ProximalSolvers (measured) | `b0de3f7fc91767b97197ff4b458207e308998943`, tree `a836d532…`, version 0.3.2, package hash `f37fc61f…`, harness hash `b7bf3d95…` |
| ProximalBase | registered 0.5.4 (tag `v0.5.4`, commit `9c5a43bf…`), release tree `1226119eb2cc6144f7345c727f0e7682632f7826`, package hash `d4747f2a…` |
| Julia | 1.10.13 (`e184dd51…`) and 1.13.3 (`67ac47b9…`), separate environments, records and reports |
| Dependencies | every Manifest entry per Julia version (`lock` in `campaign.toml`) |
| Settings | `PS_SUITE=extended`, `PS_GROUPS=cd,sgl,gradient,newton,admm,paths,primal_dual`, `PS_CASES` = `cases.txt` joined by commas, `PS_SAMPLES=100`, `PS_SECONDS=3`, `PS_CASE_SECONDS=60`, `PS_PROFILE_SECONDS=0`, one Julia and one BLAS thread, `PS_REPETITION=1..5` in fresh processes |
| Machine | Intel Core i9-13900 (hybrid), Linux; every formal process pinned with `taskset -c 6` (a performance core); SMT sibling 7 must stay idle |

The full values are in `campaign.toml`; `campaign.py` checks them, not this table.

## Requirements

- The frozen machine (`[machine]` in `campaign.toml`), quiet: no other heavy work, and
  nothing on logical CPUs 6 and 7. Linux with `git`, `taskset` and `lscpu`.
- Python 3.11 or later.
- The exact Julia builds. With juliaup: `juliaup add 1.10.13` and `juliaup add 1.13.3`;
  pass the build's own executable, for example
  `~/.julia/juliaup/julia-1.13.3+0.x64.linux.gnu/bin/julia`, not the juliaup launcher.
  `campaign.py` rejects any other build by its commit.
- Network access for `setup.jl` (General registry and packages). The setup must reproduce
  the frozen lock exactly; if the registry now resolves a different dependency version,
  the run stops and the campaign needs a versioned amendment (STAGE2_PLAN.md §3).

## Run (after the freeze is recorded on #110)

Run each shell snippet in this file as a script (`bash file.sh`) or in a subshell
(`( ... )`): they use `set -euo pipefail` and `exit`, which would close an interactive shell.

```bash
set -euo pipefail
FREEZE_SHA=...            # the freeze commit recorded on #110
BASE=/absolute/path/outside/any/checkout
git clone https://github.com/mlakolar/ProximalSolvers.jl.git "$BASE/pinned"
git -C "$BASE/pinned" checkout --detach b0de3f7fc91767b97197ff4b458207e308998943
git clone https://github.com/mlakolar/ProximalSolvers.jl.git "$BASE/freeze"
git -C "$BASE/freeze" checkout --detach "$FREEZE_SHA"
CAMPAIGN="$BASE/freeze/benchmark/campaigns/pre06/campaign.py"
ROOT="$BASE/pre06-stage2a-campaign-v1"     # the official root must have this name

for V in 1.10 1.13; do
  case $V in 1.10) J=~/.julia/juliaup/julia-1.10.13+0.x64.linux.gnu/bin/julia ;;
             1.13) J=~/.julia/juliaup/julia-1.13.3+0.x64.linux.gnu/bin/julia ;; esac
  code=0
  python3 -B "$CAMPAIGN" run --julia-version "$V" --julia "$J" --pinned "$BASE/pinned" \
    --work "$BASE/work" --root "$ROOT" --freeze-sha "$FREEZE_SHA" || code=$?
  # 2 = valid records with a non-ok case: continue, but the numerical gate has failed.
  [ "$code" -eq 0 ] || [ "$code" -eq 2 ] || { echo "Julia $V stopped; see $ROOT/julia-$V" >&2; exit 1; }
done
```

Exit status of `run` and `verify`: **0** valid records and every case `ok`; **2** valid
records with at least one non-`ok` case (the numerical gate fails; the run is complete
and is never retried for this reason); **1** a stop, any integrity failure or a usage
error. Python itself also exits 2 when it cannot open the script, so a caller accepts 0
or 2 from `verify` only together with its result lines (`RECORD INTEGRITY: PASS` and
`NUMERICAL: PASS` or `FAIL`), as `archive.sh` and the retrieval snippet below do.

Each `run` takes one Julia version through these steps and stops at the first failure:

1. Machine: Linux; the frozen CPU model; logical CPU 6 online, listed in
   `/sys/devices/cpu_core/cpus` and paired only with sibling 7.
2. Checkouts: the pinned checkout is the top of a git checkout at the pinned commit and
   tree with no tracked, untracked or ignored file beyond it; the freeze checkout is at
   `--freeze-sha`, equally clean, and leaves every path in `unchanged_paths` identical to
   the pinned commit. `--root` and `--work` are separate and outside both checkouts.
3. Campaign files: `cases.txt` has the recorded SHA-256, exact IDs only (no glob, blank,
   comment or duplicate), the `[[case]]` order, 14 primary and 5 diagnostic cases.
4. A fresh root (`julia-<V>` must not exist) and a fresh environment; both outside the checkouts.
5. Environment: `benchmark/setup.jl <pinned> <env> 0.5.4` with `JULIA_DEPOT_PATH` set to a
   campaign depot followed by the Julia build's own bundled depots (never `~/.julia`). The
   Manifest must equal the frozen lock (every entry's UUID, version and tree; the only path
   entry is ProximalSolvers at the pinned checkout; no repository entry), and Project.toml
   must be `benchmark/Project.toml` plus the develop source. Read-only snapshots of both
   are kept with their SHA-256. From here on Pkg runs offline.
6. Loaded identity (`environment-inventory.toml`): the Julia build commit, the CPU model,
   the active project and depot path,
   ProximalBase 0.5.4 tracked from the registry, and the git tree hash of the loaded
   ProximalBase directory equal to the `v0.5.4` release tree; ProximalSolvers loaded from
   the pinned checkout.
7. Selection: `PS_LIST` must print exactly the IDs of `cases.txt` (order aside, no
   duplicate, missing or unknown ID), and run.jl's own catalog functions must give each
   case the frozen phase, suite, inputs, issue, measure and target.
8. Repetitions 1–5. Before each, the wrapper waits (at most 300 s) for the 1-minute
   load to fall to 1.0. Each is a fresh `taskset -c 6 julia --startup-file=no --history-file=no
   --project=<env> benchmark/run.jl` with the exact environment of `campaign.toml`. While
   it runs, its allowed and observed CPUs are recorded; before and after, the load,
   governor, EPP, turbo, frequency, temperatures and the CPU 6/7 busy times. After it:
   exit code 0 or 2 (anything else stops), exit code consistent with `nonok_cases`, all
   six record files and nothing else, both metadata files equal to the frozen values
   (SHA, `proximalsolvers_dirty = false`, path, fingerprints, ProximalBase version and
   hash, `case_filter` byte for byte, suite, groups, sampling settings, threads, CPU),
   the catalog equal to the frozen fields, metrics covering the 19 cases once, earlier
   repetitions' files unchanged, and the environment and pinned checkout unchanged.
9. Fixed-input cases have one `data_hash` across repetitions.
10. `validate.py --expected-runs 5` must report valid records (gate A); then
    `summarize.py` and `check_analysis.py`.
11. Exploratory receipts on CPU 6 (labelled; not formal records): `local.jl --save` for
    all 19 IDs in one process (work counters), and one `local.jl` process per case for its
    first call including compilation.
12. `result.json`, `checksums.sha256` over every file of `julia-<V>`, and a verification
    of the evidence as in "Verify" below, which decides the exit status.

Every command, its environment, working directory, start and end time, wall time, exit
code, stdout and stderr is in `receipt.jsonl`, `commands-and-exit-codes.log` and `logs/`.
Nothing is ever overwritten: logs are opened exclusively, and run.jl refuses an existing
record prefix.

### Reading the result

`campaign.py` reports three things separately:

- **Record integrity (gate A):** `valid` only if every check above and `validate.py`
  pass. Exit code 2 is a completed repetition with numerical failures, not an integrity
  failure.
- **Numerical result (gate B):** `all ok`, or the list of non-`ok` cases by repetition.
  A run whose records are valid can still fail here; such failures are archived and
  reported, never retried or dropped.
- **Hardware:** `controlled` only if, in every repetition, the process was allowed and
  observed only on CPU 6, the sibling was at most 5% busy, the 1-minute load was at most
  1.0 at the start, and the governor, EPP and turbo state matched `campaign.toml`;
  otherwise `observational`, with the reasons. A wrong affinity stops the run.

### Stops and retries

Any stop leaves `result.json` with `status = "stopped"` and the reason, plus the full
evidence. Do not edit or delete it. Per `[protocol]` in `campaign.toml`: never rerun one
repetition or one case, and never retry because of a numerical result. A Julia version
stopped for an infrastructure reason may be repeated once, completely, after the cause
is recorded on #110: move the stopped `julia-<V>` to `attempts/julia-<V>-attempt1/` in
the root, use a fresh `--work`, and run again. A second stop needs a versioned amendment.

## Verify

```bash
python3 -B "$CAMPAIGN" verify "$ROOT" --freeze-sha "$FREEZE_SHA"
```

This needs only Python and a clean checkout of the freeze commit, which must be the
commit that produced the evidence (its HEAD and the digest of `campaign.py` are in the
receipt). The receipt is not trusted for the protocol: official evidence must have the
frozen settings and five repetitions, and an official root must hold exactly `julia-1.10`
and `julia-1.13`, both official, plus at most one stopped attempt per version under
`attempts/`. For each `julia-<V>` it checks the file
checksums (no missing, changed or extra file), that the attempt completed, the root's
`campaign.toml` and `cases.txt` against the freeze checkout, the Manifest snapshot against
the lock and against its digest at setup, the Project snapshot, the loaded identities, the
archived `PS_LIST` and catalog outputs, that every command of the protocol ran once, in
order, with its exact arguments, environment, directory and an accepted exit code, the
recorded affinity of every repetition, the required outputs (validation, summary,
exploratory receipts), every repetition's records as in step 8,
fixed-input data hashes; it runs `validate.py` afresh and compares it with
`validation.json`, and recomputes the numerical and hardware results from the records,
which must agree with the receipt. It ends with `RECORD INTEGRITY`, `NUMERICAL` (with the
non-`ok` primary cases, which block an unconditional "healthy reference" label, plan §5),
`HARDWARE` lines and an `EVIDENCE` line (`OFFICIAL` for valid official evidence,
`PILOT / NON-OFFICIAL` for valid pilot evidence, `NOT VALID` on any integrity failure), and
exits as `run` does. Pilot evidence fails unless
`--allow-pilot` is given. `VERIFY PASS` concerns the records; the numerical and hardware
results are printed beside it.

## Archive (maintainer)

`archive.sh` (beside `campaign.py`; bash, Linux, GNU tools) is the only archive and
publication recipe; the commands below call it and nothing else. The layout follows
STAGE2_PLAN.md §6. In the root, add `README.md` (purpose, links, hardware, the commands
above), `FREEZE.md` (freeze SHA, approval, dates, deviations) and, after review,
`independent-review.md`. Then:

```bash
ARCHIVE="$BASE/freeze/benchmark/campaigns/pre06/archive.sh"
code=0
"$ARCHIVE" pack "$ROOT" "$FREEZE_SHA" || code=$?
case $code in
  0) "$ARCHIVE" release "$ROOT" "$FREEZE_SHA" --tag bench-pre06-v1 ;;
  2) echo "NUMERICAL FAILURE: archived, never a healthy reference" >&2
     # Release only after the maintainer records a disposition on #110:
     # "$ARCHIVE" release "$ROOT" "$FREEZE_SHA" --tag bench-pre06-v1 --disposition "<URL>"
     ;;
  *) echo "blocked: nothing archived" >&2; exit 1 ;;
esac
```

`archive.sh checksums ROOT` writes `ROOT/checksums.sha256` over every regular file of
the root except that file itself (so both `julia-<V>/checksums.sha256` are listed, once),
with paths relative to the root in C-locale order; any failure removes the partial list.
`archive.sh pack ROOT FREEZE_SHA` runs `checksums`, then
`campaign.py verify ROOT --archive --freeze-sha FREEZE_SHA`, and decides by its exit code:

- **0**: packs. Beside the root: `<root>.tar.gz`, its digest `<root>.tar.gz.sha256`, a
  status file `<root>.tar.gz.status` (verify exit code, numerical status, the `RECORD
  INTEGRITY`, `NUMERICAL`, `HARDWARE` and `EVIDENCE` lines, archive SHA-256) and the full
  `<root>.verify.out`. Exit 0; publication allowed.
- **2**: valid records with a non-`ok` case. Packs as above, the status file says
  `NUMERICAL FAILURE: valid archived evidence, not a healthy reference`, and `pack` exits
  2. The archive is kept; it is never described as a healthy baseline, and `release`
  needs an explicit maintainer disposition (`--disposition`, e.g. the URL of the #110
  comment that records the decision).
- **1 or anything else** (another code, a signal): blocked before `tar`; nothing is
  packed or published. `pack` never overwrites an existing tarball, sidecar or
  `.verify.out`, and refuses an archive path containing `#` (which `gh` reads as a label).

`archive.sh release ROOT FREEZE_SHA --tag TAG [--disposition REF]` publishes only an
official archive; a pilot rehearsal archive is never released. It stops, creating
nothing, unless: the tarball matches its `.sha256` and `.status`; the status is
`official`, of this campaign and freeze; the extracted tarball passes an official
`verify --archive --freeze-sha` (no `--allow-pilot`) with the packed exit code, labelled
`EVIDENCE: OFFICIAL` (exit 2 also needs `--disposition`: one line of free text recorded
verbatim, or exactly a `https://github.com/mlakolar/ProximalSolvers.jl/issues/110#issuecomment-<N>`
URL); the root, asset and tag are the
`[archive]` names of `campaign.toml`; `FREEZE_SHA` is a full SHA that exists on GitHub, is
reachable from `master` and appears in a comment on #110; and neither the tag nor a
release of it exists (only a definite "not found" counts). Then `gh release create TAG
<asset> --target FREEZE_SHA --latest=false` creates the tag at the freeze commit, with
notes saying that this is benchmark evidence and not a package release, the campaign ID,
freeze SHA, ProximalSolvers pin, ProximalBase 0.5.4 release tree, both Julia versions,
the record-integrity, numerical and hardware lines, the disposition after a numerical
failure, the archive SHA-256 and #110. A tag or asset is never overwritten, moved or
deleted (no `--clobber`); a correction is a new campaign identity, tag and asset. Every
failed check or `gh` call exits nonzero; an existing `<root>.release-notes.md` is never
overwritten. This PR creates no GitHub Release.

Post on #110 the asset URL, its SHA-256, that the asset is kept permanently and replaced
never (a correction is a new tag), and the retrieval commands below. The environment
directories and the depot under `--work` are not archived; the Manifests in the archive
contain the absolute path of the pinned checkout, which is machine specific.

## Retrieve and re-verify (independent check)

```bash
set -euo pipefail
mkdir fresh && cd fresh
gh release download bench-pre06-v1 --repo mlakolar/ProximalSolvers.jl
echo "<digest posted on #110>  pre06-stage2a-campaign-v1.tar.gz" | sha256sum -c -
tar -xzf pre06-stage2a-campaign-v1.tar.gz
git clone https://github.com/mlakolar/ProximalSolvers.jl.git freeze
git -C freeze checkout --detach "$FREEZE_SHA"
code=0
out=$(python3 -B freeze/benchmark/campaigns/pre06/campaign.py verify \
  pre06-stage2a-campaign-v1 --archive --freeze-sha "$FREEZE_SHA") || code=$?
printf '%s\n' "$out"
has() { grep -qx -- "$1" <<< "$out"; }
# 0: valid, every case ok. 2: valid records, NUMERICAL FAILURE (not a healthy reference).
# Any other code, or result lines that disagree with the code (a usage error or a missing
# script can also exit 2), means the archive does not verify.
case $code in
  0) has 'RECORD INTEGRITY: PASS' && grep -q '^NUMERICAL: PASS' <<< "$out" && has 'EVIDENCE: OFFICIAL' ;;
  2) has 'RECORD INTEGRITY: PASS' && grep -q '^NUMERICAL: FAIL' <<< "$out" && has 'EVIDENCE: OFFICIAL' ;;
  *) false ;;
esac || { echo "archive does not verify ($code)" >&2; exit 1; }
```

To reproduce the environment on another machine, run `campaign.py run` with a new pinned
path: the lock check is path independent, but the machine check will refuse a different
machine, so a run elsewhere is a new campaign or an observational, labelled replication.

## Pilot (not official)

`--pilot` runs the same receipt into a root whose name contains `pilot`, with optional
`--reps N`, `--no-exploratory` and `--override` of `PS_SAMPLES`, `PS_SECONDS` or
`PS_CASE_SECONDS`; it does not need `--freeze-sha`. Pilot evidence is labelled `pilot`
throughout, `verify` rejects it without `--allow-pilot`, and it never counts as an
official repetition (STAGE2_PLAN.md §3).

`verify` has two archive modes. **Official:** `verify ROOT --archive --freeze-sha SHA`
(no `--allow-pilot`; `--freeze-sha` is required for official evidence) needs both
`julia-<V>`, all official, in a root named `pre06-stage2a-campaign-v1`. **Pilot archive
rehearsal:** `verify ROOT --archive --allow-pilot [--freeze-sha SHA]` needs both
`julia-<V>`, all pilot, in a root whose name contains `pilot` and is not the official
name; it applies the same archive checksums and record checks. When the records are
valid its last line is `EVIDENCE: PILOT / NON-OFFICIAL (never Stage 2A baseline evidence)`,
whatever the numerical result (`EVIDENCE: NOT VALID ...` otherwise); only valid official
evidence prints `EVIDENCE: OFFICIAL`. A two-version
pilot root can be rehearsed end to end with `archive.sh pack ROOT FREEZE_SHA
--pilot-rehearsal` (its status file says `mode: pilot-rehearsal`); `archive.sh release`
refuses it.
