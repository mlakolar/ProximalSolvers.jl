# [The lasso problem](@id learn-01)

## The lasso

Given a response vector `y`, a matrix `X` of `n` rows and `p` columns, and a coefficient vector `beta`, the lasso minimizes

~~~math
\frac{1}{2n}\|y-X\beta\|_2^2+\lambda\sum_{j=1}^p|\beta_j|.
~~~

The first term fits the observations. The L1 penalty shrinks coefficients and can make them **exactly zero**. A larger `lambda` strengthens this penalty relative to the scaled loss.
