# [Lazy-curvature measurements](@id evidence-lazy-curvature-cost)

<!-- Migration source: docs/src/choosing-solver.md:L300-L338 -->

### Cost of the lazy curvature

The measurements in this section were made before groups of two columns had their own
rule: the bound of a group of two columns, like that of a larger group, took the copy of
its columns, the Gram matrix and an eigenvalue computation.

The lazy curvature and the zero-group screen save the curvature of a Gram-route group only
while that group passes the screen at every visit. A screened visit still computes the
correlations of the group. In one profile, a screened visit took 155 ns and a visit to a
zero group whose curvature was already computed took 135 ns (neither changed a
coefficient), so these zero-group visits cost about the same in that profile: the screen
saves the curvature, not the visit.

From a cold start (`x = 0`, residual `y`), the first full pass starts at the residual `y`
and screens each eligible group against the current residual, after the updates of the
groups before it; the guards of the screen can bypass it for a group. A group that fails the
screen needs its curvature, and it can leave the active set again later. The saving
therefore depends on how many groups ever fail the screen, not on the number of active
groups at the solution. In the low-occupancy designs measured below, many groups entered the
active set in the first pass at a small `λ / λmax` and left it later. Starting a path from a
nearby solution can reduce the number of groups that fail the screen in the first pass; this
has not been measured.

Measured on these designs, with `n = 500` rows, groups of 2 or 8 columns, and `λ` set so that
about 5% of the groups were active at the solution (`λ / λmax` about 0.06 to 0.10):

- On one exclusive node, with one thread, Julia 1.10 and 1.13, the solve was 1.05 to 1.45
  times faster than computing every curvature before the first pass at `p = 1024`, and 1.5
  to 3.3 times at `p = 256`, except 1.2 to 1.3 times in one layout and group size on Julia
  1.13. At high occupancy the largest slowdown against computing every curvature before the
  first pass was about 4%. The two computations gave bit-identical iterates in every cell.
- A separate diagnostic profile on a shared node (absolute times noisy) found that 40% to 68%
  of the groups computed a curvature in the first pass. In a `λ` sweep on one of these
  designs (`p = 1024`) in that profile, the ratio was about 1.9 to 3.6 for `λ / λmax ≥ 0.2`,
  and about 1 for `λ / λmax ≤ 0.04`.

These are measurements on these designs, not general claims: the ratio depends on `n`, the
group sizes, the layout and `λ`.
