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

nparams(f) = maximum(length(m.sig.parameters) - 1 for m in methods(f))
arity_ok(f, n) = any(length(m.sig.parameters) - 1 == n for m in methods(f))

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
    emit_ir(io, "update_state!/$tag", PS.update_state!, Tuple{tf, tg, ts, tm})
    kind === :apg && emit_ir(io, "_prox_grad_step!/$tag", PS._prox_grad_step!, Tuple{tf, tg, ts, T})
    kind !== :apg && emit_ir(io, "backtrack!/$tag", PS.LineSearches.backtrack!, Tuple{ts, typeof(m.ls), tf, tg})
    # convergence_assessment: (state, f, g, options) at base, (state, options) once f, g are dropped
    if arity_ok(PS.convergence_assessment, 4)
      emit_ir(io, "convergence_assessment/$tag", PS.convergence_assessment, Tuple{ts, tf, tg, to})
    else
      emit_ir(io, "convergence_assessment/$tag", PS.convergence_assessment, Tuple{ts, to})
    end
    emit_ir(io, "gradient_converged!/$tag", PS.gradient_converged!, Tuple{ts, to})
    tr = PS.OptimizationTrace{tm}()
    if arity_ok(PS.trace!, 7)
      emit_ir(io, "trace!/$tag", PS.trace!, Tuple{typeof(tr), tf, tg, ts, Int, tm, to})
    else
      emit_ir(io, "trace!/$tag", PS.trace!, Tuple{typeof(tr), ts, Int, to})
    end
    emit_ir(io, "_solve_gradient!/$tag", PS._solve_gradient!, Tuple{ts, tf, tg, tm, to, Float64})
    if isdefined(PS, :_trial_point!)
      emit_ir(io, "_trial_point!/$tag", PS._trial_point!, Tuple{ts, tg, typeof(st.x), typeof(kind === :apg ? st.grad_f_y : st.grad_f_x)})
    end
    emit_ir(io, "_state_norm/$tag", PS._state_norm, Tuple{ts, typeof(st.x)})
    emit_ir(io, "_state_normdiff/$tag", PS._state_normdiff, Tuple{ts})
  end
  # inference of the four default cases
  for T in (Float32, Float64), kind in (:pgd, :apg)
    f, g, x0 = problem(T)
    m = meth(kind, T)
    rt = Base.return_types(PS.solve!, Tuple{typeof(x0), typeof(f), typeof(g), typeof(m)})
    println(io, "INFER solve!/", kind, "/", T, " return_types=", rt)
    opts = ProximalOptions()
    st = PS.initial_state(m, opts, f, g, copy(x0))
    rt2 = Base.return_types(PS._solve_gradient!, Tuple{typeof(st), typeof(f), typeof(g), typeof(m), typeof(opts), Float64})
    println(io, "INFER _solve_gradient!/", kind, "/", T, " return_types=", rt2)
    ok = try
      @inferred PS._solve_gradient!(st, f, g, m, opts, time()); "inferred-ok"
    catch e
      "inferred-FAIL " * first(sprint(showerror, e), 160)
    end
    println(io, "INFER _solve_gradient!/", kind, "/", T, " @inferred=", ok)
    ok2 = try
      @inferred PS.solve!(copy(x0), f, g, m); "inferred-ok"
    catch e
      "inferred-FAIL " * first(sprint(showerror, e), 160)
    end
    println(io, "INFER solve!/", kind, "/", T, " @inferred=", ok2)
  end
end
println("IR_CHILD DONE ", OUT, " ", filesize(OUT), " bytes")
