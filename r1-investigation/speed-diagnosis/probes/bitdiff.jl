# bitwise comparison of the step result: cand vs base and cand vs x1d, over the accuracy families (ARGS: N SEED)
include(joinpath(@__DIR__, "accfam.jl"))
function main2()
  println("# julia ", VERSION, " N=", N, " seed=", SEED, ": per family/type: cases, both ok, cand!=base (bits), max |cand-base|/|base| , cand!=x1d (bits), cand throws, base throws")
  for (fname, gen) in FAMS, T in (Float32, Float64)
    rng = Xoshiro(hash((fname, T, SEED))); cnt = 0; both = 0; dcb = 0; dcx = 0; mx = 0.0; tc = 0; tb = 0; tries = 0
    while cnt < N && tries < 20N
      tries += 1; inp = gen(rng, T); inp === nothing && continue; cnt += 1
      xk, y, λ, old = inp
      zb, eb = step_in(TREES.base, xk, y, λ, old)[1:2]; zc, ec = step_in(TREES.cand, xk, y, λ, old)[1:2]; zx, ex = step_in(TREES.x1d, xk, y, λ, old)[1:2]
      tc += ec !== nothing; tb += eb !== nothing
      if eb === nothing && ec === nothing
        both += 1; bits(v) = reinterpret(Base.uinttype(T), v)
        if !(isnan(zb) && isnan(zc)) && bits(zb) != bits(zc); dcb += 1; isfinite(zb) && isfinite(zc) && !iszero(zb) && (mx = max(mx, Float64(abs(zc - zb)/abs(zb)))); end
        ex === nothing && !(isnan(zx) && isnan(zc)) && bits(zx) != bits(zc) && (dcx += 1)
      end
    end
    @printf("%-14s %-8s cases %6d both-ok %6d  cand!=base %5d  maxrel %.2e  cand!=x1d %4d  throws cand %5d base %5d\n", fname, T, cnt, both, dcb, mx, dcx, tc, tb)
  end
end
main2()
