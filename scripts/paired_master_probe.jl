# A fresh child process for one isolated side of paired_master_diagnostics.jl.
using ProximalBase, ProximalSolvers, LinearAlgebra, Random, SparseArrays, TOML, Logging
include(joinpath(@__DIR__, "paired_master_diagnostics.jl"))
const PM = PairedMasterDiagnostics
const PB = ProximalBase
const PS = ProximalSolvers
BLAS.set_num_threads(1)
length(ARGS) == 6 || error("expected exact PS/PB paths, commits and source digests")
ps_root, ps_sha, ps_digest, pb_root, pb_sha, pb_digest = ARGS
realpath(pathof(PS)) == realpath(joinpath(ps_root, "src", "ProximalSolvers.jl")) || error("wrong loaded PS path")
realpath(pathof(PB)) == realpath(joinpath(pb_root, "src", "ProximalBase.jl")) || error("wrong loaded PB path")
ps_identity = PM.checkout_identity(ps_root, ps_sha; digest = ps_digest)
pb_identity = PM.checkout_identity(pb_root, pb_sha; digest = pb_digest)
PM.pinned_revision(ps_root) == pb_sha || error("PS/PB pin mismatch")
bits(v::Union{Float32, Float64}) = string(typeof(v), ":", bitstring(v))
bits(v::AbstractArray) = bits.(v)

# Independent Float64 arithmetic, including evaluation of Float32 solutions at
# wider precision. These helpers never call PB prox or PS caches/stopping code.
function objective_kkt(X, y, x, scale, lambda)
  A, b, z = Float64.(X), Float64.(y), Float64.(x)
  residual = A * z - b
  gradient = Float64(scale) .* (A' * residual)
  objective = Float64(scale) * sum(abs2, residual) / 2 + Float64(lambda) * sum(abs, z)
  kkt = maximum(eachindex(z)) do j
    iszero(z[j]) ? max(abs(gradient[j]) - Float64(lambda), 0.0) :
      abs(gradient[j] + Float64(lambda) * sign(z[j]))
  end
  objective, kkt, A * z
end

# Enumerate all signed supports of the two-dimensional full-rank problem.
# The singular fixture reduces independently to one fitted coefficient.
function reference(X, y, scale, lambda, nonunique)
  A, b, alpha, penalty = Float64.(X), Float64.(y), Float64(scale), Float64(lambda)
  if nonunique
    c = A[:, 1]
    slope, curvature = alpha * dot(c, b), alpha * dot(c, c)
    coefficient = sign(slope) * max(abs(slope) - penalty, 0.0) / curvature
    return [coefficient, 0.0, 0.0]
  end
  H, q = alpha .* (A' * A), alpha .* (A' * b)
  best, best_value = zeros(2), Inf
  for s1 in -1:1, s2 in -1:1
    signs = [s1, s2]
    support = findall(!iszero, signs)
    z = zeros(2)
    isempty(support) || (z[support] = H[support, support] \ (q[support] - penalty .* signs[support]))
    all(j -> signs[j] * z[j] > 0, support) || continue
    gradient = H * z - q
    all(j -> j in support || abs(gradient[j]) <= penalty + 64eps(Float64) * max(1, norm(q, Inf)), 1:2) || continue
    value = alpha * sum(abs2, A * z - b) / 2 + penalty * sum(abs, z)
    if value < best_value
      best, best_value = z, value
    end
  end
  isfinite(best_value) || error("independent signed-support reference failed")
  best
end

records = Dict{String, Any}()
for T in (Float32, Float64), design in ("orthogonal", "correlated", "nonunique")
  X = design == "orthogonal" ? T[1 0; 0 1; -1 0; 0 -1] :
      design == "correlated" ? T[1 .25; -.5 1; .75 -.25; 1 1] :
      T[1 1 0; -.5 -.5 0; .75 .75 0; 1 1 0]
  y = design == "orthogonal" ? T[1.25, -.75, -1.25, .75] : T[1, -.5, .75, .125]
  nonunique = design == "nonunique"
  for (scale_id, scale) in enumerate((one(T), T(.25))),
      (penalty_id, lambda) in enumerate((zero(T), T(.125), T(10))), start_id in 1:2,
      method_name in ("random", "cyclic", "pgd")
    x = start_id == 1 ? zeros(T, size(X, 2)) : T.(range(-.25, .5; length = size(X, 2)))
    f = scale_id == 1 ? LeastSquaresLoss(y, X) : scale * LeastSquaresLoss(y, X)
    g = NormL1(lambda)
    rng = Xoshiro(713)
    method = method_name == "random" ? CDSolver(; rng) :
             method_name == "cyclic" ? CDSolver(; order = :cyclic, momentum = false, rng) :
             ProximalGradientDescent()
    result = with_logger(NullLogger()) do
      method_name == "pgd" ? solve!(x, f, g, method, ProximalOptions(; maxiter = 10_000,
        ftol = eps(T)^2, xtol = eps(T)^2, gradtol = T == Float32 ? 1e-6 : 1e-10)) :
        solve!(x, f, g, method)
    end
    result.minimizer === x || error("result lost caller iterate identity")
    objective, kkt, fitted = objective_kkt(X, y, x, scale, lambda)
    solution = reference(X, y, scale, lambda, nonunique)
    optimum, _, reference_fit = objective_kkt(X, y, solution, scale, lambda)
    tolerance = T == Float32 ? 5e-4 : 2e-6
    objective_scale = max(1.0, abs(optimum))
    isfinite(objective) && objective - optimum <= tolerance * objective_scale || error("independent objective failure")
    kkt <= tolerance * max(1.0, Float64(scale) * norm(Float64.(X)' * Float64.(y), Inf), Float64(lambda)) ||
      error("independent KKT failure: $T/$design/$scale_id/$penalty_id/$start_id/$method_name: $kkt")
    abs(Float64(result.minimum) - objective) <= tolerance * objective_scale || error("returned objective mismatch")
    norm(fitted - reference_fit, Inf) <= 4tolerance * max(1, norm(reference_fit, Inf)) || error("independent fitted-value failure")
    nonunique || norm(Float64.(x) - solution, Inf) <= 4tolerance * max(1, norm(solution, Inf)) || error("independent coefficient failure")
    record = Dict{String, Any}("minimum" => bits(result.minimum), "objective" => objective,
      "kkt" => kkt, "fitted" => fitted, "rng_next" => string(rand(rng, UInt64)))
    nonunique || (record["point"] = bits(x))
    for name in (:passes, :iterations, :converged, :iteration_converged, :x_converged,
        :x_residual, :f_converged, :f_residual, :grad_converged, :g_residual,
        :f_increased, :maxchange, :tolerance, :kkt_checks, :gap, :backtrack_steps,
        :f_calls, :grad_calls, :prox_calls, :call_limit_reached)
      hasproperty(result, name) || continue
      value = getproperty(result, name)
      record[string(name)] = value isa Union{Float32, Float64} ? bits(value) : value
    end
    records["lasso/$T/$design/$scale_id/$penalty_id/$start_id/$method_name"] = record
  end
end

# Exercise the scalar oracle itself, including thresholds, without a compatibility alias.
selector = pb_sha == PM.PB_A ? :prox_entry : :prox_block
isdefined(PB, selector) || error("missing expected scalar oracle $selector")
scalar_prox = getfield(PB, selector)
for T in (Float32, Float64), (li, lambda) in enumerate((zero(T), T(.125), T(10))),
    (si, step) in enumerate((one(T), T(.5))), (vi, value) in enumerate(T[-2, -.25, 0, .25, 2])
  answer = scalar_prox(NormL1(lambda), value, 2, step)
  expected = sign(Float64(value)) * max(abs(Float64(value)) - Float64(step) * Float64(lambda), 0.0)
  answer isa T && answer == T(expected) || error("independent scalar oracle failure")
  records["scalar/$T/$li/$si/$vi"] = Dict("value" => bits(answer))
end

# The public iterate stays dense; only this exact PB owner contract is private to CD.
function owner_record(owner)
  Dict("dimension" => PB.ncoordinates(owner), "active" => PB.nactive(owner),
    "coordinates" => collect(PB.activecoordinates(owner)), "values" => bits(PB.activevalues(owner)),
    "dense" => bits(Vector(owner)))
end
for T in (Float32, Float64)
  owner = PB.SparseIterate(T[0, 2, 0, -1])
  records["owner/$T/construct"] = owner_record(owner)
  handle = PB.activecoordinates(owner)
  owner[1] = T(3)
  # Existing handles retain their captured length; reacquire after activation.
  length(handle) == 2 && PB.nactive(owner) == 3 || error("owner activation/handle contract changed")
  records["owner/$T/activate"] = merge(owner_record(owner), Dict("previous_handle_length" => length(handle)))
  owner[2] = zero(T)
  PB.nactive(owner) == 3 || error("zero update unexpectedly compacted owner")
  records["owner/$T/zero"] = owner_record(owner)
  dropzeros!(owner)
  PB.nactive(owner) == 2 || error("owner compaction failed")
  records["owner/$T/compact"] = owner_record(owner)
  clone = copy(owner)
  records["owner/$T/copy"] = owner_record(clone)
  output = zeros(T, 4)
  copyto!(output, clone)
  output == T[3, 0, 0, -1] || error("private owner dense scatter changed")
  records["owner/$T/scatter"] = Dict("dense" => bits(output))
end
PM.checkout_identity(ps_root, ps_sha; digest = ps_digest)
PM.checkout_identity(pb_root, pb_sha; digest = pb_digest)
document = Dict("format" => 1, "records" => records,
  "provenance" => Dict("PS" => ps_identity, "PB" => pb_identity,
    "julia" => string(VERSION), "blas" => sprint(show, BLAS.get_config())))
PM.checked_records(document)
TOML.print(stdout, document; sorted = true)
