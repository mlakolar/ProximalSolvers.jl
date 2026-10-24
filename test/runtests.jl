using Test


tests = [
  "prox_solvers",
  "nonconvex",
  "nonconvex_blocks",
  "linesearch",
  "image_models",
  "call_limits",
  "admm",
  "product_space",
  "active_set",
  "group_lasso",
  "multiresponse",
  "low_rank",
  "coordinate_descent",
  "sparse_x",
  "group_penalties",
  "sparse_group_paths",
  "box_paths",
  "refit_cache",
  "nonconvex_penalties",
  "glm",
  "newton_nonconvex",
  "duality_gap",
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
