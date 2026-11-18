# Exact activation boundaries of the exceptional branches, by driving real private functions (instrumented copy)
# on one-column / one-vector problems at exponent e.
include(joinpath(@__DIR__, "instr_load.jl"))
function runs(e::Int, T, S)
  # a = ‖X_1‖² = 2^e exactly (n=1, x = 2^(e/2) when e even)
  x1 = ldexp(T(1), e ÷ 2)
  X = reshape([x1], 1, 1); y = [x1]
  α = S === Nothing ? nothing : ldexp(S(1), 0)
  m = PS.LSModel(y, X, α === nothing ? one(T) : α)
  g = NormL1(T(0.5))
  xs = SparseIterate(T, 1)
  PS.initialize!(m, xs)
  cnt_reset!()
  r = try PS.coordinate_step!(m, g, xs, 1); :ok catch ex; ex isa ArgumentError ? :refused : :err end
  c = cnt_snapshot()
  (r, get(c, :outside_band, 0) > 0)
end
function scan(T, S; range)
  prev = nothing; out = String[]
  for e in range
    e % 2 == 0 || continue
    st = runs(e, T, S)
    key = (st[1], st[2])
    if key != prev; push!(out, "a=2^$e -> $(key[1]) band_exit=$(key[2])"); prev = key; end
  end
  out
end
for (T, S, rng, nm) in ((Float32, Float32, -300:300, "F32, S=F32, alpha=1"), (Float64, Float64, -2200:2200, "F64, S=F64, alpha=1"))
  println("== band of the lasso step ($nm): transitions of (outcome, took _outside_band) as the curvature a = 2^e grows")
  foreach(println, scan(T, S; range=rng))
end
# same with a loss scale alpha = 2^l on a = 1 (column of ones): p = alpha*a
function runs_alpha(l::Int, T, S)
  X = reshape([T(1)], 1, 1); y = [T(1)]
  m = PS.LSModel(y, X, ldexp(S(1), l)); g = NormL1(T(0.25)); xs = SparseIterate(T, 1); PS.initialize!(m, xs); cnt_reset!()
  r = try PS.coordinate_step!(m, g, xs, 1); :ok catch ex; ex isa ArgumentError ? :refused : :err end
  (r, get(cnt_snapshot(), :outside_band, 0) > 0)
end
for (T, S, rng, nm) in ((Float32, Float32, -200:200, "F32 data, F32 alpha"), (Float32, Float64, -1200:1200, "F32 data, F64 alpha"), (Float64, Float64, -1200:1200, "F64"))
  prev = nothing; println("== lasso step band vs loss scale alpha=2^l, a=1 ($nm)")
  for l in rng
    st = runs_alpha(l, T, S); if st != prev; println("alpha=2^$l -> $(st[1]) band_exit=$(st[2])"); prev = st; end
  end
end
# response_scale branches over sum of squares and alpha
function rs_branch(T, S, ey::Int, l::Int, n::Int=4)
  y = fill(ldexp(T(1), ey), n); X = reshape(ones(T, n), n, 1)
  m = PS.LSModel(y, X, ldexp(S(1), l)); cnt_reset!()
  v = try PS.response_scale(m, nothing) catch ex; ex isa ArgumentError ? :refused : :err end
  c = cnt_snapshot()
  b = get(c, :rs_t1, 0) > 0 ? "t1" : get(c, :rs_t2, 0) > 0 ? "t2" : get(c, :rs_exc, 0) > 0 ? "exc" : "?"
  (b, v isa Symbol ? v : :ok)
end
for (T, S, nm, eys, ls) in ((Float32, Float32, "F32/F32", -80:1:70, -130:1:130), (Float32, Float64, "F32 data/F64 alpha", -80:1:70, -300:2:300), (Float64, Float64, "F64/F64", -600:2:540, -1100:2:1100))
  println("== response_scale branch (y = 2^ey on 4 entries, alpha = 2^l) $nm: area map (rows ey step, cols l step) summarized by transitions along l at ey=0 and ey=-40/40")
  for ey in (0, T === Float32 ? -40 : -400, T === Float32 ? 40 : 400)
    prev = nothing
    for l in ls
      st = rs_branch(T, S, ey, l); if st != prev; println("  ey=$ey: l=$l -> $st"); prev = st; end
    end
  end
end
