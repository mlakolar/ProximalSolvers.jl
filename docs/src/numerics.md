# Numerical behavior

CD's private PB SparseIterate retains stored activation/compaction order. First
full passes admit coordinates, active passes refine them, and only a full pass
strictly below the change tolerance converges. Random LS uses historical
momentum/restarts and refreshes moved residual caches before full checks; the
borrowed RNG advances. Cyclic and explicit momentum=false remain supported.
Zero columns choose the nearest-zero penalty minimizer, including lambda=0.
Nonzero-column curvature underflow is an error. tol=0 stays strict; maxpasses=0
returns unconverged with no updates. A nonfinite returned objective is refused
before dense scatter; this is not robust dynamic-range recovery.

PGD retains native LS image/value/gradient order, scalar steps, fused PB prox,
TFOCS objective-to-gradient checks, finite curvature-growth refusal and zero-step
gradient refresh. Historical objective/iterate/FASTA convergence tests combine
by OR. Converged does not guarantee KKT below gradtol; objective rounding can
stop even with very small ftol. Check objective/KKT independently. Native
Float32 may stagnate earlier. Finite inputs do not ensure finite intermediates;
historical LS image exceptional-range limitations remain outside this extraction.

Callbacks/display sample print_every; stored traces include each iteration. A
callback receives the trace when storing, otherwise a state. Limits are checked
after an iteration and counts may overshoot. iteration_converged means a limit,
not success. Positive gaptol is refused; positive gapevery is inert at gaptol=0.
The retained scalar APIs/results do not introduce a new stopping/logging engine.
