# Oracle records for the held-out set (protocol §3). Usage: julia gen_oracle.jl <worker> <nworkers>
include(joinpath(@__DIR__, "lib.jl"))
using JuMP, Clarabel
include(joinpath(@__DIR__, "oracle_lib.jl"))
const W, NW = parse(Int, ARGS[1]), parse(Int, ARGS[2])
dir = joinpath(HERE, "..", "out", "oracle"); mkpath(dir)
probs = vcat(dev_problems(), heldout_problems())
for (i, prob) in enumerate(probs), T in (Float64, Float32)
  ((2i + (T == Float32)) % NW == W) || continue
  f = joinpath(dir, "$(prob.id)_$(T).jls"); isfile(f) && continue
  X, y, λ = Float64.(T.(prob.X)), Float64.(T.(prob.y)), Float64(T(prob.λ))
  t = @elapsed begin
    β, sp = primal(X, y, λ); θ, sd = dual(X, y, λ)
  end
  U = Pbig(X, y, λ, β); D, θf = dual_lower(X, y, λ, θ)
  rrel = Float64(norm(big.(y) - big.(X) * big.(β)) / norm(big.(y)))
  rec = (; id = prob.id, T = string(T), β, U = Float64(U), D = Float64(D), Ubig = U, Dbig = D,
         relwidth = Float64((U - D) / D), rrel, exactfit = rrel < 1e-8, status = (sp, sd), secs = t)
  serialize(f, rec)
  @printf "%-28s %-7s width %.1e rrel %.1e %s %.1fs\n" prob.id T rec.relwidth rrel rec.status t
end
