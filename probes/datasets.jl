using Random, LinearAlgebra
function data(name; seed = 296)
  rng = Xoshiro(seed)
  if name == "diag"         # steep column 1e6, flat column 1, uncorrelated; y in the flat column
    X = [1e6 0.0; 0.0 1.0; 0.0 0.5]; y = [0.0, 1.0, 0.2]
    return X, y
  elseif name == "orth"     # orthogonal columns with scales 1e6, 1, 1, 1; y orthogonal to column 1
    Q = Matrix(qr(randn(rng, 8, 8)).Q)
    X = Q[:, 1:4] * Diagonal([1e6, 1.0, 1.0, 1.0])
    y = Q[:, 2:4] * [1.0, -1.0, 0.5] + 0.2 * Q[:, 5]
    return X, y
  end
  n, p = name == "big" ? (60, 40) : (30, 12)
  X = randn(rng, n, p)
  β = zeros(p); β[1:4] .= [2.0, -1.5, 1.0, 0.5]
  noise = name == "exact" ? 0.0 : 0.3
  name == "ill" && (X .*= (10.0 .^ range(0, -4; length = p))')
  name == "zerocol" && (X[:, 3] .= 0)
  name == "small" && (X .*= 0.05)
  y = X * β + noise * randn(rng, n)
  X, y
end
