# Warmed allocations of one out-of-range coordinate step that takes the recomputed-distance branch (ds2 < ss/16), base against head,
# plus the ordinary step. One column, the residual set to a near-parallel vector before each of the visits; the base copy with counters
# (base_instr) confirms that the branch ran. All measured inside a function after warmup.
include("r1lib.jl")
module Instr; include(joinpath(@__DIR__, "base_instr", "src", "ProximalSolvers.jl")); end
const INS = Instr.ProximalSolvers
const RECOMP = getfield(INS, :RECOMP)
function setup(P, xk::Vector{T}, r::Vector{T}, λ::T) where T
  X = reshape(copy(xk), :, 1); x = SparseIterate(zeros(T, 1))
  m = P.cdmodel(SqrtLeastSquaresLoss(copy(r), X), x); P.initialize!(m, x); copyto!(m.ls.r, r)
  g = NormL1(λ); P._prepare!(m, g, x); m, g, x
end
function visits!(cs::F, m, g, x, r, reps) where F
  for _ in 1:reps
    copyto!(m.ls.r, r); x[1] = zero(eltype(r)); m.ls.a[1] = eltype(r)(NaN)
    cs(m, g, x, 1)
  end
  nothing
end
println("# Julia ", VERSION)
for T in (Float32, Float64), n in (3, 30, 2000)
  rng = Xoshiro(11)
  u = randn(rng, n); sx, sr = T === Float32 ? (-65, -65) : (-495, -495)
  xk = T.(ldexp.(u, sx)); r = T.(ldexp.(u .* 1.5 .+ 1e-7 .* randn(rng, n), sr))        # tiny scale, nearly parallel
  ra = sqrt(sum(abs2, Float64.(xk))); λ = T(0.3 * ra)
  m0, g0, x0 = setup(INS, xk, r, λ); RECOMP[] = 0; visits!(INS.coordinate_step!, m0, g0, x0, r, 5)
  ran = RECOMP[]
  for (tn, P) in (("base", TREES.base), ("head", TREES.cand))
    m, g, x = setup(P, xk, r, λ); cs = P.coordinate_step!
    visits!(cs, m, g, x, r, 5)
    b = @allocated visits!(cs, m, g, x, r, 1000)
    @printf("%-8s n=%-5d %s recompute-branch visits (of 5, counted in base copy): %d | %d B for 1000 visits\n", T, n, tn, ran, b)
  end
end
