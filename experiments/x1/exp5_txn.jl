# X1 experiment 5: a refusal inside a pass leaves the caller's x unchanged (dense Vector and SparseIterate owner), BASE/X1A/X1B.
include("x1lib.jl")
function hdr(x) x isa SparseIterate ? (Vector(x), nactive(x), collect(ProximalBase.activecoordinates(x))) : (copy(x),) end
println("# Julia ", VERSION)
for T in (Float64,)
  rng = Xoshiro(1); n, p = 30, 8
  X = randn(rng, T, n, p); y = randn(rng, T, n)
  for (label, colscale, rows) in (("column 5 at 2^-520 (BASE solves, prototypes refuse)", (5, -520), nothing),
                                  ("column 8 at 2^-520, last column", (8, -520), nothing),
                                  ("column 1 at 2^-1070 (curvature underflows: BASE refuses too)", (1, -1070), nothing))
    Xs = copy(X); Xs[:, colscale[1]] = ldexp.(Xs[:, colscale[1]], colscale[2])
    λ = T(0.3 * norm(Xs' * y, Inf) / norm(y))
    λ = isfinite(λ) && λ > 0 ? λ : T(0.5)
    for owner in (false, true), warm in (false, true), order in (:cyclic, :random)
      x0 = warm ? T.(0.01 .* randn(Xoshiro(2), p)) : zeros(T, p)
      res = Dict()
      for t in TNAMES
        P = getproperty(TREES, t)
        x = owner ? SparseIterate(copy(x0)) : copy(x0)
        h0 = hdr(x)
        out = try
          with_logger(NullLogger()) do; P.solve!(x, SqrtLeastSquaresLoss(y, Xs), NormL1(λ), P.CDSolver(; order, rng = Xoshiro(5))); end
          "solved"
        catch e
          "throws " * first(sprint(showerror, e), 45)
        end
        res[t] = (out, hdr(x) == h0)
      end
      println(rpad(label, 62), " owner=", rpad(owner, 5), " warm=", rpad(warm, 5), " ", rpad(order, 7), join([" | $t: $(res[t][1]) x_unchanged_on_throw=$(startswith(res[t][1], "throws") ? res[t][2] : "n/a")" for t in TNAMES]))
    end
  end
end
