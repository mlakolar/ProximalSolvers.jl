include("<RUN>/scripts/common.jl")
setprecision(BigFloat,512)
function checkrounding()
  nd=0;nu=0;examples=0
  for (key,o) in sort(collect(ORACLE.recs);by=first)
    id,ts=key;T=ts=="Float64" ? Float64 : Float32;X,y,lambda=data(problem(id),T)
    xb,yb,th=big.(X),big.(y),big.(o.θ)
    t=min(big(1),1/norm(th),big(lambda)/maximum(abs,xb'*th))
    D=t*dot(th,yb);U=Pbig(X,y,lambda,o.β)
    nd+=big(o.D)>D;nu+=big(o.U)<U
    if (big(o.D)>D || big(o.U)<U) && examples<3
      println(key," storedD-minus-rederivedD=",Float64(big(o.D)-D)," storedU-minus-P=",Float64(big(o.U)-U));examples+=1
    end
  end
  println("stored D above rederived witness in ",nd,"/160; stored U below P(oracle beta) in ",nu,"/160")
end
checkrounding()
