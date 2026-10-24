using LinearAlgebra, Random, Printf, Serialization

function option(name, default)
    k = findfirst(==(name), ARGS)
    k === nothing && return default
    k < length(ARGS) || error("$name needs an argument")
    ARGS[k + 1]
end
const ROOT = abspath(option("--root", joinpath(@__DIR__, "results")))
const SIZES = parse.(Int, split(option("--sizes", "10,20"), ','))
const ROUNDS = parse(Int, option("--rounds", "2"))
const MAXITER = parse(Int, option("--maxiter", "1000"))
const TOL = parse(Float64, option("--tol", "1e-10"))
const STEP_FACTORS = (0.05, 0.2, 0.5)
mkpath(ROOT)
BLAS.set_num_threads(1)

clean(x) = replace(string(x), '\t' => ' ', '\n' => ' ', '\r' => ' ')
record(io, row) = (println(io, join(clean.(row), '\t')); flush(io))
const HEADER = ("problem", "p", "s", "rank", "solver", "round", "step_factor", "seconds",
                "iterations", "objective", "max_objective_increase", "all_trace_finite", "positive_definite",
                "support", "status", "detail")
support_string(S, diagonal) = join(("$(r):$(c)" for c in axes(S, 2) for r in c:size(S, 1)
                                   if (diagonal || r != c) && !iszero(S[r, c])), ';')
function trace_diagnostics(values)
    isempty(values) && return NaN, false
    all(isfinite, values) || return Inf, false
    maximum((max(values[k] - values[k - 1], 0.0) for k in 2:length(values)); init = 0.0), true
end

function objective(d, S, U)
    theta = S + U * U'
    if d.kind == :logdet
        F = cholesky(Symmetric(theta); check = false)
        issuccess(F) || return Inf
        return dot(d.A, theta) - 2sum(log, diag(F.U))
    end
    dot(theta, d.A * theta * d.B) / 2 + dot(d.A - d.B, theta)
end

function covariance_pair(p)
    rng = Xoshiro(2400 + p)
    ox = Matrix(SymTridiagonal(1.5 .+ 0.2rand(rng, p), 0.15 .+ 0.1rand(rng, p - 1)))
    oy = copy(ox)
    oy[2, p] = oy[p, 2] = 0.13
    oy[3, p - 1] = oy[p - 1, 3] = -0.11
    oy += 0.15I
    n = 10p
    X = randn(rng, n, p) / cholesky(Symmetric(ox)).U'
    Y = randn(rng, n, p) / cholesky(Symmetric(oy)).U'
    Matrix(Symmetric(X'X / n)), Matrix(Symmetric(Y'Y / n))
end

function regression_data()
    rng = Xoshiro(2424)
    n, p, s = 200, 400, 5
    X = randn(rng, n, p)
    X .-= sum(X; dims = 1) ./ n
    for j in axes(X, 2)
        X[:, j] ./= sqrt(sum(abs2, X[:, j]) / n)
    end
    beta = zeros(p)
    beta[randperm(rng, p)[1:s]] .= 3rand(rng, (-1.0, 1.0), s)
    y = X * beta + 0.1randn(rng, n)
    y .-= sum(y) / n
    (; X, y, s, support = findall(!iszero, beta))
end
