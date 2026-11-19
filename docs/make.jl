ENV["GKSwstype"] = "100"
using Documenter, Literate, ProximalSolvers

const GENERATED = joinpath(@__DIR__, "src", "examples")
rm(GENERATED; force = true, recursive = true)
mkpath(GENERATED)

# The examples that become documentation pages. A path is relative to `examples/`, and a page
# is written to `docs/src/examples/<the same path>.md`. With `notebook = true`, a notebook is
# also written next to its page. When a script is added to `examples/` it is added here too, and the check below
# fails otherwise. Gallery categories and descriptions live here with their example paths.
const EXAMPLES = [
  (section = "Problems", path = "problems/lasso.jl",
   title = "Lasso", notebook = false,
   gallery = "Sparse regression", description = "Choose a small set of predictors with an ℓ₁ penalty."),
  (section = "Problems", path = "problems/weighted_lasso.jl",
   title = "Weighted lasso", notebook = false,
   gallery = "Sparse regression", description = "Shrink different coefficients by different amounts, including an unpenalized predictor."),
  (section = "Problems", path = "problems/nonnegative_least_squares.jl",
   title = "Nonnegative least squares", notebook = false,
   gallery = "Sparse regression", description = "Fit nonnegative mixture amplitudes and compare with a sparse fit."),
  (section = "Problems", path = "problems/nonnegative_lasso.jl",
   title = "Nonnegative sparse regression", notebook = false,
   gallery = "Sparse regression", description = "Estimate the amounts of a few components in a noisy mixture."),
  (section = "Problems", path = "problems/elastic_net.jl",
   title = "Elastic net", notebook = false,
   gallery = "Sparse regression", description = "See how adding a ridge penalty changes the coefficients of correlated predictors."),
  (section = "Problems", path = "problems/l0_sparse_regression.jl",
   title = "ℓ₀-penalized sparse regression", notebook = false,
   gallery = "Sparse regression", description = "Compare hard thresholding from different starts with lasso and elastic net."),
  (section = "Problems", path = "problems/group_lasso.jl",
   title = "Group lasso", notebook = false,
   gallery = "Structured regression", description = "Select entire blocks of regression coefficients with a group penalty."),
  (section = "Problems", path = "problems/square_root_lasso.jl",
   title = "Square-root lasso", notebook = false,
   gallery = "Sparse regression", description = "Fit a sparse regression using a penalty calibrated without a known noise scale."),
  (section = "Problems", path = "problems/linf_regularized_regression.jl",
   title = "Least squares with an ℓ∞ penalty", notebook = false,
   gallery = "Sparse regression", description = "Shrink the largest coefficient magnitudes with an ℓ∞ penalty."),
  (section = "Statistical applications", path = "problems/robust_sparse_regression.jl",
   title = "Robust sparse regression", notebook = false,
   gallery = "Sparse regression", description = "Fit a sparse signal and flag unusually large response errors."),
  (section = "Statistical applications", path = "problems/scaled_lasso.jl",
   title = "Scaled lasso", notebook = false,
   gallery = "Sparse regression", description = "Estimate the regression coefficients and noise scale from the same data."),
  (section = "Statistical applications", path = "problems/sparse_deconvolution.jl",
   title = "Sparse deconvolution and event recovery", notebook = false,
   gallery = "Signal processing", description = "Recover the timing and strength of brief events from blurred measurements."),
  (section = "Statistical applications", path = "problems/change_point_detection.jl",
   title = "Change-point detection", notebook = false,
   gallery = "Signal processing", description = "Find jumps in the level of a noisy time series."),
  (section = "Statistical applications", path = "problems/stability_selection.jl",
   title = "Stability selection with repeated lasso fits", notebook = false,
   gallery = "Sparse regression", description = "See which predictors enter repeated lasso fits on random half-samples."),
  (section = "Statistical applications", path = "problems/nodewise_gaussian_graph.jl",
   title = "Gaussian graph: neighborhood selection", notebook = false,
   gallery = "Covariance and graphs", description = "Infer conditional relationships with one lasso fit per variable."),
  (section = "Statistical applications", path = "problems/sparse_additive_regression.jl",
   title = "Sparse additive regression", notebook = false,
   gallery = "Structured regression", description = "Select predictors whose effects may be nonlinear."),
  (section = "Statistical applications", path = "problems/multitask_group_lasso.jl",
   title = "Multi-task group lasso", notebook = false,
   gallery = "Structured regression", description = "Find predictors shared across several related regression tasks."),
  (section = "Statistical applications", path = "problems/categorical_group_selection.jl",
   title = "Categorical factor selection", notebook = false,
   gallery = "Structured regression", description = "Choose complete categorical factors by grouping their level contrasts."),
  (section = "Statistical applications", path = "problems/sparse_covariance_soft_thresholding.jl",
   title = "Sparse covariance thresholding", notebook = false,
   gallery = "Covariance and graphs", description = "Use soft thresholding to remove small off-diagonal covariance estimates."),
  (section = "Solver comparisons", path = "comparisons/lasso_solvers.jl",
   title = "Lasso: solvers at equal accuracy", notebook = true,
   gallery = "Solver comparisons", description = "Compare how much work lasso solvers need to reach the same accuracy."),
  (section = "Solver comparisons", path = "comparisons/group_lasso_solvers.jl",
   title = "Group lasso: CD, PGD and APG", notebook = false,
   gallery = "Solver comparisons", description = "Compare coordinate and gradient methods on one group-lasso problem.")]

# The set of scripts under `examples/`, in subfolders too, equals the registry.
let root = joinpath(@__DIR__, "..", "examples"), found = String[]
  for (dir, _, names) in walkdir(root), name in names
    endswith(name, ".jl") && push!(found, replace(relpath(joinpath(dir, name), root), '\\' => '/'))
  end
  registered = [e.path for e in EXAMPLES]
  allunique(registered) || error("docs/make.jl: duplicate script in the example registry.")
  unregistered, missing_files = sort(setdiff(found, registered)), sort(setdiff(registered, found))
  isempty(unregistered) && isempty(missing_files) ||
    error("docs/make.jl: the example registry differs from the scripts under examples/. ",
          "Not in the registry: ", unregistered, ". Registered but missing: ", missing_files, ".")
end

for e in EXAMPLES
  source = joinpath(@__DIR__, "..", "examples", e.path)
  outdir = joinpath(GENERATED, dirname(e.path))
  titled = s -> "# # $(e.title)\n#\n" * s
  tutorial = s -> titled(s) * "\n\n# [Reproduce the figures locally](../index.md#Reproduce-the-figures).\n"
  Literate.markdown(source, outdir; documenter = true, credit = false, preprocess = tutorial)
  # The notebook is written next to the generated Markdown file, and Documenter copies it
  # to the build; the page links to it by its file name relative to the page source.
  e.notebook && Literate.notebook(source, outdir; execute = false, credit = false, preprocess = titled)
end
example_pages(section) = [e.title => joinpath("examples", splitext(e.path)[1] * ".md")
                          for e in EXAMPLES if e.section == section]

const PRETTYURLS = get(ENV, "CI", "false") == "true"
gallery_path(e) = splitext(e.path)[1]
html_escape(s) = replace(s, '&' => "&amp;", '<' => "&lt;", '>' => "&gt;", '"' => "&quot;")

open(joinpath(GENERATED, "index.md"), "w") do io
  println(io, """
# Examples Gallery

Explore sparse regression, signal recovery, and structured models with examples you can run in Julia.
Each tutorial explains the model, reproduces its figure, and checks the fitted result.
""")
  for group in unique(e.gallery for e in EXAMPLES)
    println(io, "## $group\n")
    println(io, "```@raw html")
    println(io, "<div class=\"examples-gallery\">")
    for e in filter(e -> e.gallery == group, EXAMPLES)
      path = gallery_path(e)
      page = PRETTYURLS ? "$path/" : "$path.html"
      println(io, """
<a class="examples-gallery-card" href="$page">
  <img src="$path.svg" alt="" loading="lazy" decoding="async">
  <span class="examples-gallery-title">$(html_escape(e.title))</span>
  <span class="examples-gallery-description">$(html_escape(e.description))</span>
</a>
""")
    end
    println(io, "</div>\n```\n")
  end
  println(io, """
## Reproduce the figures

From the repository root, run these commands to build the documentation.

```sh
julia --project=docs -e 'using Pkg; Pkg.develop(path=pwd()); Pkg.instantiate()'
julia --project=docs docs/make.jl
```

To run a numerical example on its own, use `julia --project=. examples/<path>.jl`.
The standalone scripts use the package environment. The documentation build uses Plots.
""")
end

makedocs(sitename = "ProximalSolvers.jl", authors = "Mladen Kolar",
  repo = Documenter.Remotes.GitHub("mlakolar", "ProximalSolvers.jl"), modules = [ProximalSolvers],
  format = Documenter.HTML(prettyurls = PRETTYURLS, edit_link = "master",
    assets = ["assets/examples-gallery.css"]),
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
      "Benchmarks and performance" => "benchmarks.md",
      "Glossary" => "glossary.md"],
    "Examples Gallery" => "examples/index.md",
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
        "Oracle range observations" => "contracts/evidence/oracle-range-observations.md",
        "Historical example index" => "contracts/evidence/examples-index-baseline.md",
        "Square-root fallback history" => "contracts/evidence/sqrt-fallback-406.md"]],
    hide("numerics.md"), hide("stopping-limits.md"), hide("concepts.md"),
    hide("sparsity-and-kkt.md"), hide("internals.md"),
    hide("developer/implementation-notes.md")], checkdocs = :exports)
# Raw gallery links are relative to examples/index.html in both URL modes.
# Catch a missing generated image or an incorrect card target in the docs build.
let build = joinpath(@__DIR__, "build", "examples")
  for e in EXAMPLES
    path = gallery_path(e)
    page = PRETTYURLS ? joinpath(build, path, "index.html") : joinpath(build, "$path.html")
    svg = joinpath(build, "$path.svg")
    isfile(page) || error("Missing example page for gallery: $page")
    isfile(svg) && filesize(svg) > 0 || error("Missing generated figure for gallery: $svg")
  end
end

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
