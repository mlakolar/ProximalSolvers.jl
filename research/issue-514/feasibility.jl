module Enclosure1138
import ProximalBase
include(joinpath(@__DIR__, "enclosure", "research", "indballl1-signed-enclosure", "enclosures.jl"))
end

struct Accuracy
    coefficient_relative::Float64
    coefficient_absolute::Float64
    objective_relative::Float64
    mapping_relative::Float64
end

function accuracy(d::Fixture{T}, profile::Symbol) where T
    coeff, obj, map = T === Float32 ? (1e-5, 1e-5, 1e-4) : (1e-10, 1e-9, 1e-8)
    profile === :ordinary && return Accuracy(coeff, 0, obj, map)
    profile === :mixed && return Accuracy(coeff / 2, coeff / 2, obj, map)
    if profile === :tight
        map = T === Float32 ? 1e-10 : 1e-12
        obj = d.name == "rounded_zero_predictor" && T === Float64 ? 1e-18 : 1e-10
        return Accuracy(2.0^-40, 0, obj, map)
    end
    throw(ArgumentError("unknown accuracy profile $profile"))
end

function norm2_64(x)
    m = maximum(a -> abs(Float64(a)), x)
    (iszero(m) || !isfinite(m)) && return m
    m * sqrt(sum(a -> abs2(Float64(a) / m), x))
end

norm_64(x, ::L1) = sum(a -> abs(Float64(a)), x)
norm_64(x, ::L2) = norm2_64(x)
dual_64(x, ::L1) = maximum(abs, x)
dual_64(x, ::L2) = norm2_64(x)
gamma64(k) = (c = k * (eps(Float64) / 2); c / (1 - c))

function budgets(d, a)
    alpha = Float64(d.alpha)
    yscaled = sqrt(alpha) * norm2_64(d.y)
    col = maximum(norm2_64, eachcol(d.X))
    frob = norm2_64(d.X)
    # ||X||_{1->2} = maximum column norm. Use the Frobenius upper bound for ||X||_{2->2}.
    M = sqrt(alpha) * (d.ball === :l1 ? col : frob)
    r = Float64(d.r)
    cost = M * yscaled + 1.5 * M^2 * r
    scale = max(yscaled, sqrt(alpha) * col * r)^2 / 2
    gap = a.objective_relative * scale / 2
    cap = min(r, a.coefficient_absolute + a.coefficient_relative * r, iszero(cost) ? Inf : gap / cost)
    curvature = col > 0 ? alpha * col^2 : 1.0
    mapping = a.mapping_relative * sqrt(alpha) * col * max(yscaled, sqrt(alpha) * col * r)
    (; cap, gap, mapping, curvature, col, frob, objective_scale=scale)
end

# Non-interval ambiguity screen for the compared nonnegative norm in Float64.
# Use the serial-depth model for positive terms, including divisions, squares,
# sqrt and radius subtraction on L2. These normal-range screens are numerical tolerances.
function norm_noise(x, g, s)
    k = length(x) + (g isa L1 ? 2 : 7)
    gamma64(k) * max(s, Float64(g.r))
end

function norm_decision(x, g, cap)
    s = norm_64(x, g)
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

decision(::Val{:B}, x, g, cap; stop=false) = norm_decision(x, g, cap)

@inline function enclosure_decision(x, g::L1, cap, refine_sign, refine_all=false)
    b = Enclosure1138.wide_screen(x, g.r)
    refined = false
    if b !== nothing && (refine_all || Enclosure1138.straddles(b, cap) ||
                          (refine_sign && Enclosure1138.straddles(b, 0.0)))
        b = Enclosure1138.compensated(x, g.r)
        refined = true
    end
    b === nothing && return (; code=:unresolved, membership=:unknown, margin=NaN, refined)
    lo, hi = b
    code = hi <= cap ? :pass : lo > cap ? :over : :unresolved
    membership = hi <= 0 ? :inside : lo > 0 ? :outside : :unknown
    (; code, membership, margin=hi, refined)
end
decision(::Val{:C}, x, g::L1, cap; stop=false) = enclosure_decision(x, g, cap, stop)
