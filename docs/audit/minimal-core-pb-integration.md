# C4: exact-source ProximalBase integration

This integration follows the atomic minimal reduction (PR #242, merged as
`64930401cfc0451e886728d916263c4dab2baf36`) and its passing full master run
[42969288882](https://github.com/mlakolar/ProximalSolvers.jl/actions/runs/42969288882).
It preserves the twelve-file source architecture, supported dense lasso API,
C0 characterization, native arithmetic, private PB SparseIterate adapter,
result contracts, stopping rules, and the separately approved Linux-only matrix.
No release/version change is authorized or included.

## Exact sources and demonstrated incompatibility

- PS A: `64930401cfc0451e886728d916263c4dab2baf36`.
- PB A: `e8a45a8a6ffe2a6f92d83c4c77d62a9b7631e291`.
- PB B, refreshed current master: `eff21b6d7d33c622313122f46c6ee71693c101ee`.
- PB B Git tree: `c76123a0109c0a0f683cb75085371696dffe1c8c`.

PB B includes the scalar pure-block oracle rename. Unadapted PS A loaded with a
missing `prox_entry` import warning, then failed with `UndefVarError` in all four
raw/scaled Float32/Float64 CD probes before scattering the caller's iterate.
The corresponding PGD probes succeeded. This is a concrete scalar API break;
no private-owner incompatibility was observed.

The runtime adaptation changes exactly three names: import `prox_block` and use
it in the positive-curvature LS coordinate update and the flat-column helper.
There is no compatibility alias or new dispatch layer. The scalar NormL1 body is
unchanged between the two PB sources. No group solver, block workspace, symmetric
owner, Newton code, or PR #237 history is imported.

Root/docs Project sources now pin PB B exactly. PB's Project.toml is byte-identical
between A and B, including dependency/compat/extension metadata. Consequently the
Julia-1.10 floor manifest changes only PB's revision and Git tree identity. This
metadata update is not a claim of a new Julia-1.10 test run; active CI remains
current stable Julia1 on Linux x64.

## Always-run paired controls

Run:

```sh
julia --startup-file=no --project=@stdlib scripts/paired_master_diagnostics.jl
```

The existing gated `Benchmark analysis controls` job retains its Python controls
and executes this Julia control on every invocation. It has no main-tier,
nightly-reuse, dependency-version or environment-fingerprint skip. Existing
required check names, verdict inputs, merge gate, test matrix, and nightly
selection semantics are unchanged.

The control fetches isolated immutable PS A and PB A/B Git checkouts. It resolves
two temporary package environments and launches separate fresh probe processes.
Before/after probes it checks clean tracked Git HEADs, actual loaded package paths,
committed source pins and Project/src SHA256 digests. A sibling checkout or
matching version string cannot substitute for the selected source. Any missing
source, failed child, missing record, independent accuracy failure, or A/B
divergence fails the analysis job and the existing required gates.

There are 288 paired records:

- 216 lasso cases: Float32/64, orthogonal/correlated/nonunique designs, raw or
  explicitly scaled LS, zero/nonzero starts, zero/moderate/large penalties, CD
  random default momentum, CD cyclic without momentum, and PGD.
- 60 scalar-oracle records and 12 private-owner activation/compaction/copy/scatter
  records.

The lasso probe computes objectives/KKT residuals directly in Float64, evaluates
Float32 points at wider precision, enumerates signed supports for the tiny
full-rank two-variable reference, and reduces the duplicate/null-column case to
its one-dimensional fitted coefficient. None of those references calls PB prox,
PS gradient caches or stopping helpers. Unique cases compare coefficient/minimum
bits and returned counters/flags; nonunique cases compare fitted values,
objective and KKT instead of requiring an arbitrary coefficient representative.
The normal full suite retains the broader unchanged C0 numerical oracles.

PGD control-only options request tighter tolerances to make these small independent
accuracy checks useful. They do not alter the ordinary default stopping contract:
`converged=true` remains an OR-based historical flag, not a KKT certificate.
The broader default-options source audit separately observed identical A/B
records with PGD KKT residuals as large as approximately 1.75e-3; it does not claim
those defaults satisfy `gradtol` as an optimality bound.

## Validation evidence

Local/CI test outcomes and final review links are recorded after executing the
integration head. The focused policy tests exercise full-SHA refusal, dirty/wrong
source detection, missing/changed records, and the unconditional gated workflow
attachment. The full PB-B package suite, docs and ordinary precompile remain
required before review and merge.
