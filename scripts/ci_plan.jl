# Choose the test tier of a CI run from the event, the changed files and the PR labels
# (adapted from ProximalBase.jl).
#
#   julia scripts/ci_plan.jl [--base=REF]     # your working tree against REF (origin/master)
#   julia scripts/ci_plan.jl --labels=test:full   # your working tree, with a label
#   julia scripts/ci_plan.jl --event=pull_request --base=A --head=B --labels=test:full,bug
#   julia scripts/ci_plan.jl --event=workflow_dispatch --tier=standard
#
# The rules are in .github/tier-rules.toml and the tier lists in test/tiers.toml; test/tiers.jl
# applies them. Writes `tier`, `focus`, `run_tests` and `timeout` to $GITHUB_OUTPUT and a
# decision table to $GITHUB_STEP_SUMMARY when those are set, and prints both. Pushes (master
# and release tags) always run full. A scheduled run is full unless a run that passed the full
# tier on the same commit, with the same resolved dependencies, is less than a day old (see
# `recent_full_run`). No packages are needed.

include(joinpath(dirname(@__DIR__), "test", "tiers.jl"))
include(joinpath(@__DIR__, "ci_verdict.jl"))
using .TestTiers

const ROOT = dirname(@__DIR__)

# The test jobs of the full tier, as the CI workflow names them; all must pass.
const FULL_JOBS = CIVerdict.expected_jobs("full")
# The verdict job of runs that are not for a pull request.
const VERDICT = "CI required jobs"

function options(args)
  opts = Dict{String, String}()
  for arg in args
    m = match(r"^--([a-z-]+)=(.*)$", arg)
    m === nothing && error("unknown argument `$arg`; expected --name=value")
    opts[m.captures[1]] = m.captures[2]
  end
  known = ("event", "base", "head", "labels", "tier", "sha", "repo", "environments")
  for k in keys(opts)
    k in known || error("unknown option --$k; the options are $(join(known, ", "))")
  end
  return opts
end

# The commit a change is compared with: `base` itself, or without `head` the merge base of
# `base` and HEAD.
base_commit(base, head) = head === nothing ? readchomp(Cmd(`git merge-base $base HEAD`; dir = ROOT)) : base

# Without `head`, the working tree (and untracked files) against the merge base with `base`,
# as a PR would show it: a local check before a push.
function changed_files(base, head)
  # --no-renames lists both paths of a rename, so a removed path still counts.
  revs = head === nothing ? (base_commit(base, head),) : (base, head)
  out = read(Cmd(`git diff --name-only --no-renames $revs`; dir = ROOT), String)
  head === nothing && (out *= "\n" * read(Cmd(`git ls-files --others --exclude-standard`; dir = ROOT), String))
  return sort!(unique(filter(!isempty, split(out, '\n'))))
end

# Whether a change to test/tiers.toml only adds test files that the change also adds: compares
# the parsed tier lists at `base` with those at `head` (or in the working tree without `head`),
# see TestTiers.manifest_additions.
function tiers_additions(base, head, paths)
  exists(rev, path) = success(Cmd(`git cat-file -e $rev:$path`; dir = ROOT))
  athead(path) = head === nothing ? isfile(joinpath(ROOT, path)) : exists(head, path)
  exists(base, "test/tiers.toml") || return nothing, ["it does not exist at the base $base"]
  new_files = String[]
  for path in paths
    m = match(r"^test/(.+)\.jl$", path)
    m !== nothing && !exists(base, path) && athead(path) && push!(new_files, m.captures[1])
  end
  old = read(Cmd(`git show $base:test/tiers.toml`; dir = ROOT), String)
  new = head === nothing ? read(joinpath(ROOT, "test", "tiers.toml"), String) :
        read(Cmd(`git show $head:test/tiers.toml`; dir = ROOT), String)
  return TestTiers.manifest_additions(old, new, new_files)
end

# The GitHub CLI: its output lines, or an error if it fails.
gh_lines(args) = readlines(`gh $args`)

function tsv(line, n, what)
  f = split(line, '\t')
  length(f) == n || error("unexpected line from $what: $(repr(line))")
  return f
end

"""
    recent_full_run(repo, sha, environments; gh = gh_lines, at = time()) -> (id or nothing, reasons)

A run of this workflow on `sha` that makes a scheduled full run redundant: not for a pull
request, created in the 24 hours before `at` (Unix time), concluded `success`; in its latest
attempt `CI required jobs` and every test job of the full tier (`FULL_JOBS`) succeeded; and it
recorded the resolved test environments `environments` (artifact names
`environment-<julia>-<digest>` written by scripts/ci_environment.jl), so the same Julia
versions and package versions were tested. `reasons` says why each candidate was rejected.
`gh` runs the GitHub CLI and returns its output lines (tests pass a fake). Malformed output
throws, so the caller runs the full tier rather than skip it.
"""
function recent_full_run(repo, sha, environments; gh = gh_lines, at = time())
  isempty(environments) && return nothing, ["the resolved test environments of this run are unknown"]
  reasons = String[]
  runs = gh(["run", "list", "--repo", repo, "--workflow", "CI.yml", "--commit", sha, "--status", "success",
             "--limit", "50", "--json", "databaseId,event,createdAt,conclusion,headSha",
             "--jq", ".[] | [.databaseId, .event, (.createdAt | fromdateiso8601), .conclusion, .headSha] | @tsv"])
  for line in runs
    id, event, created, conclusion, head = tsv(line, 5, "gh run list")
    event != "pull_request" && conclusion == "success" && head == sha || continue
    at - 24 * 3600 <= parse(Float64, created) <= at || continue
    jobs = Dict{String, String}()
    for l in gh(["api", "repos/$repo/actions/runs/$id/jobs?filter=latest&per_page=100", "--paginate",
                 "--jq", ".jobs[] | [.name, (.conclusion // \"\")] | @tsv"])
      name, c = tsv(l, 2, "the jobs of run $id")
      jobs[name] = c
    end
    failed = [name for name in [VERDICT; FULL_JOBS] if get(jobs, name, "missing") != "success"]
    if !isempty(failed)
      push!(reasons, "run $id: " * join(("$name: $(get(jobs, name, "missing"))" for name in failed), ", "))
      continue
    end
    artifacts = Set(gh(["api", "repos/$repo/actions/runs/$id/artifacts?per_page=100", "--paginate",
                        "--jq", ".artifacts[] | select(.expired | not) | .name"]))
    missing = setdiff(environments, artifacts)
    if !isempty(missing)
      push!(reasons, "run $id tested other dependencies (it has no $(join(missing, ", ")))")
      continue
    end
    return String(id), reasons
  end
  return nothing, reasons
end

# `gh` and `at` (Unix time) are passed on to recent_full_run (tests pass a fake GitHub CLI).
function plan(opts; gh = gh_lines, at = time())
  manifest = TestTiers.load(joinpath(ROOT, "test", "tiers.toml"), joinpath(ROOT, ".github", "tier-rules.toml"))
  # The runner checks this too, but here an unclassified test file fails within seconds.
  TestTiers.check(manifest, TestTiers.discover(joinpath(ROOT, "test")))
  event = get(opts, "event", "pull_request")
  lines = String[]
  focus = String[]
  if event == "pull_request"
    base, head = get(opts, "base", "origin/master"), get(opts, "head", nothing)
    paths = changed_files(base, head)
    labels = unique(filter(!isempty, String.(strip.(split(get(opts, "labels", ""), ',')))))
    additions, problems = nothing, String[]
    "test/tiers.toml" in paths && ((additions, problems) = tiers_additions(base_commit(base, head), head, paths))
    tier, focus, decisions, notes = TestTiers.pr_tier(manifest, paths, labels; manifest_additions = additions)
    push!(lines, "Changed files ($(length(paths))), the rule that decides each, and its tier:", "",
          "| Path | Tier | Why |", "|---|---|---|")
    for (path, t, why) in decisions
      push!(lines, "| `$path` | $t | $why |")
    end
    isempty(problems) || push!(lines, "", "`test/tiers.toml` does more than add new test files, so it needs full: " *
                                       join(problems, "; ") * ".")
    isempty(notes) || push!(lines, "", notes...)
  elseif event == "workflow_dispatch"
    tier = get(opts, "tier", "full")
    TestTiers.rank(tier) > 0 || error("unknown tier `$tier`")
    push!(lines, "Manual run of tier $tier.")
  elseif event == "schedule"
    tier = "full"
    push!(lines, "Scheduled run of the full tier.")
    if haskey(opts, "sha") && haskey(opts, "repo")
      environments = filter(!isempty, split(get(opts, "environments", ""), ','))
      # A failed or malformed answer from the API runs the full tier; it never skips it.
      id, reasons = try
        recent_full_run(opts["repo"], opts["sha"], environments; gh, at)
      catch err
        err isa InterruptException && rethrow()
        nothing, ["could not check for an earlier full run on this commit: " * first(sprint(showerror, err), 300)]
      end
      if id === nothing
        isempty(reasons) || push!(lines, "", "Not skipped: " * join(reasons, "; ") * ".")
      else
        tier = "none"
        push!(lines, "", "Run $id passed the full tier on this commit in the last 24 hours, with the same " *
                         "Julia and package versions ($(join(environments, ", "))); nothing to repeat.")
      end
    end
  elseif event == "push"
    tier = "full"
    push!(lines, "A push (to master or a release tag) runs the full tier.")
  else
    error("unknown event `$event`")
  end
  # Changed files the tier already runs need no separate mention.
  if tier != "none"
    intier = Set(TestTiers.select(manifest, tier))
    filter!(name -> !(name in intier), focus)
  else
    empty!(focus)
  end
  run_tests = tier != "none"
  timeout = run_tests ? manifest.timeouts[tier] : 0
  summary = run_tests ? "Tests: tier **$tier**" * (isempty(focus) ? "" : " and the focus files $(join(focus, ", "))") :
            "Tests: **none needed**"
  pushfirst!(lines, summary, "")
  return (; tier, focus = join(focus, ","), run_tests, timeout), lines
end

function main(args)
  result, lines = plan(options(args))
  text = join(lines, '\n')
  println(text)
  println()
  for (k, v) in pairs(result)
    println("$k=$v")
  end
  if haskey(ENV, "GITHUB_OUTPUT")
    open(ENV["GITHUB_OUTPUT"], "a") do io
      for (k, v) in pairs(result)
        println(io, "$k=$v")
      end
    end
  end
  if haskey(ENV, "GITHUB_STEP_SUMMARY")
    open(io -> println(io, "## Test plan\n\n", text), ENV["GITHUB_STEP_SUMMARY"], "a")
  end
end

if abspath(PROGRAM_FILE) == @__FILE__
  main(ARGS)
end
