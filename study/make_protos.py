#!/usr/bin/env python3
"""Builds the prototype source trees of #378 from the audited revision. Not for merge.

usage: python3 -I make_protos.py WORKTREE OUTDIR C_A C_R C_F
  OUTDIR/master/src   the audited `src`, unchanged
  OUTDIR/A/src        absorbed-step statistic in the zero-change branch of the visit, refusal at the stop
                      (floor C_A eps(T))
  OUTDIR/R/src        report only: at a converged full pass where the resolution gate fires, a fresh residual
                      (image first) is compared with the cached one; a distance at or above
                      max(tol, C_R eps(T)) sqrt(s)|y| stops the run with converged = false
  OUTDIR/F/src        stop rule: at a converged full pass where the gate fires (floor C_F), the residual is
                      recomputed (image first) and the loop continues with a full pass; a stop is accepted
                      from a pass that started from that fresh residual, or where the gate does not fire;
                      with the absorbed-step refusal of A at the same floor
Each tree also gets OUTDIR/<name>.diff against master.
"""
import os, shutil, subprocess, sys

WT, OUT, C_A, C_R, C_F = sys.argv[1:6]


def rep(s, a, b, count=1):
    assert s.count(a) == count, (a[:70], s.count(a))
    return s.replace(a, b)


def edit(tree, path, fn):
    p = os.path.join(OUT, tree, "src", path)
    s = open(p).read()
    open(p, "w").write(fn(s))


# ---------------------------------------------------------------- shared pieces
FIELDS_OLD = """  r::Vector{T}
  a::Vector{T}
end
function _scale_type"""
FIELDS_NEW = """  r::Vector{T}
  a::Vector{T}
  absorbed::T     # prototype: the largest absorbed-step ratio of the current full pass
  thr::T          # prototype: the threshold of the solve, in the units of its change test
  resp::T         # prototype: the response scale, when relative scaling is active
  lim::T          # prototype: the limit max(tol, c eps(T)) √s‖y‖
  lim2::T         # prototype: a coefficient with x² s a below this cannot hold a refusable absorbed step
  scaled::Bool
  stalled::Bool   # prototype: the stop was refused
  rf::Vector{T}   # prototype: scratch for a fresh residual; it is `r` itself until one is needed
end
function _scale_type"""
CTOR_OLD = "  LSModel(X, y, convert(_scale_type(T, α), α), zeros(T, length(y)), fill(T(NaN), size(X, 2)))"
CTOR_NEW = "  (r = zeros(T, length(y)); LSModel(X, y, convert(_scale_type(T, α), α), r, fill(T(NaN), size(X, 2)), zero(T), zero(T), zero(T), T(Inf), T(Inf), false, false, r))"

HOOKS_MODELS = """
# ---- prototype hooks (#378) ----
const _ABSORB_FLOOR = FLOORVALUE
_arm!(m::CDModel, tol, scaled::Bool, sy) = m
_pass_reset!(m::CDModel) = m
"""

HELPERS_LS = """
# ---- prototype (#378) ----
_l1l2(g::NormL1, ::Type{T}) where T = (T(g.λ0), zero(T))
_l1l2(g::ElasticNet, ::Type{T}) where T = (T(g.λ1), T(g.λ2))
# Called from `_tolerances` with the threshold and the response scale it computed. A visit whose computed
# displacement is 0 has an unrounded step of at most about eps(T)|x_k| + eps(T) τ_k, so a coefficient with
# eps(T) √(s a_k)|x_k| below half the limit max(tol, c eps(T)) √s‖y‖ cannot be refused: `lim2` is the
# square of that bound on √(s a_k)|x_k|, compared without a square root (Inf when the check is off).
function _arm!(m::LSModel{T}, tol, scaled::Bool, sy) where T
  m.thr, m.scaled, m.stalled, m.absorbed = tol, scaled, false, zero(T)
  m.resp = scaled ? T(sy) : zero(T)
  m.lim = scaled ? max(tol, _ABSORB_FLOOR * eps(T) * m.resp) : T(Inf)
  m.lim2 = scaled ? abs2(m.lim / (2 * eps(T))) : T(Inf)
  m
end
_arm!(m::BlockLSModel, tol, scaled::Bool, sy) = (_arm!(m.ls, tol, scaled, sy); m)
@inline _absorbable(m::LSModel, old, a) = abs2(old) * (m.s * a) >= m.lim2
_pass_reset!(m::LSModel{T}) where T = (m.absorbed = zero(T); m)
_pass_reset!(m::BlockLSModel) = (_pass_reset!(m.ls); m)
_uncertified(m::LSModel) = m.stalled
_uncertified(m::BlockLSModel) = m.ls.stalled
# The step of a visit without the rounding of old + b/a, for a nonzero coefficient that keeps its sign.
@inline function _unrounded_signed(old::T, b::T, a::T, p::T, l1::T, l2::T) where T
  ρ = l2 / p
  (b / a - (l1 / p) * sign(old) - ρ * old) / (one(T) + ρ)
end
@inline _unrounded(old::T, b::T, a::T, p::T, l1::T, l2::T) where T = abs(_unrounded_signed(old, b, a, p, l1, l2))
"""

NOTE_A = """
# A visit whose computed displacement is 0 at a nonzero coefficient: record the unrounded step over its
# unit max(√s‖y‖, λ1/√(s a)) when it is at or above the threshold.
@noinline function _note_absorbed!(m::LSModel{T}, g, old::T, b::T, a::T) where T
  m.scaled || return nothing
  l1, l2 = _l1l2(g, T)
  sc = _curvature_scale(m, a)
  v = _unrounded(old, b, a, T(m.s * a), l1, l2) * sc
  v >= m.thr || return nothing
  q = v / max(m.resp, l1 / sc)
  q > m.absorbed && (m.absorbed = q)
  nothing
end
@noinline function _note_absorbed_block!(m::BlockLSModel{T}, g::GroupNormL2, k::Int, mk::Int, ℓ::T) where T
  ls = m.ls
  ls.scaled || return nothing
  λw = T(g.λ0) * T(g.w[k])
  c = λw / T(ls.s * ℓ)
  nv = zero(T)
  for i in 1:mk                      # m.u holds the block (its displacement is zero), m.b the correlations
    v = m.u[i] + m.b[i] / ℓ
    m.old[i] = v
    nv += v * v
  end
  nv = sqrt(nv)
  d = zero(T)
  for i in 1:mk
    di = nv > c ? m.b[i] / ℓ - (c / nv) * m.old[i] : -m.u[i]
    d += di * di
  end
  sc = _curvature_scale(ls, ℓ)
  v = sqrt(d) * sc
  v >= ls.thr || return nothing
  q = v / max(ls.resp, λw / sc)
  q > ls.absorbed && (ls.absorbed = q)
  nothing
end
function _stop_check!(m::LSModel{T}, g, x, st, maxh, scaled::Bool) where T
  m.absorbed >= _ABSORB_FLOOR * eps(T) || return :converged
  m.stalled = true
  :uncertified
end
_stop_check!(m::BlockLSModel, g, x, st, maxh, scaled::Bool) = _stop_check!(m.ls, g, x, st, maxh, scaled)
"""

STEP_OLD = """  h = new - old
  iszero(h) && return h      # x and the residuals do not change
  x[k] = new"""
STEP_A = """  h = new - old
  if iszero(h)               # x and the residuals do not change
    iszero(old) || !_absorbable(m, old, a) || _note_absorbed!(m, g, old, b, a)
    return h
  end
  x[k] = new"""
BLOCK_OLD = """  moved || return zero(T)
  copyto!(blockview(x, k), u)"""
BLOCK_A = """  if !moved
    zeroblock || !_absorbable(ls, norm(u), ℓ) || _note_absorbed_block!(m, g, k, mk, ℓ)
    return zero(T)
  end
  copyto!(blockview(x, k), u)"""

PASS_OLD = """function _pass!(x, m, g, st::_CDState{T}, full::Bool, scaled::Bool) where {T}
  maxh = if full"""
PASS_NEW = """function _pass!(x, m, g, st::_CDState{T}, full::Bool, scaled::Bool) where {T}
  full && _pass_reset!(m)
  maxh = if full"""
ARM_OLD = """  u = scaled ? sy : one(T)
  T(s.tol)*u, scaled
end"""
ARM_NEW = """  u = scaled ? sy : one(T)
  _arm!(m, T(s.tol)*u, scaled, sy)
  T(s.tol)*u, scaled
end"""

# the fresh residual, image first, into `dest`
FRESH = """
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
"""

# path length in the sweep
STATE_OLD = """  maxchange::T
  tolerance::T
end
_CDState(::Type{T}, x, s::CDSolver) where T =
  _CDState{T, typeof(s.rng)}(s.random, s.rng, Vector{Int}(undef, s.random ? ncoordinates(x) : 0),
                          _Momentum{T}(), 0, false, T(NaN), T(NaN))"""
STATE_NEW = """  maxchange::T
  tolerance::T
  path::T         # prototype: the sum of the changes of the visits since the last fresh residual
end
_CDState(::Type{T}, x, s::CDSolver) where T =
  _CDState{T, typeof(s.rng)}(s.random, s.rng, Vector{Int}(undef, s.random ? ncoordinates(x) : 0),
                          _Momentum{T}(), 0, false, T(NaN), T(NaN), zero(T))"""
SWEEP_OLD = """  n = length(coords)
  maxh = zero(T)
  if st.random
    order = _shuffle!(st.order, n, st.rng)
    for i in 1:n
      h = _visit!(m, g, x, @inbounds(coords[order[i]]), scaled)
      h > maxh && (maxh = h)
    end
  else
    for i in 1:n
      h = _visit!(m, g, x, @inbounds(coords[i]), scaled)
      h > maxh && (maxh = h)
    end
  end
  maxh
end"""
SWEEP_NEW = """  n = length(coords)
  maxh = zero(T)
  sumh = zero(T)
  if st.random
    order = _shuffle!(st.order, n, st.rng)
    for i in 1:n
      h = _visit!(m, g, x, @inbounds(coords[order[i]]), scaled)
      h > maxh && (maxh = h)
      sumh += h
    end
  else
    for i in 1:n
      h = _visit!(m, g, x, @inbounds(coords[i]), scaled)
      h > maxh && (maxh = h)
      sumh += h
    end
  end
  st.path += sumh
  maxh
end"""
GATE = """
# Whether the rounding carried by the cached residual can reach the limit max(tol, c eps) √s‖y‖: the
# resolution eps √s (Σ‖X_k‖|x_k| + 2 path) bounds the resolution at the start plus the path.
# First with the bound Σ√(s a_k)|x_k| ≤ √(nnz Σ s a_k x_k²), which needs one square root; the sum itself
# only where that bound does not decide.
function _resolution_gate(m::LSModel{T}, x, st) where T
  m.scaled || return false
  Q = zero(T)
  nz = 0
  for k in _activeentries(x)
    v = x[k]
    iszero(v) && continue
    Q += T(m.s * m.a[k]) * v * v
    nz += 1
  end
  eps(T) * (sqrt(nz * Q) + 2 * st.path) < m.lim && return false
  P = zero(T)
  for k in _activeentries(x)
    v = x[k]
    iszero(v) || (P += _curvature_scale(m, m.a[k]) * abs(v))
  end
  eps(T) * (P + 2 * st.path) >= m.lim
end
"""
CHECK_C = """
# At the stop: a fresh residual, image first, and the unrounded step of every coordinate from it.
function _stop_check!(m::LSModel{T}, g, x, st, maxh, scaled::Bool) where T
  scaled || return :converged
  GATE_LINE
  m.rf === m.r && (m.rf = Vector{T}(undef, length(m.r)))
  rf = _fresh_residual!(m.rf, m, x)
  l1, l2 = _l1l2(g, T)
  q = zero(T)
  for k in 1:ncoordinates(x)
    a = m.a[k]
    iszero(a) && continue
    b = _column_dot(m.X, rf, k, a)[2]
    old = x[k]
    h = _scaled_prox(m, g, old + b / a, k, a) - old
    u = abs(h)
    if !iszero(old)             # where the step keeps the sign of old, the unrounded form
      su = _unrounded_signed(old, b, a, T(m.s * a), l1, l2)
      (old > 0 ? old + su > 0 : old + su < 0) && (u = abs(su))
    end
    sc = _curvature_scale(m, a)
    v = u * sc
    v >= st.tolerance || continue
    q = max(q, v / max(m.resp, l1 / sc))
  end
  q >= _ABSORB_FLOOR * eps(T) || return :converged
  m.stalled = true
  :uncertified
end
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
INIT_F = """  _fresh_residual!(m.r, m, x)     # prototype: image first
  fill!(m.a, T(NaN))
  m
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
PLAIN_F = """    converged = maxh<tol
    if full && converged
      if !fresh && _stale(m, x, st)
        _refresh!(m, x)            # prototype: the next pass is a full pass from a fresh residual
        st.path = zero(T)
        fresh = true
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
    fresh = false
  end
  x
end
_stale(m, x, st) = false
_refresh!(m, x) = m
function _usemomentum"""


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
BLOCK_INIT_F = """  _fresh_block_residual!(ls.r, ls, x)     # prototype: image first
  fill!(ls.a, T(NaN))
  m
end"""
BLOCK_F = """
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
# The gate for groups: ‖X_g x_g‖ ≤ √ℓ_g ‖x_g‖ for the curvature bound ℓ_g.
function _stale(m::BlockLSModel{T}, x, st) where T
  ls = m.ls
  ls.scaled || return false
  Q = zero(T)
  nz = 0
  for k in activecoordinates(x)
    ℓ = m.ℓ[k]
    (iszero(ℓ) || isnan(ℓ)) && continue
    q = zero(T)
    for v in blockview(x, k)
      q += v * v
    end
    Q += T(ls.s * ℓ) * q
    nz += 1
  end
  eps(T) * (sqrt(nz * Q) + 2 * st.path) < ls.lim && return false
  P = zero(T)
  for k in activecoordinates(x)
    ℓ = m.ℓ[k]
    (iszero(ℓ) || isnan(ℓ)) && continue
    P += _curvature_scale(ls, ℓ) * norm(blockview(x, k))
  end
  eps(T) * (P + 2 * st.path) >= ls.lim
end
_refresh!(m::BlockLSModel, x) = (_fresh_block_residual!(m.ls.r, m.ls, x); m)
"""


CHECK_R = """
# Report only: where the resolution gate fires, compare the cached residual with a fresh one.
function _residual_refused!(ls::LSModel{T}, rf::Vector{T}) where T
  d = zero(T)
  r = ls.r
  @inbounds @simd for i in eachindex(rf)
    d += abs2(rf[i] - r[i])
  end
  sqrt(T(ls.s)) * sqrt(d) >= ls.lim || return :converged
  ls.stalled = true
  :uncertified
end
function _stop_check!(m::LSModel{T}, g, x, st, maxh, scaled::Bool) where T
  _resolution_gate(m, x, st) || return :converged
  m.rf === m.r && (m.rf = Vector{T}(undef, length(m.r)))
  _residual_refused!(m, _fresh_residual!(m.rf, m, x))
end
function _stop_check!(m::BlockLSModel{T}, g, x, st, maxh, scaled::Bool) where T
  _stale(m, x, st) || return :converged
  ls = m.ls
  ls.rf === ls.r && (ls.rf = Vector{T}(undef, length(ls.r)))
  _residual_refused!(ls, _fresh_block_residual!(ls.rf, ls, x))
end
"""
STALE = "_stale(m::LSModel, x, st) = _resolution_gate(m, x, st)\n_refresh!(m::LSModel, x) = (_fresh_residual!(m.r, m, x); m)\n"
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
MOM_F = """    if full && converged
      if !fresh && _stale(m, x, st)
        _refresh!(m, x)            # prototype: as in the plain loop
        st.path = zero(T)
        fresh = true
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
    fresh = false
    if full
      _momentum_reset!(mom, x, m)"""


def base(tree):
    d = os.path.join(OUT, tree)
    shutil.rmtree(d, ignore_errors=True)
    os.makedirs(d)
    subprocess.run(f"git -C {WT} archive 8cc022222d3c90ef86a24ca0c957b02faaf4fc1f src | tar -x -C {d}", shell=True, check=True)


def common(tree, floor):
    edit(tree, "cd/leastsquares.jl", lambda s: rep(rep(s, FIELDS_OLD, FIELDS_NEW), CTOR_OLD, CTOR_NEW) + HELPERS_LS)
    edit(tree, "cd/models.jl", lambda s: s + HOOKS_MODELS.replace("FLOORVALUE", floor))
    edit(tree, "cd/solver.jl", lambda s: rep(rep(s, PASS_OLD, PASS_NEW), ARM_OLD, ARM_NEW))


def proto_a(tree, floor):
    common(tree, floor)
    edit(tree, "cd/leastsquares.jl", lambda s: rep(rep(s, STEP_OLD, STEP_A), BLOCK_OLD, BLOCK_A) + NOTE_A)


def path(tree):
    edit(tree, "cd/solver.jl", lambda s: rep(rep(s, STATE_OLD, STATE_NEW), SWEEP_OLD, SWEEP_NEW))


def proto_r(tree, floor):
    common(tree, floor)
    path(tree)
    edit(tree, "cd/solver.jl", lambda s: rep(s, "function _usemomentum", "_stale(m, x, st) = false\nfunction _usemomentum"))
    edit(tree, "cd/leastsquares.jl", lambda s: s + FRESH + GATE + BLOCK_F.replace("_refresh!(m::BlockLSModel, x) = (_fresh_block_residual!(m.ls.r, m.ls, x); m)\n", "") + CHECK_R)


def proto_f(tree, floor):
    proto_a(tree, floor)
    path(tree)
    edit(tree, "cd/leastsquares.jl", lambda s: s + FRESH + GATE + STALE + BLOCK_F)

    def solver(s):
        i = s.index("function _cd_plain!")
        j = s.index("function _usemomentum") + len("function _usemomentum")
        body = rep(rep(s[i:j], PLAIN_OLD, PLAIN_F), "  converged, visits = true, 0\n", "  converged, visits, fresh = true, 0, false\n")
        tail = rep(rep(s[j:], "  converged, visits = true, 0\n", "  converged, visits, fresh = true, 0, false\n"), MOM_OLD, MOM_F)
        return s[:i] + body + tail
    edit(tree, "cd/solver.jl", solver)


base("master")
for name, fn, floor in (("A", proto_a, C_A), ("R", proto_r, C_R), ("F", proto_f, C_F)):
    base(name)
    fn(name, floor)
    with open(os.path.join(OUT, name + ".diff"), "w") as io:
        subprocess.run(["diff", "-ru", "master/src", name + "/src"], cwd=OUT, stdout=io)
    print(name, "built with floor", floor, ";", sum(1 for l in open(os.path.join(OUT, name + ".diff")) if l.startswith(("+", "-")) and not l.startswith(("+++", "---"))), "changed lines")
