include(joinpath(@__DIR__, "lib.jl")); include(joinpath(@__DIR__, "pts.jl"))
pt = only(filter(p -> p.set == "M81" && p.id == "D10-s1" && p.T == "Float64" && p.start == "zero" && p.config == "random-owner", points()))
prob = problem(pt.id); X, y, λ = data(prob, Float64)
β = pt.β; println("nnz ", count(!iszero, β), " sorted |β| ", sort(abs.(β[β .!= 0]); rev = true)[1:min(10, end)])
for e in (1e-6, 1e-5, 3e-5)
  S = effsupport(β, e); println("εdrop=", e, " S=", S, " rank=", rank(X[:, S]))
  b = cand_B(X, y, λ, β; εdrop = e); c = cand_Bc(X, y, λ, β; εdrop = e)
  println("  B ", b.info.status, " ", vcert(X, y, λ, λ, β, b.θ).ratio, "   Bc ", c.info.status, " ", vcert(X, y, λ, λ, β, c.θ).ratio)
end
