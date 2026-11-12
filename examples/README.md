# Minimal-core lasso examples

Run `julia --project=. examples/01_cd_lasso.jl`,
`julia --project=. examples/02_pgd_lasso.jl` or
`julia --project=. examples/03_sparse_cd_lasso.jl`. Each checks an independent
analytic solution; the third runs coordinate descent on a caller-owned
`SparseIterate` and also checks that the result shares that owner. Historical
feature examples remain on legacy/full and protected archives.
