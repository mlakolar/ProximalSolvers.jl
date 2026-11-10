# Coordinate descent reference

## Pinned ProximalBase block interface

These docstrings come from the exact ProximalBase dependency used by this
build. Rendering them here keeps links valid while the breaking block API
awaits publication in ProximalBase's development documentation.

```@docs
ProximalBase.prox_block
ProximalBase.prox_block!
```

## Square-root losses

```@docs
SqrtLeastSquaresLoss
SqrtQuadraticFunction
```

## Penalty levels and paths

```@docs
lambda_max
solve_path
PathResults
ProximalSolvers.PATH_GAPTOL
LLA
```

## Reweighting and refits

```@docs
reweight!
ReweightResults
refit!
RefitCache
```

## Models and their interface

```@docs
CDModel
cdmodel
ProximalSolvers.intercept
ProximalSolvers.residuals
ProximalSolvers.linear_predictor
ProximalSolvers.deviance
ProximalSolvers.nulldeviance
```

The interface of a model (see [A coordinate descent model of your own](@ref)):

```@docs
ProximalSolvers.initialize!
ProximalSolvers.coordinate_derivatives
ProximalSolvers.update_cache!
ProximalSolvers.coordinate_step!
ProximalSolvers.coordinate_scale
ProximalSolvers.response_scale
ProximalSolvers.loss_value
ProximalSolvers.check_penalty
```
