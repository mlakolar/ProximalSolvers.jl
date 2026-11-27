# An independent bound on the exact objective of the stored Float32 data.
# The caller checks the floating-point mode before using this workspace.
struct _DualGapWorkspace
    residual_lower::Vector{Float64}
    residual_upper::Vector{Float64}
    signed_correlation_lower::Vector{Float64}
end

_DualGapWorkspace(n::Int, p::Int) =
    _DualGapWorkspace(Vector{Float64}(undef, n), Vector{Float64}(undef, n),
                      Vector{Float64}(undef, p))

_dual_gap_fp_supported() = rounding(Float64) === RoundNearest && !Base.get_zero_subnormals()

function _dual_gap_residual_bounds!(work, X, y, x)
    lower, upper = work.residual_lower, work.residual_upper
    copyto!(lower, y)
    copyto!(upper, y)
    @inbounds for j in eachindex(x)
        coefficient = Float64(x[j])
        iszero(coefficient) && continue
        for i in eachindex(y)
            # A product of two widened finite Float32 numbers is exact.
            product = Float64(X[i, j]) * coefficient
            iszero(product) && continue
            lower[i] = prevfloat(lower[i] - product)
            upper[i] = nextfloat(upper[i] - product)
        end
    end
    nothing
end

function _dual_gap_correlation_bounds!(work, X, x)
    lower, upper = work.residual_lower, work.residual_upper
    radius = 0.0
    @inbounds for j in eachindex(x)
        correlation_lower, correlation_upper = 0.0, 0.0
        for i in eachindex(lower)
            entry = Float64(X[i, j])
            iszero(entry) && continue
            r_lower, r_upper = if signbit(entry)
                upper[i], lower[i]
            else
                lower[i], upper[i]
            end
            correlation_lower = prevfloat(correlation_lower + prevfloat(entry * r_lower))
            correlation_upper = nextfloat(correlation_upper + nextfloat(entry * r_upper))
        end
        radius = max(radius, -correlation_lower, correlation_upper)
        work.signed_correlation_lower[j] = signbit(x[j]) ? -correlation_upper : correlation_lower
    end
    radius
end

function _dual_gap_loss_bounds(work)
    lower, upper = 0.0, 0.0
    @inbounds for i in eachindex(work.residual_lower, work.residual_upper)
        r_lower, r_upper = work.residual_lower[i], work.residual_upper[i]
        magnitude_lower = max(0.0, r_lower, -r_upper)
        magnitude_upper = max(-r_lower, r_upper)
        if !iszero(magnitude_lower)
            lower = prevfloat(lower + prevfloat(magnitude_lower * magnitude_lower))
        end
        if !iszero(magnitude_upper)
            upper = nextfloat(upper + nextfloat(magnitude_upper * magnitude_upper))
        end
    end
    max(0.0, prevfloat(0.5 * lower)), nextfloat(0.5 * upper)
end

function _dual_gap_penalty_lower(x, level)
    lower = 0.0
    @inbounds for coefficient in x
        iszero(coefficient) && continue
        # The validated level is also exactly representable in Float32.
        lower = prevfloat(lower + level * abs(Float64(coefficient)))
    end
    lower
end

function _dual_gap_shrinkage(level::Float64, radius::Float64)
    radius <= level && return 1.0
    # A nearest-rounded ratio can be above the exact feasibility boundary.
    max(0.0, prevfloat(level / radius))
end

function _dual_gap_numerator_upper(work, x, level, shrinkage, loss_upper)
    # For r = y - Xx and the exact dual point shrinkage * r, the gap is
    # (1 - shrinkage)^2 * loss + sum(abs(x[j]) * (level - shrinkage * c[j])),
    # with c[j] = sign(x[j]) * X[:, j]' * r. Feasibility makes each term nonnegative.
    loss_term = if shrinkage == 1.0
        0.0
    else
        reduction = nextfloat(1.0 - shrinkage)
        nextfloat(nextfloat(reduction * reduction) * loss_upper)
    end
    numerator = loss_term
    @inbounds for j in eachindex(x)
        coefficient = abs(Float64(x[j]))
        iszero(coefficient) && continue
        correlation = prevfloat(shrinkage * work.signed_correlation_lower[j])
        slack = nextfloat(level - correlation)
        numerator = nextfloat(numerator + nextfloat(coefficient * slack))
    end
    numerator
end

function _relative_dual_gap_upper!(work::_DualGapWorkspace, X::Matrix{Float32},
                                  y::Vector{Float32}, x::Vector{Float32}, level::Float64)
    _dual_gap_residual_bounds!(work, X, y, x)
    radius = _dual_gap_correlation_bounds!(work, X, x)
    loss_lower, loss_upper = _dual_gap_loss_bounds(work)
    penalty_lower = _dual_gap_penalty_lower(x, level)
    primal_lower = prevfloat(loss_lower + penalty_lower)
    isfinite(radius) && isfinite(loss_upper) && isfinite(primal_lower) || return nothing
    if primal_lower <= 0
        return all(iszero, x) && all(iszero, y) ? 0.0 : nothing
    end
    shrinkage = _dual_gap_shrinkage(level, radius)
    numerator = _dual_gap_numerator_upper(work, x, level, shrinkage, loss_upper)
    bound = iszero(numerator) ? 0.0 : nextfloat(numerator / primal_lower)
    isfinite(bound) && bound >= 0 ? bound : nothing
end
