using Serialization
include("run.jl")
open("integration-replay.tsv","w") do io
  println(io,"case\tmethod\tlevels\tcertified\tmax_coefficient_difference\tmax_prediction_difference\tbitwise_equal")
  for id in (1,20,169,171),method in ("apg","hybrid")
    c=only(filter(c->c.id==id,cases()));d=data(c)
    previous=deserialize("rss-$id-$method.ser")
    result=julia_fit(d,method)
    checked=metrics(d,result)
    valid=length(checked)==c.depth && all(m.valid for m in checked)
    @test valid
    @test all(result.converged)
    coefficient=max((norm(a-b,Inf) for (a,b) in zip(previous.solutions,result.solutions))...)
    prediction=max((norm(d.X*(a-b),Inf) for (a,b) in zip(previous.solutions,result.solutions))...)
    @test prediction <= 1e-7*max(1.,norm(d.y,Inf))
    equal=all(a==b for (a,b) in zip(previous.solutions,result.solutions))
    println(io,join((id,method,length(checked),valid,coefficient,prediction,equal),'\t'))
  end
end
