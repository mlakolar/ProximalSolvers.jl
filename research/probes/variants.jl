# #317 probe-only variants of LineSearches.backtrack! / _step_curvature (never in src).
# VARIANT=M (master) | R1 (subnormal ‖d̂‖² -> zero-step exit) | R2 (2·dot/xy_sq) | R3 (R2 + scaled-norm c for Float64)
using ProximalSolvers, LinearAlgebra
const PS = ProximalSolvers; const LS = PS.LineSearches
const VARIANT = get(ENV, "VARIANT", "M")
const SUBNORMAL_HITS = Ref(0)   # times a nonzero subnormal ‖d̂‖² reached backtrack!
let src = read(joinpath(pkgdir(PS), "src", "line_searches.jl"), String)
  i1 = findfirst("function backtrack!(", src).start; i2 = findfirst("\nhas_updated_gradient", src).start
  body = src[i1:i2]
  hit = "    xy_sq = _norm(state.delta_x)^2\n"
  @assert occursin(hit, body)
  body = replace(body, hit => hit * "    (zero(T) < xy_sq < floatmin(T)) && (Main.SUBNORMAL_HITS[] += 1)\n")
  if VARIANT == "R1"
    old = "    if xy_sq == zero(T) && isfinite(state.f_x)"; @assert occursin(old, body)
    body = replace(body, old => "    if xy_sq < floatmin(T) && isfinite(state.f_x)")
  elseif VARIANT == "R2g"
    old = "        local_l *= 2. / xy_sq"; @assert occursin(old, body)
    body = replace(body, old => "        iszero(local_l) || (local_l *= 2. / xy_sq)")
  elseif VARIANT in ("R2", "R3")
    old = "        local_l *= 2. / xy_sq"; @assert occursin(old, body)
    body = replace(body, old => "        local_l = 2 * local_l / xy_sq")
  end
  VARIANT == "M" || Core.eval(LS, Meta.parseall(body))
  VARIANT == "M" && Core.eval(LS, Meta.parseall(body))  # same source + counter only
end
if VARIANT == "R3"
  @eval PS function _step_curvature(state::ProximalGradientDescentState{Float64}, m)
    c = m * (state.model.α * (LinearAlgebra.norm(state.dz) / LinearAlgebra.norm(state.delta_x))^2)
    c <= state.L, c
  end
end
