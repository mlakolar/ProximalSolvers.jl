# Copies src/ of the worktree to optA/src and replaces the PGD start by the full Frobenius bound (option A).
import shutil, sys, pathlib
wt = pathlib.Path(sys.argv[1]); out = pathlib.Path(sys.argv[2])
if out.exists(): shutil.rmtree(out)
shutil.copytree(wt / "src", out / "src")
p = out / "src/solvers/proximal_gradient_descent.jl"
s = p.read_text()
a = s.index("function _scanned_initial_curvature")
b = s.index("function update_state!(")
s = s[:a] + "function _scanned_initial_curvature(::Type{T}, X, α) where {T}\n  _initial_curvature(T, _root_scale(T, α), _frobenius_upper(T, X))\nend\n\n" + s[b:]
p.write_text(s)
print("option A written to", out)
