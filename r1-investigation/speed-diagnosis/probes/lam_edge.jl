include(joinpath(@__DIR__, "irlib.jl"))
using ProximalBase, Random
Pb = loadvariant("base"); Pc = loadvariant("cand_final")
X = randn(Xoshiro(1), 30, 8); y = randn(Xoshiro(2), 30)
for lam in (-0.1, NaN, 0.0, Inf, 1e-300, 0.3)
  for (nm, P) in (("base", Pb), ("cand", Pc))
    res = try
      g = NormL1(lam); x = zeros(8)
      r = with_logger(NullLogger()) do; P.solve!(x, SqrtLeastSquaresLoss(y, X), g, P.CDSolver(order = :cyclic, maxpasses = 50)); end
      string("ok passes=", r.passes, " conv=", r.converged, " nnz=", count(!iszero, x), " obj=", r.minimum)
    catch e
      string("throws ", typeof(e), ": ", first(sprint(showerror, e), 70))
    end
    println(rpad(string(lam), 8), nm, " ", res)
  end
end
