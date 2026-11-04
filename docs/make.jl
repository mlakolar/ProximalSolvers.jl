# scenario (disposable PR, not for merging): what a PR's docs/make.jl can see, then a failing build
println("scenario: DOCUMENTER_KEY present: ", !isempty(get(ENV, "DOCUMENTER_KEY", "")),
        "; GITHUB_TOKEN present: ", !isempty(get(ENV, "GITHUB_TOKEN", "")))
error("scenario: a deliberately failing documentation build")
using Documenter, DocumenterInterLinks, Literate, ProximalSolvers

# Links to the functions of ProximalBase go to its documentation: `@extref` in
# these pages, and the fallbacks for the `@ref`s of the docstrings.
const links = InterLinks("ProximalBase" => "https://mlakolar.github.io/ProximalBase.jl/dev/")
const fallbacks = ExternalFallbacks("KronQuadratic" => "@extref ProximalBase.KronQuadratic",
                                    "prox_entry" => "@extref ProximalBase.prox_entry")

# The examples become pages, run when the documentation is built. Each gets a
# title, and a section marker "# --- title ---" becomes a heading.
const EXAMPLES = joinpath(@__DIR__, "..", "examples")
const GENERATED = joinpath(@__DIR__, "src", "examples")
const TITLES = Dict(
    "01" => "The lasso", "02" => "A lasso path", "03" => "Momentum and Anderson acceleration",
    "04" => "Other penalties", "05" => "The group lasso", "06" => "Generalized linear models",
    "07" => "The square-root and scaled lasso", "08" => "Post-lasso, adaptive and reweighted lasso",
    "09" => "A differential network", "10" => "Three proximal gradient solvers",
    "11" => "Low-rank regression", "12" => "The graphical lasso by ADMM",
    "13" => "A model of your own", "14" => "Primal–dual generalized lasso",
    "15" => "Sparse graph-fused regression", "16" => "Second-difference trend filtering")
const SECTION = r"^# -+ (.+?) -*$"m
headings(s) = replace(s, SECTION => m -> "# ### " * uppercasefirst(match(SECTION, m)[1]) * "\n#")
rm(GENERATED; force = true, recursive = true)
mkpath(GENERATED)
example_pages = Pair{String, String}[]
for file in sort(filter(endswith(".jl"), readdir(EXAMPLES)))
    title = TITLES[file[1:2]]
    Literate.markdown(joinpath(EXAMPLES, file), GENERATED; documenter = true, credit = false,
                      preprocess = s -> "# # $title\n#\n" * headings(s))
    push!(example_pages, title => joinpath("examples", replace(file, r"\.jl$" => ".md")))
end

makedocs(
    sitename = "ProximalSolvers.jl",
    authors = "Mladen Kolar",
    repo = Documenter.Remotes.GitHub("mlakolar", "ProximalSolvers.jl"),
    modules = [ProximalSolvers],
    format = Documenter.HTML(
        prettyurls = get(ENV, "CI", "false") == "true",
        canonical = "https://mlakolar.github.io/ProximalSolvers.jl/stable/",
        edit_link = "master",
        mathengine = Documenter.KaTeX(),
        size_threshold = 400_000,
    ),
    pages = [
        "Home" => "index.md",
        "User guide" => [
            "Getting started" => "getting_started.md",
            "Choosing a solver" => "choosing_solver.md",
            "Architecture" => "architecture.md",
            "Calling the solvers" => "solve.md",
            "Checking a solution" => "optimality.md",
            "Migrating to this release" => "migration.md",
        ],
        "Coordinate descent" => [
            "The method" => "coordinate_descent.md",
            "The losses" => "losses.md",
            "Penalty paths and screening" => "paths.md",
            "Reweighting and refitting" => "drivers.md",
            "Proximal Newton" => "prox_newton.md",
            "A model of your own" => "extending.md",
        ],
        "Proximal methods" => [
            "Proximal gradient" => "proximal_gradient.md",
            "Active-set proximal gradient" => "active_set.md",
            "Screened SLOPE paths" => "slope.md",
            "ADMM" => "admm.md",
            "Primal–dual splitting" => "primal_dual.md",
            "Lecture: choosing a composite splitting" => "composite_lessons.md",
        ],
        "Examples" => example_pages,
        "API reference" => [
            "Solvers and options" => "api/solvers.md",
            "Coordinate descent" => "api/coordinate_descent.md",
        ],
        "Background" => [
            "Related packages and benchmarks" => "related_packages.md",
            "CoordinateDescent comparison" => "performance.md",
            "References" => "references.md",
        ],
    ],
    checkdocs = :exports,
    plugins = [links, fallbacks],
)

# Deploy only when the trusted deploy job of .github/workflows/Documentation.yml asks for it (a
# push to master or a release tag, with the key from the deploy-key environment). Pull requests
# and local builds build and check the documentation without deploying or needing credentials.
if get(ENV, "DOCUMENTER_DEPLOY", "false") == "true"
  deploydocs(repo = "github.com/mlakolar/ProximalSolvers.jl.git", devbranch = "master", push_preview = false)
end
