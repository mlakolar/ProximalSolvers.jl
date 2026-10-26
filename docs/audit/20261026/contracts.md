# Mathematical contracts checked

All norms are Euclidean/Frobenius unless a documented solver option changes the
measurement. ProximalBase uses `prox_{γg}(z) = argmin_x g(x)+norm(x-z)^2/(2γ)`.
Scaling belongs to the supplied loss/penalty, not to an implicit sample-size rule.

| Family | Represented problem and update | Conditions and stopping checked |
|---|---|---|
| PGD | `f+g`, `prox_{g/L}(x-grad(f,x)/L)`; optional diagonal metric | Smooth loss, exact supplied proximal operator, majorization; TFOCS gradient estimate uses convexity. Normalized IHT is exact only for quadratic directional curvature. Small changes are not independent certificates. |
| Accelerated PG | Extrapolate from accepted x/x_previous; step from y; restart an increasing extrapolation | Convex acceleration assumptions are separate from numerical restart/backtracking. Nonconvex APG has no general stationarity claim. Return accepted candidate, including restored x on failure. |
| Monotone accelerated PG | Extrapolated candidate z and plain candidate v; sufficient-decrease test, keep lower objective | Both origins, gradients and affine images must match retained step. Backtracking progress finite; Li–Lin rates conditional on their hypotheses. |
| Active PG | Restrict coefficients/groups, full gradient activates excluded violations, inner APG | Independent full proximal equation now gates success. Its tolerance is `gradtol*max(1,norm(initial_gradient,Inf))`; an inner change rule alone is insufficient. |
| Coordinate least squares | `s*sum(w.*(y-offset-Xβ-β0).^2)/2`; exact scalar quadratic step | Centered weighted columns; CSC lazy residual shift; cached norms reset by initialize. Model/data fixed during workspace reuse. |
| Multiresponse | `s*norm(Y-1β0'-XB)^2/2`; row-group step | Block Hessian is a scalar identity for a row. Group partition must match row indices; intercept vector and residual matrix retained. |
| Quadratic/Kronecker | `s*(x'Ax/2+b'x+c)` or `s*(<Θ,AΘB>/2+<C,Θ>)` | Symmetric PSD curvature is a mathematical precondition, not proved by traits. Lower-triangle coordinates move two entries. Flat nonzero slopes reject. Full block eigenvalue bounds, not diagonal approximations. |
| Square-root | `sqrt(sum(w.*(y-Xβ-β0).^2))` or `sqrt(x'Ax+2b'x+c)` | Exact scalar minimizers; nonnegative quadratic is a caller precondition. Coordinate stopping at zero residual cannot certify joint optimality unless objective is zero. No square-root duality certificate is claimed. |
| GLM CD | `s*sum(w_i*ell(X_iβ+offset_i,y_i))` with global scalar curvature bound | Scalar derivatives and bound supplied by the loss; CD does not fit a GLM intercept. Statistical response domains remain those of the chosen scalar loss. Zero-weight observations are omitted before evaluation. |
| GLM Newton | Weighted quadratic model with working responses and floored curvature, inner CD, original-objective line search | Floor/damping is approximate curvature, not a global majorizer. Objective stagnation requires original-gradient stationarity; a computable path gap uses its own valid certificate, with raw-score guards for convolution loss. Inner failures retained. |
| Generic Newton | Minimize new-point `quadratic_model(f,x)` plus original g; Armijo along model solution minus x | Nonnegative coordinate diagonals alone do not establish PSD of a user Hessian. Refresh copied/scalar model state every outer step; shared refinement pass budget; original residual certifies stationarity. |
| QUIC | `w*(tr(SX)-logdet(X))+sum(λ_ij*abs(X_ij))` | Cholesky acceptance preserves SPD; inverse updated from accepted factor. Off-diagonal penalty uses sum of transposed weights. Component decomposition and scalar diagonal solution checked. Gap uses checked weak-duality arithmetic. |
| ADMM | Split x=z; scaled dual u; exact prox f/rho, relaxed prox g/rho | Closed proper convex functions and a saddle point required for usual convergence. Primal `norm(x-z)`, dual `rho*norm(z-zprev)`; adaptive rho rescales u and stops changing after 50 adjustments. Nonconvex execution is not a convergence guarantee. |
| Condat–Vu | `f+g+h(Dx)`; primal forward/prox, dual prox conjugate at extrapolated Dx | Convex functions, global gradient bound L, adjoint dimensions, `τ*(L/2+σ*norm_d^2)<1`. Matrix one/Inf norm bound is certified; a supplied/numerical L is the caller's obligation. Both KKT residuals or a valid gap; heuristics eventually fixed. |
| SLOPE | Single-response supplied least squares and sorted L1 weights | Leading restricted weights require excluded coefficients zero. Full fixed-point checks repair exclusions; per-level budget includes repairs. Hybrid caches signed cluster columns and reserves APG fallback work. |
| Paths / LLA / reweight | Decreasing finite penalty grids, warm coefficients/cache, strong screening and rechecks; tangent-weight stages | Repeated/zero levels supported by CD grids. Nonconvex results are stationary/algorithm-dependent, not global. A weight-change flag and inner convergence are distinct. Snapshots do not alias x. |
| Refit | Restrict entire point to support, QR or cached support Hessian solve | Empty and singular supports covered by suite. Cache owner identity does not detect same-shape data changes; unchanged data is required. Outside support now zero. |

The normal manual gives detailed equations and cross-references. This table
records which obligations were checked; it is not a new convergence theorem.
Finite precision can limit a certificate. Unsupported custom conjugates raise
errors; unavailable two-term gaps use the documented fallback rule. Callback and
initialization calls are not strict within-iteration budget cutoffs: the existing
options explicitly check call limits after completed iterations. Zero means no
call limit; ProximalOptions still requires maxiter greater than one, while
CDSolver supports zero passes. A callback/limit can stop an accurate point, so the
returned convergence flag is evaluated at that point under its selected rule.

## External theorem check

The ADMM hypothesis was checked against Boyd et al. (2011), §3.2,
Assumptions 1–2 (printed pp. 15–16), and over-relaxation against §3.4.3
(printed p. 21), at the [author-hosted paper](https://web.stanford.edu/~boyd/papers/pdf/admm_distr_stats.pdf),
DOI 10.1561/2200000016, accessed 2026-10-26. This was a statement/hypothesis
check, not a new proof audit of the cited literature. The manual now requires
a saddle point and exact proximal updates. A primal solution alone does not
supply the paper's dual-attainment hypothesis.
