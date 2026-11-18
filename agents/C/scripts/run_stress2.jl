# usage: julia run_stress2.jl <tag> <id-regex> <variant>   variants: fix1 (fixed c=1 decade), trk1 (track c=1 decade), trkh (track c=1 half-decade),
#        fix1h (fixed c=1 half-decade), trk01 (track c=0.1 half-decade)
include(joinpath(@__DIR__, "lib.jl"))
tag, rx, variant = ARGS[1], Regex(ARGS[2]), ARGS[3]
cfg = Dict("fix1" => (; sched = :fixed, c = 1.0, step = 1.0, stages = 16), "trk1" => (; sched = :track, c = 1.0, step = 1.0, stages = 16),
           "trkh" => (; sched = :track, c = 1.0, step = 0.5, stages = 28), "fix1h" => (; sched = :fixed, c = 1.0, step = 0.5, stages = 28),
           "trk01" => (; sched = :track, c = 0.1, step = 0.5, stages = 28))[variant]
S = deserialize(joinpath(@__DIR__, "..", "out", "stress_problems.jls"))
out = open(joinpath(@__DIR__, "..", "out", "stress2_$(variant)_$tag.tsv"), "w")
println(out, join(["id", "T", "start", "variant", "stuck_conv", "Pstuck_over_Pstar", "fired", "certified", "nstages", "passes", "secs", "MB", "ret_excess", "ret_ratio", "ret_nnz", "n", "p"], '\t'))
for pr in S.probs
  occursin(rx, pr.id) || continue
  for T in (Float64, Float32)
    rec = S.recs[(pr.id, string(T))]; haskey(rec, :err) && continue
    X, y, λ = data(pr, T)
    for (sname, b0) in pr.starts
      β0, conv, ps = stuck_point(X, y, λ, T.(b0))
      Pst = Pbig(X, y, λ, β0); Dor = big(rec.D)
      if conv
        println(out, join([pr.id, T, sname, variant, true, Float64(Pst / Dor), false, "", 0, 0, 0.0, 0.0, "", "", count(!iszero, β0), size(X, 1), size(X, 2)], '\t')); continue
      end
      f = try fallback2(X, y, λ, β0; cfg...) catch e; (; err = sprint(showerror, e)) end
      haskey(f, :err) && (println(out, join([pr.id, T, sname, variant, false, Float64(Pst / Dor), true, "ERROR", f.err], '\t')); continue)
      Pret = Pbig(X, y, λ, f.β)
      println(out, join([pr.id, T, sname, variant, false, Float64(Pst / Dor), true, f.certified, f.nstages, f.passes, round(f.secs; digits = 4), round(f.bytes / 2^20; digits = 2),
                         Float64((Pret - Dor) / Dor), f.ratio, count(!iszero, f.β), size(X, 1), size(X, 2)], '\t')); flush(out)
    end
  end
end
close(out)
