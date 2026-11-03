# The verdict job of the CI workflow ("PR required jobs" on pull requests, "CI required jobs"
# otherwise). It runs after the plan, the test jobs and the benchmark analysis controls, even
# when they failed or were cancelled, and passes only if the plan and the benchmark controls
# passed and, when the plan asked for tests, every test job of the planned tier passed in its
# latest attempt. On a pull request it also reads the PR's current labels: a run whose plan chose
# a lower tier than a test:standard or test:full label now asks for fails, so re-running an
# older run (its plan saw older labels) cannot replace the checks of the labeled run.
#
#   julia scripts/ci_verdict.jl   # with the environment of the workflow step
#
# It fails closed: an API request that fails four times counts as a failure. test/ci_gate.jl
# tests the decisions. No packages are needed.

module CIVerdict

const TIER_ORDER = ("quick", "standard", "full")

"""
    expected_jobs(tier) -> Vector{String}

The test jobs a tier runs, as the CI workflow names them; `none` runs none.
"""
function expected_jobs(tier::AbstractString)
  tier == "none" && return String[]
  tier in TIER_ORDER || throw(ArgumentError("unknown tier `$tier`"))
  jobs = ["Julia 1.10 - ubuntu-latest - x64", "Julia 1 - ubuntu-latest - x64"]
  tier == "full" && append!(jobs, ["Julia 1 - macos-latest - aarch64", "Julia 1 - windows-latest - x64"])
  return ["$j - $tier" for j in jobs]
end

rank(tier) = something(findfirst(==(tier), TIER_ORDER), 0)

"""
    problems(; plan, analysis, tests, run_tests, tier, jobs, labels, event) -> Vector{String}

Why the run must not pass; empty when it passes. `plan`, `analysis` and `tests` are the results
of those jobs (`needs.<job>.result`), `run_tests` and `tier` the plan's outputs, `jobs` the
conclusion of each job of the run in its latest attempt (name => conclusion), `labels` the
PR's current labels (`nothing` for other events) and `event` the run's event: a push (master or
a tag) must run full, and the nightly run full or, after a verified earlier full run, none.
"""
function problems(; plan, analysis, tests, run_tests, tier, jobs, labels = nothing, event = "")
  out = String[]
  event == "push" && tier != "full" && push!(out, "A push must run the full tier, not '$tier'.")
  event == "schedule" && !(tier in ("full", "none")) && push!(out, "The nightly run must run full or none, not '$tier'.")
  plan == "success" || push!(out, "The test plan did not succeed ($plan).")
  analysis == "success" || push!(out, "Benchmark analysis controls: $analysis.")
  if tier == "none"
    run_tests == "false" && tests == "skipped" ||
      push!(out, "Tier none, but run_tests=$run_tests and the test jobs are $tests.")
  elseif tier in TIER_ORDER
    run_tests == "true" || push!(out, "Tier $tier without run_tests ($run_tests).")
    tests in ("cancelled", "skipped") && push!(out, "The test jobs are $tests.")
    for name in expected_jobs(tier)
      c = get(jobs, name, "missing")
      c == "success" || push!(out, "$name: $(isempty(c) ? "not finished" : c).")
    end
  else
    push!(out, "The plan gave no valid tier ('$tier').")
  end
  if labels !== nothing
    for label in labels
      m = match(r"^test:(.+)$", label)
      m === nothing && continue
      t = String(m.captures[1])
      if !(t in ("standard", "full"))
        push!(out, "Label `$label` names no tier above quick; use test:standard or test:full.")
      elseif rank(t) > rank(tier)
        push!(out, "Label `$label` asks for at least $t, but this run's plan chose $(isempty(tier) ? "nothing" : tier): " *
                   "the labels changed after the plan. Use Re-run all jobs, or push.")
      end
    end
  end
  return out
end

# Output of `gh api .../jobs --jq` with JOBS_JQ: one tab-separated line per job.
const JOBS_JQ = """.jobs[] | [.name, (.conclusion // "")] | @tsv"""

function parse_jobs(lines)
  jobs = Dict{String, String}()
  for line in lines
    isempty(strip(line)) && continue
    f = split(line, '\t')
    length(f) == 2 || error("unexpected job line: $(repr(line))")
    jobs[f[1]] = f[2]
  end
  return jobs
end

# `gh api` with retries; `nothing` after four failures.
function gh_retry(args; tries = 4, wait = 15, gh = args -> readlines(`gh api $args`))
  for attempt in 1:tries
    try
      return gh(args)
    catch err
      err isa InterruptException && rethrow()
      println("::warning::gh api $(first(args)) failed (attempt $attempt): ", first(sprint(showerror, err), 200))
      attempt < tries && sleep(wait)
    end
  end
  return nothing
end

function main(env = ENV; gh = args -> readlines(`gh api $args`), wait = 15)
  get(k) = Base.get(env, k, "")
  tier, repo, run_id = get("TIER"), get("GITHUB_REPOSITORY"), get("GITHUB_RUN_ID")
  println("Commit $(get("COMMIT")); plan: $(get("PLAN")); tier: $(isempty(tier) ? "unknown" : tier)",
          isempty(get("FOCUS")) ? "" : " with $(get("FOCUS"))", "; tests: $(get("TESTS")); ",
          "benchmark controls: $(get("ANALYSIS"))")
  out = String[]
  jobs = Dict{String, String}()
  if !isempty(expected_jobs(tier in TIER_ORDER ? tier : "none"))
    lines = gh_retry(["repos/$repo/actions/runs/$run_id/jobs?filter=latest&per_page=100", "--paginate",
                      "--jq", JOBS_JQ]; gh, wait)
    lines === nothing ? push!(out, "Could not list the jobs of run $run_id.") : (jobs = parse_jobs(lines))
  end
  labels = nothing
  if get("GITHUB_EVENT_NAME") == "pull_request"
    labels = gh_retry(["repos/$repo/issues/$(get("PR"))/labels", "--paginate", "--jq", ".[].name"]; gh, wait)
    labels === nothing && (push!(out, "Could not read the labels of PR $(get("PR")).") ; labels = String[])
    println("Current labels: ", isempty(labels) ? "none" : join(labels, ", "))
  end
  append!(out, problems(; plan = get("PLAN"), analysis = get("ANALYSIS"), tests = get("TESTS"),
                        run_tests = get("RUN_TESTS"), tier, jobs, labels, event = get("GITHUB_EVENT_NAME")))
  foreach(p -> println("::error::", p), out)
  isempty(out) && println("Every required job passed.")
  return isempty(out) ? 0 : 1
end

end # module

if abspath(PROGRAM_FILE) == @__FILE__
  exit(CIVerdict.main())
end
