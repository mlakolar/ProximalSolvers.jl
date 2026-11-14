# Runs repro.jl once per variant in a fresh process: julia --project=. runvariants.jl sweep v1 v2 ...
using Pkg; Pkg.instantiate(); Pkg.precompile()
sweep = ARGS[1]
datasets = ARGS[2]
for v in ARGS[3:end]
  out = "repro-$(replace(v, '+' => '_'))-s$(sweep).tsv"
  cmd = `$(Base.julia_cmd()) --project=. --startup-file=no $(joinpath(@__DIR__, "repro.jl")) $out $v $sweep $datasets`
  t = @elapsed ok = success(pipeline(cmd; stdout = devnull, stderr = stderr))
  println("=====VARIANT $v sweep=$sweep ok=$ok seconds=$(round(t; digits=1))")
  println("=====TSV BEGIN $out"); isfile(out) && print(read(out, String)); println("=====TSV END")
end
