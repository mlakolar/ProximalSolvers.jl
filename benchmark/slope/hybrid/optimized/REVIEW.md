# Pre-merge self-review

This is the implementing agent's review of PR #99. It is not an independent
review or a GitHub approval. Final CI status is visible on the pull request.

## Scope checked

- Public dispatch and defaults: `SLOPEHybrid()` remains explicit, uses the
  existing result types, and accepts the supported scaled least-squares data.
  APG's existing behavior is preserved through the shared private driver.
- Cluster invariants: signed membership, rank-weight prefix sums, threshold
  crossings, merging/removal and cache invalidation were traced against the
  scalar oracle and repeated-sweep tests. PG handles splitting and zero-group
  activation. Zero-curvature directions have explicit production-kernel tests.
- Safeguards: a rejected CD block restores the preceding PG point and resets
  APG state; slow progress and the bounded trial route to APG. Reduced APG
  stopping returns control to full-problem checks and working-set repairs.
  The one-step remainder respects the per-level budget. Only the shared full
  residual check can declare convergence.
- Storage: cluster arrays are reused; dense cache capacity is bounded by
  `n * min(p,32)` even for CSC inputs. Cached values are refreshed after PG and
  invalidated after relevant group changes. Allocation-free column accumulation
  does not imply allocation-free paths or lower process RSS.
- Evidence: coverage includes all 1,980 requested paths and missing native
  levels; external accuracy and internal flags remain separate. Failed fits,
  replay failures and development attempts are retained. Different eligible
  subsets and medians are not combined into an unsupported direct speedup.
- Scope of claims: comparisons identify the pinned native source, independent
  acceptance targets, native path cap, separate allocator scopes and process
  memory limitations. They do not claim globally fastest performance or FDR
  guarantees. Primary timings remain tied to the recorded measured snapshot.

## Finding fixed

The original trial-budget expression `10*(cd_sweeps+1)` could overflow for a
valid, very large positive `Int`. The helper now saturates at half the remaining
budget before multiplying. The default trial and ordinary parameter results
are unchanged. Regression checks cover the largest `Int` sweep/budget values
and agreement with the original mathematical expression over 2,032 ordinary
parameter combinations.

Discovery job `13456761` passed **899 focused assertions on each of Julia
1.13.2 and 1.10.12**, including those three new assertions. Its source patch,
logs, environment setup and scheduler receipt are retained under `evidence/`.
The earlier merged full suite passed 18,533 assertions. The full 220-workload
timing study was not repeated for this integer-boundary fix.

## Assessment

No unresolved blocking code findings remain from this self-review. The
option is suitable for review as an opt-in least-squares SLOPE solver, subject
to final-head CI. Reviewers should retain the practical limitations: allocation
traffic often increases on controls, RSS did not improve, native comparisons
are incomplete under the recorded caps, and the primary timing snapshot
predates the later master integration and integer-boundary fix.
