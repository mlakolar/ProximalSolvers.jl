include(joinpath(@__DIR__, "irlib.jl"))
vs = split(get(ENV, "VARS", "base,k"), ",")
tag = get(ENV, "TAG", "q1")
for T in (Float64, Float32)
  for v in vs
    PS = loadvariant(v)
    specs = sweep_specs(PS, T)
    for (i, tt) in enumerate(specs)
      txt = native_text(PS._sweep!, Tuple{tt.parameters[2:end]...})
      write(joinpath(OUT, "$tag-$(v)-$(T)-sweep$(i).s"), txt)
      llvm = llvm_text(PS._sweep!, Tuple{tt.parameters[2:end]...})
      write(joinpath(OUT, "$tag-$(v)-$(T)-sweep$(i).ll"), llvm)
      h = histo(txt)
      println(v, " ", T, " spec", i, " lines=", count(==('\n'), txt), " ninstr=", sum(values(h)), " sqrt=", sum((get(h, k, 0) for k in keys(h) if occursin("sqrt", k)); init=0), " div=", sum((get(h, k, 0) for k in keys(h) if occursin("div", k)); init=0),
        " call=", get(h, "call", 0), " jmp/j*=", sum((c for (k, c) in h if startswith(k, "j")); init=0))
    end
  end
end
