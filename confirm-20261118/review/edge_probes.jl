include(joinpath(@__DIR__,"..","scripts","lib.jl"))
BLAS.set_num_threads(1)
for T in (Float64,Float32)
 X=T[1 1];y=T[0];b=T[1,-1];λ=T(.1)
 for mode in (:off,:d2)
  try
   x,r,_,lg=solve_mode(X,y,λ,b,"cyclic-dense";mode)
   println("zero y ",T," ",mode," x=",x," conv=",r.converged," value=",r.minimum," lg=",lg)
  catch e
   println("ERROR zero y ",T," ",mode,": ",sprint(showerror,e))
  end
 end
end
# Finite data and objective, but certificate norm-square overflows Float64.
X=[1. 1.;0. .01]; b=[1.,-1.];y=X*b; λ=.1
for scale in (1e-200,1e200)
 for mode in (:off,:d2)
  try
   xs,rs,_,lg=solve_mode(X*scale,y*scale,λ*scale,b,"cyclic-dense";mode)
   println("range ",scale," ",mode," ret=",xs," conv=",rs.converged," minimum=",rs.minimum)
  catch e
   println("ERROR range ",scale," ",mode,": ",sprint(showerror,e))
  end
 end
end
# Change coefficient/response scale while keeping valid column curvature.
for scale in (1e-200,1e200)
 X=[1. 1.;0. .01];b=[1.,-1.]*scale;y=X*b;λ=.1
 for mode in (:off,:d2)
  try
   xs,rs,_,lg=solve_mode(X,y,λ,b,"cyclic-dense";mode)
   println("coefficient range ",scale," ",mode," conv=",rs.converged," minimum=",rs.minimum)
  catch e
   println("ERROR coefficient range ",scale," ",mode,": ",sprint(showerror,e))
  end
 end
end
# Observe stage points without adding a dual bound.
seen=Any[]
hook=(m,x)->(push!(seen,(Vector(x),m.cpup,m.cplo));0.0)
solve_mode([1. 1.],[0.],.1,[1.,-1.],"cyclic-dense";mode=:d2,dual=hook)
println("zero-y stage points and exposed bounds: ",seen)
