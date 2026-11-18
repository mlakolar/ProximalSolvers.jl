# X1 experiment 4: outcome scans of public solve! along one-axis exact power-of-two rescalings, BASE/X1A/X1B. julia --project=ps-353 exp4_scans.jl {Float32|Float64}
include("x1lib.jl")
const T = ARGS[1] == "Float32" ? Float32 : Float64
sqrtlam_max(X, y) = (sy = maximum(abs, Float64.(y)); sx = maximum(abs, Float64.(X)); (iszero(sy) || iszero(sx)) ? 0.0 : norm((Float64.(X)./sx)' * (Float64.(y)./sy), Inf) / norm(Float64.(y)./sy) * sx)
const MSGS = Dict{String,String}()
function msgcode(msg)
  c = occursin("coordinate curvature underflows", msg) ? 'A' : occursin("the curvature of coordinate", msg) ? 'B' : occursin("outside the supported range", msg) ? 'R' : 'S'
  MSGS[string(c)] = msg; c
end
function outcome(P, X, y, λ)
  xs = zeros(T, size(X, 2))
  try
    r = with_logger(NullLogger()) do
      P.solve!(xs, SqrtLeastSquaresLoss(y, X), NormL1(λ), P.CDSolver(; order = :cyclic, rng = Xoshiro(5)))
    end
    r.converged ? 'C' : 'u'
  catch e
    msgcode(first(split(sprint(showerror, e), '\n')))
  end
end
function inst(sy, sx; col1 = false, n = 30, p = 8, lf = 0.3)
  rng = Xoshiro(11); X0 = randn(rng, n, p); y0 = randn(rng, n)
  if col1; X = T.(X0); X[:, 1] = T.(ldexp.(X0[:, 1], sx)); else X = T.(ldexp.(X0, sx)); end
  y = T.(ldexp.(y0, sy))
  (all(isfinite, X) && all(isfinite, y) && any(!iszero, X) && any(!iszero, y)) || return nothing
  λ = try T(lf*sqrtlam_max(X, y)) catch; return nothing end
  (isfinite(λ) && λ > 0) || return nothing
  X, y, λ
end
function intervals(str, rs)
  out = String[]; start = 1
  for i in 2:length(str)+1
    if i > length(str) || str[i] != str[start]; push!(out, "$(str[start])[$(rs[start])..$(rs[i-1])]"); start = i; end
  end
  join(out, " ")
end
rs = T === Float32 ? (-170:140) : (-1100:1040)
scans = [("y only: y*2^s, X=1", s -> inst(s, 0)), ("X only: X*2^s, y=1", s -> inst(0, s)), ("joint: y,X both *2^s", s -> inst(s, s)),
         ("one column: X[:,1]*2^s, rest 1, y=1", s -> inst(0, s; col1 = true)), ("opposite: y*2^s, X*2^-s", s -> inst(s, -s)),
         ("opposite2: y*2^-s, X*2^s", s -> inst(-s, s))]
println("# ", T, " Julia ", VERSION, ". C converged+certified, u returned but converged=false, . input not representable/λ not finite;",
        " throws: A='coordinate curvature underflows', B='curvature of coordinate k (squared norm) not finite', R='coordinate step ... outside the supported range' (prototype refusal), S=other")
for (nm, f) in scans
  codes = Dict(t => String[] for t in TNAMES)
  for s in rs
    i = f(s)
    for t in TNAMES; push!(codes[t], i === nothing ? "." : string(outcome(getproperty(TREES, t), i...))); end
  end
  str = Dict(t => join(codes[t]) for t in TNAMES)
  println("## ", nm)
  for t in TNAMES; println("  ", rpad(t, 5), intervals(str[t], collect(rs))); end
  # differing region
  dif = [s for (j, s) in enumerate(rs) if !(codes[:base][j] == codes[:x1a][j] == codes[:x1b][j])]
  if isempty(dif); println("  trees agree everywhere")
  else
    trip = [string(codes[:base][j], codes[:x1a][j], codes[:x1b][j]) for (j, s) in enumerate(rs)]
    keep = [!(codes[:base][j] == codes[:x1a][j] == codes[:x1b][j]) for j in eachindex(rs)]
    # intervals of constant (base,x1a,x1b) triple where they differ
    out = String[]; j = 1
    while j <= length(rs)
      if keep[j]; j2 = j; while j2 < length(rs) && keep[j2+1] && trip[j2+1] == trip[j]; j2 += 1; end
        push!(out, "$(trip[j])[$(rs[j])..$(rs[j2])]"); j = j2 + 1
      else; j += 1; end
    end
    println("  differing (base,x1a,x1b triple per interval): ", join(out, " "))
  end
  flush(stdout)
end
for (k, v) in sort(collect(MSGS)); println("msg ", k, ": ", v); end
