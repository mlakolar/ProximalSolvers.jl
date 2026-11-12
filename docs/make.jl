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
  pages = ["Home" => "index.md", "Support and migration" => "support.md",
    "Numerical contracts" => "numerics.md", "Architecture" => "internals.md",
    "Examples" => example_pages, "API" => "api.md"], checkdocs = :exports)
if get(ENV, "DOCUMENTER_DEPLOY", "false") == "true"
  deploydocs(repo = "github.com/mlakolar/ProximalSolvers.jl.git", devbranch = "master", push_preview = false)
end
