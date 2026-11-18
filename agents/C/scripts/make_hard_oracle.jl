include(joinpath(@__DIR__, "hard.jl"))
probs = hard_problems(); recs = Dict{Tuple{String,String},Any}()
for pr in probs, T in (Float64, Float32)
  t = @elapsed (rec = try oracle_for(pr.X, pr.y, pr.λ, T) catch e; (; err = sprint(showerror, e)) end)
  recs[(pr.id, string(T))] = rec
  haskey(rec, :err) ? (@printf "%-28s %-7s ERROR %s\n" pr.id T rec.err) :
    @printf "%-28s %-7s n=%4d p=%5d λ=%.3e P*∈[%.8e,%.8e] w=%.1e rrel=%.1e exact=%s %s (%.1fs) | %s\n" pr.id T size(pr.X,1) size(pr.X,2) pr.λ rec.D rec.U rec.relwidth rec.rrel rec.exactfit rec.status t pr.desc
end
serialize(joinpath(@__DIR__, "..", "out", "hard_problems.jls"), (; probs, recs))
