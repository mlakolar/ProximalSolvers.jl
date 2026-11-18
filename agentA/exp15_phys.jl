include("lib.jl"); include("optB.jl"); include("optC.jl"); include("optC2.jl")
using Logging
include("exp10_common.jl")
# E15: "physical units" examples; outcome of the public solve! under A / C2 / B1, with the BigFloat objective at the returned point
# versus the best objective found by 3000 extra BigFloat... (reference: A's own certified result is checked by the certificate; here we
# report converged/gap/passes and whether it throws).
function obj_big(X, y, λ, β)
  setprecision(BigFloat, 256) do
    Xb = big.(X); yb = big.(y); βb = big.(β)
    Float64(sqrt(sum(abs2, yb .- Xb*βb)) + big(λ)*sum(abs, βb))
  end
end
cases = Dict{String,Function}(
  "F32 y = 1.6e-19 * N(0,1) (charge in coulombs), X standardized, n=200 p=20" => () -> begin
    rng = Xoshiro(1); n, p = 200, 20; X = randn(rng, Float32, n, p); β0 = zeros(p); β0[1:3] .= (2, -1, 1)
    y = Float32.((X*β0 .+ randn(rng, n)) .* 1.6e-19); (X, y, Float32(0.5*sqrt(n))) end,
  "F32 y = 1e-21 * N(0,1) (energies in joules), n=100 p=10" => () -> begin
    rng = Xoshiro(2); n, p = 100, 10; X = randn(rng, Float32, n, p); y = Float32.((X[:,1] .* 3 .+ randn(rng, n)) .* 1e-21); (X, y, Float32(0.4*sqrt(n))) end,
  "F32 X = 1e-17 * N(0,1) (femto-units design), y ~ N(0,1), n=100 p=10" => () -> begin
    rng = Xoshiro(3); n, p = 100, 10; X = Float32.(randn(rng, n, p) .* 1e-17); y = randn(rng, Float32, n); (X, y, Float32(0.1*1e-17*sqrt(n))) end,
  "F32 raw counts: X ~ 1e10 columns (norm ~1e11), y ~ 1e10" => () -> begin
    rng = Xoshiro(4); n, p = 100, 10; X = Float32.(randn(rng, n, p) .* 1e10); y = Float32.(randn(rng, n) .* 1e10); (X, y, Float32(0.05*1e11)) end,
  "F64 y = 1e-200 * N(0,1), n=100 p=10" => () -> begin
    rng = Xoshiro(5); n, p = 100, 10; X = randn(rng, n, p); y = (X[:,1] .* 3 .+ randn(rng, n)) .* 1e-200; (X, y, 0.4*sqrt(n)) end,
  "F64 y = 1e200 * N(0,1), n=100 p=10" => () -> begin
    rng = Xoshiro(6); n, p = 100, 10; X = randn(rng, n, p); y = (X[:,1] .* 3 .+ randn(rng, n)) .* 1e200; (X, y, 0.4*sqrt(n)) end,
  "F64 y = 1e-12 * N(0,1) (ordinary small scale)" => () -> begin
    rng = Xoshiro(7); n, p = 100, 10; X = randn(rng, n, p); y = (X[:,1] .* 3 .+ randn(rng, n)) .* 1e-12; (X, y, 0.4*sqrt(n)) end,
  "F32 y = 1e-12 * N(0,1) (pico-units), n=100 p=10" => () -> begin
    rng = Xoshiro(8); n, p = 100, 10; X = randn(rng, Float32, n, p); y = Float32.((X[:,1] .* 3 .+ randn(rng, n)) .* 1e-12); (X, y, Float32(0.4*sqrt(n))) end,
)
function report(tag)
  println("== ", tag)
  for (nm, f) in sort(collect(cases); by = first)
    X, y, λ = f()
    o = Base.invokelatest(outcome, eltype(X), X, y, λ)
    print("  ", rpad(nm, 78), " ")
    if o.ok
      @printf("ok conv=%s gap=%s passes=%d obj=%.6e\n", o.conv, isnan(o.gap) ? "NaN" : @sprintf("%.1e", o.gap), o.passes, obj_big(X, y, λ, o.x))
    else
      println("THROWS: ", o.msg)
    end
  end
end
tag = ARGS[1]
tag == "C2" && install_C2!(); tag == "B1" && install_B1!()
report(tag)
