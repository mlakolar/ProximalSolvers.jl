# Documentation and solver contracts

The documentation has three readers:

- **Learn** (`docs/src/learn/`): students; derivations, figures, examples and exercises.
- **Use** (the existing flat `docs/src/` pages): practitioners; installation, solver choice, support and results.
- **Contracts** (`docs/src/contracts/`): implementers; complete numerical rules with permanent clause IDs.

Before changing a numerical routine, read `contracts/index.md`, the routine's
contract, `inputs.md`, `working-precision.md` and `results-failures.md` (all under
`docs/src/`). State a numerical rule in full in one clause; other layers summarize
it and link there. A behavior change updates the clause and its tests in the same
pull request, and updates the support matrix when the supported surface changes.
Explain in the clause's Tests field when a new test is unnecessary.

Keep clause IDs. Retire an obsolete clause in place and link to its replacement.
Put historical measurements, dates, revisions and issue investigations in
`contracts/evidence/` or a Change log. `docs/audit/` is historical evidence, not
the current specification; some archived documents describe absent solvers.

Original example scripts remain the single source for the Literate example pages
and package example tests. Register new scripts in `docs/make.jl`. Preserve
published page paths and anchors. Run the documentation checks described in
`CONTRIBUTING.md`; prose-length and vocabulary reports guide review rather than
substitute for it. The completed migration ledger is archival provenance, not a
permanent freeze on future documentation or solver changes.
