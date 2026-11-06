# Stage 2B audit probe: what the benchmark harness's reset operations do to an iterate.
#
# It loads ProximalBase only (no ProximalSolvers), builds the iterate shapes that the
# harness resets between timed samples (benchmark/cases.jl), applies the harness's own
# reset operation to a used iterate, and prints what survives: values, active coordinates
# and the group layout. Run it against each ProximalBase under comparison and diff the
# outputs. It is an audit instrument, not a measurement: nothing here is timed.
#
#   julia --project=<env with ProximalBase> reset_semantics.jl > out.tsv
#
# Output: one `key<TAB>value` line per observation. A reset operation that throws is
# recorded as `ERROR <type>`, never skipped: every reset invocation prints a `.status` line, and
# a comparison with an erroring operand prints `ERROR`, not `true`.

using ProximalBase
using LinearAlgebra, SparseArrays

const PB = ProximalBase

observe(key, value) = println(key, '\t', value)

# Equality of two guarded observations; an `ERROR` operand makes the result `ERROR`, never `true`.
function same(a, b)
  (startswith(string(a), "ERROR") || startswith(string(b), "ERROR")) && return "ERROR operand"
  return a == b
end

function guarded(f)
  try
    return f()
  catch err
    return "ERROR " * string(typeof(err))
  end
end

active_of(x) = guarded(() -> join(collect(PB.activecoordinates(x)), ','))
nactive_of(x) = guarded(() -> PB.nactive(x))
values_hash(x) = guarded(() -> string(hash(collect(Float64, x))))
allzero(x) = guarded(() -> all(iszero, x))

observe("probe.proximalbase_version", string(pkgversion(PB)))
observe("probe.julia", string(VERSION))

# ---- P14 (paths/lasso/cd/grid8/call): reset! = fill!(x, 0.0) on a SparseIterate -------
# The harness builds x = SparseIterate(p) once and, between timed samples, resets it with
# fill!(x, 0.0) after solve_path has left a working set behind.
p = 32   # the size of the harness's regression and grouped problems (benchmark/problems.jl)
used = PB.SparseIterate(p)
for (i, v) in ((3, 1.5), (17, -2.0), (22, 0.25), (30, 4.0))   # a synthetic used working set
  used[i] = v
end
observe("sparse.used.nactive_before_reset", nactive_of(used))
observe("sparse.used.active_before_reset", active_of(used))

by_fill = copy(used)
observe("sparse.fill0.status", guarded(() -> (fill!(by_fill, 0.0); "ok")))
observe("sparse.fill0.all_values_zero", allzero(by_fill))
observe("sparse.fill0.nactive", nactive_of(by_fill))
observe("sparse.fill0.active", active_of(by_fill))

by_clear = copy(used)
observe("sparse.fill0_dropzeros.status", guarded(() -> (dropzeros!(fill!(by_clear, 0.0)); "ok")))
observe("sparse.fill0_dropzeros.all_values_zero", allzero(by_clear))
observe("sparse.fill0_dropzeros.nactive", nactive_of(by_clear))
observe("sparse.fill0_dropzeros.active", active_of(by_clear))

fresh = PB.SparseIterate(p)
observe("sparse.fresh.nactive", nactive_of(fresh))
observe("sparse.fresh.active", active_of(fresh))
observe("sparse.fill0.matches_fresh_workingset", same(active_of(by_fill), active_of(fresh)))
observe("sparse.fill0_dropzeros.matches_fresh_workingset",
        same(active_of(by_clear), active_of(fresh)))

# ---- P04/P05 (cd/group-lasso, sgl/sparse-group, call): copyto!(x, start) -------------
# x = AtomIterate(p, groups); start = copy(x); the solver writes x; the reset is
# copyto!(x, start). The groups are those of benchmark/problems.jl at p = 32 (8 groups of 4);
# the used working sets here are synthetic (set by writes, not by a solver call).
groups = [collect(j:min(j + 3, p)) for j in 1:4:p]

function atom_reset_case(label, warm_groups, used_groups)
  x = PB.AtomIterate(p, groups)
  for k in warm_groups, j in groups[k]
    x[j] = 0.5 + j / 1000
  end
  start = copy(x)
  for k in used_groups, j in groups[k]
    x[j] = -1.0 - j / 1000
  end
  observe("atom.$label.start.nactive", nactive_of(start))
  observe("atom.$label.start.active", active_of(start))
  observe("atom.$label.start.values_hash", values_hash(start))
  observe("atom.$label.used.nactive", nactive_of(x))
  observe("atom.$label.used.active", active_of(x))
  status = guarded(() -> (copyto!(x, start); "ok"))
  observe("atom.$label.copyto.status", status)
  observe("atom.$label.after.nactive", nactive_of(x))
  observe("atom.$label.after.active", active_of(x))
  observe("atom.$label.after.values_hash", values_hash(x))
  observe("atom.$label.after.matches_start_values", guarded(() -> collect(x) == collect(start)))
  observe("atom.$label.after.matches_start_active", same(active_of(x), active_of(start)))
  # The harness repeats the reset between samples: a second reset must be idempotent.
  for k in used_groups, j in groups[k]
    x[j] = 7.0
  end
  observe("atom.$label.repeat.status", guarded(() -> (copyto!(x, start); "ok")))
  observe("atom.$label.repeat.matches_start_active", same(active_of(x), active_of(start)))
  observe("atom.$label.repeat.matches_start_values", guarded(() -> collect(x) == collect(start)))
end

atom_reset_case("cold_start", Int[], [2, 5, 8])      # the harness case: start has no active group
atom_reset_case("warm_start", [3, 7], [2, 5, 8])     # start with a working set, other groups used
atom_reset_case("warm_overlap", [3, 7], [7, 8])      # used groups overlap the start's

# ---- P13 (admm/lasso/admm/construction/setup): the private SVD cache -----------------
# The setup certificate reads loss.V, loss.s2 and loss.sUtY after PB._svd_cache!(loss).
X = reshape(sin.(1:(40 * 12)), 40, 12)
y = cos.(1:40)
loss = PB.LeastSquaresLoss(y, X)
observe("setup.has_svd_cache_fn", isdefined(PB, :_svd_cache!))
observe("setup.svd_cache_call", guarded(() -> (PB._svd_cache!(loss); "ok")))
for name in (:V, :s2, :sUtY)
  observe("setup.field.$name", hasproperty(loss, name))
end
observe("setup.self_consistency",
  guarded(() -> begin
    gram = loss.V * Diagonal(loss.s2) * loss.V'
    rhs = loss.V * loss.sUtY
    max(norm(gram - X' * X, Inf) / max(1.0, norm(X' * X, Inf)),
        norm(rhs - X' * y, Inf) / max(1.0, norm(X' * y, Inf)))
  end))

# ---- QUIC (newton/glasso*/quic/tight/call): exact symmetry of the loss matrix --------
# The harness builds LogDetLoss(a.S). 0.6 checks exact symmetry. A wrapper-free matrix
# that is symmetric only up to rounding is recorded, because it is a contract change.
S = let A = reshape(cos.(1:25), 5, 5); A * A' + I end
Sasym = copy(S); Sasym[1, 2] += 1e-12
observe("quic.logdet.symmetric_matrix", guarded(() -> (PB.LogDetLoss(S); "ok")))
observe("quic.logdet.symmetric_exact", issymmetric(S))
observe("quic.logdet.asymmetric_matrix", guarded(() -> (PB.LogDetLoss(Sasym); "ok")))
observe("quic.logdet.symmetric_wrapper", guarded(() -> (PB.LogDetLoss(Symmetric(Sasym)); "ok")))

# ---- the symmetric owner the QUIC solver builds internally ---------------------------
observe("owner.supertype", string(supertype(PB.SymmetricSparseIterate)))
observe("owner.is_abstractmatrix", PB.SymmetricSparseIterate <: AbstractMatrix)
owner = PB.SymmetricSparseIterate(5)
owner[2, 1] = 3.0
observe("owner.fill0", guarded(() -> (fill!(owner, 0.0); "ok")))
observe("owner.fill0.nactive", nactive_of(owner))
observe("owner.has_p_field", hasfield(typeof(owner), :p))
