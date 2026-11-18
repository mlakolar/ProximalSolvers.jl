#!/usr/bin/env python3
"""Build the two X1 prototypes of src/cd/sqrtlasso.jl from the dac9f4b file by line ranges.
x1a = "C2":   ordinary path bit-identical (prox_block + band test); band exits take the cold path.
x1b = "C2τ":  the threshold is formed in range as (λ/ra)(d/w) and passed to shrink; no band test.
Usage: make_x1.py SRC DST {a|b}"""
import sys
src, dst, var = sys.argv[1], sys.argv[2], sys.argv[3]
L = open(src, encoding="utf-8").read().split("\n")
assert L[56].startswith("  ny, ey = _scaled_norm") and L[88].startswith("function _scaled_norm")
assert L[125].startswith("@inline function _distance_sqr") and L[177].startswith("@inline function _sqrt_minimizer")
assert L[278] == "end" and L[279].startswith("# The refusal of a residual")
prep = ["  ny = _se_norm(Float64, m.ls.y)        # y is finite (`solve!` checks it), so this is not `nothing`",
        "  m.floor64 = 16eps(T)*ldexp(ny.s, ny.e)"]
dist = ["# ‖r − q x‖², in T, for the column x.",
        "@inline function _distance_sqr(x::AbstractVector{T}, r::AbstractVector{T}, q::T) where T",
        "  s = zero(T)",
        "  @inbounds @simd for i in eachindex(r)",
        "    v = r[i] - q*x[i]",
        "    s += v*v",
        "  end",
        "  s",
        "end"]
cold = [
"# The step where a or ρ² (or, in x1a, the threshold) is outside the range of the fast path, out of line.",
"# Float32: the same step in Float64, on Float64 copies of the column and the residual in the work vectors",
"# `rowmag64` and `res64` (the conversions are exact, and the squares of Float32 numbers and their sums stay in",
"# the normal range of Float64, so the Float64 step leaves its fast path only for r = 0).",
"@noinline function _sqrt_cold(m::SqrtLSModel, x, r, PEN::PENT32, old::Float32, a::Float32, k::Int)",
"  xw, rw = copyto!(m.rowmag64, x), copyto!(m.res64, r)",
"  Float32(_sqrt_step(m, xw, rw, PEN64, Float64(old), sum(abs2, xw), dot(xw, rw), sum(abs2, rw), k))",
"end",
"# Float64: with a in range, r = 0 gives b = 0 and d = 0, so the minimizer is old (0 for λ ≥ √a). Any other",
"# step outside the range is refused, before the coordinate or the residual changes.",
"@noinline function _sqrt_cold(m::SqrtLSModel, x, r, PEN::PENT64, old::Float64, a::Float64, k::Int)",
"  _clean_sum(a, length(r)) && all(iszero, r) && return LAM >= sqrt(a) ? 0.0 : old",
"  throw(ArgumentError(\"the coordinate step of coordinate $k is outside the supported range of Float64 (the squared norm of its column or of the residual, or the threshold, leaves the normal range); rescale the data\"))",
"end"]
if var == "a":
    step = [
"# The minimizer for a positive finite a (prototype x1a of #353: the fast path of dac9f4b unchanged; an a, a ρ²",
"# or a threshold outside its range takes `_sqrt_cold`). A recomputed d² is used as it is: its squares that",
"# underflow change it by at most n nextfloat(zero(T))/2, and d = 0 (r parallel to X_k) gives the centre c.",
"@inline _sqrt_minimizer(m::SqrtLSModel{T}, old::T, a::T, b::T, ρ2::T, k::Int) where T =",
"  _sqrt_step(m, view(m.ls.X, :, k), m.ls.r, m.gt, old, a, b, ρ2, k)",
"@inline function _sqrt_step(m, x, r, g::NormL1{T}, old::T, a::T, b::T, ρ2::T, k::Int) where T",
"  n = length(r)",
"  (_clean_sum(a, n) & _clean_sum(ρ2, n)) || return _sqrt_cold(m, x, r, g, old, a, k)",
"  λ = g.λ0",
"  ra = sqrt(a)",
"  λ >= ra && return zero(T)",
"  q = b/a",
"  c = old + q",
"  d2 = ρ2 - b*q",
"  d2 < ρ2/16 && (d2 = _distance_sqr(x, r, q))",
"  d = sqrt(d2)",
"  p = ra*(sqrt(ra - λ)*sqrt(ra + λ))",
"  γ = d/p",
"  τ = γ*λ",
"  ((floatmin(T) <= p) & (iszero(d) | ((floatmin(T) <= γ <= floatmax(T)) & (floatmin(T) <= τ <= floatmax(T))))) ?",
"    prox_block(g, c, k, γ) : _sqrt_cold(m, x, r, g, old, a, k)",
"end"]
    rep = {"PEN64": "NormL1(Float64(g.λ0))", "PENT32": "NormL1{Float32}", "PENT64": "NormL1{Float64}", "PEN": "g", "LAM": "g.λ0"}
else:
    step = [
"# The minimizer for a positive finite a (prototype x1b of #353). Where a and ρ² pass `_clean_sum`, with",
"# ra = fl(√a), λ < ra and w = √(ra − λ) √(ra + λ), the threshold is τ = (λ/ra)(d/w): λ/ra < 1, and d/w is at",
"# most √(floatmax eps/floatmin) √(2/eps) = √(2 floatmax/floatmin) < floatmax (d ≤ √floatmax,",
"# ra ≥ √(floatmin/eps) and w ≥ ra √(eps/2)), so τ does not overflow, and it underflows only where the exact",
"# threshold does. A recomputed d² is used as it is (d = 0 for r parallel to X_k gives the centre c).",
"@inline _sqrt_minimizer(m::SqrtLSModel{T}, old::T, a::T, b::T, ρ2::T, k::Int) where T =",
"  _sqrt_step(m, view(m.ls.X, :, k), m.ls.r, m.gt.λ0, old, a, b, ρ2, k)",
"@inline function _sqrt_step(m, x, r, λ::T, old::T, a::T, b::T, ρ2::T, k::Int) where T",
"  n = length(r)",
"  (_clean_sum(a, n) & _clean_sum(ρ2, n)) || return _sqrt_cold(m, x, r, λ, old, a, k)",
"  ra = sqrt(a)",
"  λ >= ra && return zero(T)",
"  q = b/a",
"  d2 = ρ2 - b*q",
"  d2 < ρ2/16 && (d2 = _distance_sqr(x, r, q))",
"  shrink(old + q, (λ/ra)*(sqrt(d2)/(sqrt(ra - λ)*sqrt(ra + λ))))",
"end"]
    rep = {"PEN64": "Float64(λ)", "PENT32": "Float32", "PENT64": "Float64", "PEN": "λ", "LAM": "λ"}
def sub(s):
    for k in ("PEN64", "PENT32", "PENT64", "PEN", "LAM"): s = s.replace(k, rep[k])
    return s
out = L[:56] + prep + L[58:85] + L[102:124] + dist + L[133:165] + step + [sub(s) for s in cold] + L[279:]
open(dst, "w", encoding="utf-8").write("\n".join(out))
