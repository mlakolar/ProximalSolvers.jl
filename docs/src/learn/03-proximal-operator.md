# [The proximal operator](@id learn-03)

## Soft-thresholding and proximal operators

A **proximal operator** trades off staying near a proposed value and reducing a penalty. For L1, its scalar form is **soft-thresholding**:

~~~math
\operatorname{soft}(z,t)=\operatorname{sign}(z)\max(|z|-t,0).
~~~

For example, soft-thresholding `0.3` at threshold `0.5` gives `0`, while thresholding `-0.9` gives `-0.4`. The exact zero is the key to lasso sparsity. ProximalBase provides the [losses and penalties](https://mlakolar.github.io/ProximalBase.jl/dev/) used here.
