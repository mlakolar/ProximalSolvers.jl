# Test tiers: which test files a tier runs, and which tier a pull request needs (adapted from
# ProximalBase.jl). test/runtests.jl uses this module to select the files of a tier, and
# scripts/ci_plan.jl uses it to choose the tier of a CI run; test/tier_selection.jl tests it.
# The tier lists are in test/tiers.toml and the CI rules in .github/tier-rules.toml.

module TestTiers

import TOML

export TIERS

# Each tier runs its own files and the files of every tier before it.
const TIERS = ("quick", "standard", "full")

rank(tier::AbstractString) = something(findfirst(==(tier), TIERS), 0)

struct Rule
  patterns::Vector{String}
  regexes::Vector{Regex}
  tier::String # a tier, or "none": no package tests
  focus::Vector{String}
  why::String
end

"""
    Manifest

The parsed tiers.toml: the lowest tier of each test file, the helper files that are not tests,
and the directories with environments of their own; with tier-rules.toml also the rules that
map changed paths to tiers and the CI timeouts.
"""
struct Manifest
  tier::Dict{String, String}
  helpers::Vector{String}
  environments::Vector{String}
  rules::Vector{Rule}
  timeouts::Dict{String, Int}
end

struct ManifestError <: Exception
  problems::Vector{String}
end

function Base.showerror(io::IO, e::ManifestError)
  print(io, "test/tiers.toml or .github/tier-rules.toml has problems:")
  foreach(p -> print(io, "\n  - ", p), e.problems)
end

"""
    load(tiers_path, [rules_path])

Read the tier lists and, if given, the CI rules (two TOML files, read as one).
"""
function load(tiers_path::AbstractString, rules_path::Union{Nothing, AbstractString} = nothing)
  data = TOML.parsefile(tiers_path)
  if rules_path !== nothing
    rules = TOML.parsefile(rules_path)
    for k in keys(rules)
      haskey(data, k) && throw(ManifestError(["`$k` is in both $tiers_path and $rules_path"]))
    end
    merge!(data, rules)
  end
  return parse_manifest(data)
end
parse_manifest(text::AbstractString) = parse_manifest(TOML.parse(text))

isstrings(v) = v isa AbstractVector && all(x -> x isa AbstractString, v)

function parse_manifest(data::AbstractDict)
  problems = String[]
  tier = Dict{String, String}()
  tables = get(data, "tiers", Dict{String, Any}())
  for name in keys(tables)
    name in TIERS || push!(problems, "unknown tier `$name` in [tiers]; the tiers are $(join(TIERS, ", "))")
  end
  for t in TIERS
    files = get(tables, t, String[])
    if !isstrings(files)
      push!(problems, "tier `$t` must be a list of file names, not `$(repr(files))`")
      continue
    end
    isempty(files) && push!(problems, "tier `$t` lists no test files")
    for file in files
      if haskey(tier, file)
        push!(problems, "`$file` is listed in both `$(tier[file])` and `$t`")
      else
        tier[file] = t
      end
    end
  end
  other = get(data, "not_tests", Dict{String, Any}())
  helpers = String[get(other, "helpers", String[])...]
  environments = String[get(other, "environments", String[])...]
  for file in helpers
    haskey(tier, file) && push!(problems, "`$file` is both a helper and in tier `$(tier[file])`")
  end
  rules = Rule[]
  for (i, rule) in enumerate(get(data, "risk", Any[]))
    t = get(rule, "tier", "")
    t == "none" || rank(t) > 0 || push!(problems, "risk rule $i has tier `$t`; use none or one of $(join(TIERS, ", "))")
    patterns = get(rule, "paths", String[])
    focus = get(rule, "focus", String[])
    if !(isstrings(patterns) && isstrings(focus))
      push!(problems, "risk rule $i: `paths` and `focus` must be lists of strings")
      continue
    end
    isempty(patterns) && push!(problems, "risk rule $i has no paths")
    for name in focus
      haskey(tier, name) || push!(problems, "risk rule $i has focus `$name`, which is in no tier")
    end
    push!(rules, Rule(patterns, map(glob_regex, patterns), t, focus, get(rule, "why", "")))
  end
  timeouts = Dict{String, Int}()
  for (t, minutes) in get(data, "timeouts", Dict{String, Any}())
    rank(t) > 0 && minutes isa Integer && minutes > 0 ||
      push!(problems, "timeouts.$t = $minutes: use a tier and a positive number of minutes")
    timeouts[t] = minutes
  end
  if haskey(data, "timeouts")
    for t in TIERS
      haskey(timeouts, t) || push!(problems, "timeouts.$t is missing")
    end
  end
  isempty(problems) || throw(ManifestError(problems))
  return Manifest(tier, helpers, environments, rules, timeouts)
end

isenvironment(m::Manifest, name) = any(dir -> startswith(name, dir * "/"), m.environments)

"""
    discover(testdir) -> Vector{String}

The names of the Julia files under `testdir` as ParallelTestRunner's `find_tests` gives them:
the path relative to `testdir` without `.jl`, with `/` separators, leaving out `runtests.jl`.
The CI plan uses it, which loads no packages.
"""
function discover(testdir::AbstractString)
  names = String[]
  for (root, _, files) in walkdir(testdir), file in files
    endswith(file, ".jl") && file != "runtests.jl" || continue
    rel = relpath(joinpath(root, file[1:(end - 3)]), testdir)
    push!(names, replace(rel, '\\' => '/'))
  end
  return sort!(names)
end

"""
    check(manifest, discovered)

Check the manifest against the test file names found on disk (as ParallelTestRunner's
`find_tests` names them): every file has a tier, is a helper, or lies in an environment
directory, and every name in the manifest exists. Throws a `ManifestError` listing every
problem.
"""
function check(m::Manifest, discovered)
  found = Set{String}(discovered)
  problems = String[]
  for name in sort!(collect(found))
    haskey(m.tier, name) || name in m.helpers || isenvironment(m, name) ||
      push!(problems, "`test/$name.jl` has no tier: add it to one tier in test/tiers.toml")
  end
  for name in sort!(collect(keys(m.tier)))
    name in found || push!(problems, "`$name` is in tier `$(m.tier[name])`, but test/$name.jl does not exist")
  end
  for name in m.helpers
    name in found || push!(problems, "helper `$name` does not exist")
  end
  isempty(problems) || throw(ManifestError(problems))
  return nothing
end

"""
    select(manifest, tier) -> Vector{String}

The test files that `tier` runs, sorted: every file whose lowest tier is `tier` or lower.
"""
function select(m::Manifest, tier::AbstractString)
  r = rank(tier)
  r > 0 || throw(ArgumentError("unknown test tier `$tier`; the tiers are $(join(TIERS, ", "))"))
  return sort!([name for (name, t) in m.tier if rank(t) <= r])
end

# A glob over repository paths: `*` and `?` stay within a directory, `**` spans directories.
function glob_regex(pattern::AbstractString)
  out = IOBuffer()
  chars = collect(pattern)
  i = 1
  while i <= length(chars)
    c = chars[i]
    if c == '*' && i < length(chars) && chars[i + 1] == '*'
      if i + 1 < length(chars) && chars[i + 2] == '/'
        print(out, "(?:.*/)?")
        i += 3
      else
        print(out, ".*")
        i += 2
      end
      continue
    elseif c == '*'
      print(out, "[^/]*")
    elseif c == '?'
      print(out, "[^/]")
    elseif c in raw"\.^$+()[]{}|"
      print(out, '\\', c)
    else
      print(out, c)
    end
    i += 1
  end
  return Regex("^" * String(take!(out)) * "\$")
end

"""
    classify(manifest, paths; manifest_additions = nothing) -> (tier, focus, decisions)

The minimum tier for a change to `paths` (repository-relative, `/`-separated): the highest
tier of the first rule matching each path, or `full` for a path no rule matches. `"none"`
means no package tests. Changed test files and the `focus` files of matched rules are
returned in `focus`: CI runs them beside the tier. `decisions` gives each path's rule.

`manifest_additions`, when given, are the names that test/tiers.toml adds, all of them test
files new in the change (see [`manifest_additions`](@ref)): the tier lists then decide quick,
and the new files run as changed test files.
"""
function classify(m::Manifest, paths; manifest_additions = nothing)
  decisions = Tuple{String, String, String}[]
  focus = Set{String}()
  tier = "none"
  raise(t) = (t != "none" && rank(t) > rank(tier)) && (tier = t)
  for path in paths
    i = findfirst(rule -> any(r -> occursin(r, path), rule.regexes), m.rules)
    if path == "test/tiers.toml" && manifest_additions !== nothing
      push!(decisions, (path, "quick", isempty(manifest_additions) ? "no tier list changed (comments or order only)" :
                        "adds only test files new in this change ($(join(manifest_additions, ", "))), which run beside the tier"))
      raise("quick")
    elseif i === nothing
      push!(decisions, (path, "full", "no rule matches this path"))
      raise("full")
    else
      rule = m.rules[i]
      push!(decisions, (path, rule.tier, rule.why))
      raise(rule.tier)
      union!(focus, rule.focus)
    end
    mt = match(r"^test/(.+)\.jl$", path)
    mt !== nothing && push!(focus, mt.captures[1])
  end
  # A focus file that has no tier no longer exists (deleted or renamed) or is a helper.
  filter!(name -> haskey(m.tier, name), focus)
  return tier, sort!(collect(focus)), decisions
end

"""
    pr_tier(manifest, paths, labels; manifest_additions = nothing) -> (tier, focus, decisions, notes)

The tier of a pull request that changes `paths` and carries `labels`: [`classify`](@ref),
raised by the labels test:standard or test:full (labels never lower the tier; another
`test:` label is an error). No changed paths give quick. `focus` leaves out the files the tier
runs anyway; `notes` describe the labels.
"""
function pr_tier(m::Manifest, paths, labels; manifest_additions = nothing)
  tier, focus, decisions = classify(m, paths; manifest_additions)
  notes = String[]
  isempty(paths) && (tier = "quick"; push!(notes, "No changed files were found; the minimum is quick."))
  for label in labels
    mt = match(r"^test:(.+)$", label)
    mt === nothing && continue
    t = String(mt.captures[1])
    t in ("standard", "full") ||
      throw(ArgumentError("label `$label` names no tier above quick; use test:standard or test:full"))
    push!(notes, "Label `$label` asks for at least $t.")
    (tier == "none" || rank(t) > rank(tier)) && (tier = t)
  end
  intier = tier == "none" ? Set(focus) : Set(select(m, tier))
  return tier, filter(name -> !(name in intier), focus), decisions, notes
end

"""
    manifest_additions(old_text, new_text, new_files) -> (additions, problems)

Compare two versions of test/tiers.toml, parsed. When the new one only adds test files that
are new in the change (`new_files`: names, as in the tier lists, of test files the change adds),
`additions` are their names (empty when nothing in the tier lists changed) and `problems` is
empty. Otherwise `additions` is `nothing` and `problems` says why: a file removed from the
lists or moved to another tier, an added name that is not a new file of the change, or a
change outside [tiers] (helpers, environments).
"""
function manifest_additions(old_text::AbstractString, new_text::AbstractString, new_files)
  old_data, new_data, old, new = try
    a, b = TOML.parse(old_text), TOML.parse(new_text)
    a, b, parse_manifest(a), parse_manifest(b)
  catch err
    err isa InterruptException && rethrow()
    return nothing, ["the tier lists could not be compared: " * first(sprint(showerror, err), 300)]
  end
  problems = String[]
  for name in sort!(collect(keys(old.tier)))
    t = old.tier[name]
    if !haskey(new.tier, name)
      push!(problems, "`$name` is removed from tier `$t`")
    elseif new.tier[name] != t
      push!(problems, "`$name` moves from `$t` to `$(new.tier[name])`")
    end
  end
  additions = sort!([name for name in keys(new.tier) if !haskey(old.tier, name)])
  for name in additions
    name in new_files ||
      push!(problems, "`$name` is added to tier `$(new.tier[name])`, but test/$name.jl is not a new file of this change")
  end
  outside(d) = filter(kv -> kv.first != "tiers", d)
  outside(old_data) == outside(new_data) || push!(problems, "something outside [tiers] changed (helpers or environments)")
  return isempty(problems) ? (additions, problems) : (nothing, problems)
end

end
