# ir_child.jl <outfile>   (one tree = --project, one fresh process)
# Writes, per function, the LLVM IR (code_llvm, debuginfo=:none) for concrete argument types taken from real states built
# by PS.initial_state, and the inference results (return_types of solve!, @inferred of _solve_gradient!).
include(joinpath(@__DIR__, "common.jl"))
ensure_env()
using ProximalBase: LeastSquaresLoss, NormL1
using ProximalSolvers
using InteractiveUtils
using Test
using Random
const PS = ProximalSolvers
env_header()
if ARGS[1] == "warm"
  println("IR_CHILD warm done")
  exit(0)
end
const OUT = ARGS[1]

function problem(::Type{T}, n = 60, p = 24) where {T}
  rng = Xoshiro(7)
  X = Matrix{T}(randn(rng, n, p)); y = Vector{T}(randn(rng, n))
  f = (one(T) / T(n)) * LeastSquaresLoss(y, X)
  g = NormL1(T(0.05))
  (f, g, zeros(T, p))
end

meth(kind, T) = kind === :pgd ? ProximalGradientDescent() : kind === :pgd32 ? ProximalGradientDescent(ls = PS.LineSearches.BackTracking(0.9f0, 0.5f0, Inf32)) : AccProxGradDescent()

# A function is dumped by name: every candidate argument tuple (the real types of the solver states and options built by
# PS.initial_state, in the call conventions known for the function at either revision) that some method of the function
# accepts is dumped. A function whose signature changes between revisions (trace! at the head loses three arguments)
# therefore keeps its label `name/tag`; the methods found are listed on IRMETHODS lines.
function emit_ir(io, label, f, types)
  println(io, "@@@IR ", label)
  try
    s = sprint(io2 -> code_llvm(io2, f, types; debuginfo = :none, raw = false))
    print(io, s)
  catch e
    println(io, "IR_ERROR ", sprint(showerror, e))
  end
  println(io, "@@@END ", label)
end

function emit_by_name(io, tag, name::Symbol, candidates::Vector)
  if !isdefined(PS, name)
    println(io, "IRMETHODS ", name, "/", tag, " <not defined>")
    return
  end
  f = getfield(PS, name)
  ms = collect(methods(f))
  println(io, "IRMETHODS ", name, "/", tag, " ", join(sort!([string(m.sig) for m in ms]), " ;; "))
  found = [c for c in candidates if hasmethod(f, Tuple{c...})]
  isempty(found) && println(io, "IRNOCANDIDATE ", name, "/", tag, " (no candidate argument tuple is accepted by a method)")
  for c in found
    label = length(found) == 1 ? string(name, "/", tag) : string(name, "/", tag, "@", length(c))
    emit_ir(io, label, f, Tuple{c...})
  end
end

open(OUT, "w") do io
  println(io, "IRFILE julia ", VERSION, " tree ", pkgdir(PS))
  for T in (Float64, Float32), kind in (:pgd, :pgd32, :apg)
    (kind === :pgd32 && T === Float64) && continue
    f, g, x0 = problem(T)
    m = meth(kind, T)
    opts = ProximalOptions()
    st = PS.initial_state(m, opts, f, g, copy(x0))
    tag = string(kind, "/", T)
    println(io, "STATETYPE ", tag, " ", typeof(st))
    tf, tg, tm, ts, to = typeof(f), typeof(g), typeof(m), typeof(st), typeof(opts)
    tx = typeof(st.x)
    tr = PS.OptimizationTrace{tm}()
    ttr = typeof(tr)
    emit_by_name(io, tag, :update_state!, [[tf, tg, ts, tm]])
    kind === :apg && emit_by_name(io, tag, :_prox_grad_step!, [[tf, tg, ts, T]])
    kind !== :apg && emit_by_name(io, tag, :backtrack!, [[ts, typeof(m.ls), tf, tg]])
    emit_by_name(io, tag, :convergence_assessment, [[ts, tf, tg, to], [ts, to]])
    emit_by_name(io, tag, :gradient_converged!, [[ts, to]])
    emit_by_name(io, tag, :g_residual, [[ts]])
    emit_by_name(io, tag, :trace!, [[ttr, tf, tg, ts, Int, tm, to], [ttr, ts, Int, to], [ttr, ts, Int, tm, to],
                                     [ttr, tf, tg, ts, Int, to]])
    emit_by_name(io, tag, :extended_trace!, [[Dict{Any,Any}, ts]])
    emit_by_name(io, tag, :_solve_gradient!, [[ts, tf, tg, tm, to, Float64], [ts, tf, tg, tm, to]])
    emit_by_name(io, tag, :_state_norm, [[ts, tx]])
    emit_by_name(io, tag, :_state_normdiff, [[ts]])
    emit_by_name(io, tag, :f_residual, [[T, T, Float64]])
    emit_by_name(io, tag, :_unchanged, [[tx, tx]])
    emit_by_name(io, tag, :_copy!, [[tx, tx]])
    emit_by_name(io, tag, :_copyto!, [[tx, tx]])
    isdefined(PS, :_trial_point!) &&
      emit_by_name(io, tag, :_trial_point!, [[ts, tg, tx, typeof(kind === :apg ? st.grad_f_y : st.grad_f_x)]])
  end
  # inference of the four default cases, and of the same four with ftol = 0 (positional options for solve!)
  for T in (Float32, Float64), kind in (:pgd, :apg), (optlabel, opts) in (("", ProximalOptions()), ("/ftol0", ProximalOptions(ftol = 0)))
    f, g, x0 = problem(T)
    m = meth(kind, T)
    lab(n) = string(n, "/", kind, "/", T, optlabel)
    rt = optlabel == "" ? Base.return_types(PS.solve!, Tuple{typeof(x0), typeof(f), typeof(g), typeof(m)}) :
                          Base.return_types(PS.solve!, Tuple{typeof(x0), typeof(f), typeof(g), typeof(m), typeof(opts)})
    println(io, "INFER ", lab("solve!"), " return_types=", rt)
    st = PS.initial_state(m, opts, f, g, copy(x0))
    rt2 = Base.return_types(PS._solve_gradient!, Tuple{typeof(st), typeof(f), typeof(g), typeof(m), typeof(opts), Float64})
    println(io, "INFER ", lab("_solve_gradient!"), " return_types=", rt2)
    ok = try
      @inferred PS._solve_gradient!(st, f, g, m, opts, time()); "inferred-ok"
    catch e
      "inferred-FAIL " * first(sprint(showerror, e), 160)
    end
    println(io, "INFER ", lab("_solve_gradient!"), " @inferred=", ok)
    ok2 = try
      optlabel == "" ? (@inferred PS.solve!(copy(x0), f, g, m)) : (@inferred PS.solve!(copy(x0), f, g, m, opts)); "inferred-ok"
    catch e
      "inferred-FAIL " * first(sprint(showerror, e), 160)
    end
    println(io, "INFER ", lab("solve!"), " @inferred=", ok2)
  end
end
println("IR_CHILD DONE ", OUT, " ", filesize(OUT), " bytes")
