# #515 paired timing: B0 (the #514 prototype) against the candidates B1 and B2, with strict A
# as context only. The pairing follows ../issue-514/benchmark.jl: each comparison times the
# baseline (left) and the candidate (right) with dedicated objects, 16 repetitions per process
# alternating the execution order (8 per order), plus an independent A/A pair of separately
# created baseline replicas. Each configuration runs in two fresh processes with opposite
# warm-up orders, so every cell has 32 pairs.
#
# Statistic, fixed before the official run (as in #514): the cell ratio is the median of the
# within-pair candidate/baseline time ratios; a repeatable slowdown requires all four
# warm-order x execution-order medians to exceed max(1.05, the cell's A/A 90th percentile);
# a repeatable improvement requires all four to be below min(0.95, the A/A 10th percentile).
#
# Usage: julia --project=../issue-514/env/<v> bench.jl <outdir> <forward|reverse> [short]
include(joinpath(@__DIR__, "common.jl"))
using Statistics

out, warm_order = ARGS[1:2]
short = length(ARGS) > 2 && ARGS[3] == "short"
mkpath(out)

# ---------------------------------------------------------------- end-to-end solves
struct Run{P,R,D,F,G,M}
    d::D
    f::F
    g::G
    method::M
    a::Accuracy
end
Run(::Val{P}, ::Val{R}, d, m) where {P,R} =
    Run{P,R,typeof(d),typeof(loss(d)),typeof(ball(d)),typeof(m)}(d, loss(d), ball(d), m, accuracy(d, :ordinary))

execute(w::Run{:A}) = native_A(w.d, w.f, w.g, w.method)
execute(w::Run{:B0}) = projected_policy(Val(:B), w.d, w.f, w.g, w.method, budgets(w.d, w.a), w.a)
execute(w::Run{:B1}) = B1.projected_policy(w.d, w.f, w.g, w.method, B1.budgets(w.d, w.a), w.a)
execute(w::Run{:B2}) = B2.projected_policy(w.d, w.f, w.g, w.method, B2.budgets(w.d, w.a), w.a)

@noinline function batch(w::Run, n)
    sink = 0.0
    for _ in 1:n
        r = execute(w)
        sink += Float64(r.x[1])
    end
    sink
end

# Untimed description of one arm's solve, including the independent MPFR check when cheap.
function describe(w::Run{P}, ref, best) where P
    r = execute(w)
    if P === :A
        res = r.result
        x = r.x
        status = r.status
        claimed = res !== nothing && res.converged
        it = res === nothing ? -1 : res.iterations
        grads = res === nothing ? -1 : res.grad_calls
        projs = res === nothing ? -1 : res.prox_calls
        proposals, full = -1, -1
        b = budgets(w.d, w.a)
    else
        x, status, claimed, it, grads, projs = r.x, r.status, r.success, r.iterations, r.gradients, r.projections
        proposals = r.stop_checks
        full = P === :B2 ? r.stop_checks - r.prescreen_rejects : r.stop_checks
        b = P === :B0 ? budgets(w.d, w.a) : P === :B1 ? B1.budgets(w.d, w.a) : B2.budgets(w.d, w.a)
    end
    q = ref === nothing ? nothing : independent(w.d, x, w.g, b, ref, best)
    (; status, claimed, accurate=q === nothing ? missing : q.acceptable, iterations=it, gradients=grads,
       projections=projs, proposals, full_checks=full,
       trials=P === :A ? -1 : r.trials, rejected=P === :A ? -1 : r.rejected,
       x_sha256=bytes2hex(sha256(reinterpret(UInt8, x))))
end

# ---------------------------------------------------------------- fixed work
# Proposal points: x_fail is the B1 iterate after half of B0's iterations (a proposal B0
# rejects), x_pass is B0's returned point (the accepted proposal). For each point the
# working-precision quantities B2 reads are formed exactly as the solver forms them.
struct Point{T}
    x::Vector{T}
    z::Vector{T}       # fl(X x), the cached image
    G::Vector{T}       # working gradient from z (PGD keeps this vector)
    fx::T
end
function point(d::Fixture{T}, f, x) where T
    z = zeros(T, size(d.X, 1)); dz = similar(z); G = zeros(T, length(x))
    PS._image!(z, PS._image_model(f), x)
    fx = PS._value_and_gradient!(G, x, f, z, dz)
    Point(copy(x), z, G, fx)
end

struct Proposal{Arm,Role,K,T,D,F,G,N0,N1,N2}
    d::D
    f::F
    g::G
    pt::Point{T}
    b0::N0
    b1::N1
    b2::N2
    dec1::B1.Decision   # formed by the accepted trial, outside the timed stop path
    dec2::B2.Decision
    w0::StopWorkspace{T}
    w1::B1.StopWorkspace{T}
    w2::B2.StopWorkspace{T}
end

# B0: decision at the stop (used, as in B0's stop path) and the full check.
function proposal(w::Proposal{:B0})
    dec = norm_decision(w.pt.x, w.g, w.b0.cap)
    dec.code === :pass || return false
    stop_scores!(w.w0, w.pt.x, w.d, w.g, w.b0, nothing).pass
end
# B1: the accepted trial's decision is cached by the solver; the full check reuses it.
function proposal(w::Proposal{:B1})
    w.dec1.code === :pass || return false
    B1.stop_scores!(w.w1, w.pt.x, w.dec1, w.d, w.g, w.b1, nothing).pass
end
# B2: PGD pre-screens with its own working gradient, then runs the full check only when the
# screen cannot reject; APG keeps B1's path.
function proposal(w::Proposal{:B2,R,K}) where {R,K}
    dec = w.dec2
    dec.code === :pass || return false
    K === :PGD && B2.prescreen_rejects(w.pt.G, w.pt.x, dec, w.d, w.g, w.b2, w.pt.fx) && return false
    B2.stop_scores!(w.w2, w.pt.x, dec, w.d, w.g, w.b2, nothing).pass
end
# Trial-time decision costs (the cached B1 decision is formed here, so time it with the trial).
trial_decision(w::Proposal{:B0}) = norm_decision(w.pt.x, w.g, w.b0.cap).code === :pass
trial_decision(w::Proposal) = B1.norm_decision(w.pt.x, w.g, w.b1.cap).code === :pass

struct Fixed{Op,Arm,Role,P}
    prop::P
end
@noinline function batch(w::Fixed{:proposal}, n)
    sink = 0.0
    for _ in 1:n
        sink += proposal(w.prop)
    end
    sink + 1
end
@noinline function batch(w::Fixed{:decision}, n)
    sink = 0.0
    for _ in 1:n
        sink += trial_decision(w.prop)
    end
    sink + 1
end
@noinline function batch(w::Fixed{:setup,Arm}, n) where Arm
    sink = 0.0
    p = w.prop
    for _ in 1:n
        b = Arm === :B0 ? budgets(p.d, accuracy(p.d, :ordinary)) :
            Arm === :B1 ? B1.budgets(p.d, accuracy(p.d, :ordinary)) :
            Arm === :B2 ? B2.budgets(p.d, accuracy(p.d, :ordinary)) : B2.budgets_onepass(p.d, accuracy(p.d, :ordinary))
        sink += b.cap
    end
    sink
end

function make_fixed(op, arm, role, kind, d, f, g, pt)
    a = accuracy(d, :ordinary)
    T = eltype(d.start)
    m = kind === :APG ? PS.AccProxGradDescent() : PS.ProximalGradientDescent()
    b0, b1, b2 = budgets(d, a), B1.budgets(d, a), B2.budgets(d, a)
    prop = Proposal{arm,role,kind,T,typeof(d),typeof(f),typeof(g),typeof(b0),typeof(b1),typeof(b2)}(d, f, g, pt,
             b0, b1, b2, B1.norm_decision(pt.x, g, b1.cap), B2.norm_decision(pt.x, g, b2.cap),
             StopWorkspace(d), B1.StopWorkspace(d), B2.StopWorkspace(d))
    Fixed{op,arm,role,typeof(prop)}(prop)
end

# ---------------------------------------------------------------- pairing (as #514)
function measure(w, n)
    t0 = time_ns()
    checksum = batch(w, n)
    elapsed = time_ns() - t0
    isfinite(checksum) || error("invalid timing checksum")
    Float64(elapsed) / n
end

function allocations(w, n)
    batch(w, n)
    (@allocated(batch(w, n))) / n, (@allocations(batch(w, n))) / n
end

function paired(io, info, left, right, aa0, aa1)
    warm = warm_order == "forward" ? (left, right, aa0, aa1) : (right, left, aa1, aa0)
    for w in warm
        batch(w, 1)
    end
    estimate = max(minimum(measure(left, 1) for _ in 1:3), minimum(measure(right, 1) for _ in 1:3), 1.0)
    n = clamp(round(Int, 1.5e6 / estimate), 1, 4096)
    times = short ? 2 : 16
    a_bytes, a_count = allocations(left, min(n, 32))
    b_bytes, b_count = allocations(right, min(n, 32))
    aa0_bytes, aa0_count = allocations(aa0, min(n, 32))
    aa1_bytes, aa1_count = allocations(aa1, min(n, 32))
    for k in 1:times
        forward = isodd(k) == (warm_order == "forward")
        if forward
            a, b = measure(left, n), measure(right, n)
            aa_b, aa_a = measure(aa1, n), measure(aa0, n)
        else
            b, a = measure(right, n), measure(left, n)
            aa_a, aa_b = measure(aa0, n), measure(aa1, n)
        end
        row = (; info..., warm_order, rep=k, order=forward ? :AB : :BA, aa_order=forward ? :BA : :AB, batch=n,
               a_ns=a, b_ns=b, aa_a_ns=aa_a, aa_b_ns=aa_b, a_bytes, b_bytes, aa_a_bytes=aa0_bytes,
               aa_b_bytes=aa1_bytes, a_count, b_count, aa_a_count=aa0_count, aa_b_count=aa1_count)
        position(io) == 0 && println(io, join(keys(row), '\t'))
        println(io, join(values(row), '\t'))
    end
    flush(io)
end

const CASES514 = ("tie_scale_0", "l1_interior", "l1_correlated_active", "l1_correlated_interior",
                  "l1_tied_2048_1", "l1_correlated_2048")

function e2e_workloads(T)
    ds = [d for d in fixtures(T; short) if d.name in CASES514]
    # The banded Toeplitz solves at p = 2048 (up to 320 dense iterations) stay in the parity
    # replay; the end-to-end timing uses the diagonal and block designs at that size.
    append!(ds, profile_fixtures(T; dims=short ? (2, 16) : PROFILE_DIMS, toeplitz_max=256))
    ds
end

reference_ok(d) = !startswith(d.name, "pf_") || d.design !== :dense || length(d.start) <= 256

function end_to_end(io, T)
    for d in e2e_workloads(T)
        ref = reference_ok(d) ? reference_data(d) : nothing
        best = ref === nothing ? nothing : startswith(d.name, "pf_") ? zeros(BigFloat, length(d.start)) : optimum(ball(d), ref)
        for m in methods(d), (la, ra) in ((:B0, :B1), (:B0, :B2), (:A, :B2))
            left, right = Run(Val(la), Val(:left), d, m), Run(Val(ra), Val(:right), d, m)
            aa0, aa1 = Run(Val(la), Val(:aa0), d, m), Run(Val(la), Val(:aa1), d, m)
            dl, dr = warm_order == "forward" ? (describe(left, ref, best), describe(right, ref, best)) :
                     reverse((describe(right, ref, best), describe(left, ref, best)))
            info = (; T, case=d.name, p=length(d.start), design=d.design, method=name(m), a_arm=la, b_arm=ra,
                    (Symbol("a_", k) => v for (k, v) in pairs(dl))..., (Symbol("b_", k) => v for (k, v) in pairs(dr))...)
            paired(io, info, left, right, aa0, aa1)
        end
    end
end

function fixed_work(io, T)
    dims = short ? (2, 16) : PROFILE_DIMS
    for p in dims, design in (:blocks, :toeplitz), kind in (:PGD, :APG)
        d = only(filter(v -> v.name == "pf_$(design)_active_$p", profile_fixtures(T; dims=(p,))))
        f, g = loss(d), ball(d)
        a = accuracy(d, :ordinary)
        m = kind === :APG ? methods(d)[2] : methods(d)[1]
        r0 = projected_policy(Val(:B), d, f, g, m, budgets(d, a), a)
        r0.success || continue
        half = B1.projected_policy(d, f, g, m, B1.budgets(d, a), a; maxiter=max(1, r0.iterations ÷ 2))
        for (label, x) in ((:fail, half.x), (:pass, r0.x))
            pt = point(d, f, x)
            mk(op, arm, role) = make_fixed(op, arm, role, kind, d, f, g, pt)
            # Proposal: B0 vs B1 (full check, cached decision), B0 vs B2 (screen [+ full]).
            pass0 = proposal(mk(:proposal, :B0, :x).prop)
            pass1 = proposal(mk(:proposal, :B1, :x).prop)
            pass2 = proposal(mk(:proposal, :B2, :x).prop)
            @assert pass0 == pass1 == pass2
            # pt.G is the PB oracle's gradient from fl(X x): PGD's stored gradient and the
            # vector B2 forms for APG are the same computation.
            b2 = B2.budgets(d, a)
            screened = kind === :PGD && B2.prescreen_rejects(pt.G, pt.x, B2.norm_decision(pt.x, g, b2.cap), d, g, b2, pt.fx)
            for (la, ra) in ((:B0, :B1), (:B0, :B2))
                paired(io, (; T, p, design, method=kind, op=:proposal, point=label, check_passes=pass0,
                           b2_screen_rejects=screened, a_arm=la, b_arm=ra),
                       mk(:proposal, la, :left), mk(:proposal, ra, :right), mk(:proposal, la, :aa0), mk(:proposal, la, :aa1))
            end
            label === :pass || continue
            paired(io, (; T, p, design, method=kind, op=:decision, point=label, check_passes=pass0,
                       b2_screen_rejects=screened, a_arm=:B0, b_arm=:B1),
                   mk(:decision, :B0, :left), mk(:decision, :B1, :right), mk(:decision, :B0, :aa0), mk(:decision, :B0, :aa1))
            if kind === :PGD
                for (la, ra) in ((:B0, :B1), (:B0, :B2), (:B0, :onepass))
                    paired(io, (; T, p, design, method=:any, op=:setup, point=:none, check_passes=pass0,
                               b2_screen_rejects=screened, a_arm=la, b_arm=ra),
                           mk(:setup, la, :left), mk(:setup, ra, :right), mk(:setup, la, :aa0), mk(:setup, la, :aa1))
                end
            end
        end
    end
end

setprecision(BigFloat, 2304) do
    for (file, run) in (("solves", end_to_end), ("fixed", fixed_work))
        open(joinpath(out, file * ".tsv"), "w") do io
            for T in (Float32, Float64)
                run(io, T)
            end
        end
    end
end
