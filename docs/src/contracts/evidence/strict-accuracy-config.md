# [Historical strict-accuracy configuration](@id EVIDENCE-STRICT-01)

This relocation checkpoint preserves baseline text before normalization.

<!-- Baseline: docs/src/numerics.md:L336-L355; a6293e6ff7e654a87babbc5de2314205be13d6c5 -->

On the package's benchmark cases (Float64 PGD and APG, Float32 APG, with 10
input draws each, on Julia 1.10 and 1.13 and two CPU models) it met the
independently computed targets of a relative duality gap of `1e-8` in Float64
and `1e-5` in Float32. It is **not** a guarantee of accuracy on other problems,
and `converged=true` is still not a certificate: check the returned point
independently, for example with the bound below. With this configuration
Float32 PGD reached its floating-point fixed point and met the independent
`1e-5` target on the benchmark cases (in these probes, with `maxiter = 10000`;
10 input draws each, on Julia 1.10 and 1.13, one CPU model). With the stagnation
stop (see "A stagnation stop" below), such a solve ends, before `maxiter` on those
cases, at an iteration that meets its condition, with `stagnated=true` and
`converged=false`. At an iteration whose accepted iterate is unchanged, the
computed `x` and gradient tests can hold (the computed gradient residual can be
`0`), but under `ftol = 0` the exact-stall rule (see "An exact stall" below) does
not count them; between such iterations the iterate can still move. The computed
residual is not an accuracy measure: the `1e-5` target was checked with the
independent duality gap.
These probes were made before the stationarity check of a stop was added
(see [The stationarity check of a stop](@ref "The stationarity check of a stop")); they are not repeated here for the current code.


