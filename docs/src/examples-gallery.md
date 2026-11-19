# Examples gallery

Start with a problem you recognize, inspect the fitted coefficients, then open
its executable walkthrough. The figures below run the same source scripts used
by the problem pages and package tests.

## Lasso: shrink individual coefficients

The lasso example has orthogonal columns with unequal norms, so its answer can
be checked directly. Coordinate descent and proximal gradient recover the same
soft-thresholded solution. The zero row in the design makes the response retain
a component that no coefficient can fit.

```@example gallery_lasso
using Plots, ProximalSolvers
redirect_stdout(devnull) do
    include(joinpath(dirname(pathof(ProximalSolvers)), "..", "examples", "problems", "lasso.jl"))
end
coefficient_positions = collect(1:2)
comparison = plot(; xticks = (coefficient_positions, ["β₁", "β₂"]),
    ylabel = "Coefficient", title = "Lasso on orthogonal columns",
    size = (760, 360), legend = :bottomleft)
for (values, name, offset) in zip(([1.7, -0.925], x_cd, x_pgd),
        ("Closed form", "Coordinate descent", "Proximal gradient"), (-0.24, 0.0, 0.24))
    bar!(comparison, coefficient_positions .+ offset, values; bar_width = 0.22, label = name)
end
comparison
```

[Open the lasso walkthrough](examples/problems/lasso.md), including sparse
coefficient storage and acceleration on a correlated design. To understand why
some coefficients become zero, begin with [optimality conditions](@ref learn-02).

## Group lasso: select blocks together

The group lasso example places noncontiguous features into three groups. The
second group, containing features 2, 3 and 5, is inactive in the fitted model.
The plot compares the simulated coefficients with the estimates returned by
three solvers. Shrinkage changes the active coefficients too.

```@example gallery_group
using Plots, ProximalSolvers
redirect_stdout(devnull) do
    include(joinpath(dirname(pathof(ProximalSolvers)), "..", "examples", "problems", "group_lasso.jl"))
end
feature_positions = collect(1:p)
comparison = plot(; xticks = (feature_positions, string.(feature_positions)),
    xlabel = "Feature", ylabel = "Coefficient", title = "Group lasso with noncontiguous groups",
    size = (760, 380), legend = :outerbottom)
for (values, name, offset) in zip((beta_true, beta, beta_pgd, beta_apg),
        ("Simulated", "Coordinate descent", "Proximal gradient", "Accelerated PG"),
        (-0.27, -0.09, 0.09, 0.27))
    bar!(comparison, feature_positions .+ offset, values; bar_width = 0.16, label = name)
end
comparison
```

[Open the group-lasso walkthrough](examples/problems/group_lasso.md) for the
block layout, penalty scaling and independent optimality checks.

## Choose the next example

| Goal | Walkthrough |
|:--|:--|
| Give each feature its own penalty weight | [Weighted lasso](examples/problems/weighted_lasso.md) |
| Combine sparsity with ridge shrinkage | [Elastic net](examples/problems/elastic_net.md) |
| Use a residual-norm loss with a certificate | [Square-root lasso](examples/problems/square_root_lasso.md) |
| Control the largest coefficient | [ℓ∞ regularization](examples/problems/linf_regularized_regression.md) |
| Estimate a noise scale alongside coefficients | [Scaled lasso](examples/problems/scaled_lasso.md) |
| Find piecewise-constant structure | [Change-point detection](examples/problems/change_point_detection.md) |
| Estimate conditional neighborhoods | [Gaussian graph](examples/problems/nodewise_gaussian_graph.md) |
| Select groups of basis functions | [Sparse additive regression](examples/problems/sparse_additive_regression.md) |
| Select features shared across responses | [Multi-task group lasso](examples/problems/multitask_group_lasso.md) |
| Threshold a covariance estimate | [Sparse covariance](examples/problems/sparse_covariance_soft_thresholding.md) |
| Compare solvers at independently checked accuracy | [Lasso comparison](examples/comparisons/lasso_solvers.md) and [group comparison](examples/comparisons/group_lasso_solvers.md) |

These figures illustrate their particular datasets. The [benchmark guide](benchmarks.md)
explains what a measured performance comparison can support.
