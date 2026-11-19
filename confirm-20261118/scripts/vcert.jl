function vcert(X::Matrix{Float64}, y::Vector{Float64}, lo::Float64, hi::Float64, β::Vector{Float64}, θ::Vector{Float64})
  n, p = size(X)
  ε = eps(Float64); η = nextfloat(0.0); nη = n*η; ψ = (n + 1)*ε
  fail(why) = (; ok = false, ratio = NaN, Dlo = NaN, gap = NaN, t = NaN, why)
  res = copy(y); mag = abs.(y); nb = 0; sb = 0.0
  for k in 1:p
    v = β[k]; iszero(v) && continue
    nb += 1; sb += abs(v)
    @inbounds for i in 1:n
      t = X[i, k]*v; res[i] -= t; mag[i] += abs(t)
    end
  end
  sr = 0.0; smu = 0.0; sθ = 0.0; w = 0.0; Aw = 0.0; wy = 0.0; Ay = 0.0
  @inbounds for i in 1:n
    sr += res[i]*res[i]; smu += mag[i]*mag[i]; sθ += θ[i]*θ[i]
    w += θ[i]*res[i]; Aw += abs(θ[i]*res[i]); wy += θ[i]*y[i]; Ay += abs(θ[i]*y[i])
  end
  (isfinite(sr) & isfinite(smu) & isfinite(sθ) & isfinite(w) & isfinite(wy) & isfinite(sb)) || return fail(:nonfinite)
  Nup = up(sqrt(up(up(sr*(1 + ψ)) + nη)))
  Nlo = sr >= ldexp(Float64(n), -969) ? dn(sqrt(dn(sr*(1 - ψ)))) : 0.0
  Mup = up(sqrt(up(up(smu*(1 + ψ)) + nη)))
  Eup = up(up(((nb + 1)*ε)*Mup) + up(up(Float64(nb)*Float64(n))*η))
  Θup = up(sqrt(up(up(sθ*(1 + ψ)) + nη)))
  bmax = 0.0; amax = 0.0; q = 0.0
  for k in 1:p
    bk = 0.0; ak = 0.0
    @inbounds @simd for i in 1:n
      v = X[i, k]; bk += v*θ[i]; ak += v*v
    end
    (isfinite(bk) & isfinite(ak)) || return fail(:nonfinite)
    bmax = max(bmax, abs(bk)); amax = max(amax, ak)
    iszero(β[k]) || (q += β[k]*bk)
  end
  isfinite(q) || return fail(:nonfinite)
  Rup = up(sqrt(up(up(amax*(1 + ψ)) + nη)))
  Eb = up(up((n*ε)*up(Rup*Θup)) + nη)        # |b_k − b̂_k| ≤ Eb, b_k = X_kᵀθ̂
  G = up(bmax + Eb)
  isfinite(G) || return fail(:nonfinite)
  t = max(0.0, min(dn(1/Θup), dn(lo/G)))      # no cap at 1: tθ̂ is feasible for every t ≥ 0 with tΘup ≤ 1, tG ≤ λ
  wlo = dn(dn(w - up(up((n*ε)*up(Aw*(1 + ψ))) + nη)) - up(Θup*Eup))     # ≤ θ̂ᵀr
  B1 = up(up(Nup + Eup) - dn(t*wlo))                                      # ≥ ‖r‖ − tθ̂ᵀr
  Σup = up(sb*(1 + nb*ε)); Σlo = dn(sb*(1 - nb*ε))
  S1 = up(hi*Σup)
  E2 = up(up(up(up((nb*ε)*bmax) + Eb)*Σup) + nb*η)
  S2 = dn(dn(t*q) - up(t*E2))                                              # ≤ t Σ β_k b_k
  gap = up(B1 + up(S1 - S2))                                               # ≥ P(β) − tθ̂ᵀy
  Plo = dn(max(0.0, dn(Nlo - Eup)) + dn(lo*Σlo))
  D1 = dn(Plo - gap)
  wylo = dn(wy - up(up((n*ε)*up(Ay*(1 + ψ))) + nη))
  D2 = dn(t*wylo)
  Dlo = max(D1, D2)
  isfinite(gap) || return fail(:nonfinite)
  Dlo > 0 || return (; ok = false, ratio = NaN, Dlo, gap, t, why = :Dlo_nonpositive)
  Pup = up(up(Nup + Eup) + S1)
  ratio = max(0.0, min(up(gap/Dlo), up(up(Pup - Dlo)/Dlo)))
  (; ok = ratio <= TARGET, ratio, Dlo, gap, t, why = ratio <= TARGET ? :ok : :ratio)
end
