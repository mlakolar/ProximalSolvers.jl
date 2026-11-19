include(joinpath(@__DIR__,"..","scripts","lib.jl"))
module OldModule
include(joinpath(@__DIR__,"..","perf","old","src","ProximalSolvers.jl"))
end
const OLD=OldModule.ProximalSolvers
rng=Xoshiro(123); mismatches=0;count=0
for trial in 1:4000,T in (Float64,Float32)
 n=rand(rng,2:12);scale=trial%4==0 ? T(2.0^-70) : one(T)
 X=T.(randn(rng,n,3)).*scale;b=T.(randn(rng,3));y=trial%3==0 ? X*b : X*b+T.(randn(rng,n)).*scale.*T(.1)
 λ=T(rand(rng)*.8)*norm(X[:,1]);x=SparseIterate(b)
 f=SqrtLeastSquaresLoss(y,X);g=NormL1(λ)
 m=PS.cdmodel(f,x);OLDm=OLD.cdmodel(f,x)
 for (mod,mo) in ((PS,m),(OLD,OLDm));mod.initialize!(mo,x);mod._prepare!(mo,g,x);end
 a,bb,rr=PS._column_dot_rsqr(X,m.ls.r,1,T(NaN));z=PS._sqrt_minimizer(m,x[1],a,bb,rr,1)
 za=OLD._sqrt_minimizer(OLDm,x[1],a,bb,rr,1)
 global count+=1
 if !isequal(z,za);global mismatches+=1;println("mismatch ",trial," ",T," ",z," ",za);end
end
println("delta=0 step comparisons ",count," mismatches ",mismatches)
