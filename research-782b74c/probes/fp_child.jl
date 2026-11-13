# fp_child.jl <outfile> <shard_i> <shard_k> <limit>   (one tree, one fresh process; the tree is --project)
#            warm                                      (instantiate, header and guard only)
include(joinpath(@__DIR__, "common.jl"))
const FP_WARM = !isempty(ARGS) && ARGS[1] == "warm"
ensure_env()
using ProximalBase: LeastSquaresLoss, NormL1
using ProximalSolvers
TREE_DIR_REF[] = pkgdir(ProximalSolvers)
include(joinpath(@__DIR__, "corpus.jl"))
include(joinpath(@__DIR__, "runner.jl"))

function fp_main(outfile, shard_i, shard_k, limit)
  cases = corpus_cases()
  total = length(cases)
  shard_k > 1 && (cases = cases[shard_i:shard_k:end])
  limit > 0 && (cases = cases[1:min(limit, end)])
  println("FP corpus total ", total, ", this run ", length(cases), " (shard ", shard_i, "/", shard_k, ", limit ", limit, ")")
  digests = Dict{String,Vector{UInt8}}()
  counts = Dict{String,Int}()
  nthrow = Dict{String,Int}()
  manual_false = 0
  manual_true = 0
  t0 = time()
  open(outfile, "w") do io
    for (i, sc) in enumerate(cases)
      rec = case_record(sc)
      write(io, rec)
      key = string(sc.solver, "/", sc.T)
      append!(get!(digests, key, UInt8[]), SHA.sha1(rec))
      counts[key] = get(counts, key, 0) + 1
      occursin("\nOUTCOME throw", rec) && (nthrow[key] = get(nthrow, key, 0) + 1)
      occursin("\nMANUAL_SAME false", rec) && (manual_false += 1)
      occursin("\nMANUAL_SAME true", rec) && (manual_true += 1)
      i % 1000 == 0 && println("FP progress ", i, "/", length(cases), " ", round(time() - t0; digits = 1), " s")
    end
  end
  println("FP records ", sum(values(counts)), " in ", round(time() - t0; digits = 1), " s; file ", outfile, " ",
          filesize(outfile), " bytes")
  for k in sort!(collect(keys(counts)))
    println("FP group ", k, " records=", counts[k], " throw=", get(nthrow, k, 0), " digest=", sha1hex(digests[k]))
  end
  println("FP manual-path agreement: same=", manual_true, " different=", manual_false)
  println("FP file sha256 ", bytes2hex(SHA.sha256(read(outfile))))
end

env_header()
if FP_WARM
  println("FP warm done")
else
  length(ARGS) == 4 || error("usage: fp_child.jl outfile shard_i shard_k limit")
  fp_main(ARGS[1], parse(Int, ARGS[2]), parse(Int, ARGS[3]), parse(Int, ARGS[4]))
end
