## Round 2 at `cde5443`

One commit on `43a362d`, a comment-only change (`src/solvers/image_models.jl`, 2 lines).

### Verdict on the round 1 review

1. **Blocker 1 (the proof comment of `_se_norm_onepass`): accepted and fixed.** "Each underflowing square then loses less than `floatmin(T) u`" is now "loses at most `floatmin(T) u`". The orchestrator reproduced the equality case (`v = ldexp(1f0, -75)`: `v*v == 0f0`, the exact square is `floatmin(Float32)·eps(Float32)/2`, and `sum(abs2, Float32[1, v]) == 1f0` satisfies the one-pass guard). The rest of the sentence stands: with `s ≥ 4 length(a) floatmin(T)`, `u s / length(a) ≥ 4 floatmin(T) u`, which is above `floatmin(T) u`. The wording came from the base's comment of the single-vector form.
2. **Nonblocking notes: no change.** The differences on direct private calls (shape, axis and element-type checks of ProximalBase's `norm_diff`; a zero-row `_flat_column` with an invalid column index; the folded difference norm with Float32 operands and a Float64 working type; BigFloat scales in the subnormal interval of Float64 given to `_root_scale`) are outside what a public call can pass, as the review states, and are recorded here as known. The 8 to 14 % (0.5 to 1.6 ns) cost of an isolated `g_residual` call at 12 coefficients matches the pattern the round 1 tables showed at p = 12; no solve cell exceeds the gate. The cross-platform run is the `Nightly` dispatch at the final commit.

### What the implementer checked

The other comments and documentation lines this PR added or changed were searched for strict claims of the same kind ("less than", "below", "at most", "exact"); none needed a change. `grep -rn "loses less than" src docs test` finds nothing. `comment_scan.py`: 0 candidate lines.

### What ran

`git diff 43a362d cde5443` changes two comment lines and no code line, so the test, fingerprint, sweep and timing results of round 1 at `43a362d` stand for the code; nothing was re-run locally. CI runs the suite at this commit.
