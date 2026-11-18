# The #308 inflated-start fixture: first_change, first_target, iterations and x of seeds 33, 34, 35.
# usage: run in a worktree; PS321_TESTFILE is test/core_regressions.jl of that worktree (default). At the base the public
# solve! is used (old helper); at head the helper is called with L0 = 1. Prints a hash and the numbers.
using Pkg; Pkg.instantiate()
using ProximalSolvers, ProximalBase, LinearAlgebra, Random, SHA
const PS = ProximalSolvers
println("# Julia ", VERSION, " PS ", pkgdir(PS))
path = joinpath(dirname(Base.active_project()), "test", "core_regressions.jl")
body = Meta.parseall(read(path, String)).args
body = first(filter(e -> e isa Expr && e.head === :module, body)).args[3].args
names = (:pgd_lasso_design, :pgd_relative_gap, :pgd_strict, :pgd_recording_solve)
callname(e) = (c = e.args[1]; c isa Expr && c.head === :where && (c = c.args[1]); c isa Expr && c.head === :call ? c.args[1] : (c isa Expr && c.head === :(::) ? nothing : nothing))
function pick(e)
  e isa Expr || return false
  e.head in (:function, :(=)) || return false
  e.args[1] isa Expr || return false
  c = e.args[1]; c.head === :where && (c = c.args[1])
  c.head === :call && c.args[1] in names
end
for e in filter(pick, body); Core.eval(Main, e); end
head = occursin("L0", read(path, String))
println("# helper takes L0: ", head)
c = 1e-6
for seed in (33, 34, 35)
  X, y, s, λ = pgd_lasso_design(seed, 100, 32)
  o = head ? pgd_recording_solve(c .* X, c .* y, s, c^2 * λ, ones(32), 2000; L0 = 1) : pgd_recording_solve(c .* X, c .* y, s, c^2 * λ, ones(32), 2000)
  println("seed ", seed, "\tfirst_change=", o.first_change, "\tfirst_target=", o.first_target, "\titerations=", o.r.iterations, "\tgap=", o.gap, "\tstagnated=", o.r.stagnated, "\txhash=", bytes2hex(sha256(reinterpret(UInt8, o.x)))[1:16], "\tx1=", o.x[1], "\tminimum=", o.r.minimum)
end
