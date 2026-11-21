# Independent MPFR diagnostics from the represented data. The solver does
# not call these functions to select, repair or accept any iterate.
big_norm(::L1, x) = sum(abs, x)
big_norm(::L2, x) = sqrt(sum(abs2, x))
big_dual(::L1, x) = maximum(abs, x)
big_dual(::L2, x) = sqrt(sum(abs2, x))

function exact_project(::L1, z, r)
    sum(abs, z) <= r && return copy(z)
    m = sort!(abs.(z); rev=true)
    total = zero(r)
    for k in eachindex(m)
        total += m[k]
        threshold = (total - r) / k
        if k == length(m) || threshold >= m[k+1]
            return [copysign(max(0, abs(t)-threshold), t) for t in z]
        end
    end
    error("empty projection")
end

function exact_project(::L2, z, r)
    s = sqrt(sum(abs2, z))
    s <= r ? copy(z) : (r/s) .* z
end

function exact_witness(g, z, r)
    s = big_norm(g, z)
    s <= r && return z
    # Inward rounding also covers rounding of sqrt and component products.
    w = prevfloat(r/s) .* z
    factor = prevfloat(one(r))
    while big_norm(g, w) > r
        w .*= factor
    end
    w
end

function reference_data(d)
    X = if d.design === :diagonal
        BigFloat.(diag(d.X))
    elseif d.design === :blocks
        # Verify the data representation used by the sparse reference products.
        @assert d.X == block_design(eltype(d.y), length(d.start))
        BigFloat(1)/4
    else
        BigFloat.(d.X)
    end
    (; X, y=BigFloat.(d.y), r=BigFloat(d.r), s=BigFloat(d.alpha))
end

function block_mul(q::BigFloat, x)
    z = copy(x)
    for j in 1:2:length(x)-1
        z[j] = x[j] + q*x[j+1]
        z[j+1] = x[j+1] + q*x[j]
    end
    z
end
design_mul(X::BigFloat, x) = block_mul(X, x)
design_mul(X::Vector, x) = X .* x
design_mul(X::Matrix, x) = X*x
adjoint_mul(X, x) = design_mul(X, x)
adjoint_mul(X::Matrix, x) = transpose(X)*x

function optimal_l1_dense(X, y, r)
    H, z = transpose(X)*X, transpose(X)*y
    u = H\z
    sum(abs, u) <= r && return u
    p = size(X, 2)
    for signs in Iterators.product(ntuple(_ -> (-1, 0, 1), p)...)
        support = findall(!iszero, collect(signs))
        isempty(support) && continue
        signvec = BigFloat[signs[i] for i in support]
        mat = H[support, support]
        a, b = mat\z[support], mat\signvec
        lambda = (dot(signvec,a)-r)/dot(signvec,b)
        lambda >= 0 || continue
        x = zeros(BigFloat,p)
        x[support] .= a .- lambda .* b
        all(x[i] * signs[i] > 0 for i in support) || continue
        score = H*x-z
        all(abs(score[i]) <= lambda for i in 1:p if signs[i] == 0) && return x
    end
    error("no valid independent l1 support")
end

function ridge_root(normsq, target)
    normsq(zero(target)) <= target && return zero(target)
    hi = one(target)
    while normsq(hi) > target
        hi *= 2
    end
    lo = zero(target)
    for _ in 1:192
        mid = (lo+hi)/2
        if normsq(mid) <= target
            hi = mid
        else
            lo = mid
        end
    end
    hi
end

function optimal_l2_blocks(q, y, r)
    z = block_mul(q, y)
    plus, minus = (1+q)^2, (1-q)^2
    pp, mm = zero(r), zero(r)
    tail = isodd(length(y)) ? abs2(z[end]) : zero(r)
    for j in 1:2:length(z)-1
        pp += abs2(z[j]+z[j+1])/2
        mm += abs2(z[j]-z[j+1])/2
    end
    lambda = ridge_root(t -> pp/(plus+t)^2+mm/(minus+t)^2+tail/(1+t)^2, r^2)
    x = z ./ (1+lambda)
    for j in 1:2:length(x)-1
        a = (z[j]+z[j+1])/(plus+lambda)
        b = (z[j]-z[j+1])/(minus+lambda)
        x[j], x[j+1] = (a+b)/2, (a-b)/2
    end
    x
end

function optimum(g, ref)
    X, y, r = ref.X, ref.y, ref.r
    if X isa Vector
        @assert all(==(X[1]), X)
        answer = exact_project(g, y ./ X, r)
    elseif X isa BigFloat
        if g isa L2
            answer = optimal_l2_blocks(X, y, r)
        else
            # Repeated identical pairs with common active first-coordinate sign.
            @assert all(==(1), y[1:2:end]) && all(==(BigFloat(1)/2), y[2:2:end])
            answer = zeros(BigFloat, length(y))
            answer[1:2:end] .= r/(length(y)÷2)
            gradient = adjoint_mul(X, design_mul(X,answer)-y)
            @assert all(<(0), gradient[1:2:end]) &&
                    maximum(abs, gradient[2:2:end]) <= -gradient[1]
        end
    elseif g isa L1
        answer = optimal_l1_dense(X,y,r)
    else
        H, z = transpose(X)*X, transpose(X)*y
        at(t) = (H+t*I)\z
        lambda = ridge_root(t -> sum(abs2, at(t)), r^2)
        answer = at(lambda)
    end
    answer
end

function normal_cone(g::L1, w, grad, r)
    lambda = maximum(abs, grad)
    residual = maximum(j -> iszero(w[j]) ? max(0, abs(grad[j])-lambda) :
                          abs(grad[j]+copysign(lambda,w[j])), eachindex(w))
    residual, lambda * max(0, r - sum(abs,w))
end

function normal_cone(g::L2, w, grad, r)
    sq = sum(abs2,w)
    lambda = iszero(sq) ? zero(sq) : max(0,-dot(w,grad)/sq)
    maximum(abs, grad .+ lambda .* w), lambda * sqrt(sq) * max(0,r - sqrt(sq))
end

function independent(d, x, g, b, ref, best)
    if !all(isfinite, x)
        return (; violation=NaN, signed_margin=NaN, witness_gap=NaN, kkt=NaN, complementarity=NaN,
                mapping=NaN, witness_loss_change=NaN, witness_obj_error=NaN, x_error=NaN,
                exact_composite=NaN, smooth=NaN, native_grad=NaN, exact_grad=NaN, acceptable=false)
    end
    z = BigFloat.(x)
    signed = big_norm(g,z)-ref.r
    violation = max(0,signed)
    w = exact_witness(g,z,ref.r)
    @assert big_norm(g,w) <= ref.r
    residual = design_mul(ref.X,w)-ref.y
    grad = ref.s .* adjoint_mul(ref.X,residual)
    raw_gradient = ref.s .* adjoint_mul(ref.X,design_mul(ref.X,z)-ref.y)
    # Canonical support function expression, evaluated independently of our
    # numerical stop and any production or experimental projection.
    gap = max(0,ref.r * big_dual(g,grad) + dot(grad,w))
    L = BigFloat(eltype(x)(b.curvature))
    mapped = exact_project(g, w .- grad ./ L, ref.r)
    mapping = L*maximum(abs,w-mapped)
    kkt, comp = normal_cone(g,w,grad,ref.r)
    objective(v) = ref.s/2 * sum(abs2,design_mul(ref.X,v)-ref.y)
    obj_z, obj_w = objective(z), objective(w)
    change = abs(obj_z-obj_w)
    native = d.alpha .* (transpose(d.X)*(d.X*x-d.y))
    acceptable = violation <= BigFloat(b.cap) && gap <= BigFloat(b.gap) &&
                 mapping <= BigFloat(b.mapping) && change <= BigFloat(b.gap)
    (; violation=Float64(violation), signed_margin=Float64(signed), witness_gap=Float64(gap),
       kkt=Float64(kkt), complementarity=Float64(comp), mapping=Float64(mapping),
       witness_loss_change=Float64(change), witness_obj_error=Float64(obj_w-objective(best)),
       x_error=Float64(maximum(abs,z-best)), exact_composite=violation > 0 ? Inf : Float64(obj_z),
       smooth=Float64(obj_z), native_grad=Float64(maximum(abs,native)),
       exact_grad=Float64(maximum(abs,raw_gradient)), acceptable)
end
