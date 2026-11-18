using ProximalBase, ProximalSolvers
const PB = ProximalBase; const PS = ProximalSolvers
println(VERSION, " ", pathof(PB))
println(names(PB; all=false) |> length, " exported/public names (names())")
println(PB._scaled_product(0.75, 1.0, -1074))
println(isdefined(PB, :NumericalKernels))
@static if VERSION >= v"1.11"
  println("public: ", sort([n for n in names(PB) if Base.ispublic(PB,n) && !Base.isexported(PB,n)]))
end
