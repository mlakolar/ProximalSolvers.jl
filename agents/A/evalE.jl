# Candidate E: dual lower bound from the smoothed problem F_δ (production solver on augmented data),
# transplanted to the original point β via the generalised validator `vcert`.
include(joinpath(@__DIR__, "lib.jl"))
include(joinpath(@__DIR__, "pts.jl"))
function candE(X::Matrix{T}, y::Vector{T}, λ, β0::Vector{Float64}; stages = 5, c0 = 1e-2, maxpass = 20_000) where T
  Xd, yd, λd = Float64.(X), Float64.(y), Float64(λ)
  P0 = Float64(Pbig(X, y, λ, T.(β0)))
  β = copy(β0); passes = 0; best = (; ok = false, ratio = NaN, stage = 0, selfok = false, selfstage = 0, selfratio = NaN, passes = 0)
  selfdone = false
  for j in 0:stages-1
    δ = c0*P0*10.0^(-j)
    Xa = vcat(X, zeros(T, 1, size(X, 2))); ya = vcat(y, T(δ))
    x, r, _, _ = ps_solve(Xa, ya, λ, β; order = :cyclic, momentum = false, maxpasses = maxpass)
    β = Float64.(x); passes += r.passes
    # (a) does the smoothed point itself certify the original problem (production certificate)?
    if !selfdone
      code, ratio = certify_at(X, y, λ, T.(β))
      if code === :certified; selfdone = true; best = (; best..., selfok = true, selfstage = j + 1, selfratio = ratio); end
    end
    # (b) transplant: θ̂ = r_δ/√(‖r_δ‖²+δ²) validated at the ORIGINAL point β0
    rr = yd - Xd*β; θ = rr ./ sqrt(sum(abs2, rr) + Float64(T(δ))^2)
    v = vcert(Xd, yd, λd, λd, β0, θ)
    if v.ok && !best.ok; best = (; best..., ok = true, ratio = v.ratio, stage = j + 1); end
    best.ok && (selfdone || j >= 2) && break
  end
  (; best..., passes)
end
const PROMOTE = length(ARGS) > 0 && ARGS[1] == "promote"
out = open(joinpath(@__DIR__, "out", PROMOTE ? "eval_E64.tsv" : "eval_E.tsv"), "w")
println(out, join(["set", "id", "T", "start", "config", "ok", "ratio", "stage", "selfok", "selfstage", "selfratio", "passes", "sec", "lbexc", "excess"], '\t'))
pts = points()
neg = [p for p in pts if p.set == "NEG"]
keep = vcat([p for p in pts if p.set in ("M81", "OPTx")], neg[1:5:end])
PROMOTE && (keep = filter(p -> p.T == "Float32", keep))
for pt in keep
  TT = pt.T == "Float64" ? Float64 : Float32
  prob = problem(pt.id); o = oracle(pt.id, TT); X, y, λ = data(prob, TT)
  P = Pbig(X, y, λ, TT.(pt.β)); lbexc = Float64((P - big(o.U))/big(o.U)); exc = Float64((P - big(o.D))/big(o.D))
  t0 = time()
  r = PROMOTE ? candE(Float64.(X), Float64.(y), Float64(λ), pt.β) : candE(X, y, λ, pt.β)
  sec = time() - t0
  println(out, join(Any[pt.set, pt.id, pt.T, pt.start, pt.config, r.ok, r.ratio, r.stage, r.selfok, r.selfstage, r.selfratio, r.passes, round(sec; digits = 3), lbexc, exc], '\t')); flush(out)
end
close(out)
