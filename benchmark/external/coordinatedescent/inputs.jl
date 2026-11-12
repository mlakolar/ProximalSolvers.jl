include("common.jl")

# Usage: inputs.jl OUTDIR [--suite quick|extended] [--tiny]. Tiny artifacts are fixtures.
const DESIGN_SIZES = Dict("A" => (500, 2500, 50), "B" => (500, 2500, 50),
  "C" => (5000, 500, 50), "E" => (500, 2500, 50), "D" => (1000, 20000, 20))

function input_seed(key, rep = 1)
  seed = UInt64(0xcbf29ce484222325) ⊻ UInt64(rep)
  for byte in codeunits(key)
    seed = (seed ⊻ UInt64(byte)) * UInt64(0x100000001b3)
  end
  string(seed)
end

function write_inputs(output; suite = "quick", tiny = false)
  output = abspath(output)
  ispath(output) && (!isdir(output) || !isempty(readdir(output))) && error("use a fresh artifact directory")
  catalog = read_catalog(; suite)
  mkpath(output)
  manifest = Dict{String,Any}("schema_version" => 1, "byte_order" => "little",
    "storage_order" => "column-major", "suite" => suite, "fixture" => tiny,
    "julia" => string(VERSION), "generator" => "benchmark/problems.jl:lasso_design",
    "generator_sha256" => file_sha256(joinpath(HARNESS_ROOT, "problems.jl")),
    "catalog_sha256" => file_sha256(CATALOG_PATH), "design" => Any[], "case" => Any[])
  maxima = Dict{String,Float64}()
  grids = Dict{String,Vector{Float64}}()
  for design in sort!(unique([c["design"] for c in catalog]))
    n, p, s = tiny ? (60, 40, 5) : DESIGN_SIZES[design]
    a = lasso_design(Symbol(design), 1; n, p, s)
    λmax = lambda_max(a.X, a.y)
    λpath = lambda_grid(λmax, 0.01, 50)
    groups = [collect(j:min(j + 4, p)) for j in 1:5:p]
    indices = Int64.(reduce(vcat, groups))
    offsets = Int64[1; 1 .+ cumsum(length.(groups))]
    arrays = Dict("X" => a.X, "y" => a.y, "beta_true" => a.β, "beta0" => zeros(p),
      "group_indices" => indices, "group_offsets" => offsets, "group_weights" => ones(length(groups)),
      "weights" => ones(p), "fixed_loadings" => feasible_lasso_loadings(a.X, a.y),
      "lambda_path" => λpath)
    files = Dict(name => write_array(output, "$design/$name.$(eltype(array) == Int64 ? "i64" : "f64")", array)
      for (name, array) in arrays)
    push!(manifest["design"], Dict("id" => design, "label" => design, "n" => n, "p" => p,
      "s" => s, "generator" => "lasso_design", "repetition" => 1, "generator_key" => a.key,
      "data_seed" => input_seed(a.key), "lambda_max" => λmax, "lambda_path" => λpath,
      "groups" => groups, "files" => files))
    maxima[design], grids[design] = λmax, λpath
  end
  for (index, c) in enumerate(catalog)
    λs = c["lambda"] == "path" ? grids[c["design"]] : [c["lambda"] * maxima[c["design"]]]
    push!(manifest["case"], Dict("id" => c["id"], "estimator" => c["estimator"],
      "design" => c["design"], "lambda" => c["lambda"], "lambda_values" => λs,
      "order" => c["order"], "solver_seed" => 117_000 + index,
      "fixed_loadings" => "$(c["design"])/fixed_loadings.f64",
      "weights" => "$(c["design"])/weights.f64", "starting_point" => "$(c["design"])/beta0.f64",
      "group_indices" => "$(c["design"])/group_indices.i64",
      "group_offsets" => "$(c["design"])/group_offsets.i64"))
  end
  write_toml(joinpath(output, "manifest.toml"), manifest)
  artifact = read_artifact(output)
  println("ARTIFACT_SHA256 ", artifact.sha256, " cases=", length(catalog), " fixture=", tiny)
  artifact
end

function inputs_main(args)
  isempty(args) && error("usage: inputs.jl OUTDIR [--suite quick|extended] [--tiny]")
  output, suite, tiny = first(args), "quick", false
  i = 2
  while i <= length(args)
    if args[i] == "--suite"
      i += 1
      i <= length(args) || error("--suite needs a value")
      suite = args[i]
    elseif args[i] in ("--tiny", "--fixtures")
      tiny = true
    else
      error("unknown option $(args[i])")
    end
    i += 1
  end
  write_inputs(output; suite, tiny)
end

if abspath(PROGRAM_FILE) == @__FILE__
  inputs_main(ARGS)
end
