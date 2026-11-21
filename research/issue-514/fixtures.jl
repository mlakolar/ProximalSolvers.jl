struct Fixture{T}
    name::String
    ball::Symbol
    design::Symbol
    X::Matrix{T}
    y::Vector{T}
    r::T
    start::Vector{T}
    alpha::T
end

identity_design(T, p) = Matrix{T}(I, p, p)
function block_design(T, p)
    X = identity_design(T, p)
    for j in 1:2:p-1
        X[j+1, j] = X[j, j+1] = T(0.25)
    end
    X
end

function fixtures(::Type{T}; short=false) where T
    result = Fixture{T}[]
    function add(name, ball, X, y, r, start=zeros(T, size(X, 2)); design=:diagonal, alpha=one(T))
        push!(result, Fixture(name, ball, design, X, y, T(r), start, T(alpha)))
    end
    I2 = identity_design(T, 2)
    for k in (-20, 0, 20)
        add("tie_scale_$k", :l1, I2, fill(ldexp(one(T), k), 2), ldexp(T(0.1), k))
    end
    for tail in (T(0.25), T(2))
        x = T[1, tail * eps(T)]
        add("stationary_tail_$(tail)_eps", :l1, I2, x, one(T), copy(x))
    end
    for (j, r) in enumerate((prevfloat(one(T)), one(T), nextfloat(one(T)), T(1.001)))
        add("active_transition_$j", :l1, I2, T[2, -1], r)
    end
    add("l1_interior", :l1, I2, T[0.25, -0.375], one(T))
    add("l1_boundary_start", :l1, I2, T[0.75, -0.5], one(T), T[0.5, -0.5])
    add("l1_exact_boundary_stop", :l1, I2, T[0.75, 0.75], T(1.5), T[0.75, 0.75])
    add("l1_infeasible_start", :l1, I2, ones(T, 2), one(T), T[0.75, 0.75])
    add("l1_nonfinite_start", :l1, I2, ones(T, 2), one(T), T[NaN, 0])
    h = eps(T)
    add("rounded_zero_predictor", :l1, reshape(T[1+h], 1, 1), T[1.5+2h], T(2), T[1.5])
    X = T[1 0.375 0.125 -0.125; 0.25 1 -0.25 0.125;
          -0.125 0.125 1 0.375; 0.125 -0.25 0.125 1]
    y = T[1, -0.75, 0.375, 0.5]
    add("l1_correlated_active", :l1, X, y, T(0.6); design=:dense)
    add("l1_correlated_scaled", :l1, X, y, T(0.6); design=:dense, alpha=T(0.25))
    add("l1_correlated_interior", :l1, X, y, T(4); design=:dense)
    add("l1_correlated_transition", :l1, X, y, T(1.5), T[-0.75, 0, 0.5, 0]; design=:dense)
    for p in (4, 2, 5)
        a = zeros(T, p)
        a[1], a[2] = T === Float32 ? one(T) : T(3), T(11)
        X0 = T(2) * identity_design(T, p)
        add("l2_1036_$p", :l2, X0, T(2).*a, one(T); alpha=T(0.25))
    end
    X4 = T(2) * identity_design(T, 4)
    for r in (T(1), T(4))
        add("l2_422_ortho_$r", :l2, X4, T[4, -4, 0.5, 2], r; alpha=T(0.25))
    end
    rng = Xoshiro(422)
    X422 = 2.0 * identity_design(Float64, 4) + 0.1 * rand(rng, 4, 4)
    ball_ref = [0.6, -0.8, 0.0, 0.0]
    y422 = X422 * ball_ref + transpose(X422) \ (8 * ball_ref)
    add("l2_422_correlated", :l2, T.(X422), T.(y422), one(T); design=:dense, alpha=T(0.25))
    x = T[1, sqrt(eps(T))/4]
    add("l2_rounded_copy", :l2, I2, x, one(T), copy(x))
    add("l2_nonfinite_start", :l2, X4, ones(T, 4), one(T), T[0, Inf, 0, 0])
    for p in (short ? (4, 32) : (2, 4, 5, 32, 256, 1024, 2048))
        for (design, Xp) in ((:diagonal, identity_design(T, p)), (:blocks, block_design(T, p)))
            y = [T((mod(7j, 23) - 11) / 8) for j in 1:p]
            for (kind, r) in ((:active, T(sqrt(p) / 4)), (:interior, T(2sqrt(p))))
                add("l2_$(design)_$(kind)_$p", :l2, Xp, y, r; design, alpha=inv(T(p)))
            end
            start = zeros(T, p)
            start[1] = T(2)
            add("l2_$(design)_infeasible_$p", :l2, Xp, y, one(T), start; design, alpha=inv(T(p)))
        end
    end
    if !short
        # PB #1037, comment 7002945595 (the original vector is Float64).
        z = vcat(one(T), fill(T(1.0432899624317958e-8), 1023))
        add("l2_1050_1024", :l2, identity_design(T,1024), z, T(0.51))
        p = 2048
        Xbig = identity_design(T, p)
        for (j, r) in enumerate(T[2.048, 843.4569612191655, 1765.9906913347882, 1762.9198115568126])
            add("l1_tied_2048_$j", :l1, Xbig, ones(T, p), r)
        end
        Xblock = block_design(T, p)
        add("l1_correlated_2048", :l1, Xblock, [isodd(j) ? one(T) : T(0.5) for j in 1:p],
            T(256); design=:blocks, alpha=inv(T(p)))
    end
    result
end

function controls(T)
    X = identity_design(T, 4)
    y = T[-1.5, 0.75, 1.5, -0.25]
    ((:nonnegative, PB.IndNonnegative(), max.(zero(T), y)),
     (:box, PB.IndBox(T(-0.5), T(0.75)), clamp.(y, T(-0.5), T(0.75))),
     (:linf, PB.IndBallLinf(T(0.5)), clamp.(y, T(-0.5), T(0.5)))), PB.LeastSquaresLoss(y, X), y
end

loss(d::Fixture) = d.alpha == 1 ? PB.LeastSquaresLoss(d.y, d.X) :
                                 PB.Scaled(PB.LeastSquaresLoss(d.y, d.X), d.alpha)
ball(d::Fixture) = d.ball === :l1 ? PB.IndBallL1(d.r) : PB.IndBallL2(d.r)
const L1 = PB.IndBallL1
const L2 = PB.IndBallL2
