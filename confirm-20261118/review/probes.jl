include(joinpath(@__DIR__, "..", "scripts", "lib.jl"))
BLAS.set_num_threads(1)
println("Julia ", VERSION, " BLAS threads ",BLAS.get_num_threads())
for T in (Float64,Float32)
  X=T[1 1;0 .01];y=T[0,0];g=NormL1(T(.1));x=SparseIterate(T[1,-1]);m=PS.cdmodel(SqrtLeastSquaresLoss(y,X),x);PS.initialize!(m,x);PS._prepare!(m,g,x)
  PS._certify!(m,x);old=(m.cpup,m.cplo,m.cdlo)
  fill!(x,zero(T));code,ratio=PS._certify!(m,x)
  println("zero certificate ",T," code=",code," bounds=",(m.cpup,m.cplo,m.cdlo)," previous=",old)
end
# Compare all main-run M1/M1g returned vectors, re-evaluate bounds and result objective independently.
max_obj_rel=0.; mismatches=0; count=0; bounds_bad=0; result_bad=0
probs=vcat(dev_problems(),heldout_problems())
for prob in probs,T in (Float64,Float32),config in CONFIGS,st in prob.starts
  o=deserialize(joinpath(HERE,"..","out","oracle","$(prob.id)_$(T).jls"))
  X,y,λ=T.(prob.X),T.(prob.y),T(prob.λ);β0=start_point(prob,st,o.β)
  x0,r0,_,_=solve_mode(X,y,λ,β0,config;mode=:off)
  !r0.converged && r0.passes<100000 || continue
  x,r,_,lg=solve_mode(X,y,λ,β0,config;mode=:d2)
  xg,rg,_,lgg=solve_mode(X,y,λ,β0,config;mode=:d2,dual=m1g_dual)
  global count+=1
  if !(isequal(x,xg)&&r.converged==rg.converged&&lg.via==lgg.via&&lg.used==lgg.used)
    global mismatches+=1;println("MISMATCH ",prob.id,T,config,st)
  end
  c=cert_at(X,y,λ,x);P=Pbig(X,y,λ,x)
  if !(big(c.plo)<=P<=big(c.pup))
    global bounds_bad+=1;println("BAD BOUND ",prob.id,T,config,st)
  end
  rel=Float64(abs(big(r.minimum)-P)/P)
  global max_obj_rel=max(max_obj_rel,rel)
  if rel>100eps(T)
    global result_bad+=1;println("OBJECTIVE ",prob.id," ",T," ",config," ",st," retx0=",x==x0," minimum=",r.minimum," P=",Float64(P)," rel=",rel)
  end
end
println("replay count=",count," mismatches=",mismatches," bounds_bad=",bounds_bad," result_bad=",result_bad," max_obj_rel=",max_obj_rel)
