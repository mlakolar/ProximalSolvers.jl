# The cancelled d̃: x = e1 (scaled), r = [c, δ, ...], δ = 2^-s with the squares of δ below / near the range of Float64; also parallel + tiny perpendicular.
# Master recomputes d̃ with a rescaled norm; the candidate with a plain sum of squares. Both against the BigFloat reference and the step bound.
include("r1lib.jl")
println("# julia ", VERSION)
T = Float64
cnt = 0; ndiff = 0; worstb = 0.0; worstc = 0.0; maxdiffratio = 0.0; zflip = 0; bigdiff = nothing
for n in (2, 3, 30), ex in (0, -100, -480, 100), s in 480:30:1070, cexp in (-1000, -700, -540, -520, -300, -1, 0, 100), λf in (0.5, 0.9, 0.999, 1e-3)
  for (sh, sgn) in ((1, 1), (3, -1))
    x = zeros(T, n); x[1] = ldexp(1.0, ex)
    r = zeros(T, n); r[1] = sgn*ldexp(1.0, cexp); r[2] = ldexp(sh/2, -s)
    λ = λf*x[1]
    out = try evaluate_r(x, r, λ, 0.0) catch; continue end
    b, c = out[:base], out[:cand]
    global cnt += 1
    isfinite(b.ratio) && (global worstb = max(worstb, b.ratio)); isfinite(c.ratio) && (global worstc = max(worstc, c.ratio))
    oclass(b) == oclass(c) || println("CLASS DIFF ", oclass(b), " ", oclass(c))
    if oclass(b) === :value && b.z !== c.z
      global ndiff += 1; (iszero(b.z) != iszero(c.z)) && (global zflip += 1)
    end
  end
end
println("cases=", cnt, " | worst excess/bound base=", worstb, " cand=", worstc, " | differ=", ndiff, " (zero flips ", zflip, ")")
