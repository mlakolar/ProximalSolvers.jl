#!/usr/bin/env python3
"""Generate an instrumented copy of src/cd/leastsquares.jl (counters only; no behaviour change).
Usage: mkinstr.py SRC DST. Counter ids: see IDS."""
import sys, re
src = open(sys.argv[1]).read()
IDS = ["outside_band","exceptional_step_l1","cs_calls","cs_fast","cs_two_roots","cs_root_p","rs_calls","rs_t1","rs_t2","rs_exc",
       "dot_cachemiss","dot_calls","sqnorm_cold","flat_column","step_flat_zero_a","grp_deferred","grp_gram","grp_singleton","grp_flatgroup",
       "grp_screen_attempt","grp_screen_zero","grp_lazy_curv","grp_zero_ell","exc_ridge_refuse","scaled_prox","coord_step","grp_step","init_calls","grp_gram_calls"]
def sub(old, new, count=1):
    global src
    assert src.count(old) >= 1, old
    src = src.replace(old, new, count)
def C(name): return f"_C[{IDS.index(name)+1}] += 1; "
# step
sub("@inline function coordinate_step!(m::LSModel{T}, g, x::SparseIterate{T}, k::Int) where {T}\n  a, b = _column_dot(m, k)",
    "@inline function coordinate_step!(m::LSModel{T}, g, x::SparseIterate{T}, k::Int) where {T}\n  "+C("coord_step")+"a, b = _column_dot(m, k)")
sub("function _scaled_prox(m::LSModel{T}, g, c::T, k::Int, a::T) where T\n", "function _scaled_prox(m::LSModel{T}, g, c::T, k::Int, a::T) where T\n  "+C("scaled_prox"))
sub("@noinline function _outside_band(m::LSModel{T}, g, c::T, k::Int, a::T) where T\n", "@noinline function _outside_band(m::LSModel{T}, g, c::T, k::Int, a::T) where T\n  "+C("outside_band"))
sub("@noinline function _exceptional_step(g::NormL1{<:Real, Nothing}, c::T, α::T, a::T, k::Int) where {T<:Union{Float32, Float64}}\n",
    "@noinline function _exceptional_step(g::NormL1{<:Real, Nothing}, c::T, α::T, a::T, k::Int) where {T<:Union{Float32, Float64}}\n  "+C("exceptional_step_l1"))
sub("@noinline _refuse_ridge_step(::Type{T}, k::Int) where T =\n  throw(", "@noinline _refuse_ridge_step(::Type{T}, k::Int) where T =\n  (_C[%d] += 1; throw(" % (IDS.index("exc_ridge_refuse")+1))
src = src.replace('rescale the data or the loss"))\n@noinline _exceptional_step(g, c, α, a, k::Int) =', 'rescale the data or the loss")))\n@noinline _exceptional_step(g, c, α, a, k::Int) =')
# column dot cache miss
sub("  b = zero(T)\n  if isnan(a)\n    a = zero(T)\n    @inbounds @simd for i in eachindex(r)\n      a += X[i, k]*X[i, k]\n      b += r[i]*X[i, k]",
    "  b = zero(T)\n  _C[%d] += 1\n  if isnan(a)\n    _C[%d] += 1\n    a = zero(T)\n    @inbounds @simd for i in eachindex(r)\n      a += X[i, k]*X[i, k]\n      b += r[i]*X[i, k]" % (IDS.index("dot_calls")+1, IDS.index("dot_cachemiss")+1))
sub("function _sqnorm!(m::LSModel{T}, k::Int) where T\n  a = m.a[k]\n  if isnan(a)\n", "function _sqnorm!(m::LSModel{T}, k::Int) where T\n  a = m.a[k]\n  if isnan(a)\n    _C[%d] += 1\n" % (IDS.index("sqnorm_cold")+1))
sub("function _flat_column(m::LSModel{T}, k::Int) where T\n", "function _flat_column(m::LSModel{T}, k::Int) where T\n  "+C("flat_column"))
# curvature scale
sub("@inline function _curvature_scale(m::LSModel{T}, a::T) where T\n  p = m.s*a\n  q = T(p)\n  floatmin(T) <= q <= floatmax(T) && return sqrt(q)\n  S = typeof(p)\n  (p < floatmin(S) || isinf(p) && isfinite(a)) && return T(sqrt(m.s)*sqrt(S(a)))\n  T(sqrt(p))",
    "@inline function _curvature_scale(m::LSModel{T}, a::T) where T\n  _C[%d] += 1\n  p = m.s*a\n  q = T(p)\n  floatmin(T) <= q <= floatmax(T) && (_C[%d] += 1; return sqrt(q))\n  S = typeof(p)\n  (p < floatmin(S) || isinf(p) && isfinite(a)) && (_C[%d] += 1; return T(sqrt(m.s)*sqrt(S(a))))\n  _C[%d] += 1\n  T(sqrt(p))" % tuple(IDS.index(n)+1 for n in ("cs_calls","cs_fast","cs_two_roots","cs_root_p")))
# response scale
sub("function response_scale(m::LSModel{T}, x) where T\n", "function response_scale(m::LSModel{T}, x) where T\n  "+C("rs_calls"))
sub("    floatmin(T) <= q <= floatmax(T) && return sqrt(q)\n    S = typeof(p)\n    if S !== T && floatmin(S) <= p <= floatmax(S)\n      r = T(sqrt(p))\n      floatmin(T) <= r <= floatmax(T) && return r",
    "    floatmin(T) <= q <= floatmax(T) && (_C[%d] += 1; return sqrt(q))\n    S = typeof(p)\n    if S !== T && floatmin(S) <= p <= floatmax(S)\n      r = T(sqrt(p))\n      floatmin(T) <= r <= floatmax(T) && (_C[%d] += 1; return r)" % (IDS.index("rs_t1")+1, IDS.index("rs_t2")+1))
sub("  _response_scale_exceptional(m)\nend\n", "  _C[%d] += 1\n  _response_scale_exceptional(m)\nend\n" % (IDS.index("rs_exc")+1), 1)
# group
sub("function _initialize!(m::LSModel{T}, x::SparseIterate{T}, fresh::Bool) where T\n", "function _initialize!(m::LSModel{T}, x::SparseIterate{T}, fresh::Bool) where T\n  "+C("init_calls"))
sub("    if _flat_group(ls, idx)\n      m.ℓ[k] = zero(T)\n    elseif length(idx) == 1 && n*eps(T) <= 1/8\n",
    "    if _flat_group(ls, idx)\n      "+C("grp_flatgroup")+"m.ℓ[k] = zero(T)\n    elseif length(idx) == 1 && n*eps(T) <= 1/8\n      "+C("grp_singleton"))
sub("    elseif _curvature_deferrable(ls, idx)\n      m.ℓ[k] = T(NaN)\n    else\n", "    elseif _curvature_deferrable(ls, idx)\n      "+C("grp_deferred")+"m.ℓ[k] = T(NaN)\n    else\n      "+C("grp_gram"))
sub("  ℓ = _gram_curvature(m.ls, idx, k, m.colbuf, m.grambuf)\n", "  "+C("grp_gram_calls")+"ℓ = _gram_curvature(m.ls, idx, k, m.colbuf, m.grambuf)\n")
sub("  ℓ = m.ℓ[k]\n  if iszero(ℓ)\n    prox_block!(u, g, old, k, Inf)\n", "  "+C("grp_step")+"ℓ = m.ℓ[k]\n  if iszero(ℓ)\n    "+C("grp_zero_ell")+"prox_block!(u, g, old, k, Inf)\n")
sub("        copyto!(u, b)\n        prox_block!(u, g, u, k, γs)\n", "        "+C("grp_screen_attempt")+"copyto!(u, b)\n        prox_block!(u, g, u, k, γs)\n")
sub("        screened && return zero(T)\n", "        screened && (_C[%d] += 1; return zero(T))\n" % (IDS.index("grp_screen_zero")+1))
sub("    if isnan(ℓ)\n      ℓ = _group_curvature!(m, idx, k)\n", "    if isnan(ℓ)\n      "+C("grp_lazy_curv")+"ℓ = _group_curvature!(m, idx, k)\n")
open(sys.argv[2], "w").write(src)
open(sys.argv[2] + ".ids", "w").write("\n".join(IDS))
