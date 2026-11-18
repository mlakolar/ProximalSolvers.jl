include("exp5_stress_lib.jl")
function find(T, N)
  rng = Xoshiro(2718)
  nt = 0; shown = 0
  while nt < N && shown < 4
    t = onecol(T, rng); t === nothing && continue
    xk, y, λ, old, mode, f = t
    n = length(y)
    X = reshape(copy(xk), n, 1)
    m, g, x = make_model(X, y, λ, T[old])
    r0 = copy(m.ls.r)
    v = Base.invokelatest(visit!, m, g, x, 1)
    nt += 1
    v.err === nothing || continue
    if !isfinite(v.znew)
      ref = bigref(xk, r0, old, m.gt.λ0)
      a, b, ρ2 = PS._column_dot_rsqr(X, r0, 1, T(NaN))
      println("branch=", v.branch, " old=", old, " znew=", v.znew, " z*=", Float64(ref.zstar), " c=", Float64(ref.c), " a=", a, " b=", b, " rho2=", ρ2, " lam=", λ, " sqrt(a)=", sqrt(a), " n=", n)
      println("  xk=", xk, "\n  r=", r0)
      shown += 1
    end
  end
end
find(Float32, 40000)
