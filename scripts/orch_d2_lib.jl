# D2 with rigorous Float64 duals (vcert with θ̂ = r̂); same rule as orch_d2_rigorous.jl, as a function.
function Pup(X::Matrix{Float64}, y::Vector{Float64}, hi::Float64, β::Vector{Float64})
  n, p = size(X); ε = eps(Float64); η = nextfloat(0.0); ψ = (n + 1)*ε
  res = copy(y); mag = abs.(y); nb = 0; sb = 0.0
  for k in 1:p
    v = β[k]; iszero(v) && continue
    nb += 1; sb += abs(v)
    for i in 1:n
      t = X[i, k]*v; res[i] -= t; mag[i] += abs(t)
    end
  end
  sr = sum(abs2, res); smu = sum(abs2, mag)
  Nup = up(sqrt(up(up(sr*(1 + ψ)) + n*η))); Mup = up(sqrt(up(up(smu*(1 + ψ)) + n*η)))
  Eup = up(up(((nb + 1)*ε)*Mup) + up(up(Float64(nb)*Float64(n))*η))
  up(up(Nup + Eup) + up(hi*up(sb*(1 + nb*ε))))
end
ratio_of(P, D) = D > 0 ? up(up(P - D)/D) : Inf
function d2(X::Matrix{T}, y::Vector{T}, λ, x0; c0 = 0.3, q = 0.2, J = 8, cap = 20_000) where T
  X64, y64 = Float64.(X), Float64.(y); lo, hi = PS._level_brackets(λ)
  P0 = Pup(X64, y64, hi, Float64.(x0)); F0 = Float64(Pbig(X, y, λ, x0))
  β = copy(x0); D = 0.0; passes = 0
  for j in 0:J
    if j < J
      Xa = vcat(X, zeros(T, 1, size(X, 2))); ya = vcat(y, T(c0 * q^j * F0))
      β, r, _, _ = ps_solve(Xa, ya, λ, β; order = :cyclic, momentum = false, maxpasses = cap)
    else
      β, r, _, _ = ps_solve(X, y, λ, β; order = :cyclic, momentum = false, maxpasses = cap)
    end
    passes += r.passes
    v = vcert(X64, y64, lo, hi, Float64.(β), y64 .- X64 * Float64.(β)); isfinite(v.Dlo) && (D = max(D, v.Dlo))
    ratio_of(P0, D) <= TARGET && return (; outcome = "certified", via = "x0", passes, ratio = ratio_of(P0, D), ret = x0)
    rb = ratio_of(Pup(X64, y64, hi, Float64.(β)), D)
    rb <= TARGET && return (; outcome = "certified", via = j < J ? "stage" : "polish", passes, ratio = rb, ret = β)
  end
  Pb = Pup(X64, y64, hi, Float64.(β))
  (; outcome = "uncertified", via = "none", passes, ratio = min(ratio_of(Pb, D), ratio_of(P0, D)), ret = Pb < P0 ? β : x0)
end
