# Separate adaptive proximal-gradient evaluation

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
