# Numerical behavior

CD runs on a PB SparseIterate that retains stored activation/compaction order: a
private one for a dense vector, and a private copy of the caller's owner for a
`SparseIterate`, which starts with that owner's active zeros and slot order and
which the caller's owner receives, whole, only after a finite completed run. First
full passes admit coordinates, active passes refine them, and only a full pass
strictly below the change tolerance converges. Random LS uses historical
momentum/restarts and refreshes moved residual caches before full checks; the
borrowed RNG advances. Cyclic and explicit momentum=false remain supported.
Zero columns choose the nearest-zero penalty minimizer, including lambda=0.
Nonzero-column curvature underflow is an error. tol=0 stays strict; maxpasses=0
returns unconverged with no updates, and an owner then keeps its exact entry state.
After every pass zero coordinates leave the active set, so an owner that completed
at least one pass has none and their order follows from compaction, which moves the
last active coordinate into the place of a removed one. A nonfinite returned
objective is refused before dense scatter or owner commit; this is not robust
dynamic-range recovery. A nonconverged finite pass-limit return warns, then commits.
A numerical error leaves a caller's owner unchanged but may advance the RNG.
Dense and owner solves from the same canonical state (the owner built from the
dense vector) run the same arithmetic and RNG schedule. A different slot order of
the same active set can change the trajectory and the final point, and the change
stopping rule gives no general bound on the distance to a minimizer or on the KKT
violation: assess accuracy with an independent objective/KKT check.

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
