# Separate adaptive proximal-gradient evaluation

**Current decision:** the [broader evaluation](broad/README.md#result-and-recommendation-2026-10-25) and fresh-seed confirmation do not support a public opt-in adaPGM option. The pilot results below are retained as historical evidence; their follow-up recommendation is superseded.

This track implements the equations independently of PANOCplus and of the
unregistered author package. It adds no solver API or package dependency.

- `adaPGM`: [Latafat, Themelis, Stella and Patrinos, arXiv:2301.04431v4](https://arxiv.org/html/2301.04431v4), Algorithm 2.1. The rule combines directional Lipschitz and cocoercivity estimates. Its discriminant is evaluated as `(gamma^2*||y||²-gamma*dot(s,y))/||s||²` to avoid division by nearly zero `dot(s,y)`.
- `MM`: the Malitsky--Mishchenko rule, equation (1.1) in the same paper, with the original first growth ratio set to infinity. The original 2020 result is smooth; Remark 2.4 of the later paper supplies a composite justification. These runs use that convex composite scope, not a nonconvex or accelerated extension.

The rules use successive iterates and gradients only. There are no objective
comparisons, hidden retries, domain repairs, or line searches. `gradient!` may
internally share a value-and-gradient implementation (as for `LogDetLoss`);
"function-value-free" describes the step decision, not the underlying oracle's
arithmetic. External accuracy certificates also evaluate objectives and are
included in solve time, separately from the counted algorithmic evaluations.
Invalid gradients terminate with an explicit status and preserve the last
finite output. Divergence, invalid domains and unmet targets remain results.

We evaluate:

1. Convex lasso with Gaussian design, n=2p, p=100 and 1000. Target: relative duality gap <= 1e-6.
2. A globally finite, strongly convex separable quartic plus l1, p=100 and 1000. The gradient is locally but not globally Lipschitz. Target: absolute l1 KKT residual <= 1e-6. Quartic weights span 1 to 100.
3. Graphical lasso, p=50,200,600, cold and warm paths, as a domain stress test outside the papers' finite-smooth-loss assumptions. It must not be described as a counterexample to their theorems.

Lasso and quartic test initial gamma=0.01,1,10 without selecting the best after
seeing the result. PG/APG run once per instance with their own default initial
step. Both seeds (25,71) and all three repetitions are retained. The graphical
lasso comparison uses gamma=1, with a separate deliberately invalid-step check.

See [the shared harness methodology](../panocplus/README.md) for timing,
certificates, allocation accounting, reproduction commands and limitations.

## Discovery results (2026-10-25)

All **624/624** comparison fits met their targets: 432 graphical-lasso fits,
96 lasso fits and 96 quartic fits. At initial gamma=1, median paired time ratios
against APG were:

| problem | adaPGM / APG | MM / APG |
|---|---:|---:|
| graphical lasso (benign grid) | 0.772 | 0.767 |
| lasso | 0.896 | 1.208 |
| quartic + l1 | 0.293 | 0.355 |

The lasso/quartic rows each use 12 paired fits per method at this initial step;
the graphical-lasso rows use 108. Initial-step sensitivity is preserved: adaPGM's
median lasso/APG ratio was 1.096 at gamma=0.01 and 1.137 at gamma=10. Its quartic/APG
ratios were 0.185 and 0.322, respectively. Do not select the best initialization
and report it as the general result. These are small synthetic tests with two
seeds, not broad evidence of superiority. Submillisecond quartic timings deserve
particular caution; their consistent gains motivate broader confirmation.

Both adaptive rules had zero measured incremental bytes per iteration on the
fixed 20/120-step vector least-squares checks. Total setup and certificate bytes
remain in the raw data. No runtime dependency or solver option was added.

**Decision:** adaPGM is worth a separate, opt-in convex-method follow-up, with
broader confirmation on globally finite smooth losses. It should not become a
default log-det step rule from these benign tests. Keep the domain-stress failures
alongside these successful results, and do not infer accelerated or nonconvex
convergence guarantees. MM is a useful comparator; these measurements do not
support prioritizing it over adaPGM.

See the [raw evidence](../panocplus/evidence/20261025) and the PANOCplus README
for run identity, checked quantities and reproduction details.

The explicit S=10I domain stress test confirms the limitation: adaPGM and MM
both leave the SPD cone on the first step for gamma0=1,10,100, with no hidden
retry. All six failures are retained in `domain-probes.csv`. The safeguarded
PANOCplus prototype recovers in all three corresponding runs. This domain is
outside the cited globally finite smooth-loss assumptions.

The completed broader campaign includes 12,960 fits on five coupled globally finite convex losses, three design-conditioning levels and 15 seeds. adaPGM generally beat plain PG but lost to APG across every loss-family median in both stages. No runtime solver option was added. See `broad/README.md` for counts, failures, conditioning effects and the decision.
