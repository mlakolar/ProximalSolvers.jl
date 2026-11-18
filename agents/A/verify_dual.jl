# Verify: (i) θ* = -X d* (directional lasso) equals the min-norm certificate of oracle C; (ii) σ_C(d*) = -‖Xd*‖²,
# F'(β;d*) = ‖Xd*‖(1-‖Xd*‖); (iii) D refutes exactly the points for which C says τ*>1 or infeasible.
include(joinpath(@__DIR__, "oracleC.jl"))
function dlasso(X, λ, S, s; passes = 200_000, tol = 1e-13)
  n, p = size(X); isS = falses(p); isS[S] .= true; sg = zeros(p); sg[S] .= s
  a = vec(sum(abs2, X; dims = 1)); d = zeros(p); u = zeros(n); last = Inf
  for pass in 1:passes
    for k in 1:p
      xk = view(X, :, k); ck = dot(xk, u) - a[k]*d[k]
      z = isS[k] ? -(ck + λ*sg[k])/a[k] : (v = -ck/a[k]; τ = λ/a[k]; v > τ ? v - τ : v < -τ ? v + τ : 0.0)
      h = z - d[k]; if h != 0; u .+= h .* xk; d[k] = z; end
    end
    if pass % 50 == 0
      σ = λ*sum(sg[k]*d[k] for k in S; init = 0.0) + λ*sum(abs(d[k]) for k in 1:p if !isS[k]; init = 0.0)
      G = 0.5*dot(u, u) + σ
      abs(G - last) <= tol*max(1, abs(G)) && return (; d, u, σ, G, pass)
      last = G
    end
  end
  (; d, u, σ = NaN, G = NaN, pass = passes)
end
out = open(joinpath(@__DIR__, "out", "verify_dual.tsv"), "w")
println(out, join(["id","T","tauC","normXd","thetadiff","sigma_plus_normsq","Fprime","pred_Fprime","passes"], '\t'))
for pt in points()
  pt.set == "OPTx" && pt.T == "Float64" || continue
  prob = problem(pt.id); X, y, λ = data(prob, Float64)
  S = effsupport(pt.β, 1e-6); s = sign.(pt.β[S])
  c = oracleC(X, y, λ, pt.β); c.θ === nothing && continue
  r = dlasso(X, λ, S, s); nu = norm(r.u)
  Fp = nu + r.σ
  println(out, join(Any[pt.id, pt.T, c.τ, nu, norm(-r.u - c.θ), r.σ + nu^2, Fp, nu*(1 - nu), r.pass], '\t')); flush(out)
end
close(out)
