using Pkg
Pkg.instantiate()
for (fam, T, d) in (("scalar", "Float32", "4"), ("scalar", "Float64", "2"), ("group", "Float32", "2"))
  out = tempname()
  run(`$(Base.julia_cmd()) --startup-file=no --project=$(Base.active_project()) $(joinpath(@__DIR__, "protosweep.jl")) $out $fam $T $d $(ARGS[1]) smoke`)
  println("=== ", fam, " ", T, " ", d)
  print(read(out, String))
end
