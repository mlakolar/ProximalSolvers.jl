include(joinpath(@__DIR__, "stress.jl"))
probs = stress_problems()
recs = Dict{Tuple{String,String},Any}()
for pr in probs, T in (Float64, Float32)
  t = @elapsed (rec = try
    if occursin(r"^(TINY|BIG)", pr.id)       # power-of-two y scale: oracle of the unscaled problem, scaled exactly
      f = pr.y[1] / noiseless(20, 60, 3, 3001)[2][1]
      r0 = oracle_for(pr.X, pr.y ./ f, pr.λ, T)
      merge(r0, (; β = f .* r0.β, U = f * r0.U, D = f * r0.D))
    else
      oracle_for(pr.X, pr.y, pr.λ, T)
    end
  catch e; (; err = sprint(showerror, e)) end)
  recs[(pr.id, string(T))] = rec
  if haskey(rec, :err)
    @printf "%-28s %-7s ERROR %s\n" pr.id T rec.err
  else
    @printf "%-28s %-7s n=%4d p=%4d λ=%.3e P*∈[%.8e,%.8e] w=%.1e rrel=%.1e exact=%s %s (%.1fs)\n" pr.id T size(pr.X,1) size(pr.X,2) pr.λ rec.D rec.U rec.relwidth rec.rrel rec.exactfit rec.status t
  end
end
serialize(joinpath(@__DIR__, "..", "out", "stress_problems.jls"), (; probs, recs))
