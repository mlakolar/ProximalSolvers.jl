using Serialization
include("run.jl")
open("rss-validation.tsv","w") do io
  println(io,"case\tmethod\treturned\tcertified\tmax_gap\tmax_residual\ttiming_file\tnative_tolerance")
  for id in (1,20,169,171),method in ("apg","hybrid","libslope")
    c=only(filter(c->c.id==id,cases()));d=data(c)
    prefix=method=="libslope" ? get(ENV,"MATCH_RSS_NATIVE_PREFIX","rss") : "rss"
    r=deserialize("$prefix-$id-$method.ser")
    @test r.id==id && r.method==method
    @test all(length(x)==size(d.X,2) for x in r.solutions)
    checked=metrics(d,r)
    valid=length(checked)==length(d.grid)&&all(m.valid for m in checked)
    println(io,join((id,method,length(checked),valid,
      isempty(checked) ? Inf : maximum(m.dual_gap for m in checked),
      isempty(checked) ? Inf : maximum(m.residual for m in checked),
      "$prefix-$id-$method.time",method=="libslope" ? get(ENV,"MATCH_NATIVE_TOL","1e-8") : "n/a"),'\t'))
  end
end
