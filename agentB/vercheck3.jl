using ProximalSolvers, Random
const PS = ProximalSolvers
rng = Xoshiro(42)
open(ARGS[1], "w") do io
  for _ in 1:20000
    λ = ldexp(1 + rand(rng), rand(rng, -900:900)); α = ldexp(1.0 + rand(rng), rand(rng, -900:900)); a = ldexp(1.0 + rand(rng), rand(rng, -900:900))
    println(io, repr(λ), " ", repr(α), " ", repr(a), " ", repr(PS._threshold(Float64, λ, α, a)))
  end
end
