include("lib.jl"); include("optB.jl")
using Logging
# E10: option A (current) vs option B1 (overlay) over (x scale, y scale) grids and over ordinary families.
# For every cell: public solve! outcome under A, then under B1; list cells where A succeeds and B1 refuses, and verify
# that on every cell where B1 succeeds the result is bitwise identical to A.
function outcome(T, X, y, λ; order = :cyclic)
  xs = zeros(T, size(X, 2))
  try
    r = Base.invokelatest(() -> with_logger(NullLogger()) do
      solve!(xs, SqrtLeastSquaresLoss(y, X), NormL1(λ), CDSolver(; order, rng = Xoshiro(5)))
    end)
    (ok = true, x = copy(xs), conv = r.converged, passes = r.passes, gap = r.gap, msg = "")
  catch e
    (ok = false, x = xs, conv = false, passes = 0, gap = NaN, msg = first(split(sprint(showerror, e), '\n'))[1:min(end, 70)])
  end
end
function cells(T)
  out = Dict{Tuple{Int,Int},Any}()
  grid = T === Float32 ? (-150:5:75) : (-1070:30:1020)
  for sx in grid, sy in grid
    rng = Xoshiro(11); n, p = 30, 8
    X0 = randn(rng, n, p); y0 = randn(rng, n)
    X = T.(ldexp.(X0, sx)); y = T.(ldexp.(y0, sy))
    (all(isfinite, X) && all(isfinite, y) && any(!iszero, X) && any(!iszero, y)) || continue
    λ64 = 0.3*lam_max(X, y); λ = try T(λ64) catch; continue end
    (isfinite(λ) && λ > 0) || continue
    out[(sx, sy)] = outcome(T, X, y, λ)
  end
  out
end
resA = Dict(T => cells(T) for T in (Float32, Float64))
# ordinary families under A
function families(T)
  res = Any[]
  for (n, p) in ((20, 10), (100, 60), (400, 40), (30, 120)), lf in (0.5, 0.1, 0.02), order in (:cyclic, :random)
    rng = Xoshiro(hash((n, p, lf))); X = randn(rng, T, n, p); y = randn(rng, T, n); λ = T(lf*lam_max(X, y))
    push!(res, ((n, p, lf, order), outcome(T, X, y, λ; order)))
  end
  # near-exact-fit (noiseless) and exactly parallel / dyadic
  for σ in (0.0, 1e-9), (n, p) in ((30, 100), (50, 20))
    rng = Xoshiro(7); X = T.(randn(rng, n, p)); β0 = zeros(p); β0[1:3] .= (3.0, -2.0, 1.0)
    y = T.(X*β0 .+ σ .* randn(rng, n)); λ = T(0.2*lam_max(X, y))
    push!(res, (("exactfit", σ, n, p), outcome(T, X, y, λ)))
  end
  # y = 0, one column, p = 1 exactly parallel, dyadic integers
  push!(res, (("y=0",), outcome(T, T[1 2; 3 4; 5 6], zeros(T, 3), T(0.5))))
  push!(res, (("p=1 parallel",), outcome(T, reshape(T[1, 2, -1, 0.5], 4, 1), T[3, 6, -3, 1.5], T(0.5))))
  res
end
famA = Dict(T => families(T) for T in (Float32, Float64))
install_B1!()
resB = Dict(T => cells(T) for T in (Float32, Float64))
famB = Dict(T => families(T) for T in (Float32, Float64))
println("# E10 A vs B1")
for T in (Float32, Float64)
  lost = Tuple{Int,Int}[]; both = 0; differ = 0; refB = 0
  for (k, a) in resA[T]
    b = resB[T][k]
    if a.ok && !b.ok; push!(lost, k)
    elseif a.ok && b.ok
      both += 1
      (a.x == b.x && a.passes == b.passes && isequal(a.gap, b.gap)) || (differ += 1)
    end
  end
  nA = count(v -> v.ok, values(resA[T]))
  println(T, ": grid cells=", length(resA[T]), "; A succeeds=", nA, "; B1 refuses where A succeeds=", length(lost), "; both succeed=", both, ", of which differ=", differ)
  # ordinary families
  nd = 0
  for ((ka, a), (kb, b)) in zip(famA[T], famB[T])
    same = a.ok == b.ok && a.x == b.x && a.passes == b.passes && isequal(a.gap, b.gap)
    same || (nd += 1; println("   family ", ka, ": A ok=", a.ok, " conv=", a.conv, " ", a.msg, " | B ok=", b.ok, " conv=", b.conv, " ", b.msg))
  end
  println(T, ": ordinary families (", length(famA[T]), ") with a different outcome under B1: ", nd)
end
