# Architecture and validation

The twelve active files are module/types/blocks/line_searches/solve/utils/precompile,
solvers/image_models and proximal_gradient_descent, and cd/models/solver/leastsquares.
Small native helpers support two separately cached algorithms and existing
result types. CDModel and state hooks are private extraction/test seams, not
promises of custom loss or workspace support. Generic block/metric/certificate/
logging frameworks are deferred.

Keep exact PB A pin e8a45a8a6ffe2a6f92d83c4c77d62a9b7631e291. Later paired-master
integration needs a verified current SHA, isolated A/B evidence and initially
always-run diagnostics. PR #237's different oracle contract is not automatic.
C0 and the provenance audit describe retained mathematical/behavioral tests.

Current CI is stable Julia1 Linux x64 only for every tier. Preserve required
checks, full master validation, coverage, benchmark-analysis and conservative
policy-aware nightly reuse. Historical platform runs and the deferred macOS C0
warm-convergence failure remain historical, not newly passing claims.

Historical measured performance tables remain in the repository's
[full-package performance record](https://github.com/mlakolar/ProximalSolvers.jl/blob/master/docs/audit/historical-full-performance.md).
They are not replaced by unmeasured minimal-core claims.
