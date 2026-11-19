# Learn / Use / Contracts migration record

This directory records a one-time documentation migration. It is an audit trail,
not a permanent freeze on later documentation or numerical development.

## Baselines

The text, example and URL inventory comes from
`a6293e6ff7e654a87babbc5de2314205be13d6c5`, the revision named in the migration
plan. The implementation guard uses
`fd45a4274222e7cfe8f329c1dacd41ec26bfc2c8`, the current master revision integrated
before publishing. The branch initially started at `debbc88`; the later upstream
changes add five tutorials and the narrow nonnegative-lasso PGD path. They are
preserved. `source_code_sha256` uses the integrated implementation snapshot;
all historical text and example records still use the plan's baseline.
New nonnegative-lasso clauses cite their immutable current-source commit separately
from the 725 historical blocks. The original 14 scripts remain unchanged, and all
five newer upstream scripts remain registered and executable.

`baseline.json` contains original text as well as SHA-256 fingerprints. It records
725 blocks, 19 original inline executable examples, 14 example scripts, and
86 published page-heading fragments. The fragments were checked against an
actual Documenter build of the original revision, including its Unicode slug
rules. The baseline does not include generated HTML or benchmark output.

## Reading the ledger

There is exactly one CSV row per original block. Its ID names the original source
and first line, even if the current source has moved or shortened. The SHA-256 is
of the exact original block text. The final dispositions are:

| Disposition | Count | Meaning and check |
|:--|--:|:--|
| `moved` | 469 | Verbatim text remains at the destination; recorded link-target adjustments are the only permitted substitutions. |
| `example` | 19 | The exact original block remains an active `@example` fence and executes in the documentation build. |
| `merged` | 237 | The destination retains the substance in a named section or clause; contract Sources cite the exact original ID. |

A paragraph can contain several rules. Its primary destination is authoritative
for the main rule; `additional_destinations` identifies the other clauses needed
to account for its content. This is semantic consolidation, not a claim that
hashes prove equivalence. Normalized rules received independent review of
arithmetic, constants, qualifications, counter identities and failure boundaries.
The pull request remains the place for owner approval of the wording.

The mechanical checkpoints precede normalization in the branch history:
`b1a1ba2` inventories the baseline, `e9fb17d` stages Learn and solver excerpts,
and `bcb808f` stages shared input, precision and failure specifications. Historical
wording that conflicts with other sources remains in Unreconciled sections and is
tracked in [issue #416](https://github.com/mlakolar/ProximalSolvers.jl/issues/416).
There are no silently superseded or dropped rows.

## Checks and their lifetime

```sh
python3 -m unittest discover -s scripts -p 'test_docs*.py'
python3 scripts/docs_ledger.py verify-baseline --previous-ref origin/master
python3 scripts/docs_ledger.py check
python3 scripts/check_docs_layers.py --migration --previous-ref origin/master
CI=true julia --project=docs docs/make.jl
python3 scripts/docs_ledger.py check-urls
```

For the introducing change, the verifier reconstructs the inventories from the
recorded Git snapshots and checks the original source bytes outside docstring
bodies. It also checks exact example-script bytes and active inline-example
identity, so hiding a block in a comment or literal fence does not preserve it.
For later changes, CI compares the immutable inventory with the previous
published inventory and uses `check --structural`. It does not require future
examples or numerical implementations to remain frozen at the migration revision.

The comparison revision comes from the PR base, the pre-push commit, or the
fetched default branch for a manual build. This makes introduction detection work
across the migration's multiple commits. The permanent checks retain clause IDs,
including new registered IDs, require clause metadata and Learn exercises, check
ledger destinations and Sources, and verify old URLs in the rendered HTML.

Prose thresholds are advisory: 1,800 words per Learn chapter, 120 per Use paragraph,
300 for README, and 150 above a docstring's Extended help. A longer existing
module summary, a compact glossary definition, and a support explanation are
reviewable exceptions, not numerical correctness failures. Layer-vocabulary and
direct-link reports likewise guide review; a CD-specific clause link can be more
precise than a generic result link. Exact text preservation and semantic review
remain separate checks.

Executable code is kept in its intended layer. The original 14 scripts are
unchanged and remain the source for Literate pages and package example tests.
Learn adds reference implementations and plots. The gallery executes the original
lasso and group-lasso scripts to generate its two figures, using the existing
documentation-only plotting dependency.
