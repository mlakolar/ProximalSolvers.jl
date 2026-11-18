# Shared helpers for the agent-C experiments (disposable). Drives the real private functions of ProximalSolvers.
using LinearAlgebra, Random, Printf
using ProximalSolvers, ProximalBase
const PS = ProximalSolvers
const PB = ProximalBase
BLAS.set_num_threads(1)
setprecision(BigFloat, 512)
const BF = BigFloat
big_(a) = BF.(a)
# the exact value of an _SE as a BigFloat
se2big(a::PS._SE) = iszero(a.s) ? zero(BF) : ldexp(BF(a.s), a.e)
bigexp(x::BF, e) = ldexp(x, e)
unit(T) = eps(T) / 2
gam(T, k) = (ku = k * unit(T); ku / (1 - ku))
bnorm(v) = sqrt(sum(abs2, BF.(v)))
bnormdiff(a, b) = sqrt(sum(abs2, BF.(a) .- BF.(b)))
# random vector at scale 2^k
rscale(rng, T, n, k) = T.(randn(rng, n) .* 2.0^k)
mutable struct Tally
  name::String; n::Int; viol::Int; worst::Float64   # worst = max of the measured ratio (for tightness) 
end
Tally(name) = Tally(name, 0, 0, -Inf)
function rec!(t::Tally, ok::Bool, ratio = NaN)
  t.n += 1; ok || (t.viol += 1)
  isnan(ratio) || (t.worst = max(t.worst, ratio))
end
report(t::Tally) = @printf("  %-58s n=%6d violations=%d worst_ratio=%.6g\n", t.name, t.n, t.viol, t.worst)
