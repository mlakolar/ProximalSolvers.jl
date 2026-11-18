# usage: julia run_hard.jl <file.jls> <out-tsv> <id-regex> ; runs variants h0 (orchestrator H: fixed c=1e-2, decade), fix1, trk1, trkh on every start.
include(joinpath(@__DIR__, "lib.jl"))
file, outf, rx = ARGS[1], ARGS[2], Regex(ARGS[3])
S = deserialize(file)
V = ["h0" => (; sched = :fixed, c = 1e-2, step = 1.0, stages = 10), "fix1" => (; sched = :fixed, c = 1.0, step = 1.0, stages = 16),
     "trk1" => (; sched = :track, c = 1.0, step = 1.0, stages = 16), "trkh" => (; sched = :track, c = 1.0, step = 0.5, stages = 28)]
out = open(outf, "w")
println(out, join(["id", "T", "start", "variant", "stuck_conv", "stuck_passes", "stuck_secs", "Pstuck_over_Pstar", "stuck_excess", "cert_code_stuck", "fired", "certified", "nstages", "passes", "secs", "MB", "ret_excess", "ret_ratio", "ret_nnz", "n", "p"], '\t'))
for pr in S.probs
  occursin(rx, pr.id) || continue
  for T in (Float64, Float32)
    rec = S.recs[(pr.id, string(T))]; haskey(rec, :err) && continue
    X, y, λ = data(pr, T)
    for (sname, b0) in pr.starts
      st = @timed stuck_point(X, y, λ, T.(b0)); β0, conv, ps = st.value
      Pst = Pbig(X, y, λ, β0); Dor = big(rec.D); code, _ = certify_at(X, y, λ, β0)
      for (vn, cfg) in V
        base = [pr.id, T, sname, vn, conv, ps, round(st.time; digits = 5), Float64(Pst / Dor), Float64((Pst - Dor) / Dor), code]
        if conv
          println(out, join([base..., false, "", 0, 0, 0.0, 0.0, "", "", count(!iszero, β0), size(X, 1), size(X, 2)], '\t')); continue
        end
        f = try fallback2(X, y, λ, β0; cfg...) catch e; (; err = sprint(showerror, e)) end
        haskey(f, :err) && (println(out, join([base..., true, "ERROR", f.err], '\t')); continue)
        Pret = Pbig(X, y, λ, f.β)
        println(out, join([base..., true, f.certified, f.nstages, f.passes, round(f.secs; digits = 4), round(f.bytes / 2^20; digits = 2),
                           Float64((Pret - Dor) / Dor), f.ratio, count(!iszero, f.β), size(X, 1), size(X, 2)], '\t')); flush(out)
      end
    end
  end
end
close(out)
