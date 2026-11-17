module SqrtLasso
# Square-root lasso coordinate descent (#332): `solve!(x, SqrtLeastSquaresLoss(y, X), NormL1(λ),
# CDSolver(...))` minimizes P(β) = ‖y − Xβ‖₂ + λ‖β‖₁. `converged = true` only where the
# residual-direction duality certificate proves (P(β) − P*)/P* ≤ 1e-4, and then `gap` is that proved
# bound; otherwise `converged = false` and `gap` is NaN. Following #305, the tests assert truthful flags
# and the quality of the objective, not bits: every certified run is checked against a dual lower bound
# that the test verifies in BigFloat, and accuracy statements are medians with a margin; the per-run
# hard bound is the 1e-4 contract. The data of the reference problems are small dyadic numbers from a
# fixed hash (no random-number stream), exact in Float32 and in Float64, so both types solve the same
# problem. The dual vectors θ* and primal points β* below come from an offline Clarabel solve (the
# script is in the run record of #332 PR A, not in test/); the test trusts neither: it checks that θ*
# is dual feasible and computes D* = θ*ᵀy ≤ P* and U* = P(β*) ≥ P* in BigFloat.
using Test, LinearAlgebra, Random, SparseArrays, ProximalBase, ProximalSolvers
using Logging: with_logger, Warn
const PS = ProximalSolvers

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

const UNCERTIFIED = r"stopped without a duality certificate"
const NOTCONVERGED = r"did not converge in maxpasses"

# The result of f() and its log records.
function logged(f)
  logger = Test.TestLogger()
  r = with_logger(f, logger)
  r, logger.logs
end
messages(logs) = [string(l.message) for l in logs]

median_of(v) = (s = sort(v); k = length(s); isodd(k) ? s[(k + 1) ÷ 2] : (s[k ÷ 2] + s[k ÷ 2 + 1]) / 2)

# P(β) = ‖y − Xβ‖₂ + λ‖β‖₁ in BigFloat at 256 bits from the stored values (λ of any Real type).
objective_big(X, y, λ, β) = setprecision(BigFloat, 256) do
  norm(big.(y) .- big.(X) * big.(Vector(β))) + big(λ) * sum(abs, big.(Vector(β)))
end

# A dual lower bound D ≤ P* from the point β, in BigFloat at 256 bits: θ = t r/‖r‖ with r = y − Xβ and
# t = min(1, λ/max_k |X_kᵀr|/‖r‖) (1 − 2^-60), which is feasible (‖θ‖ ≤ 1, ‖Xᵀθ‖∞ ≤ λ, both checked
# here), and D = θᵀy. `nothing` at an exact fit (r = 0).
function dual_bound_big(X, y, λ, β)
  setprecision(BigFloat, 256) do
    Xb, yb, λb = big.(X), big.(y), big(λ)
    r = yb .- Xb * big.(Vector(β))
    nr = norm(r)
    iszero(nr) && return nothing
    g = maximum(abs, Xb' * r) / nr
    t = min(one(BigFloat), λb / g) * (1 - big(2.0)^-60)
    θ = (t / nr) .* r
    @assert norm(θ) <= 1 && maximum(abs, Xb' * θ) <= λb
    dot(θ, yb)
  end
end

# The dual bound of a committed θ*: checks ‖θ*‖ ≤ 1 and ‖Xᵀθ*‖∞ ≤ λ in BigFloat and returns θ*ᵀy.
function committed_dual(X, y, λ, θ)
  setprecision(BigFloat, 256) do
    Xb, θb = big.(X), big.(θ)
    (norm(θb) <= 1 && maximum(abs, Xb' * θb) <= big(λ)) || return nothing
    dot(θb, big.(y))
  end
end

# One solve from x0 (copied), dense or on an owner; returns the dense point, the result and the logs.
function sqrt_solve(X, y, λ, x0; owner = false, kwargs...)
  x = owner ? SparseIterate(copy(x0)) : copy(x0)
  r, logs = logged(() -> solve!(x, SqrtLeastSquaresLoss(y, X), NormL1(λ), CDSolver(; kwargs...)))
  @test r.minimizer === x
  Vector(x), r, logs
end

# The private model of a solve, prepared as `_run_cd!` prepares it, on a SparseIterate copy of β.
function prepared_model(X, y, λ, β)
  xs = SparseIterate(copy(β))
  m = PS.cdmodel(SqrtLeastSquaresLoss(y, X), xs)
  PS.initialize!(m, xs)
  PS._prepare!(m, NormL1(λ), xs)
  m, xs
end
# The certificate of `_stop_check!` at β: (code, ratio).
certify(X, y, λ, β) = ((m, xs) = prepared_model(X, y, λ, β); PS._certify!(m, xs))

# For a certified point β: the bound holds against the dual lower bound D (D ≤ P*) and the reported
# ratio is at least the excess against the upper bound U (U ≥ P*), (P − U)/U ≤ (P − P*)/P*.
function certified_ok(X, y, λ, β, ratio, D, U)
  P = objective_big(X, y, λ, β)
  (P - D) / D <= 1e-4 && big(ratio) >= (P - U) / U
end

# ---------------------------------------------------------------------------
# Reference problems
# ---------------------------------------------------------------------------
# Deterministic small integers from a fixed hash of (i, j, s) (the splitmix64 finalizer), without a
# random-number stream, reduced to [-m, m].
function mix64(i, j, s)
  z = UInt64(i) * 0x9e3779b97f4a7c15 + UInt64(j) * 0xbf58476d1ce4e5b9 + UInt64(s) * 0x94d049bb133111eb
  z = (z ⊻ (z >> 30)) * 0xbf58476d1ce4e5b9
  z = (z ⊻ (z >> 27)) * 0x94d049bb133111eb
  z ⊻ (z >> 31)
end
small_ints(n, p, s, m) = [Int(mix64(i, j, s) % UInt64(2m + 1)) - m for i in 1:n, j in 1:p]
# λmax = ‖Xᵀy‖∞/‖y‖ (the level at and above which β = 0 is a minimizer) in BigFloat at 256 bits, and
# the dyadic level round(16 frac λmax)/16 (at least 1/16), which Float32 and Float64 both represent.
lambda_max_big(X, y) = setprecision(BigFloat, 256) do
  maximum(abs, big.(X)' * big.(y)) / sqrt(sum(abs2, big.(y)))
end
dyadic_level(X, y, frac) = max(round(16 * frac * Float64(lambda_max_big(X, y))) / 16, 1 / 16)
# The families: quarter-integer designs (sixteenths for the correlated one), integer coefficients and
# dyadic noise, so that every entry of X and y, and λ, is exact in Float32 and in Float64.
function reference_problem(name)
  if name == "full rank"
    n, p = 30, 10
    X = small_ints(n, p, 1, 4) ./ 4
    y = X * [2; -1; 1; zeros(p - 3)] .+ vec(small_ints(n, 1, 2, 4)) ./ 8
    frac = 0.2
  elseif name == "rank deficient"
    n, p = 30, 12
    X = small_ints(n, p, 3, 4) ./ 4
    X[:, 11] .= X[:, 1] .+ X[:, 2]
    X[:, 12] .= X[:, 3] .- X[:, 4]
    y = X * [1; -2; 0; 1; zeros(p - 4)] .+ vec(small_ints(n, 1, 4, 4)) ./ 8
    frac = 0.2
  elseif name == "correlated"
    n, p = 30, 20
    X = (3 .* small_ints(n, 1, 5, 4) .+ small_ints(n, p, 6, 3)) ./ 16
    y = X * [1; -1; 1; zeros(p - 3)] .+ vec(small_ints(n, 1, 7, 4)) ./ 8
    frac = 0.2
  elseif name == "p > n"
    n, p = 20, 40
    X = small_ints(n, p, 8, 4) ./ 4
    y = X * [1; -2; 1; zeros(p - 3)] .+ vec(small_ints(n, 1, 9, 4)) ./ 4
    frac = 0.4
  elseif name == "exact fit"
    n, p = 8, 20
    X = small_ints(n, p, 10, 4) ./ 4
    y = X * [1; -2; 1; zeros(p - 3)]
    frac = 0.05
  elseif name == "near-exact fit"
    n, p = 12, 30
    X = small_ints(n, p, 11, 4) ./ 4
    y = X * [1; -1; 1; zeros(p - 3)] .+ vec(small_ints(n, 1, 12, 4)) ./ 65536
    frac = 0.05
  elseif name == "duplicate columns"
    n, p = 30, 12
    X = small_ints(n, p, 13, 4) ./ 4
    X[:, 7:12] .= X[:, 1:6]
    y = X * [1; -1; 0; 1; zeros(p - 4)] .+ vec(small_ints(n, 1, 14, 4)) ./ 8
    frac = 0.2
  else
    error("unknown reference problem $name")
  end
  X, y, dyadic_level(X, y, frac)
end
const REFERENCE_NAMES = ["full rank", "rank deficient", "correlated", "p > n", "exact fit", "near-exact fit", "duplicate columns"]
const EXACT_FIT_NAMES = ["exact fit", "near-exact fit"]

# The committed references of each family, from the offline Clarabel solve (status, P*, D*, U* in the
# run record): the level, exact sums of X and y (which identify the data), a dual vector θ* scaled into
# the strict interior of the dual feasible set, and the solver's primal point β*.
const REFERENCES = Dict(
    "full rank" => (λ = 0.5625, sumx = -12//1, sumy = -41//8,
      θ = [
        -0.04082747564189115, -0.04598657637805752, -0.2334221511472265, 0.26924703013735357,
        0.182504002184404, 0.28466986297919245, 0.03374402993110648, 0.21293059954692362,
        -0.28635507680606487, -0.30947877853230826, -0.036784927010709595, -0.1159043781340236,
        0.2348662716845275, 0.1277162467811889, 0.22649406566149854, 0.0580447571750171,
        -0.05994396579990324, 0.21776099577335456, 0.24058893011654103, -0.08503284789980753,
        -0.041162281109508994, 0.0843809863285202, 0.012836298062142934, 0.31344776731978685,
        0.16258297485710652, 0.1848826305111329, 0.013747800816490206, -0.1562357784927739,
        -0.28479440893281077, -0.005769971502606367],
      β = [
        1.9690818054008534, -0.9278677870007718, 0.8682690085290437, -0.019012179856112137,
        2.1175964116290592e-13, -0.06584043168727655, 7.674579613322495e-13, -9.040836865050762e-13,
        -0.1044765552611398, -4.709776827736603e-14]),
    "rank deficient" => (λ = 0.625, sumx = -47//4, sumy = 25//8,
      θ = [
        -0.01646365145146774, 0.30217285064601473, 0.04813644811354457, -0.17146913709723882,
        -0.19469954495281439, -0.1430316731927988, -0.2266167910420614, 0.1804251026237943,
        0.025482978652948816, 0.21937846341746667, 0.11932358161507106, -0.1868468725616912,
        -0.14823578935169002, 0.2821426813198083, -0.1348798361977512, 0.2278047775313078,
        -0.06779620546544714, -0.25034756727747526, -0.25984338711140087, -0.009226442602422976,
        0.12113724137994479, -0.010779613678438911, 0.008323897608455573, 0.2883478146104276,
        -0.1962618046848239, -0.012538339232742605, 0.365208859340005, 0.09607980925419385,
        0.21732782433268255, -0.058660278108713604],
      β = [
        0.8095059126856169, -1.896467247459401, 0.006656962501781533, 0.8144339217941243,
        -2.278108072721821e-12, -1.2146910768311e-12, -0.08899617140534268, 5.8993413512846145e-12,
        -0.008342527056728935, -9.124092581577368e-12, 3.250778622777974e-15, -3.90777579223504e-14]),
    "correlated" => (λ = 0.5, sumx = -335//8, sumy = -79//16,
      θ = [
        -0.2127766674269394, -0.013996353234678221, -0.26130823356511695, -0.15895003923772674,
        -0.13136282677196195, -0.21149445400231792, 0.0520384557153497, 0.136016697120464,
        -0.1445829342423117, -0.2032989645464223, -0.2715274420964102, -0.21365338051020968,
        -0.2595895467511459, 0.25190002832012215, -0.06556357771597573, 0.2796881807734126,
        -0.10488787439769075, -0.06303389624820047, 0.3444097714918842, -0.36656686722187365,
        -0.1346997580568347, 0.07078913678237932, 0.038347109149040125, 0.03102835432793637,
        -0.16502133017020107, -0.1176714924568613, 0.1628276682238252, -0.0007762440970688951,
        0.041819249033570545, -0.1411418058943254],
      β = [
        0.6177727714227937, 1.349920701285738e-13, 0.2924471755660042, 2.5808663076819995e-13,
        7.243638265965338e-14, 5.6315113971388194e-14, 7.005001743769784e-14, 1.1437915994607083e-13,
        1.8584138828885337e-13, 9.128663872604102e-14, -6.9141413615298645e-15, 7.096219361378746e-14,
        2.913162697055237e-13, 6.897946423149902e-14, 4.3480015474675874e-13, 1.1680625651746489e-13,
        1.4571155004564976e-13, 1.7207481515741073e-13, 3.1904421974827334e-13, 3.4309885563235813e-13]),
    "p > n" => (λ = 0.75, sumx = -63//4, sumy = 12//1,
      θ = [
        -0.03464317373375438, -0.052219434078336666, -0.07599585174429636, -0.0635559260279658,
        0.33411359541701163, -0.4298529265559687, 0.19188672298929324, -0.016385547656811408,
        0.1001195621043223, 0.34237238749082577, -0.33972953519122845, 0.14929019678940453,
        -0.01463287354662986, 0.06822566428993425, -0.16526661147012742, -0.12466817632095469,
        0.1789380097385966, 0.4099945836889482, -0.2751412514772046, 0.2535274666166967],
      β = [
        0.6566040372123644, -1.5347884630886321, 1.201486710438205, -0.35026544733874715,
        -0.19446587153122777, 1.2586058415628948e-13, -1.653498832281365e-14, 1.1261970824351098e-13,
        -3.58734742268876e-14, -0.12481294001491207, 9.46178469605572e-14, -2.0146114864873693e-14,
        -8.921528221948346e-14, 1.043259894421171e-14, -2.9584088061841e-14, -8.757579555234668e-14,
        0.15835817606984695, -1.3831512340903446e-13, -0.13199584564948225, 2.0776035142027443e-13,
        2.6075741434339555e-14, -2.045585471107779e-14, -1.0421328994344195e-13, -4.159891354634195e-14,
        -7.405229720691646e-14, -1.9014587465421685e-12, -6.241088508695629e-15, 2.9606062191314574e-14,
        0.23200886743474716, -2.1233625955548195e-13, 3.014611612329595e-14, -2.7095671149609676e-14,
        1.062740227466557e-14, 0.15221872582756213, 1.088087765638856e-13, 3.6579230462208694e-14,
        -9.615299955901386e-15, 8.758711440703357e-14, -3.289982812040072e-14, 1.1943094469683838e-13]),
    "exact fit" => (λ = 0.0625, sumx = -9//4, sumy = 3//2,
      θ = [
        0.023171799192561113, -0.02941775839935398, 0.04092247162033548, -0.033560901822526155,
        -0.01249317684334437, 0.00815760672539605, 0.027865511279497174, -0.0261113393954142],
      β = [
        1.0000000000048643, -1.9999999999913074, 0.999999999985715, 3.084693939876902e-12,
        -3.482692973892953e-12, 1.3103199473030176e-12, 7.845444879677952e-13, -1.6596546200981668e-13,
        1.1915992477755749e-12, 2.4100669148472647e-13, 2.60884013281995e-13, 2.739999908262213e-12,
        -7.522753964356865e-13, -1.6454745872118274e-12, -3.1654137266275765e-12, -9.958399645074065e-13,
        5.444789440458622e-12, -7.232807869718339e-13, 4.853714462679037e-13, -1.306880890672746e-12]),
    "near-exact fit" => (λ = 0.125, sumx = -1//1, sumy = -1//32768,
      θ = [
        0.04316627499948829, 0.012017309232599166, 0.0190238236547944, 0.03518337299843581,
        0.10414690667972401, -0.028398380322034844, -0.01839138583221241, -0.008860021139006245,
        -0.018651955492685127, 0.026239618792502386, -0.019025605976977854, -0.15814199413651653],
      β = [
        0.9999909011523713, -0.9999626919731393, 1.0000101487411432, 7.062911220418568e-14,
        7.272229451632858e-15, 1.3310051737840551e-15, 1.0354950773691836e-14, -1.030051802363549e-14,
        -2.0882076555860567e-6, -5.074574866556437e-14, -8.580958470349936e-15, -5.409489329746849e-15,
        4.710796770556282e-6, 5.056300604525435e-15, 1.4748905491641392e-14, 8.470100364368489e-14,
        -2.0086854253155752e-5, -6.083421680599436e-15, -2.5824130832576796e-5, 3.0528295800141996e-6,
        -1.9530056426220336e-6, -7.574104298599258e-15, 1.7375541248192812e-5, -1.8092076969696295e-5,
        7.736574531077096e-14, -4.098236953178218e-15, -5.365469032705105e-6, 2.049213239781364e-15,
        6.804450521730723e-15, -1.0831349931684555e-14]),
    "duplicate columns" => (λ = 0.4375, sumx = 43//2, sumy = 41//8,
      θ = [
        0.37974942816159774, 0.026385320462683493, -0.11783527251309735, -0.24542737964705763,
        -0.07042893410849474, 0.15869563714663384, 0.11777417589630448, 0.08194226082829115,
        -0.05395112153958556, 0.18724820747657453, 0.3550913829118042, 0.07701344403110393,
        -0.26636782019812244, 0.2068181768514082, 0.133610368792816, 0.204732246547888,
        -0.06536555892042345, 0.04059318571976385, -0.05714819664799059, 0.12528884668804935,
        0.2748782572335109, 0.07844164759353667, -0.1328646205456791, 0.022194373623978938,
        0.18766345708788854, -0.3203313026932626, -0.06312035744360919, -0.27900695538060344,
        -0.11792707123049151, -0.1686785142548324],
      β = [
        0.42982159214579174, -0.4541736906769168, -2.3403395566695265e-13, 0.3708100007570098,
        1.0598244557017439e-13, 0.031805958274124795, 0.4298215697334993, -0.4541737919870987,
        -2.3403395566660646e-13, 0.3708099215469737, 1.0598244556987889e-13, 0.031805958100568944]),
)

# ---------------------------------------------------------------------------
# A. The coordinate step and analytic cases
# ---------------------------------------------------------------------------

# One coordinate step of the model of one column xk at the value `old`: the new value and the cached
# residual r = y − xk old (rounded in T) that the step starts from.
function step_once(xk::Vector{T}, y::Vector{T}, λ::T, old::T) where T
  m, xs = prepared_model(reshape(copy(xk), :, 1), y, λ, T[old])
  r = copy(m.ls.r)
  PS.coordinate_step!(m, NormL1(λ), xs, 1)
  xs[1], r
end

# The step bound. For the coordinate problem φ(z) = ‖ρ − x z‖₂ + λ|z|, with ρ = r + x old the residual
# without the coordinate (r the cached residual), a = ‖x‖², c = xᵀρ/a and d = ‖ρ − c x‖ = ‖r − (xᵀr/a) x‖,
# the step forms a, b = xᵀr and ‖r‖² in T. With u = eps(T)/2, γ_n = n u/(1 − n u), and to first order in
# u where nothing underflows: â = a (1 + θ) with |θ| ≤ γ_n, |b̂ − b| ≤ γ_n √a ‖r‖ (Cauchy–Schwarz), and the
# computed ‖r‖² carries γ_n. In exact arithmetic on the computed ra = fl(√â), d̂ and ĉ, the step's
# threshold is that of the minimizer of the model φ′(z) = √(a′ (z − ĉ)² + d̂²) + λ|z| with a′ = ra²; it is
# formed with at most 7 roundings (relative 7u), and the shrink adds one, so the result is within
# 8.2u |ĉ| of that minimizer. Model errors: |√a′ − √a| ≤ (γ_n/2 + u) √a; √a |ĉ − c| ≤ (2γ_n + u) ‖r‖ +
# u ‖ρ‖ (c = old + b/a); |d̂ − d| ≤ (16γ_n + 13u) ‖r‖ for d̂² = ‖r‖² − b (b/a) at d̂² ≥ ‖r‖²/16 (the
# division by d̂ ≥ ‖r‖/4 gives the factor 4), and (3γ_n + 4u) ‖r‖ for the recomputed ‖r − (b/a) x‖. For
# z between 0 and c (where z* and the step lie), √a |c| ≤ ‖ρ‖ and |λ − T(λ)| |z| ≤ u ‖ρ‖ give
# |φ(z) − φ′(z)| ≤ (γ_n/2 + 3u) ‖ρ‖ + (18γ_n + 14u) ‖r‖, and φ′ is 2√a′-Lipschitz there (λ < √a′). So
#   φ(step) − min φ ≤ 2 sup |φ − φ′| + 2√a′ 8.2u |ĉ| ≤ (37γ_n + 52.4u) max(‖ρ‖, ‖r‖),
# and the test allows (37γ_n + 56u) max(‖ρ‖, ‖r‖), a margin of 3.6u for the second-order terms. A
# rounding into the subnormal range adds an absolute error of at most η/2 (η = nextfloat(zero(T))),
# which moves φ by at most (√a + λ) η/2; the test allows 4 (√a + λ) η for these. The paths that form
# the threshold in Float64 (`_sqrt_band_step`) or scale the column and the residual by powers of two
# (`_sqrt_offrange_step`, where a curvature or a residual is outside the clean range of the fast path, so
# that its squares do not underflow there) have the same counts or fewer roundings in T.
step_bound(::Type{T}, n, S, ra, λ) where T =
  (37 * (n * eps(T) / 2) / (1 - n * eps(T) / 2) + 56 * eps(T) / 2) * S + 4 * (ra + λ) * nextfloat(zero(T))

# The excess φ(z) − min φ of the value z and the bound, as Float64s, for the cached r and `old`.
# min φ is the least value of φ, in BigFloat at 256 bits, at 0, at c, at the closed form
# shrink(c, λ d/√(a (a − λ²))) (0 for λ ≥ √a) and at the end of 200 golden-section steps on the interval
# between 0 and c, which holds a minimizer.
function step_excess(xk::Vector{T}, r, λ, old, z) where T
  setprecision(BigFloat, 256) do
    x, λb = big.(xk), big(λ)
    ρ = big.(r) .+ x .* big(old)
    φ(v) = norm(ρ .- x .* v) + λb * abs(v)
    a = dot(x, x)
    c = dot(x, ρ) / a
    d = norm(ρ .- c .* x)
    zc = λb >= sqrt(a) ? big(0) : (τ = λb * d / sqrt(a * (a - λb^2)); sign(c) * max(abs(c) - τ, big(0)))
    lo, hi = minmax(big(0), c)
    gr = (sqrt(big(5)) - 1) / 2
    for _ in 1:200
      m1, m2 = hi - gr * (hi - lo), lo + gr * (hi - lo)
      φ(m1) < φ(m2) ? (hi = m2) : (lo = m1)
    end
    best = minimum(φ, (big(0), c, zc, (lo + hi) / 2))
    S = max(norm(ρ), norm(big.(r)))
    Float64(φ(big(z)) - best), Float64(step_bound(T, length(xk), S, sqrt(a), λb))
  end
end
step_ok(xk, y, λ, old) = ((z, r) = step_once(xk, y, λ, old); (e, b) = step_excess(xk, r, λ, old, z); e <= b)

@testset "coordinate step, one column ($T)" for T in (Float64, Float32)
  xk = T[1, 2, -1, 0.5]                     # a = 6.25, √a = 2.5, exact
  # d = 0 (y parallel to the column): the minimizer is the least-squares centre c = 3
  z, _ = step_once(xk, 3 .* xk, T(0.5), zero(T))
  @test z == 3
  # λ ≥ √a: 0, also at λ = √a
  @test step_once(xk, T[1, 0, 2, -1], T(3), zero(T))[1] == 0
  @test step_once(xk, T[1, 0, 2, -1], T(2.5), T(0.75))[1] == 0
  y = T[1, 0, 2, -1] .+ 2 .* xk
  for λ in (prevfloat(T(2.5)), T(2.5) * (1 - T(2)^-12), T(1.25), T(2)^-20), old in (zero(T), T(0.75), T(-3))
    @test step_ok(xk, y, λ, old)
  end
  # the guard zone: r nearly parallel to the column (d²/‖r‖² about 2^-21), and both sides of d² = ‖r‖²/16
  @test step_ok(xk, 2 .* xk .+ T(2)^-10 .* T[2, -1, 0, 0], T(0.5), zero(T))
  e1 = T[1, 0, 0, 0]
  for t in (T(3.87), T(3.88))               # d²/‖r‖² = 1/(t² + 1): above and below 1/16
    @test step_ok(e1, T[t, 1, 0, 0], T(0.25), zero(T))
  end
  # a tiny column whose squared norm is subnormal in T: γ is outside the normal range, and the
  # threshold is formed by `_sqrt_band_step` (here about 2^29, of the order of the centre)
  s, ys = T === Float32 ? (70, -30) : (530, -400)
  tiny = T(2)^-s .* xk
  @test issubnormal(sum(abs2, tiny))
  for old in (zero(T), T(2)^(ys + s - 2))
    @test step_ok(tiny, T(2)^ys .* T[1, 0, 2, -1], T(2)^(-s - 1), old)
  end
  # a subnormal residual: r = y is subnormal in every nonzero entry (`_sqrt_offrange_step`)
  sub = T(2)^(T === Float32 ? -140 : -1060)
  @test step_ok(xk, sub .* T[1, 0, 2, -1], T(2)^-10, zero(T))
  # a column at the large end of the range
  big_col = T(2)^(T === Float32 ? 40 : 300) .* xk
  @test step_ok(big_col, T[1, 0, 2, -1], T(2)^(T === Float32 ? 38 : 298), zero(T))
end

@testset "coordinate step, random one-column problems against the derived bound ($T)" for T in (Float64, Float32)
  rng = Xoshiro(2024)
  worst = 0.0
  for trial in 1:400
    n = rand(rng, 2:12)
    xk = T.(randn(rng, n))
    ρ = T.(randn(rng, n))
    mode = trial % 5
    mode == 1 && (ρ = xk .* T(randn(rng)) .+ T(1e-6) .* ρ)     # nearly parallel
    mode == 2 && (ρ = xk .* T(randn(rng)))                     # parallel up to the rounding of the product
    mode == 4 && (ρ = xk .* T(1e3 * randn(rng)) .+ ρ)          # a dominant partial residual
    λ = T(abs(randn(rng)) * norm(xk) * (mode == 3 ? 1.2 : 0.7))
    old = T(randn(rng))
    z, r = step_once(xk, ρ, λ, old)
    e, b = step_excess(xk, r, λ, old, z)
    worst = max(worst, e / b)
    @test e <= b
  end
  @test worst <= 1
end

@testset "analytic cases ($T)" for T in (Float64, Float32)
  # y = 0: β = 0, P = 0, certified with gap 0 at the first pass
  X = T[1 2 3; 4 5 6]
  x, r, logs = sqrt_solve(X, zeros(T, 2), T(0.5), zeros(T, 3); order = :cyclic)
  @test r.converged && r.gap == 0 && r.passes == 1 && iszero(x) && r.minimum == 0 && isempty(logs)
  # a zero column: its coefficient stays 0 and the run is certified
  X = T[1 0 2; 2 0 -1; 0 0 1; 1 0 1]
  y = T[1, 2, 3, 1]
  x, r, _ = sqrt_solve(X, y, T(0.25), zeros(T, 3); order = :cyclic)
  @test r.converged && x[2] == 0 && 0 <= r.gap <= 1e-4
  # λ ≥ λmax = ‖Xᵀy‖∞/‖y‖ from 0: β = 0, certified
  λ = T(2 * Float64(lambda_max_big(X, y)))
  x, r, _ = sqrt_solve(X, y, λ, zeros(T, 3); order = :cyclic)
  @test r.converged && iszero(x) && 0 <= r.gap <= 1e-4 && r.passes == 1
  # #156: X = [1 2; 0 1], y = [1, 0], λ = 0.1. The minimizer (1, 0) is an exact fit with P* = 0.1 (the
  # dual point (0.1, -0.1) has value 0.1). Started there, CD keeps it, and the run is not certified.
  X, y = T[1 2; 0 1], T[1, 0]
  x, r, logs = sqrt_solve(X, y, 0.1, T[1, 0]; order = :cyclic)
  @test x == [1, 0] && !r.converged && isnan(r.gap) && isapprox(r.minimum, 0.1; rtol = 4eps(T))
  @test length(logs) == 1 && occursin(UNCERTIFIED, messages(logs)[1])
  # #155: X = [1 1; 0 0.01], y = X (1, -1), λ = 0.1. Started at the exact fit (1, -1), no single
  # coordinate improves P = 0.2, while P* = ‖y‖ = 0.01 at 0. The run stops after one pass, uncertified.
  X = T[1 1; 0 0.01]
  y = X * T[1, -1]
  x, r, logs = sqrt_solve(X, y, 0.1, T[1, -1]; order = :cyclic)
  @test x == [1, -1] && !r.converged && isnan(r.gap) && r.passes == 1
  @test length(logs) == 1 && occursin(UNCERTIFIED, messages(logs)[1])
  # the same problem from 0 is certified at P* = 0.01
  x, r, logs = sqrt_solve(X, y, 0.1, zeros(T, 2); order = :cyclic)
  @test r.converged && iszero(x) && 0 <= r.gap <= 1e-4 && isempty(logs)
  @test isapprox(r.minimum, objective_big(X, y, 0.1, x); rtol = 4eps(T))
end

# A dominant coefficient (Stage 0 finding 7, with the deterministic data of this file): with
# β₁ about 2^20 the threshold tol ‖y‖ is loose, the first converged full pass is not certified, and a
# tightening of the threshold certifies the run (Float64). For Float32 the tightening floor
# 16 eps(Float32) ‖y‖ is above tol ‖y‖/100, so there is no tightening: with these data the first check
# certifies; the test asserts a certified bound or an uncertified stop before maxpasses.
function dominant_problem()
  n, p = 100, 30
  X = small_ints(n, p, 21, 4) ./ 4
  y = X * [2.0^20; 1; -1; 0.5; zeros(p - 4)] .+ vec(small_ints(n, 1, 22, 4)) ./ 8
  X, y, dyadic_level(X, y, 0.1)
end
@testset "dominant coefficient: certified after a tightening (Float64), no tightening (Float32)" begin
  X, y, λ = dominant_problem()
  _, r0, _ = sqrt_solve(X, y, λ, zeros(30); order = :cyclic, maxpasses = 0)
  tol0 = r0.tolerance
  x, r, logs = sqrt_solve(X, y, λ, zeros(30); order = :cyclic, maxpasses = 2000)
  @test r.converged && isempty(logs) && 0 <= r.gap <= 1e-4
  # a tightening happened only after a check that did not certify
  @test r.tolerance in (tol0 / 100, tol0 / 100 / 100)
  @test r.maxchange < r.tolerance
  D = dual_bound_big(X, y, λ, x)
  @test (objective_big(X, y, λ, x) - D) / D <= 1e-4
  X32, y32 = Float32.(X), Float32.(y)
  _, r0, _ = sqrt_solve(X32, y32, λ, zeros(Float32, 30); order = :cyclic, maxpasses = 0)
  x, r, logs = sqrt_solve(X32, y32, λ, zeros(Float32, 30); order = :cyclic, maxpasses = 2000)
  @test r.tolerance == r0.tolerance && r.passes < 2000
  if r.converged
    D = dual_bound_big(X32, y32, λ, x)
    @test 0 <= r.gap <= 1e-4 && (objective_big(X32, y32, λ, x) - D) / D <= 1e-4 && isempty(logs)
  else
    @test isnan(r.gap) && length(logs) == 1 && occursin(UNCERTIFIED, messages(logs)[1])
  end
end

# ---------------------------------------------------------------------------
# B. Reference problems with committed, self-verifying references
# ---------------------------------------------------------------------------

# The references of a family: the data, the level, D* = θ*ᵀy and U* = P(β*), checked in BigFloat.
function reference(name)
  X, y, λ = reference_problem(name)
  ref = REFERENCES[name]
  D = committed_dual(X, y, λ, ref.θ)
  (; X, y, λ, ref, D, U = objective_big(X, y, λ, ref.β))
end

@testset "references are exact data and verified bounds: $name" for name in REFERENCE_NAMES
  (; X, y, λ, ref, D, U) = reference(name)
  @test λ == ref.λ && sum(Rational{BigInt}.(X)) == ref.sumx && sum(Rational{BigInt}.(y)) == ref.sumy
  @test Float32.(X) == X && Float32.(y) == y && Float32(λ) == λ
  @test D !== nothing && D > 0 && U >= D && (U - D) / D <= 1e-9
end

# The runs of one family and type: cyclic on a dense vector (momentum off by default); random on a
# dense vector (momentum on by default); random on an owner with momentum false and true; and a warm
# start, cyclic on an owner, from β* plus a fixed perturbation. Families with an exact-fit optimum get
# maxpasses = 2000.
function reference_runs(name, ::Type{T}) where T
  (; X, y, λ, ref) = reference(name)
  XT, yT = T.(X), T.(y)
  p = size(X, 2)
  mp = name in EXACT_FIT_NAMES ? 2000 : 100_000
  warm = T.(ref.β .+ [isodd(k) ? 0.125 : -0.25 for k in 1:p])
  runs = [("cyclic dense", zeros(T, p), (; order = :cyclic)),
          ("random dense", zeros(T, p), (; rng = Xoshiro(1))),
          ("random owner momentum=false", zeros(T, p), (; rng = Xoshiro(2), momentum = false, owner = true)),
          ("random owner momentum=true", zeros(T, p), (; rng = Xoshiro(3), momentum = true, owner = true)),
          ("warm cyclic owner", warm, (; order = :cyclic, owner = true))]
  [(label, sqrt_solve(XT, yT, λ, x0; maxpasses = mp, kw...)...) for (label, x0, kw) in runs]
end

@testset "reference problems ($T)" for T in (Float64, Float32)
  excess_ordinary = Float64[]
  certified_ordinary, total_ordinary = 0, 0
  for name in REFERENCE_NAMES
    (; X, y, λ, D, U) = reference(name)
    ordinary = !(name in EXACT_FIT_NAMES)
    for (label, x, r, logs) in reference_runs(name, T)
      P = objective_big(X, y, λ, x)
      if r.converged
        # the contract, against the verified dual bound, and the reported bound against U* ≥ P*
        @test (P - D) / D <= 1e-4
        @test 0 <= r.gap <= 1e-4 && big(r.gap) >= (P - U) / U
        @test r.maxchange < r.tolerance && isempty(logs)
        @test isapprox(r.minimum, P; rtol = (size(X, 1) + size(X, 2) + 8) * eps(T))
      else
        @test isnan(r.gap) && length(logs) == 1 && occursin(UNCERTIFIED, messages(logs)[1])
      end
      if ordinary
        total_ordinary += 1
        certified_ordinary += r.converged
        r.converged && push!(excess_ordinary, Float64((P - D) / D))
      end
    end
  end
  # every run of an ordinary family (r* ≠ 0) is certified, and the median excess against D* is far
  # below the contract (measured medians: see the run record of #332 PR A)
  @test certified_ordinary == total_ordinary
  @test median_of(excess_ordinary) <= (T === Float64 ? 1e-8 : 1e-5)
end

# The stop check of the square-root model on its own (`_stop_check!`), with the state of a solve.
@testset "stop check: certified, tightened, uncertified ($T)" for T in (Float64, Float32)
  (; X, y, λ, ref) = reference("full rank")
  XT, yT = T.(X), T.(y)
  g = NormL1(λ)
  p = size(X, 2)
  function setup(β, tol)
    m, xs = prepared_model(XT, yT, λ, β)
    st = PS._CDState(T, xs, CDSolver())
    st.tolerance = T(tol)
    m, xs, st
  end
  # β = 0 with λ below λmax is not certified (t < 1): two tightenings by 100, then an uncertified stop
  m, xs, st = setup(zeros(T, p), 1)
  @test PS._stop_check!(m, g, xs, st, T(0.5)) === :retry && st.tolerance == T(1) / 100 && m.tightenings == 1
  @test isnan(st.gap) && !st.uncertified
  @test PS._stop_check!(m, g, xs, st, T(0.5)) === :retry && st.tolerance == T(1) / 100 / 100 && m.tightenings == 2
  @test PS._stop_check!(m, g, xs, st, T(0.5)) === :uncertified && st.uncertified && isnan(st.gap)
  # a pass that changed nothing is not tightened
  m, xs, st = setup(zeros(T, p), 1)
  @test PS._stop_check!(m, g, xs, st, zero(T)) === :uncertified && st.uncertified && m.tightenings == 0
  # tol/100 below the floor 16 eps(T) ‖y‖ is not used
  m, xs, st = setup(zeros(T, p), 1000 * eps(T) * norm(y))
  @test PS._stop_check!(m, g, xs, st, eps(T)) === :uncertified && m.tightenings == 0
  # an exact fit with β ≠ 0 is not tightened
  Xe = T[1 2; 3 4; 5 6]
  me, xe = prepared_model(Xe, Xe * T[1, -1], λ, T[1, -1])
  ste = PS._CDState(T, xe, CDSolver())
  ste.tolerance = one(T)
  @test PS._stop_check!(me, g, xe, ste, T(0.5)) === :uncertified && me.tightenings == 0
  # a certified point: converged, with st.gap the certified ratio rounded up to T
  βT = T.(ref.β)
  code, ratio = certify(XT, yT, λ, βT)
  m, xs, st = setup(βT, 1)
  @test code === :certified && PS._stop_check!(m, g, xs, st, T(0.5)) === :converged
  @test Float64(st.gap) >= ratio && Float64(prevfloat(st.gap)) < ratio && !st.uncertified
end

# ---------------------------------------------------------------------------
# C. The certificate at adversarial points (the private `_certify!`)
# ---------------------------------------------------------------------------
# In every case: certified implies (P − D)/D ≤ 1e-4 for a verified dual lower bound D, and a reported
# ratio at least (P − U)/U for an upper bound U ≥ P* (`certified_ok`).

@testset "certificate at perturbed optima ($T)" for T in (Float64, Float32)
  (; X, y, λ, ref, D, U) = reference("full rank")
  XT, yT = T.(X), T.(y)
  w = [isodd(k) ? 1.0 : -0.5 for k in eachindex(ref.β)]
  codes = Symbol[]
  for k in 1:10
    β = T.(ref.β .+ 10.0^-k * maximum(abs, ref.β) .* w)
    code, ratio = certify(XT, yT, λ, β)
    push!(codes, code)
    code === :certified && @test certified_ok(X, y, λ, β, ratio, D, U)
    code === :certified || @test isnan(ratio) || ratio > PS._CERT_TARGET
  end
  # the large perturbations are not certified and the small ones are
  @test codes[1] !== :certified && codes[end] === :certified
end

# A problem whose fitted values dwarf the residual: y = X β with β₁ = 2^s plus small noise. The reference
# D comes from `dual_bound_big` at a solution of CD, U from P at that solution. The certificate forms
# r̂ = y − Xβ in Float64, whose rounding is of order eps(Float64) ‖Xβ‖; where that is not small against
# ‖r‖ (β₁ = 2^40 here), it does not certify a point that the BigFloat bound shows to be optimal to about
# 1e-15: a conservative result, not a false one.
function dominant_reference(s, ::Type{T}) where T
  n, p = 40, 12
  X = small_ints(n, p, 31, 4) ./ 4
  y = X * [2.0^s; 1; -1; zeros(p - 3)] .+ vec(small_ints(n, 1, 32, 4)) ./ 8
  XT, yT = T.(X), T.(y)
  λ = dyadic_level(X, y, 0.1)
  x, r, _ = sqrt_solve(XT, yT, λ, zeros(T, p); order = :cyclic, maxpasses = 5000, tol = 1e-12)
  XT, yT, λ, x, dual_bound_big(XT, yT, λ, x), objective_big(XT, yT, λ, x)
end

@testset "certificate where the fit dwarfs the residual" begin
  # Float64 with β₁ = 2^30 and 2^40 (about 1e12), and Float32 with β₁ = 2^10
  for (s, T) in ((30, Float64), (40, Float64), (10, Float32))
    X, y, λ, x, D, U = dominant_reference(s, T)
    @test D !== nothing && (U - D) / D <= 1e-5
    codes = Symbol[]
    for δ in (0.0, 1e-6, 1e-3)
      β = T.(x .+ δ .* [isodd(k) ? 1.0 : -1.0 for k in eachindex(x)] .* maximum(abs, x))
      code, ratio = certify(X, y, λ, β)
      push!(codes, code)
      code === :certified && @test certified_ok(X, y, λ, β, ratio, D, U)
    end
    s == 40 || @test codes[1] === :certified
  end
end

@testset "certificate near λmax ($T)" for T in (Float64, Float32)
  (; X, y) = reference("full rank")
  XT, yT = T.(X), T.(y)
  λmax = lambda_max_big(X, y)
  p = size(X, 2)
  for f in (1 - 1e-12, 1 + 1e-12)
    λ = Float64(λmax * f)          # a level on Float32 data is accepted as a Float64
    β = zeros(T, p)                # the minimizer for λ ≥ λmax, near it below
    code, ratio = certify(XT, yT, λ, β)
    D = dual_bound_big(XT, yT, λ, β)
    @test code === :certified && certified_ok(XT, yT, λ, β, ratio, D, objective_big(XT, yT, λ, β))
  end
end

@testset "certificate at subnormal and extreme scales, and a subnormal coefficient" begin
  (; X, y, λ, ref, D, U) = reference("full rank")
  # (y, X, λ) → 2^s (y, X, λ) keeps the minimizers and scales P, D and U by 2^s. A residual whose sum of
  # squares is below n 2^-969 (Float64) is outside the proof: not certified.
  β = ref.β
  for s in (-990, -1040)
    code, _ = certify(ldexp.(X, s), ldexp.(y, s), ldexp(λ, s), β)
    @test code === :undefined
  end
  # the decision does not depend on a power-of-two rescaling inside the range of the proof
  for (T, scales) in ((Float64, (-300, -60, 60, 300)), (Float32, (-40, -10, 10, 40)))
    βT = T.(β)
    code0, ratio0 = certify(T.(X), T.(y), λ, βT)
    @test code0 === :certified
    for s in scales
      code, ratio = certify(ldexp.(T.(X), s), ldexp.(T.(y), s), ldexp(λ, s), βT)
      @test code === code0 && isapprox(ratio, ratio0; rtol = 1e-9)
    end
  end
  # a subnormal entry added at an inactive coordinate of the optimum
  for T in (Float64, Float32)
    βT = T.(β)
    k = argmin(abs.(βT))
    βT[k] = nextfloat(zero(T))
    code, ratio = certify(T.(X), T.(y), λ, βT)
    @test code === :certified && certified_ok(X, y, λ, βT, ratio, D, U)
  end
end

@testset "certificate: special cases from exact data" begin
  X = [1.0 2; 3 4; 5 6]
  # y = 0 and β = 0: P = 0 = P*, certified with ratio 0
  @test certify(X, zeros(3), 0.5, zeros(2)) == (:certified, 0.0)
  # y = 0 and β ≠ 0: P > 0 = P*, so a certificate would be false; not certified
  @test certify(X, zeros(3), 0.5, [1e-3, 0.0])[1] !== :certified
  # an exact fit with β ≠ 0: r̂ = 0, the direction is undefined
  @test certify(X, X * [1.0, -1.0], 0.5, [1.0, -1.0])[1] === :undefined
  # the brackets of the level: the level itself for a Float64, its two Float64 neighbours for an
  # irrational, a rational and a BigFloat level that Float64 does not hold, none for another type
  @test PS._level_brackets(Float64(π)) == (Float64(π), Float64(π))
  @test all(isnan, PS._level_brackets(PS.NormL1))
  lo, hi = PS._level_brackets(π)
  @test lo < π < hi && nextfloat(lo) == hi
  lo, hi = PS._level_brackets(1 // 3)
  @test lo < 1 // 3 < hi && nextfloat(lo) == hi
  @test PS._level_brackets(big"0.1") == (prevfloat(0.1), 0.1)
end

# ---------------------------------------------------------------------------
# D. Contracts
# ---------------------------------------------------------------------------

state(x::Vector) = (copy(x), signbit.(x))
state(x) = (Vector(x), collect(ProximalBase.activecoordinates(x)), signbit.(Vector(x)))
message(e) = sprint(showerror, e)
opposite(a::AbstractArray{Float64}) = Float32.(a)
opposite(a::AbstractArray{Float32}) = Float64.(a)

# solve! throws an exception of type E whose message contains the fragment, with the caller and a
# borrowed RNG as they were.
function refused(E, fragment, x, f, g, method)
  before = state(x)
  rng_before = method isa CDSolver ? copy(method.rng) : nothing
  err = try
    solve!(x, f, g, method)
    nothing
  catch e
    e
  end
  ok = err isa E && occursin(fragment, message(err)) && isequal(state(x), before)
  method isa CDSolver && (ok &= method.rng == rng_before)
  ok || @info "unexpected refusal" err
  ok
end

@testset "refusals before any change of x or the RNG ($T)" for T in (Float64, Float32)
  X = T[1 2 0; 0 1 1; 1 0 1; 2 1 1]
  y = T[1, 2, 0, 1]
  f = SqrtLeastSquaresLoss(y, X)
  g = NormL1(T(0.25))
  solver() = CDSolver(; rng = Xoshiro(4))
  for x in (T[0.5, 0, -0.25], SparseIterate(T[0.5, 0, -0.25]))
    @test refused(ArgumentError, "Scaled(SqrtLeastSquaresLoss", x, Scaled(f, 2.0), g, solver())
    @test refused(ArgumentError, "at lambda = 0 use LeastSquaresLoss", x, f, NormL1(zero(T)), solver())
    @test refused(ArgumentError, "at lambda = 0 use LeastSquaresLoss", x, f, NormL1(-0.0), solver())
    @test refused(ArgumentError, "weighted NormL1", x, f, NormL1(T(0.25), ones(T, 3)), solver())
    @test refused(ArgumentError, "ElasticNet", x, f, ElasticNet(T(0.25), T(0.5)), solver())
    @test refused(ArgumentError, "only unweighted NormL1 is supported with SqrtLeastSquaresLoss", x, f, NormL2(T(1)), solver())
    @test refused(ArgumentError, "penalty lambda must be finite and positive", x, f, NormL1(T(Inf)), solver())
    @test refused(ArgumentError, "X must be Matrix", x, SqrtLeastSquaresLoss(y, sparse(X)), g, solver())
    @test refused(ArgumentError, "X must be Matrix", x, SqrtLeastSquaresLoss(opposite(y), opposite(X)), g, solver())
    # a loss whose element type (that of its scratch vector) differs from the data
    @test refused(ArgumentError, "X must be Matrix", x, SqrtLeastSquaresLoss(y, X, zeros(T === Float32 ? Float64 : Float32, 4)), g, solver())
    @test refused(DimensionMismatch, "dimensions do not match", x, SqrtLeastSquaresLoss(y, X[:, 1:2]), g, solver())
    T === Float32 && @test refused(ArgumentError, "not representable", x, f, NormL1(1e-50), solver())
  end
  # PGD and APG with a dense Vector: the loss is not smooth
  for method in (ProximalGradientDescent(), AccProxGradDescent())
    @test refused(ArgumentError, "is not smooth", T[0.5, 0, -0.25], f, g, method)
  end
  # a BlockIterate (with momentum = nothing, which the block gate checks first)
  xb = BlockIterate(T, 3, [1:2, 3:3])
  @test refused(ArgumentError, "does not support a BlockIterate", xb, f, GroupNormL2(T(0.25), [1:2, 3:3]), solver())
  # other losses keep the least-squares message
  @test refused(ArgumentError, "only LeastSquaresLoss", T[0.5, 0, -0.25], QuadraticFunction(Matrix{T}(I, 3, 3), zeros(T, 3)), g, solver())
end
@testset "levels of other types on Float32 data" begin
  (; X, y) = reference("full rank")
  X32, y32 = Float32.(X), Float32.(y)
  for λ in (1, 1 // 2, big"0.5625", Base.MathConstants.golden)
    x, r, logs = sqrt_solve(X32, y32, λ, zeros(Float32, size(X, 2)); order = :cyclic)
    @test r.converged && isempty(logs)
    x64, _, _ = sqrt_solve(X, y, Float64(λ), zeros(size(X, 2)); order = :cyclic, tol = 1e-10)
    D = dual_bound_big(X, y, λ, x64)
    @test (objective_big(X, y, λ, x) - D) / D <= 1e-4
  end
end

@testset "failure partway, maxpasses = 0, warnings and momentum ($T)" for T in (Float64, Float32)
  # a column whose squared norm overflows T is refused at its first visit, after the other coordinates
  # moved on the private copy; the caller is unchanged
  s = T === Float32 ? 70 : 520
  X = T[1 0 1; 0 1 2; 1 1 0; 2 0 1]
  X[:, 3] .*= T(2)^s
  y = T[1, 2, 0, 1]
  for x in (zeros(T, 3), SparseIterate(zeros(T, 3)))
    @test refused(ArgumentError, "is not finite", x, SqrtLeastSquaresLoss(y, X), NormL1(T(0.125)), CDSolver(order = :cyclic))
  end
  (; X, y, λ) = reference("full rank")
  XT, yT = T.(X), T.(y)
  p = size(X, 2)
  # maxpasses = 0: no pass and no certificate; the iterate is kept, with the maxpasses warning
  x0 = T.(collect(1:p) ./ 8)
  for owner in (false, true)
    x, r, logs = sqrt_solve(XT, yT, λ, x0; owner, maxpasses = 0)
    @test x == x0 && r.passes == 0 && !r.converged && isnan(r.gap)
    @test length(logs) == 1 && occursin(NOTCONVERGED, messages(logs)[1])
  end
  # tol = 0: the change test does not pass, so the stop check is not reached (maxpasses warning)
  x, r, logs = sqrt_solve(XT, yT, λ, zeros(T, p); order = :cyclic, tol = 0, maxpasses = 50)
  @test !r.converged && isnan(r.gap) && r.passes == 50 && occursin(NOTCONVERGED, messages(logs)[1])
  # the uncertified warning differs from the maxpasses warning
  @test_logs (:warn, UNCERTIFIED) solve!(T[1, -1], SqrtLeastSquaresLoss(T[1 1; 0 0.01] * T[1, -1], T[1 1; 0 0.01]),
                                         NormL1(0.1), CDSolver(order = :cyclic))
  @test_logs (:warn, NOTCONVERGED) solve!(zeros(T, p), SqrtLeastSquaresLoss(yT, XT), NormL1(λ), CDSolver(maxpasses = 1))
  # CDSolver() on a dense Vector uses momentum, as for least squares (random order on the private copy)
  xs = SparseIterate(zeros(T, p))
  @test PS._usemomentum(CDSolver(), xs, PS.cdmodel(SqrtLeastSquaresLoss(yT, XT), xs))
  # the minimum agrees with P at the returned point, and an owner keeps its caller identity
  x, r, _ = sqrt_solve(XT, yT, λ, zeros(T, p); owner = true, rng = Xoshiro(9))
  @test r.converged && isapprox(r.minimum, objective_big(X, y, λ, x); rtol = (size(X, 1) + p + 8) * eps(T))
end

end
