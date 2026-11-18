#!/usr/bin/env python3
"""Builds prototype S of #378 from the audited revision. Not for merge.
Same decisions as make_protos2.py; the stop-time test first tries a bound that needs one vectorized sum.

usage: python3 -I make_protos3.py WORKTREE OUTDIR C [C ...]
  OUTDIR/master/src   the audited `src`, unchanged
  OUTDIR/S<C>/src     stop rule without a statistic in the coordinate loop. With
                        L    = max(tol, C eps(T)) sqrt(s)|y|            (the limit; relative scaling only)
                        rho  = eps(T) sqrt(s) sum_k |X_k| |x_k|          (resolution of a residual at x; groups:
                                                                         sum_g sqrt(l_g) |x_g|)
                        rho0 = eps(T) sqrt(s) max_k |X_k| sum_k |x0_k|   (a bound on the resolution at the point x0
                                                                         the cached residual was last computed from)
                      at a full pass whose largest change is below the threshold:
                        1. rho >= L: stop with converged = false (the test cannot be verified at this point);
                        2. otherwise, rho0 >= L: recompute the residual (image first), clear rho0, and continue
                           with a full pass;
                        3. otherwise: stop with converged = true, as on master.
                      The coordinate step and the sweep are those of master. Initialization adds one sum of
                      |x_k| to its loop over the nonzero coefficients.
Each tree also gets OUTDIR/S<C>.diff against master.
"""
import os, shutil, subprocess, sys

WT, OUT = sys.argv[1:3]
FLOORS = sys.argv[3:]
REV = "8cc022222d3c90ef86a24ca0c957b02faaf4fc1f"


def rep(s, a, b, count=1):
    assert s.count(a) == count, (a[:70], s.count(a))
    return s.replace(a, b)


def edit(tree, path, fn):
    p = os.path.join(OUT, tree, "src", path)
    s = open(p).read()
    open(p, "w").write(fn(s))


FIELDS_OLD = """  r::Vector{T}
  a::Vector{T}
end
function _scale_type"""
FIELDS_NEW = """  r::Vector{T}
  a::Vector{T}
  lim::T          # prototype: the limit max(tol, c eps(T)) √s‖y‖; Inf where the check is off
  n1::T           # prototype: Σ|x_k| (groups: Σ‖x_g‖) at the point the residual was last computed from
  unres::Bool     # prototype: the last converged full pass ended at a point where the test cannot be verified
  stalled::Bool   # prototype: the stop was refused
end
function _scale_type"""
CTOR_OLD = "  LSModel(X, y, convert(_scale_type(T, α), α), zeros(T, length(y)), fill(T(NaN), size(X, 2)))"
CTOR_NEW = "  LSModel(X, y, convert(_scale_type(T, α), α), zeros(T, length(y)), fill(T(NaN), size(X, 2)), T(Inf), zero(T), false, false)"

HOOKS_MODELS = """
# ---- prototype hooks (#378) ----
const _ABSORB_FLOOR = FLOORVALUE
_arm!(m::CDModel, tol, scaled::Bool, sy) = m
_stale(m::CDModel, x) = false
_refresh!(m::CDModel, x) = m
"""

INIT_OLD = """  copyto!(m.r, m.y)
  for k in _activeentries(x)
    v = x[k]
    iszero(v) && continue
    _residual_axpy!(m, k, v)
  end
  fill!(m.a, T(NaN))
  m
end"""
INIT_NEW = """  copyto!(m.r, m.y)
  n1 = zero(T)
  for k in _activeentries(x)
    v = x[k]
    iszero(v) && continue
    n1 += abs(v)                 # prototype
    _residual_axpy!(m, k, v)
  end
  m.n1 = n1
  fill!(m.a, T(NaN))
  m
end"""
BLOCK_INIT_OLD = """  copyto!(ls.r, ls.y)
  for k in activecoordinates(x)
    for j in blockindices(x, k)
      v = x[j]
      iszero(v) || _residual_axpy!(ls, Int(j), v)
    end
  end
  fill!(ls.a, T(NaN))
  m
end"""
BLOCK_INIT_NEW = """  copyto!(ls.r, ls.y)
  n1 = zero(T)
  for k in activecoordinates(x)
    q = zero(T)
    for j in blockindices(x, k)
      v = x[j]
      iszero(v) && continue
      q += v * v                 # prototype
      _residual_axpy!(ls, Int(j), v)
    end
    n1 += sqrt(q)
  end
  ls.n1 = n1
  fill!(ls.a, T(NaN))
  m
end"""

HELPERS = """
# ---- prototype S (#378) ----
# Called from `_tolerances` with the threshold and the response scale it computed.
function _arm!(m::LSModel{T}, tol, scaled::Bool, sy) where T
  m.stalled = m.unres = false
  m.lim = scaled ? max(tol, _ABSORB_FLOOR * eps(T) * T(sy)) : T(Inf)
  m
end
_arm!(m::BlockLSModel, tol, scaled::Bool, sy) = (_arm!(m.ls, tol, scaled, sy); m)
_uncertified(m::LSModel) = m.stalled
_uncertified(m::BlockLSModel) = m.ls.stalled
# The residual from x, image first.
function _fresh_residual!(dest::Vector{T}, m::LSModel{T}, x) where T
  X, y = m.X, m.y
  fill!(dest, zero(T))
  for k in _activeentries(x)
    v = x[k]
    iszero(v) && continue
    @inbounds @simd for i in eachindex(dest)
      dest[i] -= X[i, k] * v
    end
  end
  @inbounds @simd for i in eachindex(dest)
    dest[i] += y[i]
  end
  dest
end
function _fresh_block_residual!(dest::Vector{T}, ls::LSModel{T}, x::BlockIterate{T}) where T
  X, y = ls.X, ls.y
  fill!(dest, zero(T))
  for k in activecoordinates(x)
    for j in blockindices(x, k)
      v = x[j]
      iszero(v) && continue
      @inbounds @simd for i in eachindex(dest)
        dest[i] -= X[i, j] * v
      end
    end
  end
  @inbounds @simd for i in eachindex(dest)
    dest[i] += y[i]
  end
  dest
end
# The state of the stop test at x, after a full pass (which leaves the curvature of every coordinate in
# `m.a`): 2 where the resolution of a residual at x, eps √s Σ‖X_k‖|x_k|, reaches the limit; otherwise 1
# where the bound eps √s max_k‖X_k‖ Σ|x0_k| on the resolution at the point x0 the cached residual was last
# computed from reaches it; otherwise 0. Both tests are first tried with max_k a_k ≤ Σ_k a_k, which
# needs two vectorized sums and one square root: Σ√(s a_k)|x_k| ≤ √(s max_k a_k) Σ|x_k|. Only where that
# does not give 0 are the maximum and, for the first test, the sum itself formed.
function _resolution_state(m::LSModel{T}, x) where T
  isfinite(m.lim) || return 0
  a = m.a
  asum = zero(T)
  @inbounds @simd for k in eachindex(a)
    asum += ifelse(isnan(a[k]), zero(T), a[k])
  end
  vals = activevalues(x)
  x1 = zero(T)
  @inbounds @simd for i in 1:nactive(x)
    x1 += abs(vals[i])
  end
  eps(T) * _curvature_scale(m, asum) * max(x1, m.n1) < m.lim && return 0
  amax = zero(T)
  @inbounds for k in eachindex(a)
    a[k] > amax && (amax = a[k])
  end
  c = eps(T) * _curvature_scale(m, amax)
  if !(c * x1 < m.lim)
    P = zero(T)
    for k in _activeentries(x)
      v = x[k]
      iszero(v) || (P += _curvature_scale(m, m.a[k]) * abs(v))
    end
    eps(T) * P >= m.lim && return 2
  end
  c * m.n1 >= m.lim ? 1 : 0
end
function _stale(m::LSModel, x)
  st = _resolution_state(m, x)
  m.unres = st == 2
  st == 1
end
function _refresh!(m::LSModel{T}, x) where T
  _fresh_residual!(m.r, m, x)
  m.n1 = zero(T)
  m
end
function _stop_check!(m::LSModel, g, x, st, maxh, scaled::Bool)
  m.unres || return :converged
  m.stalled = true
  :uncertified
end
# The same for groups, with the curvature bound ℓ_g: ‖X_g x_g‖ ≤ √ℓ_g ‖x_g‖, and the first bound
# Σ√(s ℓ_g)‖x_g‖ ≤ √(s max_g ℓ_g) √(number of active groups) ‖x‖.
function _resolution_state(m::BlockLSModel{T}, x) where T
  ls = m.ls
  isfinite(ls.lim) || return 0
  ℓs = m.ℓ
  ℓsum = zero(T)
  @inbounds @simd for k in eachindex(ℓs)
    ℓsum += ifelse(isnan(ℓs[k]), zero(T), ℓs[k])
  end
  q = zero(T)
  nz = 0
  for k in activecoordinates(x)
    for v in blockview(x, k)
      q += v * v
    end
    nz += 1
  end
  g = sqrt(nz * q)                # Σ‖x_g‖ over the active groups is at most this
  eps(T) * _curvature_scale(ls, ℓsum) * max(g, ls.n1) < ls.lim && return 0
  ℓmax = zero(T)
  @inbounds for k in eachindex(ℓs)
    ℓs[k] > ℓmax && (ℓmax = ℓs[k])
  end
  c = eps(T) * _curvature_scale(ls, ℓmax)
  if !(c * g < ls.lim)
    P = zero(T)
    for k in activecoordinates(x)
      ℓ = m.ℓ[k]
      (iszero(ℓ) || isnan(ℓ)) && continue
      P += _curvature_scale(ls, ℓ) * norm(blockview(x, k))
    end
    eps(T) * P >= ls.lim && return 2
  end
  c * ls.n1 >= ls.lim ? 1 : 0
end
function _stale(m::BlockLSModel, x)
  st = _resolution_state(m, x)
  m.ls.unres = st == 2
  st == 1
end
function _refresh!(m::BlockLSModel{T}, x) where T
  _fresh_block_residual!(m.ls.r, m.ls, x)
  m.ls.n1 = zero(T)
  m
end
function _stop_check!(m::BlockLSModel, g, x, st, maxh, scaled::Bool)
  m.ls.unres || return :converged
  m.ls.stalled = true
  :uncertified
end
"""

ARM_OLD = """  u = scaled ? sy : one(T)
  T(s.tol)*u, scaled
end"""
ARM_NEW = """  u = scaled ? sy : one(T)
  _arm!(m, T(s.tol)*u, scaled, sy)
  T(s.tol)*u, scaled
end"""
PLAIN_OLD = """    converged = maxh<tol
    if full && converged
      status = _stop_check!(m, g, x, st, maxh, scaled)
      if status === :retry
        tol = st.tolerance
        converged = maxh<tol
      else
        st.converged = status === :converged
        break
      end
    end
  end
  x
end
function _usemomentum"""
PLAIN_NEW = """    converged = maxh<tol
    if full && converged
      if _stale(m, x)
        _refresh!(m, x)            # prototype: the next pass is a full pass from a recomputed residual
        continue
      end
      status = _stop_check!(m, g, x, st, maxh, scaled)
      if status === :retry
        tol = st.tolerance
        converged = maxh<tol
      else
        st.converged = status === :converged
        break
      end
    end
  end
  x
end
function _usemomentum"""
MOM_OLD = """    if full && converged
      status = _stop_check!(m, g, x, st, maxh, scaled)
      if status === :retry
        tol = st.tolerance
        converged = maxh<tol
      else
        st.converged = status === :converged
        break
      end
    end
    if full
      _momentum_reset!(mom, x, m)"""
MOM_NEW = """    if full && converged
      if _stale(m, x)
        _refresh!(m, x)            # prototype: as in the plain loop
        _momentum_reset!(mom, x, m)
        continue
      end
      status = _stop_check!(m, g, x, st, maxh, scaled)
      if status === :retry
        tol = st.tolerance
        converged = maxh<tol
      else
        st.converged = status === :converged
        break
      end
    end
    if full
      _momentum_reset!(mom, x, m)"""


def base(tree):
    d = os.path.join(OUT, tree)
    shutil.rmtree(d, ignore_errors=True)
    os.makedirs(d)
    subprocess.run(f"git -C {WT} archive {REV} src | tar -x -C {d}", shell=True, check=True)


def proto_s(tree, floor):
    edit(tree, "cd/leastsquares.jl", lambda s: rep(rep(rep(rep(s, FIELDS_OLD, FIELDS_NEW), CTOR_OLD, CTOR_NEW), INIT_OLD, INIT_NEW), BLOCK_INIT_OLD, BLOCK_INIT_NEW) + HELPERS)
    edit(tree, "cd/models.jl", lambda s: s + HOOKS_MODELS.replace("FLOORVALUE", floor))
    edit(tree, "cd/solver.jl", lambda s: rep(rep(rep(s, ARM_OLD, ARM_NEW), PLAIN_OLD, PLAIN_NEW), MOM_OLD, MOM_NEW))


base("master")
for c in FLOORS:
    name = "S" + c
    base(name)
    proto_s(name, c)
    with open(os.path.join(OUT, name + ".diff"), "w") as io:
        subprocess.run(["diff", "-ru", "master/src", name + "/src"], cwd=OUT, stdout=io)
    print(name, "built with floor", c, ";", sum(1 for l in open(os.path.join(OUT, name + ".diff")) if l.startswith(("+", "-")) and not l.startswith(("+++", "---"))), "changed lines")
