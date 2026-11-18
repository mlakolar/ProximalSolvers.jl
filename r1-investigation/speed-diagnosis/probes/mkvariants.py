#!/usr/bin/env python3
"""Generate single-factor variants of the fast path under variants/<name>/src (copy of the base src tree, sqrtlasso.jl edited)."""
import os, re, shutil, sys
D = "<WORK>/ProximalSolvers.jl-issue353-r1-perf/.codex-orchestrator/variants"
BASE = open(D + "/base/src/cd/sqrtlasso.jl").read()
X1D = open(D + "/x1d/src/cd/sqrtlasso.jl").read()
SEL = '''
# timing probe: select form of the soft threshold
@inline _sel(c::T, τ::T) where T = c > τ ? c - τ : (c < -τ ? c + τ : zero(T))
# timing probe: ProximalBase's _shrink_nonneg form, reproduced locally
@inline function _pnn(v::T, c::T) where T
  lo = -c
  m = ifelse(v > lo, v, lo)
  (v - ifelse(m < c, m, c)) + zero(T)
end
'''
def base_min(tail, extra=""):
    return '''@inline function _sqrt_minimizer(m::SqrtLSModel{T}, old::T, a::T, b::T, ρ2::T, k::Int) where T
  ls = m.ls
  n = length(ls.r)
  (_clean_sum(a, n) & _clean_sum(ρ2, n)) || return _sqrt_offrange_step(m, old, k)
  λ = m.gt.λ0
  ra = sqrt(a)
  λ >= ra && return zero(T)
  q = b/a
  c = old + q
  d2 = ρ2 - b*q
  if d2 < ρ2/16
    d2 = _distance_sqr(ls.X, ls.r, k, q)
    _clean_sum(d2, n) || return _sqrt_offrange_step(m, old, k)
  end
  d = sqrt(d2)
  p = ra*(sqrt(ra - λ)*sqrt(ra + λ))
  γ = d/p
  τ = γ*λ
''' + tail + "\nend\n"
OK = "((floatmin(T) <= p) & (floatmin(T) <= γ <= floatmax(T)) & (floatmin(T) <= τ <= floatmax(T)))"
BASE_TAILS = {
  "bshrink":  f"  {OK} ?\n    shrink(c, τ) : _sqrt_offrange_step(m, old, k)",
  "bsel":     f"  {OK} ?\n    _sel(c, τ) : _sqrt_offrange_step(m, old, k)",
  "bpnn":     f"  {OK} ?\n    _pnn(c, τ) : _sqrt_offrange_step(m, old, k)",
  "bnoband":  "  prox_block(m.gt, c, k, γ)",
  "bnoband_sel": "  _sel(c, τ)",
  "bnoband_shrink": "  shrink(c, τ)",
}
m = re.search(r"@inline function _sqrt_minimizer\(m::SqrtLSModel\{T\}.*?\n  \(.*?\n\nend|@inline function _sqrt_minimizer.*?\nend\n", BASE, re.S)
# locate base function text exactly: from its line to the first line equal to 'end' after it
s = BASE.index("@inline function _sqrt_minimizer(m::SqrtLSModel{T}")
e = BASE.index("\nend\n", s) + 5
def mk(name, text):
    d = f"{D}/{name}"
    if os.path.exists(d): shutil.rmtree(d)
    shutil.copytree(D + "/base/src", d + "/src")
    open(d + "/src/cd/sqrtlasso.jl", "w").write(text)
for nm, tail in BASE_TAILS.items():
    mk(nm, BASE[:s] + SEL + base_min(tail) + BASE[e:])
# x1d-derived
D_END = "  shrink(old + q, (λ/ra)*(sqrt(d2)/(sqrt(ra - λ)*sqrt(ra + λ))))\n"
assert D_END in X1D
def dvar(newtail, pre=""):
    t = X1D.replace(D_END, newtail)
    i = t.index("@inline _sqrt_minimizer(m::SqrtLSModel{T}")
    return t[:i] + SEL + t[i:]
mk("d_sel", dvar("  _sel(old + q, (λ/ra)*(sqrt(d2)/(sqrt(ra - λ)*sqrt(ra + λ))))\n"))
mk("d_pnn", dvar("  _pnn(old + q, (λ/ra)*(sqrt(d2)/(sqrt(ra - λ)*sqrt(ra + λ))))\n"))
mk("d_2div", dvar("  shrink(old + q, (sqrt(d2)*λ)/(ra*(sqrt(ra - λ)*sqrt(ra + λ))))\n"))
mk("d_sel_2div", dvar("  _sel(old + q, (sqrt(d2)*λ)/(ra*(sqrt(ra - λ)*sqrt(ra + λ))))\n"))
mk("d_pb", dvar("  prox_block(m.gt, old + q, k, sqrt(d2)/(ra*(sqrt(ra - λ)*sqrt(ra + λ))))\n"))
print("ok")

# ---- x1a-attribution variants (base arithmetic and band test unchanged) ----
def a_variant(view_top, cold7, view_at_exit):
    t = BASE
    f = t[s:e]
    helper = '''
@inline function _dist_x(x::AbstractVector{T}, r::AbstractVector{T}, q::T) where T
  s = zero(T)
  @inbounds @simd for i in eachindex(r)
    v = r[i] - q*x[i]
    s += v*v
  end
  s
end
@noinline _cold7(m, x, r, g, old, a, k) = _sqrt_offrange_step(m, old, k)
'''
    g = f
    if view_top:
        g = g.replace("  n = length(ls.r)\n", "  n = length(ls.r)\n  x = view(ls.X, :, k)\n", 1)
        g = g.replace("_distance_sqr(ls.X, ls.r, k, q)", "_dist_x(x, ls.r, q)")
    if cold7:
        xe = "view(ls.X, :, k)" if view_at_exit else ("x" if view_top else "ls.X")
        g = g.replace("_sqrt_offrange_step(m, old, k)", f"_cold7(m, {xe}, ls.r, m.gt, old, a, k)")
        g = g.replace("_sqrt_band_step(c, ra, λ, Float64(d), 0)", f"_cold7(m, {xe}, ls.r, m.gt, old, a, k)")
    return t[:s] + helper + g + t[e:]
mk("a1_view", a_variant(True, False, False))
mk("a2_cold7", a_variant(False, True, False))
mk("a3_cold7v", a_variant(False, True, True))
mk("a4_view_cold7", a_variant(True, True, False))
print("ok2")

# ---- bisect x1a/x1c against base: one factor each ----
def sub(f, old, new):
    assert old in f, old
    return f.replace(old, new, 1)
f0 = BASE[s:e]
# c1: iszero(d) in the band condition
c1 = sub(f0, "((floatmin(T) <= p) & (floatmin(T) <= γ <= floatmax(T)) & (floatmin(T) <= τ <= floatmax(T)))",
         "((floatmin(T) <= p) & (iszero(d) | ((floatmin(T) <= γ <= floatmax(T)) & (floatmin(T) <= τ <= floatmax(T)))))")
mk("c1_iszero_d", BASE[:s] + c1 + BASE[e:])
# c2: no _clean_sum on the recomputed d2
c2 = sub(f0, "    _clean_sum(d2, n) || return _sqrt_offrange_step(m, old, k)\n", "")
mk("c2_no_d2_check", BASE[:s] + c2 + BASE[e:])
# c3: generic _sqrt_step(m, X, r, g::NormL1{T}, ...) with X, r, g passed as arguments
c3 = f0.replace("@inline function _sqrt_minimizer(m::SqrtLSModel{T}, old::T, a::T, b::T, ρ2::T, k::Int) where T\n  ls = m.ls\n  n = length(ls.r)\n",
  "@inline _sqrt_minimizer(m::SqrtLSModel{T}, old::T, a::T, b::T, ρ2::T, k::Int) where T = _sqrt_step(m, m.ls.X, m.ls.r, m.gt, old, a, b, ρ2, k)\n@inline function _sqrt_step(m, X, r, g::NormL1{T}, old::T, a::T, b::T, ρ2::T, k::Int) where T\n  n = length(r)\n")
c3 = c3.replace("λ = m.gt.λ0", "λ = g.λ0").replace("_distance_sqr(ls.X, ls.r, k, q)", "_distance_sqr(X, r, k, q)").replace("prox_block(m.gt, c, k, γ)", "prox_block(g, c, k, γ)")
assert "ls." not in c3.split("\n",3)[3], c3
mk("c3_generic_step", BASE[:s] + c3 + BASE[e:])
# c4: c3 + the Float32 widening cold method pair (recursion through _sqrt_cold like x1a) -- only adds methods, hot code same text as c3
print("ok3")

# ---- candidate: band-free fast path, local nonnegative soft threshold, exits as in base/K: (m, old, k) ----
SOFT = '''# Soft thresholding at a threshold τ ≥ 0: v minus its projection onto [-τ, τ], by the two selects that the
# hardware maximum and minimum are, plus +0 (which turns the -0 of v = -0 at τ = 0 into +0). It is the value of
# `shrink` for every v and every τ ≥ 0, a NaN in v or τ included (it propagates), and it avoids `shrink`, which
# Julia 1.10 compiles, through `max` and `min`, to branches on the signs of v ∓ τ and transfers between the
# floating-point and the integer registers: 10 % to 15 % per visit.
@inline function _soft(v::T, τ::T) where T
  lo = -τ
  m = ifelse(v > lo, v, lo)
  (v - ifelse(m < τ, m, τ)) + zero(T)
end
'''
CAND_FN = '''@inline function _sqrt_minimizer(m::SqrtLSModel{T}, old::T, a::T, b::T, ρ2::T, k::Int) where T
  ls = m.ls
  n = length(ls.r)
  (_clean_sum(a, n) & _clean_sum(ρ2, n)) || return _sqrt_offrange_step(m, old, k)
  λ = m.gt.λ0
  ra = sqrt(a)
  λ >= ra && return zero(T)
  q = b/a
  d2 = ρ2 - b*q
  if d2 < ρ2/16
    d2 = _distance_sqr(ls.X, ls.r, k, q)
    _clean_sum(d2, n) || return _sqrt_offrange_step(m, old, k)
  end
  _soft(old + q, (λ/ra)*(sqrt(d2)/(sqrt(ra - λ)*sqrt(ra + λ))))
end
'''
mk("cand", BASE[:s] + SOFT + CAND_FN + BASE[e:])
# cand with the exported shrink instead of _soft (control: should reproduce the x1d slowdown on 1.10)
mk("cand_shrink", BASE[:s] + CAND_FN.replace("_soft(", "shrink(") + BASE[e:])
print("ok4")

# c1b: the same condition as c1 with short-circuit `||` instead of `|` (does the form of the OR matter?)
c1b = sub(f0, "((floatmin(T) <= p) & (floatmin(T) <= γ <= floatmax(T)) & (floatmin(T) <= τ <= floatmax(T)))",
         "(iszero(d) || ((floatmin(T) <= p) & (floatmin(T) <= γ <= floatmax(T)) & (floatmin(T) <= τ <= floatmax(T))))")
mk("c1b_oror", BASE[:s] + c1b + BASE[e:])
print("ok5")
