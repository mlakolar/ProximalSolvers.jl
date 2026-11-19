Cross-reference: the #155 confirmation round (final report: LINK155) has one result that bears on this issue's document-only disposition. The policy here is unchanged.

- The earlier summary left open whether D2 needs the generalized validator. It was not needed on the tested trajectories: on all 599 triggered runs, D2 with only the production `_certify!` bounds (exposing its D_lo, P_up and P_lo) gave the same outcomes as D2 with the generalized validator.
- Of the 43 held-out runs that stopped uncertified at an already near-optimal point, D2 certified 39 by keeping the stuck point unchanged, through its bank of dual bounds. The other 4 moved to a proved-better point but stayed uncertified.
- If the D2 PR proposed on #155 is approved, it also covers most of the #156 cases it reaches, with no separate certificate. Otherwise the "Bcm" design recorded above remains the reference for a later, separately approved certificate.
