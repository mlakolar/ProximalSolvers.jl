# Minimal-core test provenance

Base428f772 contains C0 and the separately approved Linux-only CI PR. Every old
test-tree file is accounted for below. No applicable test is hidden as a helper
or environment: only tiers is a helper, and optional generalized oracle scripts
leave with their deferred feature. C0 independent oracles remain required quick.
Historical full-package/platform measurements are preserved in
[historical-full-testing.md](historical-full-testing.md), with deferred macOS
run42949840807 explicitly distinguished from current Linux rebuild gates.

| Baseline file | Disposition / replacement |
| --- | --- |
| `TESTING.md` | Retained/adapted deliberately to the supported inventory; generic fail-closed, nightly and gate semantics retained. Two dense LS examples replace unsupported scripts. |
| `active_set.jl` | Deferred with its unsupported feature; exact original preserved on archive/legacy refs. Minimal green does not claim this feature works. |
| `admm.jl` | Deferred with its unsupported feature; exact original preserved on archive/legacy refs. Minimal green does not claim this feature works. |
| `apg_numerical_failure.jl` | Deferred with its unsupported feature; exact original preserved on archive/legacy refs. Minimal green does not claim this feature works. |
| `aqua.jl` | Retained byte-for-byte from accepted Linux-only/C0 baseline. |
| `audit_regressions.jl` | Scalar dense LS/PGD/cache/stopping portions extracted into unchanged C0 characterization, core_regressions and core_contracts; other losses/penalties/iterates/solvers/drivers deferred. |
| `audit_regressions_basics.jl` | Scalar dense LS/PGD/cache/stopping portions extracted into unchanged C0 characterization, core_regressions and core_contracts; other losses/penalties/iterates/solvers/drivers deferred. |
| `box_paths.jl` | Deferred with its unsupported feature; exact original preserved on archive/legacy refs. Minimal green does not claim this feature works. |
| `call_limits.jl` | Scalar dense LS/PGD/cache/stopping portions extracted into unchanged C0 characterization, core_regressions and core_contracts; other losses/penalties/iterates/solvers/drivers deferred. |
| `ci_gate.jl` | Retained byte-for-byte from accepted Linux-only/C0 baseline. |
| `convolution_gap.jl` | Deferred with its unsupported feature; exact original preserved on archive/legacy refs. Minimal green does not claim this feature works. |
| `coordinate_descent.jl` | Scalar dense LS/PGD/cache/stopping portions extracted into unchanged C0 characterization, core_regressions and core_contracts; other losses/penalties/iterates/solvers/drivers deferred. |
| `coordinate_descent_basics.jl` | Scalar dense LS/PGD/cache/stopping portions extracted into unchanged C0 characterization, core_regressions and core_contracts; other losses/penalties/iterates/solvers/drivers deferred. |
| `diagonal_preconditioner.jl` | Deferred with its unsupported feature; exact original preserved on archive/legacy refs. Minimal green does not claim this feature works. |
| `duality_gap.jl` | Deferred with its unsupported feature; exact original preserved on archive/legacy refs. Minimal green does not claim this feature works. |
| `examples.jl` | Retained/adapted deliberately to the supported inventory; generic fail-closed, nightly and gate semantics retained. Two dense LS examples replace unsupported scripts. |
| `flat_coordinates.jl` | Scalar dense LS/PGD/cache/stopping portions extracted into unchanged C0 characterization, core_regressions and core_contracts; other losses/penalties/iterates/solvers/drivers deferred. |
| `float32_certificates.jl` | Deferred with its unsupported feature; exact original preserved on archive/legacy refs. Minimal green does not claim this feature works. |
| `float32_certificates_basics.jl` | Deferred with its unsupported feature; exact original preserved on archive/legacy refs. Minimal green does not claim this feature works. |
| `gap_stopping.jl` | Deferred with its unsupported feature; exact original preserved on archive/legacy refs. Minimal green does not claim this feature works. |
| `generic_newton.jl` | Deferred with its unsupported feature; exact original preserved on archive/legacy refs. Minimal green does not claim this feature works. |
| `glm.jl` | Deferred with its unsupported feature; exact original preserved on archive/legacy refs. Minimal green does not claim this feature works. |
| `group_curvature.jl` | Deferred with its unsupported feature; exact original preserved on archive/legacy refs. Minimal green does not claim this feature works. |
| `group_lasso.jl` | Deferred with its unsupported feature; exact original preserved on archive/legacy refs. Minimal green does not claim this feature works. |
| `group_momentum.jl` | Scalar dense LS/PGD/cache/stopping portions extracted into unchanged C0 characterization, core_regressions and core_contracts; other losses/penalties/iterates/solvers/drivers deferred. |
| `group_penalties.jl` | Deferred with its unsupported feature; exact original preserved on archive/legacy refs. Minimal green does not claim this feature works. |
| `image_models.jl` | Scalar dense LS/PGD/cache/stopping portions extracted into unchanged C0 characterization, core_regressions and core_contracts; other losses/penalties/iterates/solvers/drivers deferred. |
| `linesearch.jl` | Scalar dense LS/PGD/cache/stopping portions extracted into unchanged C0 characterization, core_regressions and core_contracts; other losses/penalties/iterates/solvers/drivers deferred. |
| `lla_paths.jl` | Deferred with its unsupported feature; exact original preserved on archive/legacy refs. Minimal green does not claim this feature works. |
| `low_rank.jl` | Deferred with its unsupported feature; exact original preserved on archive/legacy refs. Minimal green does not claim this feature works. |
| `minimal_core_characterization.jl` | Retained byte-for-byte from accepted Linux-only/C0 baseline. |
| `mixed_precision.jl` | Scalar dense LS/PGD/cache/stopping portions extracted into unchanged C0 characterization, core_regressions and core_contracts; other losses/penalties/iterates/solvers/drivers deferred. |
| `mixed_precision_extended.jl` | Deferred with its unsupported feature; exact original preserved on archive/legacy refs. Minimal green does not claim this feature works. |
| `multiresponse.jl` | Deferred with its unsupported feature; exact original preserved on archive/legacy refs. Minimal green does not claim this feature works. |
| `naming.jl` | Retained/adapted deliberately to the supported inventory; generic fail-closed, nightly and gate semantics retained. Two dense LS examples replace unsupported scripts. |
| `newton_nonconvex.jl` | Deferred with its unsupported feature; exact original preserved on archive/legacy refs. Minimal green does not claim this feature works. |
| `nonconvex.jl` | Deferred with its unsupported feature; exact original preserved on archive/legacy refs. Minimal green does not claim this feature works. |
| `nonconvex_blocks.jl` | Deferred with its unsupported feature; exact original preserved on archive/legacy refs. Minimal green does not claim this feature works. |
| `nonconvex_penalties.jl` | Deferred with its unsupported feature; exact original preserved on archive/legacy refs. Minimal green does not claim this feature works. |
| `oracles/Project.toml` | Deferred with its unsupported feature; exact original preserved on archive/legacy refs. Minimal green does not claim this feature works. |
| `oracles/README.md` | Deferred with its unsupported feature; exact original preserved on archive/legacy refs. Minimal green does not claim this feature works. |
| `oracles/primal_dual.jl` | Deferred with its unsupported feature; exact original preserved on archive/legacy refs. Minimal green does not claim this feature works. |
| `oracles/qp.jl` | Deferred with its unsupported feature; exact original preserved on archive/legacy refs. Minimal green does not claim this feature works. |
| `oracles/quic_hypatia.jl` | Deferred with its unsupported feature; exact original preserved on archive/legacy refs. Minimal green does not claim this feature works. |
| `oracles/sqrt_hypatia.jl` | Deferred with its unsupported feature; exact original preserved on archive/legacy refs. Minimal green does not claim this feature works. |
| `path_snapshots.jl` | Deferred with its unsupported feature; exact original preserved on archive/legacy refs. Minimal green does not claim this feature works. |
| `primal_dual.jl` | Deferred with its unsupported feature; exact original preserved on archive/legacy refs. Minimal green does not claim this feature works. |
| `product_space.jl` | Deferred with its unsupported feature; exact original preserved on archive/legacy refs. Minimal green does not claim this feature works. |
| `prox_solvers.jl` | Scalar dense LS/PGD/cache/stopping portions extracted into unchanged C0 characterization, core_regressions and core_contracts; other losses/penalties/iterates/solvers/drivers deferred. |
| `quic.jl` | Deferred with its unsupported feature; exact original preserved on archive/legacy refs. Minimal green does not claim this feature works. |
| `refit_cache.jl` | Deferred with its unsupported feature; exact original preserved on archive/legacy refs. Minimal green does not claim this feature works. |
| `runtests.jl` | Retained byte-for-byte from accepted Linux-only/C0 baseline. |
| `slope.jl` | Deferred with its unsupported feature; exact original preserved on archive/legacy refs. Minimal green does not claim this feature works. |
| `slope_hybrid.jl` | Deferred with its unsupported feature; exact original preserved on archive/legacy refs. Minimal green does not claim this feature works. |
| `sparse_group_paths.jl` | Deferred with its unsupported feature; exact original preserved on archive/legacy refs. Minimal green does not claim this feature works. |
| `sparse_x.jl` | Deferred with its unsupported feature; exact original preserved on archive/legacy refs. Minimal green does not claim this feature works. |
| `sqrt_certificates.jl` | Deferred with its unsupported feature; exact original preserved on archive/legacy refs. Minimal green does not claim this feature works. |
| `structured_quadratics.jl` | Deferred with its unsupported feature; exact original preserved on archive/legacy refs. Minimal green does not claim this feature works. |
| `symmetric_penalties.jl` | Deferred with its unsupported feature; exact original preserved on archive/legacy refs. Minimal green does not claim this feature works. |
| `symmetric_penalties_basics.jl` | Deferred with its unsupported feature; exact original preserved on archive/legacy refs. Minimal green does not claim this feature works. |
| `symmetric_penalty_combinations.jl` | Deferred with its unsupported feature; exact original preserved on archive/legacy refs. Minimal green does not claim this feature works. |
| `symmetric_penalty_helpers.jl` | Deferred with its unsupported feature; exact original preserved on archive/legacy refs. Minimal green does not claim this feature works. |
| `tier_selection.jl` | Retained/adapted deliberately to the supported inventory; generic fail-closed, nightly and gate semantics retained. Two dense LS examples replace unsupported scripts. |
| `tiers.jl` | Retained byte-for-byte from accepted Linux-only/C0 baseline. |
| `tiers.toml` | Retained/adapted deliberately to the supported inventory; generic fail-closed, nightly and gate semantics retained. Two dense LS examples replace unsupported scripts. |
| `workspaces.jl` | Deferred with its unsupported feature; exact original preserved on archive/legacy refs. Minimal green does not claim this feature works. |

Specific applicable ports: coordinate_descent_basics:158 exact power-of-two
units/pass counts; coordinate_descent:474 cold coordinate_scale cache filling;
prox_solvers:114 FASTA-isolated LS stopping plus independent KKT;
linesearch:36 every-step image/gradient freshness through natural switch;
coordinate_descent_basics:54 p>n validation (small planted optimum with direct
KKT/objective); call_limits:128 first crossing/exact count history; mixed_precision:19
Float32 result residual fields stay Float64. These live in core_regressions.
