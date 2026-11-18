# Numerical verification of the mathematical claims of the report (agent B).
include(joinpath(@__DIR__, "escape.jl"))
using JuMP, Clarabel
combinations(v, k) = [v[[i for i in 1:length(v) if (m >> (i-1)) & 1 == 1]] for m in 0:(1 << length(v)) - 1 if count_ones(m) == k]
println("== 1. #155: directional derivative, descent direction, exact line minimizer")
X = [1.0 1.0; 0.0 0.01]; β = [1.0, -1.0]; y = X * β; λ = 0.1; s = sign.(β)
F(b) = norm(y - X * b) + λ * norm(b, 1)
Fp(d) = norm(X * d) + λ * dot(s, d)           # support = {1,2}
println("F(β)=$(F(β)) F(0)=$(F(zeros(2))) ‖y‖=$(norm(y))")
for d in ([1.0, 0.0], [-1.0, 0.0], [0.0, 1.0], [0.0, -1.0], [-1.0, 1.0], [1.0, -1.0], -β)
  t = 1e-6; fd = (F(β + t * d) - F(β)) / t
  println("  d=$d: F'(β;d)=$(Fp(d))  finite-diff=$(round(fd, digits = 6))")
end
# nullspace: X invertible
println("  det X = $(det(X)), cond X = $(cond(X)); null(X) = trivial -> exact fit set {β}")
# line along d = -β: φ(t) = t‖y‖ + λ(1-t)‖β‖₁ for 0 ≤ t ≤ 1
φ(t) = F(β - t * β)
println("  φ(0)=$(φ(0.0)) φ(0.5)=$(φ(0.5)) φ(1)=$(φ(1.0)) φ(1.5)=$(φ(1.5)); line_min = ", line_min(zeros(2), Float64.(X * (-β)), β, -β, λ))
# the directional lasso minimizer and θ_min (closed form: S = {1,2} so X_S'θ = λ s)
θ = (X') \ (λ * s); println("  θ_min = $θ, ‖θ‖ = $(norm(θ)) (> 1: not optimal); ψ* = $(-0.5 * norm(θ)^2)")
d, u, ρ, ps, st = dirlasso(X, β, λ; maxpasses = 100000, target = Inf, rtol = 1e-14)
println("  dirlasso: ρ=$ρ (= ‖θ_min‖ = $(norm(θ))) status=$st passes=$ps  Xd = $u (= θ_min? $(norm(u - θ) < 1e-6 || norm(u + θ) < 1e-6))")

println("\n== 2. AI3 generalization: X = I_n, y = 1, λ ∈ (1/√n, 1/√(n-1)), start β = y")
for n in 2:7
  λ = (1 / sqrt(n) + 1 / sqrt(n - 1)) / 2 * (n == 1 ? 0 : 1)
  Xn = Matrix(1.0I, n, n); yn = ones(n); βn = ones(n)
  best = Dict{Int, Float64}()
  for k in 1:n
    bk = 0.0
    for T in combinations(1:n, k)
      Xt = Xn[:, T]; G = Xt' * Xt
      w = G \ ones(k)                         # block ψ_T minimizer: d_T = -λ G^{-1} s_T, ρ_T = λ sqrt(sᵀ G⁻¹ s)
      bk = max(bk, λ * sqrt(sum(w)))
    end
    best[k] = bk
  end
  need = minimum(k for k in 1:n if best[k] > 1; init = n + 1)
  println("  n=$n λ=$(round(λ, digits = 4)) (1/√n=$(round(1 / sqrt(n), digits = 4)), 1/√(n-1)=$(round(1 / sqrt(n - 1), digits = 4))): best ρ over blocks of size k = ", [round(best[k], digits = 3) for k in 1:n], "  smallest descending block size = $need  (formula ⌊1/λ²⌋+1 = $(floor(Int, 1 / λ^2) + 1))")
end
println("  large n: λ just above 1/√n needs all n; e.g. n=1000 -> needed block size = ", floor(Int, 1 / (1 / sqrt(1000) * 1.0001)^2) + 1)

println("\n== 3. duality: ψ* = -½ min{‖θ‖²: X_Sᵀθ = λ s, |X_{S^c}ᵀθ| ≤ λ}; exact fit optimal ⇔ ‖θ_min‖ ≤ 1")
function theta_min(X, S, s, λ)
  n, p = size(X); m = Model(Clarabel.Optimizer); set_silent(m)
  @variable(m, θ[1:n]); Sc = setdiff(1:p, S)
  @constraint(m, X[:, S]' * θ .== λ * s[S])
  @constraint(m, X[:, Sc]' * θ .<= λ); @constraint(m, X[:, Sc]' * θ .>= -λ)
  @objective(m, Min, sum(abs2, θ)); optimize!(m)
  termination_status(m) == MOI.OPTIMAL ? value.(θ) : nothing
end
function sqrtlasso_opt(X, y, λ)
  n, p = size(X); m = Model(Clarabel.Optimizer); set_silent(m)
  set_attribute(m, "tol_gap_abs", 1e-12); set_attribute(m, "tol_gap_rel", 1e-12); set_attribute(m, "tol_feas", 1e-12)
  @variable(m, b[1:p]); @variable(m, uu[1:p] >= 0); @variable(m, t)
  @constraint(m, uu .>= b); @constraint(m, uu .>= -b); @constraint(m, [t; y .- X * b] in SecondOrderCone())
  @objective(m, Min, t + λ * sum(uu)); optimize!(m); objective_value(m)
end
nopt = 0; rng = Xoshiro(1); agree = 0; tot = 0; maxdiff = 0.0; mism = 0
for trial in 1:60
  n, p = rand(rng, 3:8), rand(rng, 6:14)
  Xr = randn(rng, n, p); br = zeros(p); sup = randperm(rng, p)[1:rand(rng, 1:n)]; br[sup] .= randn(rng, length(sup)); yr = Xr * br
  λr = rand(rng) * 0.6 + 0.02
  # a feasible exact-fit point: the support `sup` (rank = |sup| ≤ n) — optimal or not depending on λ
  sgn = sign.(br)
  θm = theta_min(Xr, sup, sgn, λr)
  Pb = norm(yr - Xr * br) + λr * norm(br, 1)
  Pstar = sqrtlasso_opt(Xr, yr, λr)
  optimal_true = Pb <= Pstar * (1 + 1e-7)
  d, u, ρ, ps, st = dirlasso(Xr, br, λr; maxpasses = 200000, target = Inf, rtol = 1e-14)
  ρθ = θm === nothing ? Inf : norm(θm)
  global tot += 1; global nopt += optimal_true
  pred = ρθ <= 1 + 1e-6
  global agree += (pred == optimal_true)
  (pred != optimal_true) && (global mism += 1)
  isfinite(ρθ) && (global maxdiff = max(maxdiff, abs(ρ - ρθ) / ρθ))
end
println("  $tot random exact-fit points ($nopt optimal, $(tot-nopt) not): (‖θ_min‖ ≤ 1) == (point optimal by SOCP) in $agree/$tot; max rel diff between CD-ψ ρ and ‖θ_min‖ (QP): $maxdiff")
