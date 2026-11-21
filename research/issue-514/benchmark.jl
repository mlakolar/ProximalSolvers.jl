include("load.jl")
using Statistics

out, warm_order = ARGS[1:2]
short = length(ARGS) > 2 && ARGS[3] == "short"
mkpath(out)

struct SolveRun{P,R,D,F,G,M}
    d::D
    f::F
    g::G
    method::M
end
SolveRun(::Val{P}, ::Val{R}, d, method) where {P,R} =
    SolveRun{P,R,typeof(d),typeof(loss(d)),typeof(ball(d)),typeof(method)}(d,loss(d),ball(d),method)

execute(w::SolveRun{:A}) = native_A(w.d,w.f,w.g,w.method)
function execute(w::SolveRun{P}) where P
    a = accuracy(w.d,:ordinary)
    b = budgets(w.d,a)
    projected_policy(Val(P),w.d,w.f,w.g,w.method,b,a)
end

function solvemetadata(w::SolveRun{P}, ref, solution) where P
    a = accuracy(w.d,:ordinary)
    b = budgets(w.d,a)
    r = execute(w)
    indy = independent(w.d,r.x,w.g,b,ref,solution)
    if P === :A
        result = r.result
        return (; status=r.status, claimed=result !== nothing && result.converged, accurate=indy.acceptable,
                iterations=result === nothing ? missing : result.iterations,
                projections=result === nothing ? missing : result.prox_calls,
                gradients=result === nothing ? missing : result.grad_calls,
                gap=indy.witness_gap, violation=indy.violation, mapping=indy.mapping)
    end
    (; status=r.status, claimed=r.success, accurate=indy.acceptable,
       r.iterations,r.projections,r.gradients,gap=indy.witness_gap,indy.violation,mapping=indy.mapping)
end

@noinline function batch(w::SolveRun, n)
    sink = 0.0
    for _ in 1:n
        r = execute(w)
        sink += Float64(r.x[1])
    end
    sink
end

struct Replay{Mode,Role,T,G}
    g::G
    points::Matrix{T}
    response::Matrix{T}
    x::Vector{T}
    residual::Vector{T}
    trial::Vector{T}
    projected::Vector{T}
    expected::Matrix{T}
    cap::Float64
end

function replay(::Val{M}, ::Val{R}, ::Type{T}, ball_kind, p, shape) where {M,R,T}
    radius = one(T)
    g = ball_kind === :l1 ? PB.IndBallL1(radius) : PB.IndBallL2(radius)
    start = zeros(T,p)
    rhs = zeros(T,p)
    if shape === :interior
        rhs[1:2] .= T[0.25,-0.125]
    elseif shape === :boundary
        rhs[1] = one(T)
    elseif shape === :rounded_copy
        rhs[1:2] .= ball_kind === :l1 ? T[1,eps(T)/4] : T[1,sqrt(eps(T))/4]
    else
        rhs .= T(2)
        rhs[1] = T(1.5)
        start .= T(0.01 / sqrt(p))
    end
    points = repeat(start;outer=(1,8))
    response = repeat(rhs;outer=(1,8))
    if shape === :active
        for j in 2:8
            response[1,j] += T(j)/T(8)
            response[2,j] *= isodd(j) ? T(-1) : one(T)
        end
    end
    work = Replay{M,R,T,typeof(g)}(g,points,response,zeros(T,p),zeros(T,p),zeros(T,p),zeros(T,p),
                                   zeros(T,p,8), T === Float32 ? 1e-5 : 1e-10)
    for j in axes(points,2)
        form_trial!(work,j)
        PB.value_and_prox!(work.projected,g,work.trial,one(T))
        work.expected[:,j] .= work.projected
    end
    work
end

# Each step starts with the same represented I-design coefficients and
# response. The gradient, gradient step and probe inputs match across arms.
function form_trial!(w::Replay, j)
    copyto!(w.x,1,w.points,1+(j-1)*length(w.x),length(w.x))
    @inbounds for i in eachindex(w.residual)
        w.residual[i] = w.x[i] - w.response[i,j]
    end
    PS._step!(w.trial,w.x,w.residual,one(eltype(w.trial)))
end

function fixed_trial!(w::Replay{M}, j) where M
    T = eltype(w.trial)
    form_trial!(w,j)
    if M === :A
        v = PB.value_and_prox!(w.projected,w.g,w.trial,one(T))
        return iszero(v)
    end
    PB.prox!(w.projected,w.g,w.trial,one(T))
    if M === :B
        return norm_decision(w.projected,w.g,w.cap).code === :pass
    elseif M === :cheap
        b = Enclosure1138.wide_screen(w.projected,w.g.r)
        return b !== nothing && b[2] <= w.cap
    else
        return enclosure_decision(w.projected,w.g,w.cap,j == 8,M === :every).code === :pass
    end
end

function verify_replay(a, other)
    @assert a.points == other.points && a.response == other.response
    for j in axes(a.points,2)
        fixed_trial!(a,j)
        fixed_trial!(other,j)
        @assert same_bits(a.trial,other.trial) && same_bits(a.projected,other.projected)
        @assert same_bits(a.projected,a.expected[:,j])
    end
    bytes2hex(sha256(reinterpret(UInt8,vec(a.expected))))
end

@noinline function batch(w::Replay, n)
    sink = 0.0
    for _ in 1:n, j in axes(w.points,2)
        ok = fixed_trial!(w,j)
        sink += Float64(w.projected[1]) + ok
    end
    sink
end

struct ClippingRun{Role,T,M,F,G}
    method::M
    loss::F
    ball::G
    start::Vector{T}
end
ClippingRun(::Val{R}, m::M, f::F, g::G, x::Vector{T}) where {R,M,F,G,T} =
    ClippingRun{R,T,M,F,G}(m,f,g,x)
@noinline function batch(w::ClippingRun, n)
    sink = 0.0
    for _ in 1:n
        x = copy(w.start)
        r = PS.solve!(x,w.loss,w.ball,w.method)
        @assert r.converged
        sink += x[1]
    end
    sink
end

function measure(w::W,n) where W
    t0 = time_ns()
    checksum = batch(w,n)
    elapsed = time_ns()-t0
    isfinite(checksum) || error("invalid timing checksum")
    Float64(elapsed)/n
end

function allocations(w::W,n) where W
    batch(w,n)
    (@allocated(batch(w,n)))/n, (@allocations(batch(w,n)))/n
end

# Baseline and candidate use dedicated buffers. A/A uses separately created
# baseline replicas and separate timings. Both pair orders occur eight times.
function paired(io,info,left::A,right::B,aa0::C,aa1::D; ops=1) where {A,B,C,D}
    warm = warm_order == "forward" ? (left,right,aa0,aa1) : (right,left,aa1,aa0)
    for w in warm
        batch(w,1)
    end
    estimate = max(minimum(measure(left,1) for _ in 1:3),minimum(measure(right,1) for _ in 1:3),1.0)
    n = clamp(round(Int,1.5e6/estimate),1,4096)
    times = short ? 2 : 16
    a_bytes,a_count = allocations(left,min(n,32))
    b_bytes,b_count = allocations(right,min(n,32))
    aa0_bytes,aa0_count = allocations(aa0,min(n,32))
    aa1_bytes,aa1_count = allocations(aa1,min(n,32))
    for k in 1:times
        forward = isodd(k) == (warm_order == "forward")
        if forward
            a,b = measure(left,n),measure(right,n)
            aa_b,aa_a = measure(aa1,n),measure(aa0,n)
        else
            b,a = measure(right,n),measure(left,n)
            aa_a,aa_b = measure(aa0,n),measure(aa1,n)
        end
        row = (; info..., warm_order, rep=k, order=forward ? :AB : :BA,
               aa_order=forward ? :BA : :AB, batch=n, ops,
               a_ns=a/ops,b_ns=b/ops,aa_a_ns=aa_a/ops,aa_b_ns=aa_b/ops,
               a_bytes=a_bytes/ops,b_bytes=b_bytes/ops,aa_a_bytes=aa0_bytes/ops,aa_b_bytes=aa1_bytes/ops,
               a_count=a_count/ops,b_count=b_count/ops,aa_a_count=aa0_count/ops,aa_b_count=aa1_count/ops)
        if position(io) == 0
            println(io,join(keys(row),'\t'))
        end
        println(io,join(values(row),'\t'))
    end
end

function end_to_end(io,T)
    cases = short ? ("tie_scale_0","l2_1036_4") :
            ("tie_scale_0","l1_interior","l1_correlated_active","l1_correlated_interior",
             "l1_tied_2048_1","l1_correlated_2048","l2_1036_4","l2_1036_5","l2_422_correlated",
             "l2_blocks_active_32","l2_blocks_interior_256","l2_diagonal_active_2048","l2_blocks_active_2048")
    for d in fixtures(T;short)
        d.name in cases || continue
        ref = reference_data(d)
        solution = optimum(ball(d),ref)
        for m in methods(d), (a,b) in (d.ball === :l1 ? ((:A,:B),(:B,:C)) : ((:A,:B),))
            left,right = SolveRun(Val(a),Val(:left),d,m),SolveRun(Val(b),Val(:right),d,m)
            aa0,aa1 = SolveRun(Val(a),Val(:aa0),d,m),SolveRun(Val(a),Val(:aa1),d,m)
            # Compile according to the recorded warm-first order, including assessment calls.
            if warm_order == "forward"
                ar,br = solvemetadata(left,ref,solution),solvemetadata(right,ref,solution)
            else
                br,ar = solvemetadata(right,ref,solution),solvemetadata(left,ref,solution)
            end
            info = (; T, case=d.name, p=length(d.start), ball=d.ball, method=name(m),
                    a_arm=a,b_arm=b,a_status=ar.status,b_status=br.status,
                    a_claimed=ar.claimed,b_claimed=br.claimed,a_accurate=ar.accurate,b_accurate=br.accurate,
                    a_iterations=ar.iterations,b_iterations=br.iterations,a_gradients=ar.gradients,
                    b_gradients=br.gradients,a_projections=ar.projections,b_projections=br.projections,
                    a_gap=ar.gap,b_gap=br.gap,a_violation=ar.violation,b_violation=br.violation,
                    a_mapping=ar.mapping,b_mapping=br.mapping)
            paired(io,info,left,right,aa0,aa1)
        end
    end
end

function fixed_work(io,T)
    dims = short ? (2,4) : (2,4,32,256,2048)
    shapes = short ? (:boundary,) : (:active,:interior,:boundary,:rounded_copy)
    for p in dims, shape in shapes, g in (:l1,:l2)
        comparisons = g === :l1 ? ((:A,:B),(:B,:cheap),(:B,:stop),(:B,:every)) : ((:A,:B),)
        for (a,b) in comparisons
            left,right = replay(Val(a),Val(:left),T,g,p,shape),replay(Val(b),Val(:right),T,g,p,shape)
            aa0,aa1 = replay(Val(a),Val(:aa0),T,g,p,shape),replay(Val(a),Val(:aa1),T,g,p,shape)
            digest = warm_order == "forward" ? verify_replay(left,right) : verify_replay(right,left)
            @assert digest == verify_replay(aa0,aa1)
            info = (; T,p,shape,ball=g,a_arm=a,b_arm=b,output_sha256=digest)
            paired(io,info,left,right,aa0,aa1;ops=size(left.points,2))
        end
    end
end

function clipping_benchmark(io,T)
    cs,f,y = controls(T)
    for (label,g,_) in cs, method in (PS.ProximalGradientDescent(),PS.AccProxGradDescent())
        label === :nonnegative && method isa PS.AccProxGradDescent && continue
        x = zeros(T,length(y))
        w = map(r -> ClippingRun(Val(r),method,f,g,copy(x)),(:a,:b,:aa0,:aa1))
        paired(io,(; T,control=label,method=name(method)),w...)
    end
end

setprecision(BigFloat,2304) do
    for (file,run) in (("solves",end_to_end),("fixed",fixed_work),("clipping",clipping_benchmark))
        open(joinpath(out,file*".tsv"),"w") do io
            for T in (Float32,Float64)
                run(io,T)
                flush(io)
            end
        end
    end
end
