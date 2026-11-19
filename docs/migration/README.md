# Learn / Use / Contracts migration record

This directory records a one-time documentation migration. It is an audit trail,
not a permanent freeze on later documentation or numerical development.

## Baselines

The text, example and URL inventory comes from
`a6293e6ff7e654a87babbc5de2314205be13d6c5`, the revision named in the migration
plan. The implementation and current-example guards use
`217cde72cad2b324e174012accc949da59c1bba5`, the master revision integrated before
publishing. The branch initially started at `debbc88`; subsequent upstream work
added five tutorials, the narrow nonnegative-lasso PGD path, the complete
Examples Gallery in PR #417, the square-root-lasso smoothing fallback in PR #406,
the weighted NormL1 clarification in PR #419, and uncentered SqrNormL2 ridge CD
support in PR #420. Those independently reviewed changes are retained.

`source_code_sha256`, `implementation_example_scripts` and `implementation_urls`
describe the integrated snapshot. The original `example_scripts` hashes and all historical text remain
anchored to the plan's revision. The migration itself leaves the 19 current scripts
byte-identical to the integration base, including the gallery's upstream figure
code and numerical checks. It does not undo their evolution after the plan's
14-script snapshot. New nonnegative-lasso, square-root-lasso fallback and ridge clauses cite their
immutable current source separately from the 725 historical blocks; the original example
index is retained as dated evidence.

`baseline.json` contains original text as well as SHA-256 fingerprints. It records
725 blocks, 19 original inline executable examples, 14 example scripts, and
86 published page-heading fragments. The fragments were checked against an
actual Documenter build of the original revision, including its Unicode slug
rules. The integration snapshot also records 88 heading fragments, including the
new nonnegative-lasso and square-root-lasso fallback headings. The rendered-URL
check retains the union of both snapshots. The baseline does not include generated
HTML or benchmark output.

## Reading the ledger

There is exactly one CSV row per original block. Its ID names the original source
and first line, even if the current source has moved or shortened. The SHA-256 is
of the exact original block text. The final dispositions are:

| Disposition | Count | Meaning and check |
|:--|--:|:--|
| `moved` | 470 | Verbatim text remains at the destination; recorded link-target adjustments are the only permitted substitutions. |
| `example` | 19 | The exact original block remains an active `@example` fence and executes in the documentation build. |
| `merged` | 236 | The destination retains the substance in a named section or clause; contract Sources cite the exact original ID. |

A paragraph can contain several rules. Its primary destination is authoritative
for the main rule; `additional_destinations` identifies the other clauses needed
to account for its content. This is semantic consolidation, not a claim that
hashes prove equivalence. Normalized rules received independent review of
arithmetic, constants, qualifications, counter identities and failure boundaries.
The pull request remains the place for owner approval of the wording.

The mechanical checkpoints precede normalization in the branch history:
`b1a1ba2` inventories the baseline, `e9fb17d` stages Learn and solver excerpts,
and `bcb808f` stages shared input, precision and failure specifications. Historical
wording that conflicted with other sources was first retained under Unreconciled
sections, then resolved in [issue #416](https://github.com/mlakolar/ProximalSolvers.jl/issues/416). The original quotations
and five historical anchor IDs are preserved in explicitly retired sections;
STOP-04, IN-01, APG-04 and ARCH-01 are the authoritative current clauses.
This resolution changes documentation only, not numerical behavior.
There are no silently superseded or dropped rows.

## Checks and their lifetime

```sh
python3 -m unittest discover -s scripts -p 'test_docs*.py'
python3 scripts/docs_ledger.py verify-baseline --previous-ref origin/master
python3 scripts/docs_ledger.py check --token-report /tmp/docs-token-coverage.json
python3 scripts/check_docs_layers.py --migration --previous-ref origin/master
CI=true julia --project=docs docs/make.jl
python3 scripts/docs_ledger.py check-urls
```

For the introducing change, the verifier reconstructs the inventories from the
recorded Git snapshots and checks the original source bytes outside docstring
bodies. It also checks exact example-script bytes against the recorded integration
snapshot and active original inline-example identity, so hiding a block in a comment or literal fence does not preserve it.
The full ledger check also inventories distinctive baseline tokens: complete
inline code/math expressions, identifiers, issue references, error-message
fragments, file paths, and numbers with units or exponents. It searches maintained
Markdown and actual source docstrings, including explicitly dated historical
evidence. Migration metadata, generated pages, tests, fixtures and hidden comments
cannot supply coverage. The JSON report records each token's originating block
IDs, ledger destinations and retained location or reviewed waiver.

`token-waivers.txt` contains one JSON object per non-comment line, with exactly
`token`, `blocks`, `target`, `replacement` and `reason`. The token must use the
report's normalized spelling, `blocks` must list every originating baseline ID,
and `target` must identify an existing contract clause as a repository-relative
Markdown path and fragment. The replacement must actually occur in that clause.
Each reason explains the specific equivalence, such as changing `F'` to
`F_previous` or absolute-value bars to Julia `abs`; it cannot excuse missing
information. Unknown, duplicate, incomplete, unsupported and stale waivers fail.
The workflow preserves this report even when the migration check fails.
Token matching is a lexical safety net. It does not establish mathematical
equivalence or replace review of the merged blocks and their qualifications.

For later changes, CI compares the immutable inventory with the previous
published inventory and uses `check --structural`. It does not require future
prose, tokens, examples or numerical implementations to remain frozen at the
migration revision.

The comparison revision comes from the PR base, the pre-push commit, or the
fetched default branch for a manual build. This makes introduction detection work
across the migration's multiple commits. The permanent checks retain clause IDs,
including new registered IDs, require clause metadata and Learn exercises, check
ledger destinations and Sources, and verify old URLs in the rendered HTML.

Prose thresholds are advisory: 1,800 words per Learn chapter, 120 per Use paragraph,
300 for README, and 150 above a docstring's Extended help. The complete keyword lists remain above Extended help for usable offline
help. Those lists, the longer existing module summary, a compact glossary
definition, and a support explanation are
reviewable exceptions, not numerical correctness failures. Layer-vocabulary and
direct-link reports likewise guide review; a CD-specific clause link can be more
precise than a generic result link. Exact text preservation and semantic review
remain separate checks.

Executable code is kept in its intended layer. The 19 current scripts remain
the single source for Literate pages, the upstream Examples Gallery and package
example tests. Learn adds reference implementations and plots. The gallery and
its figure-generation checks remain intact in the new navigation, using the
existing documentation-only plotting dependency.
