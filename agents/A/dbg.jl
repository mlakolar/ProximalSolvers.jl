include(joinpath(@__DIR__, "lib.jl"))
id="N40p120-0.05-s1"; T=Float32
prob=problem(id); o=oracle(id,T); X,y,λ=data(prob,T); Xd,yd,λd=Float64.(X),Float64.(y),Float64(λ)
β0=Float64.(T.(o.β)); S=findall(abs.(β0) .> 1e-9*norm(β0,Inf))
println("nnz ",count(!iszero,β0)," |S| ",length(S)," ‖r*‖/P ", norm(yd-Xd*β0)/(λd*norm(β0,1)))
rng=Xoshiro(1); β=copy(β0); β[S].+=1e-6*norm(β0,Inf)*randn(rng,length(S)); β=Float64.(T.(β))
r=yd-Xd*β; P=Float64(Pbig(X,y,λ,T.(β))); println("‖r‖/P ",norm(r)/P)
c=cand_B(Xd,yd,λd,β); println(c.info); v=vcert(Xd,yd,λd,λd,β,c.θ); println(v); println(bigcert(Xd,yd,λd,β,c.θ).ratio)
