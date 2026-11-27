# API reference

This is the **complete callable reference**, including some historical
constructor keywords that intentionally reject unsupported features.
For practical options, see [Choosing a solver](choosing-solver.md);
for deferred keyword combinations, see [Supported problems](support.md).

`ProximalGradientDescent()` provides its supported backtracking line
search by default. The qualified type
`ProximalSolvers.LineSearches.BackTracking` appears below for API
completeness. Ordinary users do **not** need to import or instantiate
it separately.

```@docs
ProximalSolver
CDSolver
ProximalGradientDescent
AccProxGradDescent
ProxNewton
LogisticADMM
ADMMSolver
solve!
ProximalOptions
NumericalFeasibility
CDResults
ProxNewtonResults
LogisticADMMResults
ADMMResults
OptimizationState
OptimizationTrace
ProximalSolvers.OptimizationResults
ProximalSolvers.LineSearches.BackTracking
ProximalSolvers.Stopping
IterateChange
ObjectiveChange
ScaledKKT
ProximalGradientMapping
Every
PrimalResidual
DualResidual
UserStop
AnyOf
AllOf
MaxIterations
MaxPasses
MaxCoordinateVisits
MaxObjectiveEvaluations
MaxGradientEvaluations
MaxProximalEvaluations
termination
ProximalSolvers.ProximalGradientStoppingResult
ProximalSolvers.CoordinateDescentStoppingResult
ProximalSolvers.ADMMStoppingResult
```
