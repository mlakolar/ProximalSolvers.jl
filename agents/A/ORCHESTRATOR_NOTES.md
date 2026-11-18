# Agent A — orchestrator record (agent's full report was delivered in-message; harness refused report.md)
Key results (files in agents/A/out):
- #156 blocking: 81/265 near-optimal baseline runs uncertified; 77/77 on exact-fit-optimum problems; 4/188 otherwise. Codes 6 :undefined, 75 :failed.
- vcert (lib.jl:14–70): Float64 outward-rounded validator for arbitrary (θ̂, β) via the Fenchel–Young identity
  P(β) − tθ̂ᵀy = (‖r‖ − tθ̂ᵀr) + Σ(λ|β_k| − tβ_k X_kᵀθ̂); t = min(1/Θ_up, λ_lo/G) (no cap at 1); D_lo = max(P_lo − gap, t(θ̂ᵀy)_lo);
  ratio = min(gap/D_lo, (P_up − D_lo)/D_lo). With θ̂ = r̂ reproduces production's 184/948 certified set. 0 unsound in ~5000 rows + 30000 fuzz.
- Bcm (support Gram Cholesky + ridge 1e-12, θ₀, bounded active-set alternating projection onto violated slabs + ball, margins 1e-3,
  ≤500 sweeps, drop ladder εdrop ∈ {1e-6,1e-5,3e-5}): M81 75/81, OPTx 119/119, NEG 0/683, 0 false. Needs |S| ≤ n gate (0.1–0.5 s when |S| ≫ n).
- Residual direction: 0/81, 0/119. Least-norm only (A): 37/81, 72/119. Directional-lasso CD (D): 61/81 + 20 refuted, NEG 683/683 refuted; slow.
- Smoothing transplant (E): F64 38/38 M81, 59/60 OPTx; native F32 30/43, 16/59; promoted-F64 43/43, 58/59. 0 certified on NEG (0 false). Passes up to 80454.
- Directional lasso duality verified: ½τ*² = −min G(d), θ* = −Xd*; d* descent iff τ* > 1.
- Exact-fit optimality is a λ-threshold: β optimal iff β solves BP and λ ≤ 1/min‖ν‖ over BP dual certificates for (S,s).
Orchestrator check of vcert structure: steps (wlo, B1, S2/E2, D1, ratio) read and found consistent with the _certify! error model; formal review deferred to Codex.
