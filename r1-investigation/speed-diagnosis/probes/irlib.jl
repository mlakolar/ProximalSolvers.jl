# IR/native dump library for #353 R1-D. Loads variants as modules, builds models, dumps _sweep! (the hot loop).
using LinearAlgebra, Random, Logging, InteractiveUtils, Printf
BLAS.set_num_threads(1)
const VROOT = "<WORK>/ProximalSolvers.jl-issue353-r1-perf/.codex-orchestrator/variants"
const OUT = "<WORK>/ProximalSolvers.jl-issue353-r1-perf/.codex-orchestrator/out"
function loadvariant(nm)
  mod = Module(Symbol("M_", nm))
  Base.include(mod, joinpath(VROOT, nm, "src/ProximalSolvers.jl"))
  getfield(mod, :ProximalSolvers)
end
using ProximalBase: SqrtLeastSquaresLoss, NormL1, SparseIterate
function problem(::Type{T}, n, p, seed) where T
  rng = MersenneTwister(seed)
  Z = randn(rng, n, p); b = zeros(p); b[1:min(5, p)] .= (1.0, -2.0, 1.5, -1.0, 0.5)[1:min(5, p)]
  y = Z*b .+ randn(rng, n)
  X, yv = T.(Z), T.(y)
  X, yv, Float64(maximum(abs, X'yv)/norm(yv))
end
# run one solve so that _sweep! gets specialized, return the specializations of _sweep!
function sweep_specs(PS, ::Type{T}) where T
  X, y, λmax = problem(T, 30, 120, 7)
  f, g = SqrtLeastSquaresLoss(y, X), NormL1(0.1*λmax)
  x = zeros(T, size(X, 2))
  with_logger(NullLogger()) do; PS.solve!(x, f, g, PS.CDSolver(order = :cyclic)); end
  m = first(methods(PS._sweep!))
  [sp.specTypes for sp in Base.specializations(m) if sp isa Core.MethodInstance && sp.specTypes isa DataType && occursin("SqrtLSModel{$T", string(sp.specTypes))]
end
function native_text(f, tt; kw...)
  io = IOBuffer(); code_native(io, f, tt; debuginfo = :none, kw...); String(take!(io))
end
function llvm_text(f, tt; kw...)
  io = IOBuffer(); code_llvm(io, f, tt; debuginfo = :none, kw...); String(take!(io))
end
# instruction mnemonic histogram of a native listing
function histo(txt)
  h = Dict{String,Int}()
  for ln in split(txt, '\n')
    s = strip(ln)
    (isempty(s) || startswith(s, '.') || startswith(s, ';') || startswith(s, '#') || endswith(s, ':') || startswith(s, "@")) && continue
    mn = split(s)[1]
    h[mn] = get(h, mn, 0) + 1
  end
  h
end
