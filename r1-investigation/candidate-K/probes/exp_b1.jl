# B (step level): where MASTER's step stays on the fast path (classes :fast and :lam), the candidate's step is bitwise equal
# (new coordinate value, updated residual cache, cached curvature), over random states. args: N seed
include("r1lib.jl")
const N = parse(Int, get(ARGS, 1, "20000")); const SEED = parse(Int, get(ARGS, 2, "1"))
function model2(P, X::Matrix{T}, y::Vector{T}, λ::T, x0::Vector{T}) where T
  x = SparseIterate(copy(x0)); m = P.cdmodel(SqrtLeastSquaresLoss(y, X), x); P.initialize!(m, x); g = NormL1(λ); P._prepare!(m, g, x); m, g, x
end
function main()
  println("# julia ", VERSION, " N=", N, " seed=", SEED)
  for T in (Float32, Float64)
    rng = Xoshiro(hash((SEED, T)))
    cnt = Dict{Symbol,Int}(); bad = Dict{Symbol,Int}(); nbad = 0; ncold_eq = 0; ncold = 0
    for trial in 1:N
      n = rand(rng, (1, 2, 3, 5, 12, 30, 100)); p = rand(rng, 1:4)
      sx = rand(rng) < 0.7 ? 0 : rand(rng, -30:30)
      X = T.(ldexp.(randn(rng, n, p), sx)); mode = rand(rng, 1:4)
      y = mode == 1 ? T.(randn(rng, n)) : mode == 2 ? T.(X * randn(rng, p) .+ 1e-6 .* randn(rng, n)) : mode == 3 ? T.(X * randn(rng, p)) : T.(ldexp.(randn(rng, n), rand(rng, -30:30)))
      x0 = rand(rng) < 0.5 ? zeros(T, p) : T.(randn(rng, p))
      lm = maximum(sqrt.(sum(abs2, Float64.(X); dims = 1)))
      λ = T(lm * (rand(rng) < 0.2 ? 1 - 2.0^(-rand(rng, 1:30)) : rand(rng) < 0.1 ? 1.0 + 2.0^(-rand(rng, 1:30)) : rand()^2))
      (isfinite(λ) && λ > 0) || continue
      mb, gb, xb = model2(TREES.base, X, y, λ, x0); mc, gc, xc = model2(TREES.cand, X, y, λ, x0)
      for rep in 1:3, k in 1:p
        cls = classify(Vector(view(X, :, k)), copy(mb.ls.r), λ, xb[k])
        hb = try TREES.base.coordinate_step!(mb, gb, xb, k) catch e; sprint(showerror, e) end
        hc = try TREES.cand.coordinate_step!(mc, gc, xc, k) catch e; sprint(showerror, e) end
        cnt[cls] = get(cnt, cls, 0) + 1
        same = (hb === hc) && mb.ls.r == mc.ls.r && all(x -> x[1] === x[2], zip(mb.ls.a, mc.ls.a) |> collect |> x -> [(a, b) for (a, b) in x] |> y -> y) && Vector(xb) == Vector(xc)
        if cls in (:fast, :lam)
          same || (bad[cls] = get(bad, cls, 0) + 1; nbad += 1)
        else
          ncold += 1; same && (ncold_eq += 1)
        end
        # keep the two states aligned for the next visit only if they agree; else stop this trial
        same || break
      end
    end
    println(T, ": steps by master class ", sort(collect(cnt)), "; fast/lam steps NOT bitwise equal: ", nbad, " ", sort(collect(bad)), "; non-fast steps: ", ncold, " of which bitwise equal ", ncold_eq)
  end
end
main()
