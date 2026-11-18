# Power-of-two rescaling scan: exact rescalings (j: X exponent, i: y exponent, l: loss-scale exponent) of one base problem;
# records which exceptional branches fire, refusals, and the error of the rescaled solution against the base one.
include(joinpath(@__DIR__, "instr_load.jl"))
using Logging
pen = ARGS[1]            # lasso | enet | group
T = ARGS[2] == "f32" ? Float32 : Float64
wide = length(ARGS) > 2 && ARGS[3] == "wide"   # Float64 loss scale on Float32 data
rng = Xoshiro(7)
n, p = 40, 12
X0 = randn(rng, T, n, p); β0 = zeros(T, p); β0[1:3] .= (1, -2, 0.5); y0 = X0*β0 + T(0.3)*randn(rng, T, n)
λmax = maximum(abs.(X0'*y0)); λ0 = 0.2λmax
groups = [collect((i-1)*3+1:i*3) for i in 1:4]
tol = T === Float32 ? 1e-6 : 1e-10
ldx(v, e) = ldexp.(v, e)
function exps()
  T === Float32 ? (collect(-90:10:70), collect(-90:10:70), collect(-100:20:100)) :
                  (collect(-700:50:550), collect(-700:50:550), collect(-1000:100:1000))
end
SA = wide ? Float64 : T
function solve_case(j, i, l)
  X = ldx(X0, j); y = ldx(y0, i)
  α = ldexp(SA(1), l)
  (isfinite(α) && α > 0 && all(isfinite, X) && all(isfinite, y)) || return :skip
  nrm(v) = all(t -> iszero(t) || (floatmin(T) <= abs(t) <= floatmax(T)/4), v)   # exact rescaling: normal entries only
  (nrm(X) && nrm(y)) || return :skip
  nrm([ldexp(Float64(b), i - j) for b in bs]) && all(b -> iszero(b) || (floatmin(T) <= abs(ldexp(b, i - j)) <= floatmax(T)/4), bs) || return :skip
  # equivalence: loss' = 2^(l+2i) loss; beta' = 2^(i-j) beta; lambda1' = lambda 2^(l+i+j); lambda2' = lambda2 2^(l+2j)
  λ1 = ldexp(Float64(λ0), l + i + j); λ2 = ldexp(0.1*Float64(λ0), l + 2j)
  LT0 = wide ? Float64 : T
  e1 = exponent(Float64(λ0)) + l + i + j; e2 = exponent(0.1*Float64(λ0)) + l + 2j
  (e1 >= exponent(floatmin(LT0)) && e1 <= exponent(floatmax(LT0)) - 2) || return :skip   # exact: level stays normal
  (pen == "enet" ? (e2 >= exponent(floatmin(LT0)) && e2 <= exponent(floatmax(LT0)) - 2) : true) || return :skip
  LT = wide ? Float64 : T
  (isfinite(λ1) && isfinite(λ2) && λ1 < floatmax(LT) ) || return :skip
  λ1c = LT(λ1); λ2c = LT(λ2)
  (λ1 != 0 && !(abs(λ1c) >= floatmin(LT))) && return :skip    # level must be normal in its own type (not rounded to 0/subnormal)
  (pen == "enet" && λ2 != 0 && !(abs(λ2c) >= floatmin(LT))) && return :skip
  (T === Float32 && !wide && (λ1c > floatmax(T)/4)) && return :skip
  f = α * LeastSquaresLoss(y, X)
  g = pen == "lasso" ? NormL1(λ1c) : pen == "enet" ? ElasticNet(λ1c, λ2c) : GroupNormL2(λ1c, groups)
  x = pen == "group" ? BlockIterate(T, p, g) : zeros(T, p)
  cnt_reset!()
  res = try
    r = with_logger(NullLogger()) do; solve!(x, f, g, CDSolver(order=:cyclic, momentum=false, tol=tol, maxpasses=20000)); end
    :ok => r
  catch e
    e isa ArgumentError ? (:refused => first(split(sprint(showerror, e), ";"))[1:min(end,70)]) : (:error => sprint(showerror, e)[1:60])
  end
  c = cnt_snapshot()
  res.first == :ok || return (res, c, NaN)
  xv = pen == "group" ? collect(x) : x
  err = NaN
  b = [ldexp(Float64(v), j - i) for v in xv]
  base = nothing
  (res.first, res.second, c, b)
end
# base solution at (0,0,0) in BigFloat-free reference: run the same solver at unit scale
function basesol()
  f = LeastSquaresLoss(y0, X0)
  g = pen == "lasso" ? NormL1(T(λ0)) : pen == "enet" ? ElasticNet(T(λ0), T(0.1λ0)) : GroupNormL2(T(λ0), groups)
  x = pen == "group" ? BlockIterate(T, p, g) : zeros(T, p)
  solve!(x, f, g, CDSolver(order=:cyclic, momentum=false, tol=tol, maxpasses=20000)); Float64.(collect(x))
end
bs = basesol()
EJ, EI, EL = exps()
out = open(joinpath(@__DIR__, "scan_$(pen)_$(ARGS[2])$(wide ? "_wide" : "").tsv"), "w")
println(out, "j\ti\tl\tstatus\tconverged\trelerr\tcounters")
for j in EJ, i in EI, l in EL
  r = solve_case(j, i, l)
  r === :skip && continue
  if r[1] isa Pair
    println(out, "$j\t$i\t$l\t$(r[1].first)\t\t\t$(r[1].second)  $(r[2])")
  else
    st, res, c, b = r
    relerr = norm(b - bs) / max(norm(bs), eps())
    println(out, "$j\t$i\t$l\tok\t$(res.converged)\t$(relerr)\t$c")
  end
end
close(out)
println("done ", ARGS)
