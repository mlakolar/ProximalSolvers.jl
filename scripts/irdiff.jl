using ProximalSolvers, ProximalBase, InteractiveUtils
const PS = ProximalSolvers
ir(st, f, g) = (io = IOBuffer(); code_llvm(io, PS._stationary!, (typeof(st), typeof(f), typeof(g), ProximalOptions); debuginfo = :none);
                replace(String(take!(io)), r"_\d+" => "_N", r"#\d+" => "#N", r"!\d+" => "!N"))
for T in (Float32, Float64), m in (ProximalGradientDescent(), AccProxGradDescent())
  X = randn(T, 20, 5); y = randn(T, 20); f = LeastSquaresLoss(y, X); g = ElasticNet(T(0.1), T(0.2))
  st = PS.initial_state(m, ProximalOptions(), f, g, zeros(T, 5))
  base = ir(st, f, g)
  @eval PS _converted_level(::Type{T}, λ::T) where T = λ
  @eval PS @noinline _converted_level(::Type{T}, λ) where T = T(λ)
  @eval PS _converted_penalty(g::ElasticNet, ::Type{T}) where T = ElasticNet(_converted_level(T, g.λ1), _converted_level(T, g.λ2))
  a2 = Base.invokelatest(ir, st, f, g)
  @eval PS _converted_penalty(g::ElasticNet, ::Type{T}) where T = ElasticNet(T(g.λ1), T(g.λ2))
  println(T, " ", nameof(typeof(m)), ": native-level _stationary! IR identical under A': ", base == a2, " (", count('\n', base), " lines)")
end
