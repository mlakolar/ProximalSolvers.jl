# G/B: targeted tiny- and huge-scale sqrt-lasso solves (cold steps and the recomputed-d branch), master vs candidate.
# Adapted from Stage 0 x3_sqrt_solves.jl. For each solve: bitwise identical or classified (outcome class, passes, converged, max relative difference of x and objective).
const HERE = @__DIR__
include(joinpath(HERE, "trees.jl"))
include(joinpath(HERE, "fp_lib.jl"))
println("Julia ", VERSION, " CPU ", Sys.CPU_NAME)
B = TREES.base; C = TREES.cand
# count calls of master's recomputed norm
@eval Base0.ProximalSolvers begin
  const _CALLS = Ref(0)
  function _scaled_norm(v::AbstractVector, n::Int)
    _CALLS[] += 1
    M = 0.0
    @inbounds for i in 1:n; M = max(M, abs(Float64(v[i]))); end
    (iszero(M) || !isfinite(M)) && return (M, 0)
    e = exponent(M)
    s = 0.0
    @inbounds for i in 1:n; w = ldexp(Float64(v[i]), -e); s += w*w; end
    (sqrt(s), e)
  end
end
rng = Xoshiro(332)
function runit(PS, T, X, y, λ, p, kind, order, β)
  x = SparseIterate(kind === :cold ? zeros(T, p) : T.(0.5 .* β))
  r = try with_logger(NullLogger()) do; PS.solve!(x, SqrtLeastSquaresLoss(y, X), NormL1(λ), PS.CDSolver(; order, rng = Xoshiro(5), tol = T === Float64 ? 1e-9 : 1e-4, maxpasses = 4000)); end catch e; return "ERR " * first(sprint(showerror, e), 100) end
  (Vector(x), r.minimum, r.passes, r.converged, r.gap)
end
nsolve = 0; ident = 0; threw = 0; outcls = 0; passdiff = 0; convdiff = 0; maxrelx = 0.0; maxrelobj = 0.0; solves_with_call = 0; extra = 0; npass = Int[]
for T in (Float32, Float64), (n, p) in ((20, 6), (50, 30), (100, 10)), sc in (T === Float32 ? (2.0^-70, 2.0^-64, 2.0^60) : (2.0^-540, 2.0^-515, 2.0^520)),
    noise in (1e-1, 1e-3, 1e-6), frac in (0.05, 0.3, 0.6), order in (:cyclic, :random), kind in (:cold, :warm)
  X, y, β = lsdata(rng, T, n, p; scale = sc, noise = noise)
  lmax = maximum(abs, Float64.(X)' * Float64.(y)) / norm(Float64.(y))
  λ = T(frac * lmax); (isfinite(λ) && λ > 0) || continue
  global nsolve += 1
  B._CALLS[] = 0
  rb = runit(B, T, X, y, λ, p, kind, order, β); c = B._CALLS[]; global extra += max(c - 1, 0); c > 1 && (global solves_with_call += 1)
  rc = runit(C, T, X, y, λ, p, kind, order, β)
  if rb isa String || rc isa String
    global threw += 1
    (rb isa String && rc isa String && rb == rc) || (global outcls += 1; println("OUTCOME-CLASS DIFF ", T, n, p, sc, noise, frac, order, kind, " base=", rb isa String ? rb : "value", " cand=", rc isa String ? rc : "value"))
    continue
  end
  if ddiff(rb, rc) === nothing; global ident += 1
  else
    rb[4] != rc[4] && (global convdiff += 1); rb[3] != rc[3] && (global passdiff += 1; push!(npass, rc[3] - rb[3]))
    nb = norm(Float64.(rb[1])); global maxrelx = max(maxrelx, nb == 0 ? norm(Float64.(rc[1])) : norm(Float64.(rc[1]) .- Float64.(rb[1]))/nb)
    global maxrelobj = max(maxrelobj, abs(Float64(rc[2]) - Float64(rb[2]))/max(abs(Float64(rb[2])), floatmin()))
  end
end
println("solves: $nsolve; throwing in both (same text unless listed above): $threw; bitwise identical: $ident; not identical: $(nsolve - threw - ident)")
println("outcome-class differences: $outcls; converged flag changes: $convdiff; pass-count changes: $passdiff ", npass, "; max rel diff x: $maxrelx; max rel diff objective: $maxrelobj")
println("solves in which master's recomputed-d branch (_scaled_norm beyond the one call of _prepare!) ran: $solves_with_call; such calls in total: $extra")
