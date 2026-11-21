# Independent allocation diagnosis. The official timing uses the frozen benchmark.
const study = dirname(@__DIR__)
include(joinpath(study, "load.jl"))
benchmark = joinpath(study, "benchmark.jl")
replay_source = split(read(benchmark, String), "struct Replay"; limit=2)[2]
replay_source = split(replay_source, "\nfunction verify_replay"; limit=2)[1]
include_string(Main, "struct Replay" * replay_source, benchmark)

@noinline function sample(f::F, memory::R, calls) where {F,R}
    for _ in 1:calls
        memory[] = Float64(f())
    end
end
function allocations_for(f::F, calls=8) where F
    memory = Ref{Float64}(0.0)
    sample(f, memory, 2)
    b = (@allocated sample(f, memory, calls))/calls
    c = (@allocations sample(f, memory, calls))/calls
    b, c
end

function typed_norm(x)
    m = maximum(a -> abs(Float64(a)), x)::Float64
    (iszero(m) || !isfinite(m)) && return m
    m * sqrt(sum(a -> abs2(Float64(a) / m), x))
end
function typed_decision(x, g, cap)
    s = typed_norm(x)
    r = Float64(g.r)
    m = s - r
    isfinite(m) || return (; code=:unresolved, membership=:unknown, margin=m, refined=false)
    noise = norm_noise(x, g, s)
    membership = m > noise ? :outside : m < -noise ? :inside :
                 iszero(s) && r > 0 ? :inside : :unknown
    separation = m - cap
    code = separation < -noise ? :pass : separation > noise ? :over : :unresolved
    (; code, membership, margin=m, refined=false)
end
function compare(T,p,shape)
    b = replay(Val(:B), Val(:right), T, :l2, p, shape)
    for j in axes(b.points,2)
        fixed_trial!(b,j)
        @assert isequal(norm2_64(b.projected),typed_norm(b.projected))
        @assert isequal(norm_decision(b.projected,b.g,b.cap),typed_decision(b.projected,b.g,b.cap))
    end
    f,g,cap = b.projected,b.g,b.cap
    old = allocations_for(()->norm_decision(f,g,cap).code===:pass)
    new = allocations_for(()->typed_decision(f,g,cap).code===:pass)
    println((;T,p,shape,old,new))
end
for T in (Float32,Float64), p in (2,4,32,256,2048), shape in (:active,:interior,:boundary,:rounded_copy)
    compare(T,p,shape)
end
println("norm old return types ",Base.return_types(norm2_64,Tuple{Vector{Float32}}))
println("typed norm return types ",Base.return_types(typed_norm,Tuple{Vector{Float32}}))
