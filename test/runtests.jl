using Test


tests = [
  "naming",
  "workspaces",
  "prox_solvers",
  "nonconvex",
  "nonconvex_blocks",
  "linesearch",
  "image_models",
  "apg_numerical_failure",
  "call_limits",
  "admm",
  "primal_dual",
  "product_space",
  "active_set",
  "slope",
  "group_lasso",
  "multiresponse",
  "low_rank",
  "coordinate_descent",
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
