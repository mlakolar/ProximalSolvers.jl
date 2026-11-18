include("lib.jl"); include("certprobe.jl")
# E6: verify the mathematical inequalities of _certify! in BigFloat (512 bits) on random and adversarial points.
# For each certified/failed result with defined internals (gap, Dlo, t) and r̂ (= m.res64 after the call):
#   θ = t r̂/‖r̂‖ (exact BigFloat vector); check feasibility ‖θ‖ ≤ 1 and ‖Xᵀθ‖∞ ≤ λ0 (λ0 = true level, BigFloat/Rational),
#   then   gap ≥ P(β) − θᵀy ,  Dlo ≤ θᵀy ,  ratio ≥ (P−θᵀy)/θᵀy ≥ (P − P*)/P*  (the last since θᵀy ≤ P*).
# Also checks that the probe returns the same (code, ratio) as the production _certify!.
function exact_check(X, y, β, λ0, m, res)
  setprecision(BigFloat, 512) do
    Xb = big.(X); yb = big.(y); βb = big.(β); λb = big(λ0)
    r̂ = big.(res)
    N = sqrt(sum(abs2, r̂))
    P = sqrt(sum(abs2, yb .- Xb*βb)) + λb*sum(abs, βb)
    (P, N, r̂, Xb, yb, λb)
  end
end
function one_case(X::Matrix{T}, y::Vector{T}, β::Vector{T}, λ0; tag = "") where T
  p = size(X, 2)
  m, g, x = make_model(X, y, λ0, β)    # NormL1(λ0) with λ0 of any real type
  # production result on a fresh model
  m2, g2, x2 = make_model(X, y, λ0, β)
  code0, ratio0 = PS._certify!(m2, x2)
  out = PS._certify_probe!(m, x); code, ratio = out[1], out[2]; extra = length(out) >= 3 ? out[3] : nothing
  same = (code == code0) && (isequal(ratio, ratio0))
  res = (viol = String[], code = code, ratio = ratio, same = same, tight = NaN)
  viols = String[]
  same || push!(viols, "probe differs from production: $code,$ratio vs $code0,$ratio0")
  if extra !== nothing && code ∈ (:certified, :failed) && !(isnan(ratio) && code === :failed && !isfinite(extra.Dlo)) 
    (P, N, r̂, Xb, yb, λb) = setprecision(BigFloat, 512) do
      exact_check(X, y, β, λ0, m, m.res64)
    end
    setprecision(BigFloat, 512) do
      t = big(extra.t)
      θ = t .* r̂ ./ N
      feas1 = t <= 1
      feas2 = maximum(abs.(Xb' * θ)) <= λb
      thy = sum(θ .* yb)
      gap_true = P - thy
      feas1 || push!(viols, "t > 1")
      feas2 || push!(viols, "theta infeasible: |X'θ|∞ = $(Float64(maximum(abs.(Xb' * θ)))) > λ0=$(Float64(λb))")
      Float64(extra.gap) >= gap_true || big(extra.gap) >= gap_true || push!(viols, "gap $(extra.gap) < true gap $(Float64(gap_true))")
      isfinite(extra.Dlo) && !(big(extra.Dlo) <= thy) && push!(viols, "Dlo $(extra.Dlo) > θ'y $(Float64(thy))")
      if code === :certified
        big(ratio) >= gap_true/thy || push!(viols, "ratio $ratio < true ratio $(Float64(gap_true/thy))")
        ratio <= PS._CERT_TARGET || push!(viols, "certified above target")
      end
      res = merge(res, (tight = code === :certified ? Float64(big(ratio)/max(gap_true/thy, big(2)^-200)) : NaN,))
    end
  end
  (viols = viols, code = code, ratio = ratio, tight = res.tight, tag = tag)
end
