Part of #353

Deletes `_scaled_norm` of `src/cd/sqrtlasso.jl`, a third scaled-norm algorithm beside the kernels of `src/solvers/image_models.jl`: its two callers (`_prepare!`, for the tightening floor, and `_sqrt_offrange_step`, for a cancelled distance) call the existing `_se_norm(Float64, ·)`. This is the fallback ("R1-min") of recommendation R1 of the Stage 0 audit; the larger simplification of the square-root lasso range handling was investigated and not taken ([result on #353](https://github.com/mlakolar/ProximalSolvers.jl/issues/353#issuecomment-6970454563)).

The fast path of the coordinate step, `_sqrt_band_step`, `_sqrt_threshold64` and the range handling of `_sqrt_offrange_step` are unchanged. No public API change, no change of outcome classes, no ProximalBase change.

Work in progress. This PR is the record of the run: the plan, each review round, the verification (what ran where, at which commit), and the final report are posted as comments.
