using Serialization
include("run.jl")
id=parse(Int,ARGS[1]);method=ARGS[2];output=ARGS[3]
c=only(filter(c->c.id==id,cases()));d=data(c)
input=method=="libslope" ? NativeInput(d.X) : nothing
fit()=method=="libslope" ? native(d,input) : julia_fit(d,method)
fit() # compile and warm only the selected solver
GC.gc()
result=fit()
serialize(output,(;id,method,solutions=result.solutions))
println("RSS_FIT_COMPLETE case=",id," method=",method," levels=",length(result.solutions))
