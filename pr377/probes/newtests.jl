# Runs only the (#317) testsets of the two owned test files, with their helpers, against the
# loaded ProximalSolvers (the project given to julia: head or base worktree).
#   julia --project=<worktree> newtests.jl <worktree with the test files>
using Test
tdir = joinpath(abspath(ARGS[1]), "test")
function keep317(expr)
  expr isa Expr || return expr
  if expr.head == :macrocall && length(expr.args) >= 3 && expr.args[1] == Symbol("@testset")
    title = expr.args[3]
    title isa String && occursin("#317", title) || return nothing
    return :(try; $expr; catch e; e isa Test.TestSetException || rethrow(); println("TESTSET FAILED: ", $title, " (", e.fail, " failed, ", e.error, " errored)"); end)
  end
  if expr.head == :module
    body = expr.args[3]
    body.args = filter(!isnothing, map(keep317, body.args))
    return expr
  end
  expr
end
for f in ("core_regressions.jl", "stopping_scale.jl")
  src = read(joinpath(tdir, f), String)
  ast = Meta.parseall(src)
  ast.args = filter(!isnothing, map(keep317, ast.args))
  println("=== ", f)
  Core.eval(Main, ast)
end
