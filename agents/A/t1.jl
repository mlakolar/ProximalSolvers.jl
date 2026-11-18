include(joinpath(@__DIR__, "lib.jl"))
# A156 fixture
X = [1.0 2.0; 0.0 1.0]; y = [1.0, 0.0]; λ = 0.1; β = [1.0, 0.0]
for (nm, f) in (("A", cand_A), ("B", cand_B))
  c = f(X, y, λ, β); r = vcert(X, y, λ, λ, β, c.θ); b = bigcert(X, y, λ, β, c.θ)
  println(nm, " θ=", c.θ, " info=", c.info, "\n   vcert=", r, "\n   big=", (b.t, b.D, b.P, b.ratio))
end
c = cand_D(X, y, λ, β, θ -> vcert(X, y, λ, λ, β, θ)); println("D ", c.θ, c.info, " ", vcert(X, y, λ, λ, β, c.θ))
