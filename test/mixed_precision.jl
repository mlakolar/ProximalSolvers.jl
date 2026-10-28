module MixedPrecisionTests

using Test
using Random
using LinearAlgebra
using ProximalBase
using ProximalSolvers

const PS = ProximalSolvers

_check_point(x::AbstractArray) = @test eltype(x) == Float32
_check_point(x::Tuple) = foreach(_check_point, x)

function _check_minimum(r, f, g)
  _check_point(r.minimizer)
  @test r.converged
  value = Float32(f(r.minimizer) + g(r.minimizer))
  @test r.minimum ≈ value rtol = 0 atol = 8eps(value)
end

function _check_result(r::PS.OptimizationResults, f, g)
  @test r.minimum isa Float32
  @test r.x_residual isa Float64
  @test r.f_residual isa Float64
  @test r.g_residual isa Float64
  _check_minimum(r, f, g)
end

function _check_result(r::PS.ADMMResults, f, g)
  @test r.minimum isa Float32
  @test r.r_norm isa Float32
  @test r.s_norm isa Float32
  @test r.eps_pri isa Float32
  @test r.eps_dual isa Float32
  @test r.ρ isa Float32
  _check_point(r.u)
  _check_minimum(r, f, g)
end

function _check_objective(r, f, g, reference)
  x = r.minimizer isa Tuple ? map(x -> Float64.(x), r.minimizer) : Float64.(r.minimizer)
  @test f(x) + g(x) ≈ reference rtol = 1e-4 atol = 1e-6
end

function _check_boundary(f, x)
  model = PS._image_model(f)
  z = model === nothing ? nothing : PS._image_buffer(model)
  d = model === nothing ? nothing : similar(z)
  grad = similar(x)
  expected = Float32(f(x))
  @test isfinite(expected) && expected > 0
  @test PS._value!(f, x, model, z) === expected
  @test PS._value_and_gradient!(grad, f, x, model, z, d) === expected
  @test eltype(grad) == Float32
end

rng = Xoshiro(129)
n, p = 40, 10
X = randn(rng, Float32, n, p)
y = X * Float32[3, -2, 1.5, 0, 0, 0, 0, 0, 0, 0] + 0.05f0 * randn(rng, Float32, n)
yb = Float32.(y .> 0)
X64, y64, yb64 = Float64.(X), Float64.(y), Float64.(yb)
A, b = X'X / n, -X'y / n
A64, b64 = X64'X64 / n, -X64'y64 / n
options = ProximalOptions(; maxiter = 2000, ftol = 1e-7, xtol = 1e-6, gradtol = 1e-5,
                           allow_f_increases = true)
reference_options = ProximalOptions(; maxiter = 2000, ftol = 1e-13, xtol = 1e-13, gradtol = 1e-10)
losses = (("least squares", (1 / n) * LeastSquaresLoss(y, X),
            (1f0 / n) * LeastSquaresLoss(y, X), (1 / n) * LeastSquaresLoss(y64, X64)),
          ("logistic loss", (1 / n) * LogisticLoss(yb, X),
            (1f0 / n) * LogisticLoss(yb, X), (1 / n) * LogisticLoss(yb64, X64)),
          ("quadratic loss", 0.5 * QuadraticFunction(A, b),
            0.5f0 * QuadraticFunction(A, b), 0.5 * QuadraticFunction(A64, b64)))
penalties = (("Float32 penalty", NormL1(0.01f0), NormL1(Float64(0.01f0))),
             ("Float64 parameter", NormL1(0.01), NormL1(0.01)),
             ("Float64 scaled penalty", 2.0 * NormL1(0.005f0), 2.0 * NormL1(Float64(0.005f0))))
methods = (("plain proximal gradient", ProximalGradientDescent()),
           ("normalized proximal gradient", ProximalGradientDescent(; normalized = true)),
           ("diagonal proximal gradient", ProximalGradientDescent(; preconditioner = :diagonal)),
           ("accelerated proximal gradient", AccProxGradDescent()),
           ("diagonal accelerated proximal gradient", AccProxGradDescent(; preconditioner = :diagonal)),
           ("monotone accelerated proximal gradient", MonotoneAccProxGradDescent()))

@testset "$loss_name with $penalty_name" for (loss_name, f, f32, f64) in losses,
                                            (penalty_name, g, g64) in penalties
  reference = solve!(zeros(p), f64, g64, AccProxGradDescent(), reference_options)
  @test reference.converged
  value = f64(reference.minimizer) + g64(reference.minimizer)
  # The unscaled Float64 parameter is a control, rather than a repaired case.
  selected_methods = penalty_name == "Float64 parameter" ? (methods[1], methods[4]) : methods
  @testset "$name" for (name, method) in selected_methods
    for loss in (f, f32)
      result = solve!(zeros(Float32, p), loss, g, method, options)
      _check_result(result, loss, g)
      _check_objective(result, f64, g64, value)
    end
  end
  if isproximable(f) && penalty_name != "Float64 parameter"
    @testset "ADMM" begin
      method = ADMMSolver(; abstol = 1e-6, reltol = 1e-5)
      for loss in (f, f32)
        result = solve!(zeros(Float32, p), loss, g, method, options)
        _check_result(result, loss, g)
        _check_objective(result, f64, g64, value)
      end
    end
  end
end

@testset "values are narrowed after scaling" begin
  for (scale, response) in ((1 / n, 1f0), (1e-50, 1f15), (1e40, 1f-15))
    x = zeros(Float32, 1)
    loss = LeastSquaresLoss([response], ones(Float32, 1, 1))
    quadratic = QuadraticFunction(ones(Float32, 1, 1), [-response], response^2 / 2)
    f = scale * loss
    @test PS._image_model(f).α === scale
    @test PS._image_model(scale * quadratic) === nothing
    _check_boundary(f, x)
    _check_boundary(scale * quadratic, x)
    if scale != 1 / n
      @test !isfinite(Float32(scale) * loss(x)) || iszero(Float32(scale) * loss(x))
    end
  end
  _check_boundary((1 / n) * LogisticLoss(yb, X), zeros(Float32, p))
end

end
