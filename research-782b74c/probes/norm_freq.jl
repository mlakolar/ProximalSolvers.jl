# norm_freq.jl: how often the tested step length and the reported step length differ in bits (issue #279, W2 item 3a).
#   tested   : _norm(delta_x)                (what convergence_assessment compares to xtol, utils.jl:33)
#   reported : _norm_diff(x, x_previous, 2.) (what the trace and the result's x_residual report, utils.jl:14, solve.jl:127)
# over the iterates of the corpus (non-refusal cases), split by T and by length < 32 / >= 32 (and by solver).
include(joinpath(@__DIR__, "common.jl"))
ensure_env()
using ProximalBase: LeastSquaresLoss, NormL1
using ProximalSolvers
TREE_DIR_REF[] = pkgdir(ProximalSolvers)
include(joinpath(@__DIR__, "corpus.jl"))
using Random

mutable struct Acc
  n::Int
  ndiff::Int
  nzero::Int
  maxrel::Float64
  maxcase::String
end
Acc() = Acc(0, 0, 0, 0.0, "")

function tally!(acc::Acc, a, b, name::AbstractString = "synthetic")
  acc.n += 1
  if a !== b
    acc.ndiff += 1
    m = max(abs(Float64(a)), abs(Float64(b)))
    if m > 0
      rel = abs(Float64(a) - Float64(b)) / m
      rel > acc.maxrel && (acc.maxrel = rel; acc.maxcase = String(name))
    end
  end
  iszero(a) && iszero(b) && (acc.nzero += 1)
  nothing
end

function iterate_case!(accs, sc::Scn)
  a = try sc.make() catch; return 0 end
  a.how === :update && return 0
  x = a.alias ? a.x0 : copy(a.x0)
  st = try
    PS._check_keywords(a.kwargs)
    PS._check_problem(x, a.f, a.g)
    a.method isa AccProxGradDescent && (PS._check_method(a.method, eltype(x)); PS._check_bound_size(a.f, eltype(x)))
    PS.initial_state(a.method, a.opts, a.f, a.g, x)
  catch
    return 0
  end
  a.prep === nothing || a.prep(st)
  opts = a.opts
  T = eltype(x)
  cls = length(x) < 32 ? :lt32 : :ge32
  keyA = (sc.solver, T, cls)
  keyB = (:all, T, cls)
  n = 0
  for iteration in 1:opts.maxiter
    ok = try
      PS.update_state!(a.f, a.g, st, a.method)
      isfinite(st.f_x + st.g_x)
    catch
      false
    end
    ok || break
    t = PS._norm(st.delta_x)
    r = PS._norm_diff(st.x, st.x_previous, 2.)
    tally!(get!(accs, keyA, Acc()), t, r, sc.name)
    tally!(get!(accs, keyB, Acc()), t, r, sc.name)
    n += 1
    _, _, _, conv, f_inc = PS.convergence_assessment(st, a.f, a.g, opts)
    conv && break
    (f_inc && !opts.allow_f_increases) && break
    opts.f_calls_limit > 0 && st.f_calls >= opts.f_calls_limit && break
    opts.grad_calls_limit > 0 && st.grad_calls >= opts.grad_calls_limit && break
    opts.prox_calls_limit > 0 && st.prox_calls >= opts.prox_calls_limit && break
  end
  n
end

function norm_main()
  cases = [s for s in corpus_cases() if s.group != 'D']
  println("NORMFREQ cases (non-refusal): ", length(cases))
  accs = Dict{Tuple{Symbol,DataType,Symbol},Acc}()
  t0 = time()
  total = 0
  for (i, sc) in enumerate(cases)
    total += iterate_case!(accs, sc)
    i % 2000 == 0 && println("NORMFREQ progress ", i, "/", length(cases), " iterates ", total, " ", round(time() - t0; digits = 1), " s")
  end
  println("NORMFREQ total iterates ", total)
  println("NORMFREQ table: solver | T | length | iterates | differ in bits | fraction | both zero | largest relative difference | case of the largest")
  for k in sort!(collect(keys(accs)); by = k -> (string(k[1]), string(k[2]), string(k[3])))
    a = accs[k]
    println("NORMFREQ ", k[1], " | ", k[2], " | ", k[3] === :lt32 ? "<32" : ">=32", " | ", a.n, " | ", a.ndiff, " | ",
            a.n == 0 ? "-" : round(a.ndiff / a.n; sigdigits = 4), " | ", a.nzero, " | ", a.maxrel, " | ", a.maxcase)
  end
end

function synth_main()
  # supplementary: random vector pairs, no solver involved
  println("SYNTH table: T | length | pairs | differ in bits | fraction | largest relative difference")
  rng = Xoshiro(7)
  for T in (Float32, Float64), len in (2, 8, 16, 31, 32, 33, 64, 128, 1000)
    acc = Acc()
    for _ in 1:4000
      x = randn(rng, T, len); y = x .+ T(1e-3) .* randn(rng, T, len)
      d = x .- y
      tally!(acc, PS._norm(d), PS._norm_diff(x, y, 2.))
    end
    println("SYNTH ", T, " | ", len, " | ", acc.n, " | ", acc.ndiff, " | ", round(acc.ndiff / acc.n; sigdigits = 4), " | ", acc.maxrel)
  end
end

env_header()
norm_main()
synth_main()
println("NORM_FREQ DONE")
