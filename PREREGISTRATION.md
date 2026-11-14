# #314 Phase B preregistration (frozen before the selection and confirmation runs)

Written 2026-11-14, before any Phase B selection (`sel`) or confirmation (`conf`) problem was solved
on the cluster. Before writing it, the only data seen was a local draw-1 smoke test of the 20 harness
cases, plus one local `sel` draw used only to estimate run time. The profiles were fixed in
`probes/probe314.jl` before either run.

## Fixed

- Code: PS `fad90d9` (clean detached worktree); PB pin `c123d56b` (tree `c2e2ddde`); harness
  files unchanged. Certificate: harness `certify` (lasso relative duality gap on the rounded inputs,
  read back in Float64). Targets: Float64 `1e-8`, Float32 `1e-5` (`CORE_TARGETS`), unchanged.
- Profiles (existing `ProximalOptions` only):
  - **D**: `ProximalOptions()`, the package defaults (`maxiter 200, ftol 1e-6, xtol 1e-8, gradtol 1e-5`).
  - **H**: `benchmark_options(residual = true)`, the current harness (`maxiter 10_000, ftol 1e-15, xtol 1e-14, gradtol 1e-11`).
  - **S**: the #312 strict stress profile (`maxiter 10_000, ftol 0, xtol 1e-300, gradtol 1e-11, allow_f_increases = true`).
  - **P1**: `maxiter 10_000, ftol 0, xtol 1e-14, gradtol = target(T), allow_f_increases = true`.
  - **P2**: the same as P1 with `gradtol = target(T)/100`.
- Why these candidates:
  - **`ftol = 0`.** #281/#270 measured the objective-change test as the cause of stops near √eps.
  - **`allow_f_increases = true`.** Near the precision floor, rounding-level objective increases end the solve early (#281 found these increase stops in Float32 APG).
  - **`xtol = 1e-14`.** With it, the step test practically never decides (an exact stall is excluded under `ftol = 0`).
  - **The gradient-mapping test decides.** Its residual is relative and scale-free. A relative residual `r` gives a relative gap of order `r` (worst case, linear) down to `r²` (locally strongly convex). So `gradtol = target` is the linear-case choice, and `target/100` adds a two-decade margin for constants.
  - **No looser candidate** (for example `√target`): the #110 ruling warns that loosening reintroduces #270's misses.
- Problems:
  - designs `ord` (200×100, independent), `cor` (240×160, AR ρ=0.8), `equi` (240×160, equicorrelated 0.5), `wide` (180×600), `ill` (240×160 independent, column scales spread over two decades);
  - λ = {0.5, 0.15, 0.02}·λmax;
  - cold and warm starts (warm = the solution at 1.25λ, as in the harness);
  - Float32 and Float64; PGD and APG.
  - Selection set: key `issue314/sel/*`, draws 1–4. Confirmation set: key `issue314/conf/*`, draws 1–6 (independent seeds).
  - Zero regularization is not included: at λ = 0 the certificate switches to a KKT residual, which the gap targets do not define.

## Definitions

- **pass:** the certificate is `:ok` and gap ≤ target.
- **missed target:** not pass.
- **false success:** `converged = true` and not pass.
- **accurate, not converged:** pass with `converged = false` (`stagnated`, `maxiter`, other).
- **reachable:** the shared trajectory reaches the target within 10 000 iterations (k* ≥ 0 exists).
- **time to target:** a timed solve stopped at k*. **Return time:** a timed solve under the profile.
  Both are medians of 5 interleaved rounds per problem, with an A/A copy of H as the noise control.

## Selection rule (applied to `sel`, separately per solver × precision)

A candidate (P1 or P2) is **eligible** when, on `sel`:
1. it has no false success; and
2. it passes every problem whose target is reachable.

Among eligible candidates, choose the one with the smaller geometric mean return time.
If neither is eligible, there is no practical recommendation for that solver × precision.

## Confirmation rule (applied once to `conf`)

The selected candidate is recommended only if, on `conf`:
1. it has no false success; and
2. every reachable problem passes, with any exception reported individually and judged by the maintainer, not waived.

Report D, H and S on the same problems as controls. No profile is added or tuned after `sel` is seen.
If confirmation fails, report NO recommendation for that solver × precision, and keep the current
harness settings, with separate time-to-accuracy diagnostics.

## Execution note

To save cluster round trips, `sel` and `conf` are computed in parallel jobs, since every profile runs on
every problem anyway. `conf` files are not opened until the selection decision is written in
`SELECTION.md`.

## Deviation (recorded 2026-11-14T10:09:59-08:00)

- Job 14239947 (j110 `probe sel 1:4`) crashed at `probe314.jl:170`. On Julia 1.10, `arms` was a `Vector{Tuple{String, ProximalOptions{Nothing}}}`, which cannot hold the time-to-target arm for k* = 1, because that arm's options carry a callback.
- The fix: `arms = Tuple{String, Any}[...]`. It changes only the container type. No profile, problem, rule or measurement changed.
- Only the j110 `sel` job is rerun. Its partial output is kept, not used. The other five jobs used the original probe (sha256 003b06b4…); they did not reach that branch (none crashed).
