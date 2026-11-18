# usage: julia run_stress.jl <tag> <id-regex>   -> out/stress_H_<tag>.tsv (+ _stages.txt)
include(joinpath(@__DIR__, "lib.jl"))
tag, rx = ARGS[1], Regex(ARGS[2])
S = deserialize(joinpath(@__DIR__, "..", "out", "stress_problems.jls"))
out = open(joinpath(@__DIR__, "..", "out", "stress_H_$tag.tsv"), "w")
logf = open(joinpath(@__DIR__, "..", "out", "stress_H_$(tag)_stages.txt"), "w")
println(out, join(["id", "T", "start", "mode", "stuck_conv", "stuck_passes", "Pstuck_over_Pstar", "stuck_excess", "fired",
                   "certified", "nstages", "passes", "secs", "MB", "ret_excess", "ret_ratio", "worse_than_stuck", "ret_nnz", "n", "p", "maxstagenz"], '\t'))
for pr in S.probs
  occursin(rx, pr.id) || continue
  for T in (Float64, Float32)
    rec = S.recs[(pr.id, string(T))]; haskey(rec, :err) && continue
    X, y, λ = data(pr, T)
    for (sname, b0) in pr.starts
      β0, conv, ps = stuck_point(X, y, λ, T.(b0))
      Pst = Pbig(X, y, λ, β0); Dor = big(rec.D)
      stuck_excess = Float64((Pst - Dor) / Dor)
      for mode in (:fixed, :adaptive)
        if conv
          println(out, join([pr.id, T, sname, mode, true, ps, Float64(Pst / Dor), stuck_excess, false, "", 0, 0, 0.0, 0.0, "", "", false, count(!iszero, β0), size(X, 1), size(X, 2), 0], '\t')); flush(out)
          continue
        end
        f = try fallback(X, y, λ, β0; stages = 10, adaptive = (mode === :adaptive)) catch e; (; err = sprint(showerror, e)) end
        if haskey(f, :err)
          println(out, join([pr.id, T, sname, mode, false, ps, Float64(Pst / Dor), stuck_excess, true, "ERROR", f.err], '\t')); flush(out); continue
        end
        Pret = Pbig(X, y, λ, f.β); ex = Float64((Pret - Dor) / Dor)
        println(out, join([pr.id, T, sname, mode, false, ps, Float64(Pst / Dor), stuck_excess, true, f.certified, f.nstages, f.passes,
                           round(f.secs; digits = 4), round(f.bytes / 2^20; digits = 2), ex, f.ratio, Pret > Pst, count(!iszero, f.β), size(X, 1), size(X, 2),
                           maximum(l.nnz for l in f.log)], '\t')); flush(out)
        println(logf, "== ", pr.id, " ", T, " ", sname, " ", mode, " Pst/P*=", Float64(Pst/Dor), " certified=", f.certified)
        for l in f.log; println(logf, "   ", l); end; flush(logf)
      end
    end
  end
end
close(out); close(logf)
