using Documenter, Literate, ProximalSolvers

const GENERATED = joinpath(@__DIR__, "src", "examples")
rm(GENERATED; force = true, recursive = true)
mkpath(GENERATED)
example_pages = Pair{String, String}[]
for (file, title) in (("01_cd_lasso.jl", "Coordinate descent lasso"),
                      ("02_pgd_lasso.jl", "Proximal gradient lasso"),
                      ("03_sparse_cd_lasso.jl", "Coordinate descent on a SparseIterate"))
  Literate.markdown(joinpath(@__DIR__, "..", "examples", file), GENERATED;
    documenter = true, credit = false, preprocess = s -> "# # $title\n#\n" * s)
  push!(example_pages, title => joinpath("examples", replace(file, ".jl" => ".md")))
end
makedocs(sitename = "ProximalSolvers.jl", authors = "Mladen Kolar",
  repo = Documenter.Remotes.GitHub("mlakolar", "ProximalSolvers.jl"), modules = [ProximalSolvers],
  format = Documenter.HTML(prettyurls = get(ENV, "CI", "false") == "true", edit_link = "master"),
  pages = ["Home" => "index.md",
    "Getting started" => "getting-started.md",
    "What problem, which algorithm?" => "concepts.md",
    "Sparsity and an optimality check" => "sparsity-and-kkt.md",
    "Choosing a solver" => "choosing-solver.md",
    "Results and troubleshooting" => "working-with-results.md",
    "Examples" => example_pages,
    "Supported problems" => "support.md",
    "Numerical behavior" => "numerics.md",
    "Glossary" => "glossary.md",
    "API reference" => "api.md",
    "For contributors" => [
      "Developer architecture" => "internals.md",
      "Implementation notes" => "developer/implementation-notes.md"]], checkdocs = :exports)
if get(ENV, "DOCUMENTER_DEPLOY", "false") == "true"
  deploydocs(repo = "github.com/mlakolar/ProximalSolvers.jl.git", devbranch = "master", push_preview = false)
end
