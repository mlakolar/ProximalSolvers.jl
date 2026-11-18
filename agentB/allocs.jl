using ProximalSolvers, Random, Printf
const PS = ProximalSolvers
include(joinpath(@__DIR__, "rs_variants.jl"))
for T in (Float32, Float64), n in (100, 10000)
  y = randn(Xoshiro(1), T, n); X = ones(T, n, 1); m = PS.LSModel(y, X, one(T)); v = randn(Xoshiro(1), n); a = zeros(T, 1)
  f1(m) = PS.response_scale(m, nothing); f2(m) = rs_new(m); f3(m) = rs_new64(m); f4(m) = PS._response_scale_exceptional(m)
  f5(m) = sum(abs2, view(m.X, :, 1)); f6(v) = PS._se_norm(Float64, v); f7(v) = PS._scaled_norm(v, length(v)); f8(m) = PS._sqnorm!(m, 1)
  for f in (f1, f2, f3, f4, f5, f8); f(m); end; for f in (f6, f7); f(v); end
  @printf("%s n=%d  allocs (bytes): response_scale %d, rs_new %d, rs_new64 %d, _response_scale_exceptional %d, sum(abs2,view) %d, _sqnorm! %d, _se_norm(F64) %d, _scaled_norm %d\n", T, n,
    @allocated(f1(m)), @allocated(f2(m)), @allocated(f3(m)), @allocated(f4(m)), @allocated(f5(m)), (m.a[1]=T(NaN); @allocated(f8(m))), @allocated(f6(v)), @allocated(f7(v)))
end
