# Shared context for the #155/#156 research agents (read fully)

You are a research agent in a RESEARCH-ONLY study of ProximalSolvers.jl (PS) issues #155 and #156 (square-root
lasso coordinate descent at exact fits). Hard rules:
- No production code changes, no commits, no pushes, no PRs, no GitHub comments, no label/issue changes.
- Do not edit the shared worktree <WS>/ProximalSolvers.jl-issue155 (read it freely).
  If you need a modified copy of PS source (prototype), create your own detached worktree:
  `git -C <WS>/ProximalSolvers.jl worktree add --detach <WS>/ProximalSolvers.jl-issue155-<you> a0a06477`
  and never commit in it. Record it in your report so the orchestrator can remove it.
- Write everything (scripts, outputs, report) under your own directory
  <RUN>/agents/<you>/ .
  Do not modify files outside it (the shared scripts/ and out/ are read-only for you).
- Run locally (20 cores, 31 GB). Keep each Julia process modest; no cluster.
- The shell's working directory resets between calls: always use absolute paths.
- Prototypes are research code. A successful numerical search is not a proof: distinguish clearly what is
  proved, what is measured, and what is conjecture. Report negative results honestly.

## Problem
F(β) = ‖y − Xβ‖₂ + λ‖β‖₁, λ > 0, dense Float32/Float64. Dual: max θᵀy s.t. ‖θ‖₂ ≤ 1, ‖Xᵀθ‖∞ ≤ λ (weak duality:
P(β) ≥ θᵀy for every feasible θ).

## Current code (PS master a0a06477, PB pin a19c59aa)
- src/cd/sqrtlasso.jl (read it): `SqrtLSModel`; coordinate step = exact 1-D minimizer (soft threshold at the LS
  centre c = old + b/a with τ = λ d/√(a(a−λ²)), d = dist(r, span X_k)); `_stop_check!` runs `_certify!` at each
  converged full pass; `_certify!` is a rigorous Float64 residual-direction certificate θ = t r̂/‖r̂‖ with outward
  rounding, target relative gap ≤ prevfloat(1e-4), returns (:certified, ratio) / (:failed, ratio|NaN) /
  (:undefined, NaN) (r̂ = 0 with β ≠ 0, etc.). Up to 2 tightenings of the change threshold by tol/100.
- src/cd/solver.jl: CD loop (`_cd_plain!`, `_cd_momentum!`), `_run_cd!`, `CDResults` (fields minimizer, minimum,
  passes, converged, maxchange, tolerance, kkt_checks, gap). Uncertified ⇒ converged=false, gap=NaN, warning.
- test/sqrt_lasso.jl, examples/problems/square_root_lasso.jl (asserts today's exact-fit behaviour).
- The historical support/joint witness (legacy/full, src/cd/sqrtdual.jl: least-norm support solve with LAPACK
  syevr eigendecomposition, error-free transforms, unpenalized projection bounds, ~450 lines) was NOT restored
  and must not be assumed. The maintainer wants a small reliable solution, not its restoration.

## Fixtures
- #155: X = [1 1; 0 0.01], y = X*[1,−1], λ = 0.1, start [1,−1]: CD stays (F = 0.2, F(0) = 0.01), uncertified.
- #156: X = [1 2; 0 1], y = [1,0], λ = 0.1: β = [1,0] optimal exact fit; θ = (0.1,−0.1) feasible, θᵀy = 0.1 = P;
  current solver cannot certify (r̂ = 0 ⇒ :undefined).

## Shared research infrastructure (read-only; reuse it)
Run dir R = <RUN>
- Julia env: `julia --project=$R/env` (Julia 1.13.4; PS dev'ed from the shared worktree, PB at the pin, JuMP,
  Clarabel, BenchmarkTools). Julia 1.10: `julia +lts --project=<WS>/ProximalSolvers.jl-issue155`
  (PS + PB only, no JuMP; load the oracle file with Serialization only if its types deserialize, else regenerate
  what you need).
- $R/scripts/matrix.jl: the preregistered matrix (80 problems: analytic A155, A156, AI3 [X = I₃, y = 1, λ = 0.65,
  start y: every 1- and 2-coordinate direction is non-descent, the 3-coordinate one descends]; noiseless
  n8p20 / n40p120 / n100p400; near-exact; ordinary n60p20; a λ sweep SW0.1–0.4 across the interpolation
  threshold; correlated ρ=.95; duplicate columns). Starts: :zero, :given (analytic), :lnfit (least-norm
  interpolant X⁺y — an adversarial exact-fit warm start), :warm (oracle β* + fixed perturbation).
- $R/out/oracle.jls (+ .txt): for each (problem id, "Float64"/"Float32") an oracle record with β*, θ* (scaled
  into exact feasibility in BigFloat), D (BigFloat-valid lower bound on P*), U = P(β*) (upper bound), rrel,
  exactfit (‖r*‖/‖y‖ < 1e-8). The Float32 record is the oracle of the Float32-rounded data.
- $R/scripts/common.jl: `include` it. Provides ORACLE, oracle(id,T), problem(id), data(prob,T), Pbig,
  ps_solve(X,y,λ,β0; owner, maxpasses=20_000, CDSolver kwargs...) → (x, result, seconds, bytes),
  certify_at(X,y,λ,β) → production `_certify!` result at an arbitrary point (no CD pass), classify(...) →
  (; excess = (P(β)−D)/D in BigFloat, optimal = excess ≤ 1e-4, rrel, atfloor, nnz).
- $R/out/baseline_1.13.tsv: the current solver over the matrix (948 runs = problems × {F64,F32} × starts ×
  {cyclic-dense momentum=false, random-owner rng=Xoshiro(7)}). Summary: 184 certified, 683 nonoptimal(155),
  81 missed-cert(156) (optimal within 1e-4 but uncertified), 0 false certifications, max certified excess 1.1e-10.
  Of the 81 missed certs only 6 have certificate code :undefined (r̂ = 0); 75 are :failed at a tiny but nonzero
  residual. Nonoptimal excess quantiles: min 3e-4, median 0.58, max 19. CD at nonoptimal exact fits in n8p20
  typically has 14–20 nonzeros (> n = 8). The :lnfit start traps CD even where the optimum is NOT an exact fit
  (SW0.3/0.4, C95; in Float32 even at a residual at the rounding floor, not exactly 0).

## Known mathematical facts you may use (verify anything you rely on)
- At r = 0 with support S, s = sign(β_S): β optimal ⇔ ∃θ: ‖θ‖ ≤ 1, X_Sᵀθ = λs, ‖X_{S^c}ᵀθ‖∞ ≤ λ; any such θ has
  θᵀy = λ‖β‖₁ = P(β). Directional derivative F'(β;d) = ‖Xd‖ + λ sᵀd_S + λ‖d_{S^c}‖₁.
- Smoothing: F_δ(β) = √(‖y−Xβ‖² + δ²) + λ‖β‖₁ equals the square-root lasso on augmented data ỹ = [y; δ],
  X̃ = [X; 0ᵀ], so the production solver can solve F_δ unchanged; F ≤ F_δ ≤ F + δ.

## Report format
Write $R/agents/<you>/report.md: findings first (numbered, each with evidence file paths and exact commands),
then tables, then limitations and open questions. Every number must come from a file you produced. Keep the
report under ~400 lines. Your final message to the orchestrator: a ≤ 60-line summary of the conclusions and
the report path.
