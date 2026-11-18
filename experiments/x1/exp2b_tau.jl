# X1 experiment 2b: does X1B's τ = (λ/ra)(√d² / (√(ra−λ)√(ra+λ))) overflow when a and ρ² are clean?
# (1) direct formula search at the corner d ≈ √floatmax, ra ≈ √(n floatmin/eps), λ = prevfloat^k(ra), exact cases
# (2) the same inputs through the real X1B/X1A/BASE step against the BigFloat reference.
include("x1lib.jl")
thr(T, n) = n * (floatmin(T)/eps(T))
clean(s::T, n) where T = isfinite(s) & (s >= thr(T, n))
function tau_formula(::Type{T}, a, ρ2, d2, λ) where T
  ra = sqrt(a); ra - λ > 0 || return T(NaN)
  (λ/ra)*(sqrt(d2)/(sqrt(ra - λ)*sqrt(ra + λ)))
end
for T in (Float32, Float64)
  rng = Xoshiro(7); worst = 0.0; worstinfo = nothing; ninf = 0; N = 0
  fmax = floatmax(T)
  for n in (1, 2, 3, 5, 30, 2000), trial in 1:20000
    # a within [thr, thr(1+10^-j)] (clean), ρ² near floatmax; d² between ρ²/16 and ρ² (and d² = ρ² most often: b = 0)
    a = T(thr(T, n)) * (1 + T(10.0)^(-rand(rng, 1:6))*rand(rng, T))
    clean(a, n) || (a = nextfloat(T(thr(T, n)));)
    clean(a, n) || continue
    ρ2 = fmax * (rand(rng) < 0.5 ? one(T) : T(1 - 0.5*rand(rng)))
    d2 = rand(rng) < 0.5 ? ρ2 : ρ2 * T(1/16 + (15/16)*rand(rng))
    ra = sqrt(a); k = rand(rng, 1:6)
    λ = foldl((v, _) -> prevfloat(v), 1:k; init = ra)
    λ > 0 || continue
    N += 1
    τ = tau_formula(T, a, ρ2, d2, λ)
    isfinite(τ) || (ninf += 1)
    # exact τ-ish relative to floatmax
    τb = setprecision(BigFloat, 256) do
      (big(λ)/big(ra))*(sqrt(big(d2))/(sqrt(big(ra) - big(λ))*sqrt(big(ra) + big(λ)))) end
    rel = Float64(τb/big(fmax)); rel > worst && (worst = rel; worstinfo = (n, a, ρ2, d2, λ, τ))
  end
  println(T, ": formula search ", N, " cases, non-finite τ: ", ninf, ", largest τ/floatmax (BigFloat exact on the same inputs) = ", worst, "  at n,a,ρ²,d²,λ,τ = ", worstinfo)
  # analytic worst case: n = 2, ra at the binade bottom, λ = prevfloat(ra), d = √floatmax
  for n in (2,)
    a = T(thr(T, n)); a = nextfloat(a, 0); while !clean(a, n); a = nextfloat(a); end
    # smallest clean a of the form x1^2: x1 = sqrt(a)
    x1 = sqrt(a); a1 = x1*x1; while !clean(a1, n); x1 = nextfloat(x1); a1 = x1*x1; end
    ra = sqrt(a1); λ = prevfloat(ra); δ = prevfloat(sqrt(fmax)); ρ2 = δ*δ
    println("   analytic corner n=2: a=", a1, " ρ²=", ρ2, " finite=", isfinite(ρ2), " τ=", tau_formula(T, a1, ρ2, ρ2, λ), " (floatmax=", fmax, ")")
    # also with ra at binade bottom exactly: x1 = power of two
    for xe in (1:2)  # scan x1 = 2^e just above the clean threshold
    end
    xk = T[x1, 0]; y = T[0, δ]
    for tr in TNAMES
      z, err, r, lam = step_in(getproperty(TREES, tr), xk, y, λ, zero(T))
      println("   step ", tr, ": z=", z, " err=", err === nothing ? "none" : first(sprint(showerror, err), 80))
    end
    # sweep λ = prevfloat^k(ra) for the true worst case x1 power of two near the threshold
    for e in (T === Float32 ? (-52:-48) : (-484:-480))
      x1 = T(2)^e; a1 = x1*x1
      clean(a1, n) || continue
      ra = sqrt(a1)
      for k in 1:3
        λ = foldl((v, _) -> prevfloat(v), 1:k; init = ra)
        println("   x1=2^", e, " k=", k, " τ formula=", tau_formula(T, a1, ρ2, ρ2, λ), "  τ/floatmax=", Float64(tau_formula(T, a1, ρ2, ρ2, λ)/fmax))
      end
    end
  end
end
