# The gate job of the CI workflow ("PR merge gate" on pull requests, "CI result" otherwise),
# copied from ProximalBase.jl, whose test/TESTING.md records how GitHub lists re-run jobs.
# It has no `needs`, so GitHub creates its check when the run starts: a new run on a commit (a
# push, or a label added to an unchanged commit) at once shows a pending gate instead of the
# green gate of an earlier run. The job then waits for this run's verdict job ("PR required
# jobs" on pull requests, "CI required jobs" otherwise), which starts after the plan, the tests
# and the benchmark controls and checks every job the plan required, and passes only when that
# job passed. Branch protection requires both checks: re-running a single test job re-runs the
# verdict job but not the gate.
#
#   julia scripts/ci_gate.jl --repo=OWNER/NAME --run-id=ID --attempt=N --sha=SHA \
#     --event=pull_request --gate="PR merge gate" --verdict="PR required jobs"
#
# It reads only this run (actions/runs/ID) through `gh api` and needs `actions: read`. It
# fails closed: a failed, cancelled, skipped or missing verdict, a run for another commit or
# event, API errors for more than 15 minutes, or no decision before the deadline. test/ci_gate.jl
# tests the decisions. No packages are needed.

module CIGate

struct Job
  name::String
  status::String     # queued, in_progress, completed, waiting, requested or pending
  conclusion::String # "" until completed
  attempt::Int       # run attempt of the job's latest execution
end

# Output of `gh api .../jobs --jq` with JOBS_JQ: one tab-separated line per job.
const JOBS_JQ = """.jobs[] | [.name, .status, (.conclusion // ""), (.run_attempt | tostring)] | @tsv"""

function parse_jobs(text::AbstractString)
  jobs = Job[]
  for line in split(text, '\n')
    isempty(strip(line)) && continue
    f = split(line, '\t')
    length(f) == 4 || error("unexpected job line: $(repr(line))")
    push!(jobs, Job(f[1], f[2], f[3], parse(Int, f[4])))
  end
  return jobs
end

# Every job except the verdict and the gate has finished, and there is no verdict job yet.
function settled(jobs; verdict, gate)
  others = filter(j -> j.name != verdict && j.name != gate, jobs)
  return !isempty(others) && all(j -> j.status == "completed", others) &&
         !any(j -> j.name == verdict, jobs)
end

"""
    decide(jobs; attempt, verdict, gate, elapsed, settled_for, grace = 90) -> (action, message)

`action` is `:wait`, `:pass` or `:fail`. `jobs` are the latest executions of this run's jobs
(`filter=latest`), `attempt` is the gate's own run attempt, `elapsed` the seconds since the
gate started and `settled_for` the seconds for which [`settled`](@ref) has held.

The gate passes only on a verdict of its own attempt that concluded `success`, or, when an
attempt re-runs the gate and nothing else (the gate itself had failed), on the verdict of an
earlier attempt that concluded `success`. A re-run of failed jobs creates the new verdict only
after the jobs it needs finish, so while any other job belongs to this attempt the gate waits
for the new verdict; jobs of a new attempt appear within seconds, so `grace` seconds pass
before the gate decides that nothing else is re-run.

On GitHub (observed in November 2026), a new attempt lists the jobs it does not re-run under
the new attempt number with their earlier results, and leaves out the jobs it re-runs until
GitHub creates them: after "Re-run failed jobs" the failed verdict is absent until the re-run
test jobs finish, and after a re-run of the gate alone the passed verdict is listed under the
gate's attempt. The branch for a verdict of an earlier attempt covers an API that lists it.
"""
function decide(jobs::AbstractVector{Job}; attempt::Integer, verdict::AbstractString,
                gate::AbstractString, elapsed::Real, settled_for::Real, grace::Real = 90)
  vs = filter(j -> j.name == verdict, jobs)
  length(vs) > 1 && return (:fail, "$(length(vs)) jobs are named `$verdict`")
  others = filter(j -> j.name != verdict && j.name != gate, jobs)
  if isempty(vs)
    done = count(j -> j.status == "completed", others)
    if settled(jobs; verdict, gate)
      settled_for >= grace &&
        return (:fail, "every job finished $(round(Int, settled_for)) s ago, but this run has no job `$verdict`")
      return (:wait, "every job finished; waiting for `$verdict` to start")
    end
    return (:wait, "waiting for the required jobs ($done of $(length(others)) finished)")
  end
  v = only(vs)
  conclusion = isempty(v.conclusion) ? "no conclusion" : v.conclusion
  if v.attempt > attempt
    return (:fail, "`$verdict` belongs to attempt $(v.attempt), after this gate's attempt $attempt")
  elseif v.attempt == attempt
    v.status == "completed" || return (:wait, "`$verdict` is $(v.status)")
    v.conclusion == "success" && return (:pass, "`$verdict` passed (attempt $attempt)")
    return (:fail, "`$verdict` concluded $conclusion (attempt $attempt)")
  end
  # The verdict is from an earlier attempt: this attempt re-runs the gate.
  any(j -> j.attempt == attempt, others) &&
    return (:wait, "attempt $attempt re-runs other jobs; waiting for its `$verdict`")
  elapsed < grace &&
    return (:wait, "attempt $attempt: waiting for re-run jobs to appear")
  v.status == "completed" && v.conclusion == "success" &&
    return (:pass, "attempt $attempt re-runs only the gate; `$verdict` passed in attempt $(v.attempt)")
  return (:fail, "attempt $attempt re-runs only the gate, and `$verdict` of attempt $(v.attempt) " *
                 "concluded $conclusion; use \"Re-run failed jobs\"")
end

# What the run itself says; the gate must belong to the run of this commit and event.
function identity_problems(run_sha, run_event, sha, event)
  problems = String[]
  run_sha == sha || push!(problems, "the run is for commit $run_sha, not $sha")
  run_event == event || push!(problems, "the run is a $run_event run, not $event")
  return problems
end

"""
    watch(fetch; attempt, verdict, gate, deadline, ...) -> (action, message)

Polls `fetch()` (the jobs of this run, or an exception when the API fails) until
[`decide`](@ref) passes or fails, `deadline` seconds pass, or the API has failed for
`api_budget` seconds in a row. It never passes on an API error. `now` and `sleep` are
injectable for tests.
"""
function watch(fetch; attempt, verdict, gate, deadline, grace = 90, api_budget = 900,
               interval = 20, fast_interval = 5, now = time, sleep = Base.sleep, log = println)
  start = now()
  settled_since = nothing
  failing_since = nothing
  last = "no response from the API yet"
  while true
    t = now()
    jobs = try
      fetch()
    catch err
      err isa InterruptException && rethrow()
      failing_since === nothing && (failing_since = t)
      last = "API error: " * first(sprint(showerror, err), 300)
      log(last)
      t - failing_since >= api_budget &&
        return (:fail, "the API failed for $(round(Int, t - failing_since)) s; last: $last")
      t - start >= deadline && return (:fail, "no decision after $(round(Int, t - start)) s; $last")
      sleep(interval)
      continue
    end
    failing_since = nothing
    if settled(jobs; verdict, gate)
      settled_since === nothing && (settled_since = t)
    else
      settled_since = nothing
    end
    action, message = decide(jobs; attempt, verdict, gate, elapsed = t - start,
                             settled_for = settled_since === nothing ? 0 : t - settled_since, grace)
    message == last || log(message)
    last = message
    action == :wait || return (action, message)
    t - start >= deadline && return (:fail, "no decision after $(round(Int, t - start)) s; $message")
    # Poll fast once the verdict exists or every other job finished, so the gate ends within
    # seconds of the verdict.
    soon = any(j -> j.name == verdict, jobs) || settled_since !== nothing || t - start < grace
    sleep(soon ? fast_interval : interval)
  end
end

# `gh api` with a time limit: a hung request counts as an API error.
function gh(args::Vector{String}; timeout = 60)
  out, err = IOBuffer(), IOBuffer()
  p = run(pipeline(`gh api $args`; stdout = out, stderr = err); wait = false)
  if timedwait(() -> process_exited(p), timeout) === :timed_out
    kill(p)
    error("gh api timed out after $timeout s")
  end
  success(p) || error("gh api failed: ", strip(String(take!(err))))
  return String(take!(out))
end

function options(args)
  opts = Dict{String, String}()
  for arg in args
    m = match(r"^--([a-z-]+)=(.*)$", arg)
    m === nothing && error("unknown argument `$arg`; expected --name=value")
    opts[m.captures[1]] = m.captures[2]
  end
  required = ("repo", "run-id", "attempt", "sha", "event", "gate", "verdict")
  known = (required..., "deadline")
  for k in keys(opts)
    k in known || error("unknown option --$k; the options are $(join(known, ", "))")
  end
  for k in required
    isempty(get(opts, k, "")) && error("--$k is required")
  end
  return opts
end

function main(args)
  opts = options(args)
  repo, run_id, sha, event, gate = opts["repo"], opts["run-id"], opts["sha"], opts["event"], opts["gate"]
  attempt = parse(Int, opts["attempt"])
  verdict = opts["verdict"]
  deadline = parse(Int, get(opts, "deadline", string(170 * 60)))
  println("Gate `$gate` of run $run_id, attempt $attempt, $event at $sha: waiting for `$verdict`.")

  # The run must be this commit's run for this event; retried like the job list.
  info = nothing
  for i in 1:10
    info = try
      split(gh(["repos/$repo/actions/runs/$run_id", "--jq", "[.head_sha, .event] | @tsv"]) |> strip, '\t')
    catch err
      println("API error: ", first(sprint(showerror, err), 300))
      nothing
    end
    info === nothing || break
    sleep(15)
  end
  info === nothing && (println("::error::The API did not describe run $run_id."); return 1)
  problems = identity_problems(info[1], info[2], sha, event)
  if !isempty(problems)
    foreach(p -> println("::error::", p), problems)
    return 1
  end

  fetch() = parse_jobs(gh(["repos/$repo/actions/runs/$run_id/jobs?filter=latest&per_page=100",
                           "--paginate", "--jq", JOBS_JQ]))
  action, message = watch(fetch; attempt, verdict, gate, deadline)
  if action == :pass
    println("Passed: ", message)
    return 0
  end
  println("::error::", message)
  return 1
end

end # module

if abspath(PROGRAM_FILE) == @__FILE__
  exit(CIGate.main(ARGS))
end
