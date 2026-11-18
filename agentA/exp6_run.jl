include("exp6_cert.jl")
using Random
tally = Dict{String,Vector{Int}}()   # family => [cases, certified, failed, undefined, violations]
viol_all = String[]
tights = Float64[]
function rec(fam, r)
  v = get!(tally, fam, zeros(Int, 5))
  v[1] += 1
  v[2] += r.code === :certified; v[3] += r.code === :failed; v[4] += r.code === :undefined
  if !isempty(r.viols)
    v[5] += 1; push!(viol_all, fam * ": " * r.tag * " :: " * join(r.viols, "; "))
  end
  isfinite(r.tight) && push!(tights, r.tight)
end
function solved(X, y, λ; kw...)
  T = eltype(X)
  x = zeros(T, size(X, 2))
  Base.CoreLogging.with_logger(Base.CoreLogging.NullLogger()) do
    solve!(x, SqrtLeastSquaresLoss(y, X), NormL1(λ), CDSolver(; order = :cyclic, kw...))
  end
  x
end
perturb(β, δ, rng) = β .+ δ .* maximum(abs, β; init = 0.0) .* randn(rng, length(β)) .* (rand(rng, length(β)) .< 0.5)
rng = Xoshiro(99)
for T in (Float64, Float32)
  # 1: ordinary Gaussian, solved + perturbed
  for trial in 1:60
    n = rand(rng, (8, 20, 60)); p = rand(rng, (3, 10, 40)); lf = rand(rng, (0.05, 0.2, 0.6))
    X = randn(rng, T, n, p); y = randn(rng, T, n)
    λ = T(lf*lam_max(X, y))
    β = solved(X, y, λ; tol = 1e-10)
    for δ in (0.0, 1e-9, 1e-6, 1e-3, 1e-1)
      b = T.(perturb(Float64.(β), δ, rng))
      rec("$T gaussian solved+perturbed", one_case(X, y, b, λ; tag = "n=$n p=$p lf=$lf δ=$δ"))
    end
  end
  # 2: near λmax and β=0
  for trial in 1:30
    n, p = 12, 8
    X = randn(rng, T, n, p); y = randn(rng, T, n)
    lm = lam_max(X, y)
    for f in (1 - 1e-12, 1 - 1e-6, 1.0, 1 + 1e-12, 1.5)
      λ = f*lm
      rec("$T near lambda_max, beta=0", one_case(X, y, zeros(T, p), T === Float32 ? Float64(λ) : λ; tag = "f=$f"))
    end
  end
  # 3: fitted values dwarf residual: y = Xβ0 + noise, β0 large
  for s in (0, 10, 20, 30, 40, 50), trial in 1:10
    n, p = 30, 6
    X = T.(randn(rng, n, p)); β0 = zeros(p); β0[1] = 2.0^s; β0[2] = 1
    y = T.(X*β0 .+ randn(rng, n))
    (all(isfinite, y)) || continue
    λ = T(0.1*lam_max(X, y))
    β = solved(X, y, λ; tol = 1e-12, maxpasses = 400)
    for δ in (0.0, 1e-8, 1e-4)
      rec("$T fit dwarfs residual (2^s)", one_case(X, y, T.(perturb(Float64.(β), δ, rng)), λ; tag = "s=$s δ=$δ"))
    end
  end
  # 4: power-of-two rescaling extremes: (y, X, λ)*2^s
  scales = T === Float64 ? (-1060, -1000, -600, -300, -60, 60, 300, 500, 700) : (-140, -100, -60, -30, 30, 60, 100)
  for s in scales, trial in 1:6
    n, p = 10, 5
    X0 = randn(rng, n, p); y0 = randn(rng, n); b0 = zeros(p); b0[1:2] .= (0.7, -0.3)
    X = T.(ldexp.(X0, s)); y = T.(ldexp.(y0, s)); λ = T(ldexp(0.05, s))
    (all(isfinite, X) && all(isfinite, y) && isfinite(λ) && λ > 0) || continue
    β = T.(b0)
    for δ in (0.0, 1e-3)
      rec("$T joint scaling 2^s", one_case(X, y, T.(perturb(Float64.(β), δ, rng)), λ; tag = "s=$s δ=$δ"))
    end
  end
  # 5: y scale and X scale independently (beta scales as y/X; keep lambda = 0.05 sqrt(a) scale via X)
  for sy in (T === Float64 ? (-900, -500, 0, 500, 900) : (-100, -50, 0, 50, 100)), sx in (T === Float64 ? (-400, 0, 400) : (-50, 0, 50)), trial in 1:4
    n, p = 10, 5
    X0 = randn(rng, n, p); y0 = randn(rng, n)
    X = T.(ldexp.(X0, sx)); y = T.(ldexp.(y0, sy)); λ = T(ldexp(0.05*3, sx))
    (all(isfinite, X) && all(isfinite, y) && isfinite(λ) && λ > 0) || continue
    β = try solved(X, y, λ; tol = 1e-9, maxpasses = 200) catch; continue end
    for δ in (0.0, 1e-4)
      rec("$T independent y/X scaling", one_case(X, y, T.(perturb(Float64.(β), δ, rng)), λ; tag = "sy=$sy sx=$sx δ=$δ"))
    end
  end
  # 6: subnormal / tiny coefficients and columns
  for trial in 1:40
    n, p = 10, 6
    X = randn(rng, T, n, p); y = randn(rng, T, n); λ = T(0.2*lam_max(X, y))
    β = solved(X, y, λ; tol = 1e-10)
    for k in 1:p
      b = copy(β); b[k] = nextfloat(zero(T)) * (rand(rng) < 0.5 ? 1 : -1)
      rec("$T subnormal coefficient", one_case(X, y, b, λ; tag = "k=$k"))
    end
    # tiny column
    X2 = copy(X); X2[:, 1] .*= T(2)^(T === Float64 ? -520 : -70)
    rec("$T tiny column", one_case(X2, y, β, λ; tag = ""))
  end
  # 7: levels of other types
  for λ0 in (T(0.25), 1 // 3, big"0.1", π, Base.MathConstants.golden, Float16(0.1), 7, T(0.1))
    for trial in 1:15
      n, p = 15, 6
      X = randn(rng, T, n, p); y = randn(rng, T, n)
      λf = λ0 isa Real ? λ0 : λ0
      β = try solved(X, y, λf; tol = 1e-9) catch; zeros(T, p) end
      for δ in (0.0, 1e-5)
        rec("$T level of type $(typeof(λ0))", one_case(X, y, T.(perturb(Float64.(β), δ, rng)), λf; tag = "λ0=$λ0"))
      end
    end
  end
  # 8: large n and many nonzeros
  for (n, p, m) in ((5000, 600, 300), (20000, 30, 30), (200, 2000, 1000))
    X = randn(rng, T, n, p); y = randn(rng, T, n)
    β = zeros(T, p); idx = randperm(rng, p)[1:m]; β[idx] .= randn(rng, T, m)
    λ = T(0.05*lam_max(X, y))
    for δ in (0.0, 1e-3)
      rec("$T large n or many nonzeros", one_case(X, y, T.(perturb(Float64.(β), δ, rng)), λ; tag = "n=$n p=$p m=$m δ=$δ"))
    end
    bs = solved(X, y, λ; tol = 1e-8, maxpasses = 300)
    rec("$T large n or many nonzeros (solved)", one_case(X, y, bs, λ; tag = "n=$n p=$p solved"))
  end
  # 9: exact-fit / rounded-to-zero examples from the PR review (Float64 data only)
  if T === Float64
    rec("exact fit with computed rhat != 0", one_case(ones(1, 3), [8 + 2.0^-49], [3*2.0^-52, 8.0, 5*2.0^-52], 0.5; tag = "review r1 #3"))
    rec("rounded-to-zero rhat", one_case(ones(1, 3), [1 + 2.0^-20], [2.0^53, 1.0, -2.0^53], 0.5; tag = "review r1 #3b"))
    for trial in 1:100
      n, p = 6, 4
      X = round.(randn(rng, n, p) .* 8) ./ 4; β = round.(randn(rng, p) .* 4) ./ 4
      y = X*β .+ ldexp.(randn(rng, n), rand(rng, -60:-20))     # near-exact fit, residual 2^-20..2^-60
      rec("Float64 near exact fits (beta fixed)", one_case(X, y, β, rand(rng, (0.01, 0.1, 0.5)); tag = ""))
    end
  end
  # 10: search for the certification boundary: scale the perturbation of the optimum finely and verify each point
  for trial in 1:20
    n, p = 20, 8
    X = randn(rng, T, n, p); y = randn(rng, T, n); λ = T(0.15*lam_max(X, y))
    β = solved(X, y, λ; tol = 1e-12, maxpasses = 400)
    w = randn(rng, p)
    for e in range(-9, -1; length = 40)
      b = T.(Float64.(β) .+ 10.0^e .* w .* maximum(abs, β))
      rec("$T boundary scan (perturbation 1e-9..1e-1)", one_case(X, y, b, λ; tag = "e=$e"))
    end
  end
end
println("# E6 certificate verification in BigFloat (512 bits). columns: cases certified failed undefined violations")
for (k, v) in sort(collect(tally); by = first)
  @printf("%-52s %6d %6d %6d %6d %4d\n", k, v...)
end
println("total cases: ", sum(v[1] for v in values(tally)), "  violations: ", sum(v[5] for v in values(tally)))
println("tightness ratio(returned ratio / true θ-ratio) over certified points: n=", length(tights), " median=", sort(tights)[div(end,2)], " max=", maximum(tights), " min=", minimum(tights))
foreach(println, first(viol_all, 20))
