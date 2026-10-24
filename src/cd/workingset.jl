####################################
#
#  Working sets for coordinate descent (Celer, skglm)
#
####################################

# CDSolver(; workingset = true): an outer loop around the passes. One full
# gradient scores every coordinate by the scaled change √aₖ |Δxₖ| that its
# proximal step would make, the quantity of the stopping rule; the passes then
# run on the working set of the nonzero coordinates and those with the largest
# scores, to a tolerance of 0.3 times the largest score, and the set doubles at
# each round. The run stops when no score exceeds tol, or with gaptol when the
# duality gap is small enough (Massias, Gramfort and Salmon, *Celer: a fast
# solver for the lasso with dual extrapolation*, 2018; Bertrand, Klopfenstein,
# Bannier, Gidel and Massias, *Beyond L1: faster and better sparse models with
# skglm*, 2022). Within a path, the strong rule already restricts the full
# passes to a working set of its own (the candidates), so the working sets are
# not used there.

const _ws_start = 100       # the size of the first working set, at least (Celer's p0)
const _ws_ratio = 0.3       # the tolerance of a round, relative to the largest score

# whether the run uses working sets: asked for, on a SparseIterate, with a model
# whose coordinate step is the proximal step of coordinate_derivatives, so that
# a full gradient and the coordinate scales give every step, and outside the
# screening of a path
_useworkingset(s::CDSolver, m, x, st::_CDState) =
  s.workingset && st.candidates === nothing && x isa SparseIterate &&
  hasmethod(coordinate_derivatives, Tuple{typeof(m), typeof(x), Int})

function _workingset_buffers!(st::_CDState{T}, n::Int) where {T}
  ws = st.ws
  if ws === nothing || length(ws.grad) != n
    ws = _WorkingSet{T}(zeros(T, n), zeros(T, n), sizehint!(Int[], n), sizehint!(Int[], n))
    st.ws = ws
  end
  ws
end

# √aₖ |Δxₖ| for the proximal step on coordinate k from the gradient G, with the
# curvature aₖ = coordinate_scale(m, x, k)², as coordinate_step! takes it
@inline function _stepscore(m, g, x::SparseIterate{T}, G::Vector{T}, k::Int) where {T}
  sk = T(coordinate_scale(m, x, k))
  iszero(sk) && return zero(T)
  a = sk * sk
  v = x[k]
  sk * abs(prox_entry(g, v - G[k] / a, k, inv(a)) - v)
end

function _cd_workingset!(x::SparseIterate{T}, m, g, st::_CDState{T}, s::CDSolver) where {T}
  n = ncoordinates(x)
  ws = _workingset_buffers!(st, n)
  sy = s.relative ? response_scale(m, x) : one(T)
  scaled = s.relative && sy > 0
  tol = scaled ? T(s.tol) * sy : T(s.tol)
  tolmin = 8 * eps(T) * (scaled ? sy : one(T))
  usegap = s.gaptol > 0 && _hasgap(m, g)
  passes, size, converged, maxscore = 0, _ws_start, false, T(NaN)
  st.relgap = T(NaN)
  while passes < s.maxpasses
    # the gradient (from the gap, which computes it, with gaptol)
    if usegap
      res = _gap!(ws.grad, m, g, x)
      if res === nothing
        usegap = false
      else
        P, D, _ = res
        st.relgap = max(P - D, zero(T)) / max(abs(P), floatmin(T))
        if st.relgap <= s.gaptol
          converged = true
          break
        end
      end
    end
    usegap || gradient!(ws.grad, m, x)
    maxscore = zero(T)
    for k in 1:n
      sc = _stepscore(m, g, x, ws.grad, k)
      ws.score[k] = sc
      sc > maxscore && (maxscore = sc)
    end
    if maxscore <= tol
      if !usegap
        converged = true
        break
      end
      tol <= tolmin && break               # the gap cannot get smaller by tightening tol
      tol = max(tol / 10, tolmin)
    end
    # the working set: the nonzero coordinates, then the largest scores
    set, rest = ws.set, ws.rest
    empty!(set); empty!(rest)
    for k in activecoordinates(x)
      iszero(x[k]) || push!(set, k)
    end
    size = min(n, max(size, 2 * length(set)))
    for k in 1:n
      ws.score[k] > 0 && iszero(x[k]) && push!(rest, k)
    end
    m_add = min(length(rest), size - length(set))
    if m_add > 0
      partialsort!(rest, 1:m_add; by = k -> -ws.score[k])
      append!(set, view(rest, 1:m_add))
    end
    # the round: the passes on the set, to a tolerance relative to the scores
    st.candidates = set
    rtol = max(T(s.tol), T(_ws_ratio) * (scaled ? maxscore / sy : maxscore))
    inner = CDSolver(s.maxpasses - passes, Float64(rtol), s.random, s.relative, s.anderson, s.momentum, 0.0, false, false)
    _cd!(x, m, g, st, inner)
    passes += st.passes
    size = min(n, 2 * size)
  end
  st.candidates = nothing
  st.passes, st.converged, st.maxchange, st.tolerance = passes, converged, maxscore, tol
  x
end
