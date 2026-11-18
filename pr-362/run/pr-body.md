Part of #353

Delivers the two cleanups of the Stage 0 audit of #353 that the maintainer approved without conditions (decisions: https://github.com/mlakolar/ProximalSolvers.jl/issues/353#issuecomment-6969675059), as separate commits:

- **R2**: five deletions with bit-identical results (`_maxabs_diff`, the summation loop of `_frobenius_upper`, `_round_up`, the loops of `_flat_column` and `_flat_group`, `_significand_exponent`);
- **R4**: the two parallel scaled-norm kernel families of `src/solvers/image_models.jl` folded into one.

No public API change, no change to stopping or convergence statuses, no ProximalBase change. The square-root lasso simplification (R1) is not in this PR.

Work in progress. This PR is the record of the run: the plan, each review round, the verification (what ran where, at which commit), and the final report are posted as comments.
