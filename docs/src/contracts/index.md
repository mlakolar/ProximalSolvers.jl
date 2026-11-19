# [Contracts for the current solver core](@id contracts-index)

Read this layer when implementing, reviewing or diagnosing solver behavior. Each
numerical rule has one full statement with a stable clause ID. The [Learn
chapters](../learn/01-lasso-problem.md) develop the mathematics, and the [Use
pages](../getting-started.md) explain how to call the package.

## Reading order

Start with the routine's contract, then read [inputs](@ref IN-01), [working
precision](@ref FP-01) and [results and failures](@ref RES-01). A mathematical
identity does not by itself specify the computation: the clause also states
accepted data, arithmetic, refusal timing and mutation boundaries.

## Clause schema

A numbered clause contains **Statement**, **Applies to** and **Sources**. **Code**
identifies the implementation, and **Tests** points to existing checks or explains
why a separate test is unnecessary. Algorithm, proof and known-limit subsections
may expand a clause. Sources refer to immutable baseline blocks in
`docs/migration/baseline.json`; the matching row of `docs/migration/ledger.csv`
records where each original block went.

A source citation records provenance. It does not certify that two formulations
are equivalent. The migration initially preserved conflicting wording under
**Unreconciled** headings. The four historical specification conflicts were
resolved in [issue #416](https://github.com/mlakolar/ProximalSolvers.jl/issues/416); their original quotations and
permanent anchors remain under **Retired historical wording**, with links to the
authoritative clauses. Evidence pages retain measured outcomes, platforms, dates
and revisions; those observations are not new solver guarantees.

Clause IDs are permanent. When a clause is replaced, keep its heading, mark it
**Retired**, and link explicitly to the replacement. New clauses receive new IDs.

## Clause registry

| Prefix | Scope | Entry point |
|:--|:--|:--|
| `IN` | Shapes, types, penalties, scalars and aliasing | [Input rules](@ref IN-01) |
| `FP` | Arithmetic, promotion and range limitations | [Working precision](@ref FP-01) |
| `CD` | Scalar least-squares coordinate descent | [Scalar CD](@ref CD-01) |
| `CDS` | Private SparseIterate run and commit | [SparseIterate CD](@ref CDS-01) |
| `CDG` | Group steps, screening and curvature | [Group CD](@ref CDG-01) |
| `CDM` | Matrix responses and row groups | [Multiresponse CD](@ref CDM-01) |
| `CDQ` | Square-root lasso and certificates | [Square-root lasso](@ref CDQ-01) |
| `PGD` | Iteration, initialization, traces and limits | [PGD iteration](@ref PGD-01) |
| `APG` | Extrapolation, restart and the bound test | [Accelerated PG](@ref APG-01) |
| `LS` | Backtracking, acceptance and range recovery | [Line search](@ref LS-01) |
| `STOP` | Proposals, stationarity checks and separate exits | [PG stopping](@ref STOP-01) |
| `RES` | Results, diagnostics and mutation on failure | [Results and failures](@ref RES-01) |
| `DEF` | Unsupported features and rejected settings | [Deferred surface](@ref DEF-01) |

The complete retained-ID list is `docs/migration/clause-registry.json`. The layer
check enforces it; this table groups the clauses for navigation.

## Shared notation

| Symbol | Meaning |
|:--|:--|
| `β`, `beta`, or source variable `x` | Caller-owned coefficients |
| `X`, `y` | Design and response; `Y` for a matrix response |
| `s` | Positive loss scale: `s * LeastSquaresLoss(y, X)` |
| `λ`, `lambda` | Penalty level; `λ₁`, `λ₂` for elastic net |
| `T` | Native coefficient/data precision, `Float32` or `Float64` |
| `L` | Inverse step size / curvature estimate |
| `α`, `β` in line-search settings | Public backtracking factors, unchanged |

Retained proofs and excerpts may call the loss scale `α` or `α_f`, or use `x`
for the coefficients. Their local notation is stated where it matters. Public
constructor keywords and stored fields retain their API spelling.

## Historical records

The repository's [archived contracts](https://github.com/mlakolar/ProximalSolvers.jl/blob/master/docs/audit/20261026/contracts.md)
are historical evidence. They describe ADMM, QUIC, SLOPE and other algorithms
that are not part of the current master branch. Use the clauses here and the
[current support matrix](../support.md) for the implemented surface. The archive
is intentionally unchanged. [History](history.md) records earlier branches and
dependency provenance; [architecture](architecture.md) describes the source layout.

## [Internal glossary](@id internal-glossary)

**Owner:** An internal name for the caller's mutable coefficient
storage. In beginner-facing pages, we call it the *coefficient
vector* or *coefficient storage*.

**Sentinel:** A placeholder value, such as `kkt_checks=0`, or `gap=NaN` where no
certificate was computed or none passed, indicating that a diagnostic is not available.

**TFOCS:** *Templates for First-Order Conic Solvers*. A historical
first-order optimization framework; the name appears in descriptions
of PGD's inherited backtracking behavior. It is not a separate solver
offered by this minimal version.

**FASTA:** *Fast Adaptive Shrinkage/Thresholding Algorithm*. Historical
terminology for a first-order algorithm and a residual-style stopping
test. Its appearance in implementation notes does not mean this
package exposes a separate FASTA solver.

**IHT:** *Iterative hard thresholding*, a method for imposing a fixed
sparsity budget by retaining selected entries. `normalized=true`
IHT-style behavior is not supported by the current PGD constructor.

**C0:** An internal project label for the frozen baseline
characterization and regression tests used during the minimal-core
rebuild. It is **not** a solver option or a user-facing algorithm.
