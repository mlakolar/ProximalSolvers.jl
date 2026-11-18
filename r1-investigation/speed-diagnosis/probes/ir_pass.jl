# Dump the compiled visit-probe loop `pass` (the per-visit hot code: fused kernel + step formula) per variant.
include(joinpath(@__DIR__, "irlib.jl"))
vs = split(get(ENV, "VARS", "base,x1d,x1a"), ","); tag = get(ENV, "TAG", "pass")
@noinline function pass(col::F, step::G, m, xv::Vector{T}, reps::Int) where {F, G, T}
  ls = m.ls; acc = zero(T)
  for _ in 1:reps, k in eachindex(xv)
    a, b, ρ2 = col(ls.X, ls.r, k, ls.a[k])
    acc += step(m, xv[k], a, b, ρ2, k)
  end
  acc
end
function model(PS, f, g, xv::Vector{T}) where T
  x = SparseIterate(copy(xv)); m = PS.cdmodel(f, x); PS.initialize!(m, x); PS._prepare!(m, g, x)
  for k in eachindex(xv); m.ls.a[k] = sum(abs2, view(m.ls.X, :, k)); end
  m
end
tagv = string(VERSION.major, ".", VERSION.minor, "-", Sys.CPU_NAME, "-", get(ENV, "TGT", "x"))
for T in (Float64, Float32), v in vs
  PS = loadvariant(v)
  X, y, λmax = problem(T, 400, 40, 3)
  f, g = SqrtLeastSquaresLoss(y, X), NormL1(0.1*λmax)
  xv = zeros(T, size(X, 2)); with_logger(NullLogger()) do; PS.solve!(xv, f, g, PS.CDSolver(order = :cyclic)); end
  m = model(PS, f, g, xv)
  tt = Tuple{typeof(PS._column_dot_rsqr), typeof(PS._sqrt_minimizer), typeof(m), typeof(xv), Int}
  txt = native_text(pass, tt); llv = llvm_text(pass, tt)
  write(joinpath(OUT, "$tag-$tagv-$v-$T.s"), txt); write(joinpath(OUT, "$tag-$tagv-$v-$T.ll"), llv)
  h = histo(txt)
  cnt(f) = sum((c for (k, c) in h if f(k)); init = 0)
  println(rpad("$v $T", 14), " ninstr=", sum(values(h)), " sqrt=", cnt(k -> occursin("sqrt", k)), " div=", cnt(k -> occursin("div", k)), " call=", get(h, "call", 0),
    " jcc=", cnt(k -> startswith(k, "j") && k != "jmp"), " jmp=", get(h, "jmp", 0), " fma=", cnt(k -> occursin("fmadd", k) || occursin("fnmadd", k)), " max/min=", cnt(k -> occursin(r"vm(ax|in)", k)),
    " blend=", cnt(k -> occursin("blend", k)), " ymm=", count("ymm", txt), " vmov=", cnt(k->startswith(k,"vmov")), " spills(rsp)=", count("[rsp", txt),
    " define_lines=", count(==('\n'), llv))
end
