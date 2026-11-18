function outcome(T, X, y, λ; order = :cyclic)
  xs = zeros(T, size(X, 2))
  try
    r = Base.invokelatest(() -> with_logger(NullLogger()) do
      solve!(xs, SqrtLeastSquaresLoss(y, X), NormL1(λ), CDSolver(; order, rng = Xoshiro(5)))
    end)
    (ok = true, x = copy(xs), conv = r.converged, passes = r.passes, gap = r.gap, msg = "")
  catch e
    (ok = false, x = xs, conv = false, passes = 0, gap = NaN, msg = first(split(sprint(showerror, e), '\n'))[1:min(end, 100)])
  end
end
function inst(T, sx, sy; n = 30, p = 8, lf = 0.3)
  rng = Xoshiro(11)
  X0 = randn(rng, n, p); y0 = randn(rng, n)
  X = T.(ldexp.(X0, sx)); y = T.(ldexp.(y0, sy))
  (all(isfinite, X) && all(isfinite, y) && any(!iszero, X) && any(!iszero, y)) || return nothing
  λ = try T(lf*lam_max(X, y)) catch; return nothing end
  (isfinite(λ) && λ > 0) || return nothing
  X, y, λ
end
code(o) = !o.ok ? 'T' : o.conv ? 'C' : 'u'     # T throws, C converged (certified), u ok but uncertified
function runs(sym, T, rng_s, f)
  s = ""; 
  for k in rng_s
    i = f(k); i === nothing && (s *= '.'; continue)
    s *= code(outcome(T, i...))
  end
  s
end
function intervals(str, rng_s)
  out = String[]; start = 1
  for i in 2:length(str)+1
    if i > length(str) || str[i] != str[start]
      push!(out, "$(str[start])[$(rng_s[start])..$(rng_s[i-1])]"); start = i
    end
  end
  join(out, " ")
end
function axes_report(label)
  println("## ", label)
  for T in (Float32, Float64)
    rs = T === Float32 ? (-150:75) : (-1075:1030)
    for (nm, f) in (("y scale 2^sy (X=1)", k -> inst(T, 0, k)), ("X scale 2^sx (y=1)", k -> inst(T, k, 0)),
                    ("joint 2^s (y,X)", k -> inst(T, k, k)))
      println(T, " ", nm, ": ", intervals(runs(nm, T, rs, f), collect(rs)))
    end
  end
end
