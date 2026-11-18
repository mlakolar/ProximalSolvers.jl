# smoke: two designs, both precisions and families, to stdout
using Pkg
Pkg.instantiate()
for (fam, T, d) in (("scalar", "Float32", "4"), ("scalar", "Float64", "8"), ("group", "Float32", "2"), ("group", "Float64", "4"))
  out = tempname()
  run(`$(Base.julia_cmd()) --startup-file=no --project=$(Base.active_project()) $(joinpath(@__DIR__, "sweep378.jl")) $out $fam $T $d smoke`)
  println("=== ", fam, " ", T, " ", d)
  print(read(out, String))
end
