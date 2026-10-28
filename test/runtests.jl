using Test


tests = [
  "audit_regressions",
  "naming",
  "workspaces",
  "prox_solvers",
  "nonconvex",
  "nonconvex_blocks",
  "linesearch",
  "diagonal_preconditioner",
  "image_models",
  "apg_numerical_failure",
  "call_limits",
  "admm",
  "primal_dual",
  "product_space",
  "active_set",
  "slope",
  "slope_hybrid",
  "group_lasso",
  "multiresponse",
  "low_rank",
  "coordinate_descent",
  "symmetric_penalties",
  "symmetric_penalty_combinations",
  "structured_quadratics",
  "path_snapshots",
  "sparse_x",
  "group_penalties",
  "sparse_group_paths",
  "box_paths",
  "refit_cache",
  "nonconvex_penalties",
  "lla_paths",
  "glm",
  "newton_nonconvex",
  "duality_gap",
  "gap_stopping",
  "float32_certificates",
  "convolution_gap",
  "quic",
  "generic_newton",
  "examples",
  "aqua",
]

for t in tests
	f = "$t.jl"
	println("* running $f ...")
    t = @elapsed include(f)
    println("done (took $t seconds).")
end
