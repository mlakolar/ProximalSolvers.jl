using ProximalSolvers,ProximalBase,Random,LinearAlgebra
module X2
include("<WORK>/ps-353-x2/src/ProximalSolvers.jl")
end
function main()
 B=ProximalSolvers;X=X2.ProximalSolvers;rng=Xoshiro(6)
 tiers=zeros(Int,3); changed=0; maxrel=0.0;maxulp=0; admitted=0; admittedchanged=0;maxadmit=0
 for trial in 1:60000
  n=rand(rng,(1,2,3,10,100,1000,10000));ey=rand(rng,-70:70)
  y=Float32.(randn(rng,n).*2.0^ey);isfinite(sum(y))||continue
  s2=sum(abs2,Float64.(y));l=rand(rng,-190:190);alpha=2.0^l/s2*(0.5+rand(rng))
  isfinite(alpha)&&alpha>0||continue
  s=0f0;for v in y;s+=v*v;end
  p=alpha*s;q=Float32(p)
  tier=!(isfinite(s)&&s>=4n*floatmin(Float32)) ? 3 : floatmin(Float32)<=q<=floatmax(Float32) ? 1 : floatmin(Float64)<=p<=floatmax(Float64)&&floatmin(Float32)<=Float32(sqrt(p))<=floatmax(Float32) ? 2 : 3
  tiers[tier]+=1;tier==2||continue
  ok=isfinite(Float32(alpha))&&Float32(alpha)>0
  admitted+=ok
  a=B.response_scale(B.LSModel(y,ones(Float32,n,1),alpha),nothing)
  b=X.response_scale(X.LSModel(y,ones(Float32,n,1),alpha),nothing)
  a===b&&continue
  changed+=1;admittedchanged+=ok
  units=abs(Int64(reinterpret(UInt32,a))-Int64(reinterpret(UInt32,b)))
  maxrel=max(maxrel,abs(Float64(a)-Float64(b))/(eps(Float32)*Float64(a)))
  maxulp=max(maxulp,units);ok&&(maxadmit=max(maxadmit,units))
 end
 println("Julia ",VERSION," tiers=",tiers," changes=",changed," max relative eps units=",maxrel," max actual ulps=",maxulp," admitted tier2=",admitted," admitted changed=",admittedchanged," max admitted ulps=",maxadmit)
end
main()
