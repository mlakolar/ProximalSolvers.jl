# Additional dense IndBallL1 least-squares workloads for the #515 profile and the
# B0/B1/B2 parity replay. They are not part of the #514 preregistered accuracy matrix.
# Every entry is exactly representable in Float32 and Float64.
#
#   diagonal  orthogonal X = I (short solves, 1-4 iterations)
#   blocks    the #514 2x2 block design with off-diagonal 1/4 (moderate solves)
#   toeplitz  banded X[i,j] = 2^-|i-j| for |i-j| <= 16, else 0 (correlated, longer
#             solves; the band keeps every entry a normal number in Float32 and Float64)
#
# active:   radius ||y||_1 / 4, so the constraint binds;
# interior: radius 2 ||y||_1, so the unconstrained fit is interior.
profile_response(T, p) = [T((mod(7j, 23) - 11) / 8) for j in 1:p]
toeplitz_design(T, p) = [abs(i - j) <= 16 ? T(ldexp(1.0, -abs(i - j))) : zero(T) for i in 1:p, j in 1:p]

const PROFILE_DIMS = (2, 4, 16, 32, 256, 2048)

function profile_fixtures(::Type{T}; dims=PROFILE_DIMS, toeplitz_max=2048) where T
    out = Fixture{T}[]
    for p in dims
        y = profile_response(T, p)
        l1y = sum(abs, Float64.(y))
        designs = Any[(:diagonal, identity_design(T, p))]
        p >= 2 && push!(designs, (:blocks, block_design(T, p)))
        p <= toeplitz_max && push!(designs, (:dense, toeplitz_design(T, p)))
        for (design, X) in designs
            label = design === :dense ? :toeplitz : design
            for (kind, r) in ((:active, T(l1y / 4)), (:interior, T(2l1y)))
                push!(out, Fixture("pf_$(label)_$(kind)_$p", :l1, design, X, copy(y), r, zeros(T, p), one(T)))
            end
        end
    end
    out
end
