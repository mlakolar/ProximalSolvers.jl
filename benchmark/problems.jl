using LinearAlgebra, SparseArrays, Random, SHA

function scenario_rng(rep::Integer, key::AbstractString)
  seed = UInt64(0xcbf29ce484222325) ⊻ UInt64(rep)
  for b in codeunits(key)
    seed = (seed ⊻ UInt64(b)) * UInt64(0x100000001b3)
  end
  Xoshiro(seed)
end

function hash_data!(io, a::SparseMatrixCSC)
  hash_data!(io, size(a))
  for field in findnz(a)
    hash_data!(io, field)
  end
end

function hash_data!(io, a::AbstractArray)
  hash_data!(io, size(a))
  if isbitstype(eltype(a))
    write(io, reinterpret(UInt8, vec(Array(a))))
  else
    for item in a
      hash_data!(io, item)
    end
  end
end

function hash_data!(io, a::Tuple)
  write(io, Int64(length(a)))
  for item in a
    hash_data!(io, item)
  end
end

hash_data!(io, a::Integer) = write(io, Int64(a))
hash_data!(io, a::Real) = write(io, Float64(a))
hash_data!(io, a::Union{AbstractString,Symbol}) = write(io, string(a))
hash_data!(io, ::Nothing) = write(io, "nothing")

function data_hash(problem::NamedTuple)
  io = IOBuffer()
  for name in sort!(collect(keys(problem)); by = string)
    write(io, string(name), '\0')
    hash_data!(io, getproperty(problem, name))
  end
  bytes2hex(sha256(take!(io)))
end

function release_problem(family::Symbol)
  rng = Xoshiro(90210)
  n, p = family == :newton ? (400, 40) : (120, 40)
  X = randn(rng, n, p)
  y = X[:, 1:4] * [1.0, -1.0, 0.5, -0.5] + randn(rng, n)
  key = "release/$(family)"
  if family == :newton
    return (; key, kind = :logistic, X, y = Float64.(y .> 0), s = 1 / n,
            λ = 0.05, w_obs = ones(n), offset = zeros(n))
  elseif family == :sqrt
    return (; key, kind = :sqrt_lasso, X, y, λ = 0.5, fit_floor = 1e-12)
  end
  (; key, kind = :lasso, X, y, s = 1 / n, λ = 0.05, w = ones(p))
end

function batched_problem(family::Symbol)
  rng = Xoshiro(90210)
  n, p = 120, 40
  X = randn(rng, n, p)
  y = X[:, 1:4] * [1.0, -0.5, 0.7, 0.2] + 0.1randn(rng, n)
  key = "batched/$(family)"
  if family in (:newton, :glm)
    probability = 1 ./ (1 .+ exp.(-X[:, 1:3] * [1.0, -0.5, 0.7]))
    labels = Float64.(rand(Xoshiro(90212), n) .< probability)
    return (; key, kind = :logistic, X, y = labels, s = 1 / n, λ = 0.03,
            w_obs = ones(n), offset = zeros(n))
  end
  family in (:csc, :lasso_csc) && (X = sparse(X))
  (; key, kind = :lasso, X, y, s = 1 / n, λ = 0.05, w = ones(p))
end

function lasso_design(design::Symbol, rep; n, p, s)
  design in (:A, :B, :C, :D, :E) || throw(ArgumentError("unknown design $design"))
  0 <= s <= p && n > 0 || throw(ArgumentError("invalid design dimensions"))
  key = "design/$(design)/$(n)x$(p)"
  rng = scenario_rng(rep, key)
  # f7e3f28:benchmark/lasso_common.jl:25-45; design parameters: lasso_bench.jl:40-44.
  X = randn(rng, n, p)
  ρ = design == :B ? 0.8 : design == :C ? 0.5 : 0.0
  if ρ > 0
    c = sqrt(1 - ρ^2)
    for j in 2:p
      @views X[:, j] .= ρ .* X[:, j-1] .+ c .* X[:, j]
    end
  end
  if design == :E
    X .= sqrt(0.5) .* X .+ sqrt(0.5) .* randn(rng, n)
  end
  for j in 1:p
    @views X[:, j] ./= sqrt(sum(abs2, X[:, j]) / n)
  end
  β = zeros(p)
  β[randperm(rng, p)[1:s]] .= rand(rng, (-1.0, 1.0), s)
  signal = X * β
  σ = sqrt(sum(abs2, signal) / n / 4.0)
  y = signal .+ σ .* randn(rng, n)
  (; key, kind = :lasso_design, X, y, β, design)
end

function lambda_max(X, y; s = 1 / size(X, 1), w = ones(size(X, 2)))
  length(w) == size(X, 2) || throw(DimensionMismatch("one weight per column is required"))
  s > 0 && isfinite(s) && all(isfinite, w) && all(>=(0), w) ||
    throw(ArgumentError("invalid scale or weights"))
  z = abs.(s .* (X' * y))
  maximum((w[j] == 0 ? (z[j] == 0 ? 0.0 : Inf) : z[j] / w[j]
           for j in eachindex(w)); init = 0.0)
end

function lambda_grid(λmax, ratio, k)
  isfinite(λmax) && λmax > 0 && 0 < ratio <= 1 && k >= 1 ||
    throw(ArgumentError("need a positive finite maximum, ratio in (0, 1], and k >= 1"))
  k == 1 && return [Float64(λmax)]
  grid = exp.(range(log(Float64(λmax)), log(Float64(λmax * ratio)); length = k))
  grid[1] = λmax
  k > 1 && (grid[end] = ratio * λmax)
  grid
end

function regression_problem(rep, key; n = 100, p = 32, design = :A,
                            kind = :lasso, fraction = 0.15)
  rng = scenario_rng(rep, key)
  X = randn(rng, n, p)
  ρ = design == :B ? 0.8 : design == :C ? 0.5 : 0.0
  if ρ > 0
    for j in 2:p
      @views X[:, j] .= ρ .* X[:, j-1] .+ sqrt(1 - ρ^2) .* X[:, j]
    end
  elseif design == :E
    X .= sqrt(0.5) .* X .+ sqrt(0.5) .* randn(rng, n)
  end
  for j in 1:p
    @views X[:, j] ./= sqrt(sum(abs2, X[:, j]) / n)
  end
  β = zeros(p)
  β[randperm(rng, p)[1:min(5, p)]] .= rand(rng, (-1.0, 1.0), min(5, p))
  y = X * β + 0.2randn(rng, n)
  s = 1 / n
  λ = fraction * lambda_max(X, y; s)
  (; key = String(key), kind, X, y, s, λ, w = ones(p))
end

function logistic_problem(rep, key; n = 120, p = 24, weighted = false)
  rng = scenario_rng(rep, key)
  X = randn(rng, n, p)
  offset = weighted ? 0.2randn(rng, n) : zeros(n)
  w_obs = weighted ? 0.5 .+ rand(rng, n) : ones(n)
  probability = 1 ./ (1 .+ exp.(-(X[:, 1:3] * [1.0, -0.5, 0.7] + offset)))
  y = Float64.(rand(rng, n) .< probability)
  (; key = String(key), kind = :logistic, X, y, s = 1 / n, λ = 0.04, w_obs, offset)
end

function grouped_problem(rep, key; n = 120, p = 32, sparse_group = false)
  a = regression_problem(rep, key; n, p)
  groups = [collect(j:min(j + 3, p)) for j in 1:4:p]
  w_group = sqrt.(Float64.(length.(groups)))
  merge(a, (; kind = sparse_group ? :sparse_group : :group, groups, w_group, α = 0.5))
end

function slope_problem(rep, key; n = 120, p = 32)
  a = regression_problem(rep, key; n, p)
  weights = a.λ .* collect(range(1.0, 0.4; length = p))
  merge(a, (; kind = :slope, λ = weights))
end

function quadratic_problem(rep, key; n = 120, p = 32)
  a = regression_problem(rep, key; n, p)
  A, b, c = a.s .* (a.X' * a.X), a.s .* (a.X' * a.y), a.s * sum(abs2, a.y) / 2
  merge(a, (; kind = :quadratic, A, b, c))
end

function glasso_problem(rep, key; n = 100, p = 12)
  rng = scenario_rng(rep, key)
  X = randn(rng, n, p)
  S = Matrix(Symmetric(X' * X / n + 0.2I))
  Λ = fill(0.08, p, p)
  for j in 1:p
    Λ[j, j] = 0
  end
  (; key = String(key), kind = :glasso, S, Λ)
end

function generalized_problem(rep, key; n = 80, p = 32)
  a = regression_problem(rep, key; n, p)
  D = spdiagm(p - 1, p, 0 => -ones(p - 1), 1 => ones(p - 1))
  (; key = String(key), kind = :generalized_lasso, X = a.X, y = a.y, s = a.s,
     μ = 0.5, D, λ1 = 0.05, λ2 = 0.12)
end

function nonconvex_problem(rep, key, kind; n = 120, p = 32)
  a = regression_problem(rep, key; n, p)
  L = a.s * opnorm(a.X)^2
  merge(a, (; kind, L, a = kind == :scad ? 3.7 : 3.0, k = min(5, p)))
end
