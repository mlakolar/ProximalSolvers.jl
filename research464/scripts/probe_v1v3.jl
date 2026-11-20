# Where v1 and v3 can differ: an active coordinate with c₂ far above λmax. X = [1 M; 0 1] + noise (κ ≈ M²),
# y = [1, -M] + noise, x₁ free, c₂ = f M. Float32 and Float64, APG and PGD, long runs, zero and reference starts.
ENV["STUDY_NO_MAIN"] = "1"
include(joinpath(@__DIR__, "study464.jl"))
for (T, Ms) in ((Float32, (30f0, 100f0, 300f0, 1000f0)), (Float64, (1e3, 1e5))), M in Ms, f in (0.3, 0.9)
  rng = MersenneTwister(round(Int, M))
  X = T.([1 M; 0 1] .+ 0.01 .* randn(rng, 2, 2))
  y = T.([1, -M] .+ 0.01 .* randn(rng, 2))
  opts = ProximalOptions(maxiter = 200_000)
  # exact reference from the KKT system in BigFloat (x₁ free; x₂ active with sign s, else x₂ = 0)
  A, b, c = big.(X), big.(y), big(T(f * M))
  Pref = nothing
  for s in (1, -1)
    x = (A' * A) \ (A' * b - [0, c * s])
    sign(x[2]) == s && (Pref = x)
  end
  Pref === nothing && (Pref = [dot(A[:, 1], b) / dot(A[:, 1], A[:, 1]), big(0)])
  runcase("P active c₂=$(f)M, M=$(M)", :ls, X, y, f * M, T[0, 1], LS2; starts = (:zero, :reference),
          options = opts, rules = (:v0, :v1, :v3), Pref = Pref)
end
open(isempty(ARGS) ? "probe_v1v3.tsv" : ARGS[1], "w") do io
  println(io, HEADER); foreach(r -> println(io, r), ROWS)
end
