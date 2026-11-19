ENV["GKSwstype"] = "100"
using Documenter, Literate, ProximalSolvers

const GENERATED = joinpath(@__DIR__, "src", "examples")
rm(GENERATED; force = true, recursive = true)
mkpath(GENERATED)

# The examples that become documentation pages. A path is relative to `examples/`, and a page
# is written to `docs/src/examples/<the same path>.md`. With `notebook = true`, a notebook is
# also written next to its page. When a script is added to `examples/` it is added here too, and the check below
# fails otherwise.
const EXAMPLES = [
  (section = "Problems", path = "problems/lasso.jl", title = "Lasso", notebook = false),
  (section = "Problems", path = "problems/weighted_lasso.jl", title = "Weighted lasso", notebook = false),
  (section = "Problems", path = "problems/elastic_net.jl", title = "Elastic net", notebook = false),
  (section = "Problems", path = "problems/group_lasso.jl", title = "Group lasso", notebook = false),
  (section = "Problems", path = "problems/square_root_lasso.jl", title = "Square-root lasso", notebook = false),
  (section = "Problems", path = "problems/linf_regularized_regression.jl", title = "Least squares with an ℓ∞ penalty", notebook = false),
  (section = "Statistical applications", path = "problems/scaled_lasso.jl", title = "Scaled lasso", notebook = false),
  (section = "Statistical applications", path = "problems/change_point_detection.jl", title = "Change-point detection", notebook = false),
  (section = "Statistical applications", path = "problems/nodewise_gaussian_graph.jl", title = "Gaussian graph: neighborhood selection", notebook = false),
  (section = "Statistical applications", path = "problems/sparse_additive_regression.jl", title = "Sparse additive regression", notebook = false),
  (section = "Statistical applications", path = "problems/multitask_group_lasso.jl", title = "Multi-task group lasso", notebook = false),
  (section = "Statistical applications", path = "problems/sparse_covariance_soft_thresholding.jl", title = "Sparse covariance thresholding", notebook = false),
  (section = "Solver comparisons", path = "comparisons/lasso_solvers.jl",
   title = "Lasso: solvers at equal accuracy", notebook = true),
  (section = "Solver comparisons", path = "comparisons/group_lasso_solvers.jl",
   title = "Group lasso: CD, PGD and APG", notebook = false)]

# The set of scripts under `examples/`, in subfolders too, equals the registry.
let root = joinpath(@__DIR__, "..", "examples"), found = String[]
  for (dir, _, names) in walkdir(root), name in names
    endswith(name, ".jl") && push!(found, replace(relpath(joinpath(dir, name), root), '\\' => '/'))
  end
  registered = [e.path for e in EXAMPLES]
  unregistered, missing_files = sort(setdiff(found, registered)), sort(setdiff(registered, found))
  isempty(unregistered) && isempty(missing_files) ||
    error("docs/make.jl: the example registry differs from the scripts under examples/. ",
          "Not in the registry: ", unregistered, ". Registered but missing: ", missing_files, ".")
end

for e in EXAMPLES
  source = joinpath(@__DIR__, "..", "examples", e.path)
  outdir = joinpath(GENERATED, dirname(e.path))
  titled = s -> "# # $(e.title)\n#\n" * s
  Literate.markdown(source, outdir; documenter = true, credit = false, preprocess = titled)
  # The notebook is written next to the generated Markdown file, and Documenter copies it
  # to the build; the page links to it by its file name relative to the page source.
  e.notebook && Literate.notebook(source, outdir; execute = false, credit = false, preprocess = titled)
end
example_pages(section) = [e.title => joinpath("examples", splitext(e.path)[1] * ".md")
                          for e in EXAMPLES if e.section == section]

const PRETTYURLS = get(ENV, "CI", "false") == "true"
makedocs(sitename = "ProximalSolvers.jl", authors = "Mladen Kolar",
  repo = Documenter.Remotes.GitHub("mlakolar", "ProximalSolvers.jl"), modules = [ProximalSolvers],
  format = Documenter.HTML(prettyurls = PRETTYURLS, edit_link = "master"),
  pages = ["Home" => "index.md",
    "Learn" => [
      "1: The lasso problem" => "learn/01-lasso-problem.md",
      "2: Optimality and KKT conditions" => "learn/02-optimality-kkt.md",
      "3: The proximal operator" => "learn/03-proximal-operator.md",
      "4: Proximal gradient descent" => "learn/04-proximal-gradient.md",
      "5: Acceleration" => "learn/05-acceleration.md",
      "6: Coordinate descent" => "learn/06-coordinate-descent.md",
      "7: Duality and certificates" => "learn/07-duality-certificates.md",
      "8: Floating-point computation" => "learn/08-floating-point.md"],
    "Use" => [
      "Getting started" => "getting-started.md",
      "Choosing a solver" => "choosing-solver.md",
      "Supported problems" => "support.md",
      "Results and troubleshooting" => "working-with-results.md",
      "Examples gallery" => "examples-gallery.md",
      "Benchmarks and performance" => "benchmarks.md",
      "Glossary" => "glossary.md"],
    "Problems" => example_pages("Problems"),
    "Statistical applications" => example_pages("Statistical applications"),
    "Solver comparisons" => example_pages("Solver comparisons"),
    "API reference" => "api.md",
    "Contracts" => [
      "How to read a contract" => "contracts/index.md",
      "Inputs" => "contracts/inputs.md",
      "Working precision" => "contracts/working-precision.md",
      "Scalar coordinate descent" => "contracts/cd-scalar.md",
      "SparseIterate coordinate descent" => "contracts/cd-sparse-iterate.md",
      "Group coordinate descent" => "contracts/cd-group.md",
      "Multiresponse coordinate descent" => "contracts/cd-multiresponse.md",
      "Square-root lasso" => "contracts/cd-sqrt-lasso.md",
      "Proximal gradient iteration" => "contracts/pg-iteration.md",
      "Accelerated proximal gradient" => "contracts/apg.md",
      "Line search" => "contracts/line-search.md",
      "PG stopping" => "contracts/pg-stopping.md",
      "Results and failures" => "contracts/results-failures.md",
      "Deferred surface" => "contracts/deferred.md",
      "Architecture" => "contracts/architecture.md",
      "History" => "contracts/history.md",
      "Evidence" => [
        "Stopping audit" => "contracts/evidence/stopping-audit-352.md",
        "Cached-residual investigation" => "contracts/evidence/cached-residual-378.md",
        "Strict-accuracy configuration" => "contracts/evidence/strict-accuracy-config.md",
        "Lazy-curvature cost" => "contracts/evidence/lazy-curvature-cost.md",
        "Oracle range observations" => "contracts/evidence/oracle-range-observations.md"]],
    hide("numerics.md"), hide("stopping-limits.md"), hide("concepts.md"),
    hide("sparsity-and-kkt.md"), hide("internals.md"),
    hide("developer/implementation-notes.md")], checkdocs = :exports)
# The pages of the flat example layout were published as `examples/<old>/` (`examples/<old>.html`
# without pretty URLs). Each old page becomes a redirect stub with a relative target, so the stub
# works under any version folder of the site; the lasso pages go to their sections. The notebook
# of the solver comparison keeps its old file name as a copy, since a notebook cannot redirect.
const REDIRECTS = [
  ("01_cd_lasso", "problems/lasso", "Coordinate-descent"),
  ("02_pgd_lasso", "problems/lasso", "Proximal-gradient-descent"),
  ("03_sparse_cd_lasso", "problems/lasso", "Coordinate-descent-on-a-SparseIterate"),
  ("04_lasso_solver_comparison", "comparisons/lasso_solvers", ""),
  ("05_apg_lasso", "problems/lasso", "Accelerated-proximal-gradient-descent"),
  ("06_group_cd_lasso", "problems/group_lasso", ""),
  ("07_elasticnet", "problems/elastic_net", ""),
  ("09_square_root_lasso", "problems/square_root_lasso", "")]
let build = joinpath(@__DIR__, "build", "examples")
  for (old, new, anchor) in REDIRECTS
    stub, target_file, target = if PRETTYURLS
      joinpath(build, old, "index.html"), joinpath(build, new, "index.html"), "../$new/"
    else
      joinpath(build, "$old.html"), joinpath(build, "$new.html"), "$new.html"
    end
    isfile(target_file) || error("docs/make.jl: the redirect target ", target_file, " does not exist")
    isempty(anchor) || occursin("id=\"$anchor\"", read(target_file, String)) ||
      error("docs/make.jl: the redirect target ", target_file, " has no anchor ", anchor)
    isempty(anchor) || (target *= "#" * anchor)
    mkpath(dirname(stub))
    write(stub, """<!DOCTYPE html>
<html>
<head>
<meta charset="utf-8">
<meta http-equiv="refresh" content="0; url=$target">
<title>This page has moved</title>
</head>
<body>
<p>This page has moved to <a href="$target">$target</a>.</p>
</body>
</html>
""")
  end
  cp(joinpath(GENERATED, "comparisons", "lasso_solvers.ipynb"), joinpath(build, "04_lasso_solver_comparison.ipynb"); force = true)
end
if get(ENV, "DOCUMENTER_DEPLOY", "false") == "true"
  deploydocs(repo = "github.com/mlakolar/ProximalSolvers.jl.git", devbranch = "master", push_preview = false)
end
