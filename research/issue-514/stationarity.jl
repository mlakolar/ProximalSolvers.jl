struct StopWorkspace{T}
    witness::Vector{Float64}
    residual::Vector{Float64}
    gradient::Vector{Float64}
    trial::Vector{T}
    projected::Vector{T}
end
function StopWorkspace(d::Fixture{T}) where T
    n, p = size(d.X)
    StopWorkspace(zeros(p), zeros(n), zeros(p), zeros(T, p), zeros(T, p))
end

function residual_score64!(grad, res, X::Matrix{Float64}, y, w)
    mul!(res, X, w)
    res .-= y
    mul!(grad, transpose(X), res)
    nothing
end

function residual_score64!(grad, res, X::Matrix{Float32}, y, w)
    fill!(res, 0)
    @inbounds for j in eachindex(w)
        wj = w[j]
        @simd for i in eachindex(res)
            res[i] += Float64(X[i,j]) * wj
        end
    end
    res .-= y
    @inbounds for j in eachindex(grad)
        s = 0.0
        @simd for i in eachindex(res)
            s += Float64(X[i,j]) * res[i]
        end
        grad[j] = s
    end
    nothing
end

function numerical_witness!(w, x, g)
    r = Float64(g.r)
    s = norm_64(x, g)
    noise = norm_noise(x, g, s)
    # A scratch witness backs away from the boundary by the norm arithmetic's
    # resolution, including the division and per-component multiplication.
    factor = s + noise < r ? 1.0 : min(1.0, (r - noise) / s)
    @. w = factor * Float64(x)
end

function estimate_gap(w, grad, g::L1, dual)
    s = max(0.0, Float64(g.r) - norm_64(w, g)) * dual
    @inbounds for j in eachindex(w, grad)
        s += abs(w[j]) * (dual + (signbit(w[j]) ? -grad[j] : grad[j]))
    end
    s
end

function estimate_gap(w, grad, g::L2, dual)
    r = Float64(g.r)
    s = norm_64(w, g)
    iszero(s) && return r * dual
    iszero(dual) && return 0.0
    # Unit-vector difference yields the cosine term without cancellation.
    anglesq = 0.0
    @inbounds @simd for j in eachindex(w, grad)
        anglesq += abs2(w[j]/s + grad[j]/dual)
    end
    dual * (max(0.0, r - s) + (s / 2) * anglesq)
end

function stop_scores!(work::StopWorkspace{T}, x, d, g, b, audit) where T
    w, res, grad = work.witness, work.residual, work.gradient
    numerical_witness!(w, x, g)
    residual_score64!(grad, res, d.X, d.y, w)
    grad .*= Float64(d.alpha)
    dual = dual_64(grad, g)
    n, p = size(d.X)
    alpha, r = Float64(d.alpha), Float64(d.r)
    # Magnitude estimate from a dense dot-product depth bound for the residual
    # and score, including subtraction and final loss scaling. No directed arithmetic.
    residual_noise = gamma64(p+2) * (b.frob * norm2_64(w) + norm2_64(d.y))
    score_noise = alpha * (residual_noise + gamma64(n+2) * norm2_64(res))
    gap_noise = 2r * (g isa L1 ? b.col : b.frob) * score_noise +
                gamma64(2p+12) * (2r * dual) + norm_noise(w, g, r) * dual
    gap = estimate_gap(w, grad, g, dual)

    L = T(b.curvature)
    @. work.trial = T(w) - T(grad) / L
    apply_projection!(work.projected, g, work.trial, one(T)/L, audit, :mapping)
    mapping = Float64(L) * maximum(j -> abs(Float64(T(w[j])) - Float64(work.projected[j])), eachindex(w))
    # Projection stays in T. The floor reflects resolution of the rounded step
    # input, with independent support gap and independent replay checking the outcome.
    map_noise = b.col * score_noise + Float64(eps(T)) * (Float64(L) * maximum(abs, w) + maximum(abs, grad))
    finite = all(isfinite, (gap, gap_noise, mapping, map_noise))
    pass = finite && gap + gap_noise <= b.gap && mapping + map_noise <= b.mapping
    limited = !finite || gap_noise > b.gap || map_noise > b.mapping
    (; gap, gap_noise, mapping, map_noise, pass, limited)
end
