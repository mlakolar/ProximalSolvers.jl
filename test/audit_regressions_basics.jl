# Audit regressions that guard against false success: an active-set or square-root result, an
# invalid certificate or a failed line search must not report convergence or move the accepted
# point. Moved from test/audit_regressions.jl to run in the quick tier (#121); the other cases
# of `audit_regressions.jl` stay there.

module AuditRegressionBasics

using Test, LinearAlgebra, Random, SparseArrays, ProximalBase, ProximalSolvers
const PS = ProximalSolvers

@testset "active-set success needs a full residual" begin
  f = QuadraticFunction(Matrix(Diagonal([1.0, 100.0])), [-1.0, -1.0])
  x = zeros(2)
  r = solve!(x, f, NormL1(0.1), ActiveAccProxGradDescent(max_outer = 1),
             ProximalOptions(maxiter = 2, ftol = 1.0, xtol = 1.0, gradtol = 1e-8))
  gradient = f.A*x + f.b
  residual = maximum(abs.(x - sign.(x-gradient).*max.(abs.(x-gradient).-0.1,0)))
  @test residual > 1e-3
  @test !r.converged
  rng = Xoshiro(88)
  X, y = randn(rng, Float32, 60, 25), randn(rng, Float32, 60)
  x = zeros(Float32, 25)
  r = solve!(x, LeastSquaresLoss(y, X), NormL1(0.05f0), ActiveAccProxGradDescent(),
             ProximalOptions(maxiter = 5000, ftol = 1e-6, xtol = 1e-6, gradtol = 1e-5))
  gradient = X'*(X*x-y)
  residual = maximum(abs.(x - sign.(x-gradient).*max.(abs.(x-gradient).-0.05f0,0)))
  @test r.converged
  @test residual <= 1e-5 * max(1, norm(X'y, Inf))
end

@testset "square-root losses converge only with a duality gap" begin
  # Coordinatewise stops at an exact fit: objective 0.2, while zero gives 0.01.
  X = [1.0 1.0; 0.0 0.01]
  start = [1.0, -1.0]; y = X * start; g = NormL1(0.1)
  for f in (SqrtLeastSquaresLoss(y, X), SqrtQuadraticFunction(X'X, -X'y, dot(y,y)))
    x = SparseIterate(start)
    r = @test_logs (:warn, r"coordinate descent") solve!(x, f, g, CDSolver(order = :cyclic))
    @test !r.converged
    @test isfinite(r.gap) && r.gap >= 0.95 - 1e-12
    @test r.minimum > f(zeros(2)) + g(zeros(2))
  end
  # The same trap with a residual outside the column space, which never
  # becomes exactly zero
  X3 = [1.0 1.0; 0.0 0.01; 0.0 0.0]
  for δ in (1e-12, 1e-9)
    y3 = X3 * start + [0.0, 0.0, δ]
    x = SparseIterate(start)
    r = @test_logs (:warn, r"coordinate descent") solve!(x, SqrtLeastSquaresLoss(y3, X3), g, CDSolver(order = :cyclic))
    @test !r.converged
    @test isfinite(r.gap) && r.gap >= 0.95 - 1e-9
  end
  x = SparseIterate(2)
  @test solve!(x, SqrtLeastSquaresLoss(zeros(2), X), g, CDSolver()).converged
  # an ordinary fit is certified, and its gap bounds the suboptimality
  rng = Xoshiro(3)
  Xn = randn(rng, 100, 10); yn = Xn[:, 1:2] * [1.0, -1.0] + 0.5randn(rng, 100)
  λ = 0.2 * norm(Xn'yn, Inf) / norm(yn)
  x = SparseIterate(10)
  r = solve!(x, SqrtLeastSquaresLoss(yn, Xn), NormL1(λ), CDSolver())
  @test r.converged
  @test 0 <= r.gap <= 1e-4
  θ = (yn - Xn*Vector(x)) / norm(yn - Xn*Vector(x))
  θ .*= min(1, λ / norm(Xn'θ, Inf))
  @test r.minimum - dot(yn, θ) <= 1e-4 * r.minimum
end

@testset "invalid certificates cannot pass stopping" begin
  @test PS._relative_gap(1.0, 2.0) == Inf
  @test PS._relative_gap(-Inf, 0.0) == Inf
  @test PS._relative_gap(Inf, Inf) == Inf
  @test PS._relative_gap(NaN, 0.0) == Inf
  @test 0 <= PS._relative_gap(1.0, nextfloat(1.0)) <= 8eps()
  # The public certificate exposes its raw arithmetic, including NaN.
  c = duality_gap(SqrNormL2(1.0), ZeroFunction(), NormL1(1.0), ones(1,1), [NaN], [0.0])
  @test isnan(c.gap)
end

struct InvalidGradient <: AbstractFunction end
(::InvalidGradient)(x) = zero(eltype(x))
ProximalBase.issmooth(::Type{InvalidGradient}) = true
ProximalBase.value_and_gradient!(out, ::InvalidGradient, x) = (fill!(out, eltype(out)(NaN)); zero(eltype(x)))

@testset "line-search failure preserves the accepted point" begin
  @test_throws ErrorException PS.LineSearches.next_curvature(floatmax(Float32), 0.5)
  for method in (ProximalGradientDescent(), AccProxGradDescent(), MonotoneAccProxGradDescent())
    x = [1.0, 2.0]
    @test_throws ErrorException solve!(x, InvalidGradient(), ZeroFunction(), method)
    @test x == [1.0, 2.0]
  end
end

# FT25 (#165): the source reads iterates only through the public interface of ProximalBase. Comments and
# string literals are removed first. A field name after a receiver is a finding unless the (file, receiver,
# field) triple is a read of a penalty, a solver, a result or a workspace, which the allowlist names; the
# receiver is the identifier before the dot, or the first argument of getfield-like calls.
const _PRIVATE_FIELDS = "nzval2ind|ind2nzval|nzval|nnz|storage|groups|group_of|layout_cache|active|position|nactive|ids"
const _FIELD_ACCESS = Regex("([A-Za-z_][A-Za-z0-9_!]*|\\)|\\])\\s*\\.\\s*(" * _PRIVATE_FIELDS * ")\\b")
const _FIELD_CALL = r"\b(getfield|setfield!|getproperty|setproperty!|propertynames|fieldnames|hasfield)\(\s*([A-Za-z_][A-Za-z0-9_!]*)?"
const _OTHER_CALL = r"\b(parentindices)\("
const _FIELD_ALLOWLIST = Set([
  ("workspaces.jl", "g", "groups"),
  ("cd/solver.jl", "g", "groups"), ("cd/solver.jl", "s", "getfield"), ("cd/solver.jl", "CDSolver", "fieldnames"),
  ("cd/models.jl", "g", "groups"), ("cd/models.jl", "g", "getfield"),
  ("cd/lla.jl", "g", "groups"),
  ("cd/multiresponse.jl", "g", "groups"),
  ("cd/gap.jl", "g", "groups"), ("cd/gap.jl", "g", "group_of"), ("cd/gap.jl", "f", "groups"), ("cd/gap.jl", "f", "group_of"),
  ("cd/sparsegroup.jl", "f", "groups"), ("cd/sparsegroup.jl", "f", "group_of"),
  ("solvers/diagonal_metric.jl", "g", "groups"), ("solvers/diagonal_metric.jl", "g", "group_of"),
  ("solvers/active_accelerated_proximal_gradient_descent.jl", "g", "groups"),
  ("solvers/slope_hybrid.jl", "w", "groups"),
  ("solvers/primal_dual.jl", "r", "getfield"),
])

# the source with comments and string literals replaced by blanks (newlines kept, so that lines match)
function _blank_literals(src::AbstractString)
  cs = collect(src)
  n = length(cs)
  out = copy(cs)
  blank!(a, b) = for t in a:b
    cs[t] == '\n' || (out[t] = ' ')
  end
  i = 1
  while i <= n
    c = cs[i]
    if c == '#'
      j = i
      if i < n && cs[i + 1] == '='
        depth, j = 1, i + 2
        while j <= n && depth > 0
          if cs[j] == '#' && j < n && cs[j + 1] == '='
            depth, j = depth + 1, j + 2
          elseif cs[j] == '=' && j < n && cs[j + 1] == '#'
            depth, j = depth - 1, j + 2
          else
            j += 1
          end
        end
        j -= 1
      else
        while j < n && cs[j + 1] != '\n'
          j += 1
        end
      end
      blank!(i, j); i = j + 1
    elseif c == '"'
      triple = i + 2 <= n && cs[i + 1] == '"' && cs[i + 2] == '"'
      j = i + (triple ? 3 : 1)
      while j <= n
        if cs[j] == '\\'
          j += 2
        elseif cs[j] == '"' && (!triple || (j + 2 <= n && cs[j + 1] == '"' && cs[j + 2] == '"'))
          j += triple ? 2 : 0
          break
        else
          j += 1
        end
      end
      j = min(j, n)
      blank!(i, j); i = j + 1
    elseif c == '\''
      prev = i > 1 ? cs[i - 1] : ' '
      if isletter(prev) || isdigit(prev) || prev in ")]}'_!."     # a transpose
        i += 1
      else
        j = i + 1
        while j <= n && cs[j] != '\''
          j += cs[j] == '\\' ? 2 : 1
        end
        j = min(j, n)
        blank!(i, j); i = j + 1
      end
    else
      i += 1
    end
  end
  String(out)
end

# (line, receiver, field, text) for every use of a private field name or a field-reflection call
function _scan_fields(src::AbstractString)
  found = Tuple{Int, String, String, String}[]
  orig = split(src, '\n')
  for (ln, line) in enumerate(split(_blank_literals(src), '\n'))
    text = strip(orig[ln])
    for m in eachmatch(_FIELD_ACCESS, line)
      push!(found, (ln, String(m.captures[1]), String(m.captures[2]), text))
    end
    for m in eachmatch(_FIELD_CALL, line)
      push!(found, (ln, something(m.captures[2], "?"), String(m.captures[1]), text))
    end
    for m in eachmatch(_OTHER_CALL, line)
      push!(found, (ln, "?", String(m.captures[1]), text))
    end
  end
  found
end

function _field_violations(file::AbstractString, src::AbstractString, allowed; used = nothing)
  bad = String[]
  for (ln, recv, field, text) in _scan_fields(src)
    key = (file, recv, field)
    if key in allowed
      used === nothing || push!(used, key)
    else
      push!(bad, "$file:$ln: `$recv.$field`: $text")
    end
  end
  bad
end

@testset "FT25: no private iterate fields in the source" begin
  allowed = Set([("planted.jl", "g", "groups")])
  # the scanner flags a private field and ignores penalty reads, comments, strings and docstrings
  planted = """
  f(x, g) = x.storage[1] + g.groups[1] # x.nzval
  h(x, k) = x.groups[k]
  \"\"\"
  docstring: x.active and x.nactive
  \"\"\"
  s = "x.position" * 'x' * "a\\"x.ids"
  #= x.nnz
  x.layout_cache =#
  u(x) = getfield(x, :storage)
  v(x) = parentindices(x)
  w(x) = x.group_of
  y = [1.0 2.0]'; z = y.active
  """
  bad = _field_violations("planted.jl", planted, allowed)
  @test length(bad) == 6
  @test any(contains("planted.jl:1:"), bad) && any(contains("planted.jl:2:"), bad)
  @test any(contains("planted.jl:9:"), bad) && any(contains("planted.jl:10:"), bad)
  @test any(contains("planted.jl:11:"), bad) && any(contains("planted.jl:12:"), bad)
  @test !any(contains("planted.jl:3:"), bad) && !any(contains("planted.jl:4:"), bad)
  @test !any(contains("planted.jl:6:"), bad) && !any(contains("planted.jl:7:"), bad) && !any(contains("planted.jl:8:"), bad)
  @test isempty(_field_violations("planted.jl", "q(g) = g.groups[1]  # allowlisted penalty read\n", allowed))

  srcdir = joinpath(pkgdir(ProximalSolvers), "src")
  files = sort!([relpath(joinpath(root, f), srcdir) for (root, _, fs) in walkdir(srcdir) for f in fs if endswith(f, ".jl")])
  @test length(files) > 20
  used = Set{Tuple{String, String, String}}()
  violations = String[]
  for rel in files
    append!(violations, _field_violations(replace(rel, '\\' => '/'), read(joinpath(srcdir, rel), String), _FIELD_ALLOWLIST; used))
  end
  @test isempty(violations)
  isempty(violations) || @info "private field uses" violations
  # the allowlist names only reads that exist
  @test isempty(setdiff(_FIELD_ALLOWLIST, used))
end

end
