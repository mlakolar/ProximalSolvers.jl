module CIGateTests

# The decisions of the CI merge gate (scripts/ci_gate.jl, copied from ProximalBase.jl) and of the
# verdict job (scripts/ci_verdict.jl) on job states as the GitHub API reports them: neither may
# pass on a stale, missing, failed, cancelled or skipped job, on API errors, or, for a pull
# request, on a plan that chose less than the PR's current test: labels ask for.

using Test

include(joinpath(dirname(@__DIR__), "scripts", "ci_gate.jl"))
include(joinpath(dirname(@__DIR__), "scripts", "ci_verdict.jl"))
using .CIGate: Job, decide, watch, settled, parse_jobs, identity_problems

const V = "PR required jobs"
const G = "PR merge gate"

job(name, status = "completed", conclusion = status == "completed" ? "success" : ""; attempt = 1) =
  Job(name, status, conclusion, attempt)
gate(; attempt = 1) = job(G, "in_progress"; attempt)
plan(args...; kw...) = job("Test plan", args...; kw...)
analysis(args...; kw...) = job("Benchmark analysis controls", args...; kw...)
aux(args...; kw...) = job("Synthetic auxiliary job", args...; kw...)
jl1(args...; kw...) = job("Julia 1 - ubuntu-latest - x64 - quick", args...; kw...)
verdict(args...; kw...) = job(V, args...; kw...)

d(jobs; attempt = 1, elapsed = 600, settled_for = 0) =
  decide(jobs; attempt, verdict = V, gate = G, elapsed, settled_for)
action(jobs; kw...) = d(jobs; kw...)[1]

@testset "gate: pending until the verdict passes" begin
  # only the gate has appeared, then the plan runs, then the tests
  @test action([gate()]; elapsed = 5) == :wait
  @test action([gate(), plan("in_progress"), analysis("queued")]) == :wait
  @test action([gate(), plan(), analysis(), aux("in_progress"), jl1("queued")]) == :wait
  # a failed test job alone does not decide: the verdict reads every job
  @test action([gate(), plan(), analysis(), aux("completed", "failure"), jl1("in_progress")]) == :wait
  @test action([gate(), plan(), analysis(), aux(), jl1(), verdict("queued")]) == :wait
  @test action([gate(), plan(), analysis(), aux(), jl1(), verdict("in_progress")]) == :wait
  @test d([gate(), plan(), analysis(), aux(), jl1(), verdict()]) == (:pass, "`PR required jobs` passed (attempt 1)")
end

@testset "gate: a verdict that is not success fails" begin
  for c in ("failure", "cancelled", "skipped", "timed_out", "action_required", "neutral", "stale", "")
    @test action([gate(), plan(), analysis(), aux(), jl1(), verdict("completed", c)]) == :fail
  end
  # documentation only: no test jobs, the verdict decides
  @test action([gate(), plan(), analysis(), verdict()]) == :pass
  @test action([gate(), plan("completed", "failure"), analysis(), verdict("completed", "failure")]) == :fail
  # the gate's own job never counts as the verdict
  @test action([job(G, "completed", "success"), plan(), analysis()]; settled_for = 1000) == :fail
end

@testset "gate: a missing verdict fails after the grace period" begin
  jobs = [gate(), plan(), analysis(), aux(), jl1()]
  @test settled(jobs; verdict = V, gate = G)
  @test !settled([gate(), plan(), analysis(), aux(), jl1("in_progress")]; verdict = V, gate = G)
  @test !settled([gate()]; verdict = V, gate = G)
  @test !settled([jobs; verdict("queued")]; verdict = V, gate = G)
  @test action(jobs; settled_for = 30) == :wait
  @test action(jobs; settled_for = 90) == :fail
  # the plan failed and the test jobs were never created
  @test action([gate(), plan("completed", "failure"), analysis()]; settled_for = 120) == :fail
  # two verdicts cannot be told apart
  @test action([gate(), verdict(), verdict()]) == :fail
  # the verdict of another event's run has another name and never counts
  @test action([jobs; job("CI required jobs")]; settled_for = 90) == :fail
end

@testset "gate: re-runs count only the gate's own attempt or a verdict nothing re-runs" begin
  # "Re-run failed jobs" after a failed Julia 1 job: the new test job and gate are attempt 2,
  # the passing auxiliary job stays at attempt 1, and the failed verdict waits for the test job.
  stale = [plan(), analysis(), aux(), verdict("completed", "failure")]
  @test action([stale; jl1("queued"; attempt = 2); gate(attempt = 2)]; attempt = 2, elapsed = 5) == :wait
  @test action([stale; jl1("queued"; attempt = 2); gate(attempt = 2)]; attempt = 2, elapsed = 3000) == :wait
  @test action([plan(), analysis(), aux(), jl1(attempt = 2), verdict("queued"; attempt = 2), gate(attempt = 2)];
               attempt = 2) == :wait
  @test action([plan(), analysis(), aux(), jl1(attempt = 2), verdict(attempt = 2), gate(attempt = 2)];
               attempt = 2) == :pass
  @test action([plan(), analysis(), aux(), jl1("completed", "failure"; attempt = 2),
                verdict("completed", "failure"; attempt = 2), gate(attempt = 2)]; attempt = 2) == :fail
  # "Re-run all jobs" after a passing run: the old success must not pass the new attempt
  rerun_all = [plan("in_progress"; attempt = 2), analysis("queued"; attempt = 2), aux(), jl1(),
               verdict(), gate(attempt = 2)]
  @test action(rerun_all; attempt = 2, elapsed = 5) == :wait
  @test action(rerun_all; attempt = 2, elapsed = 3000) == :wait
  # only the gate re-runs (it had failed on its own): the earlier verdict decides after the grace
  only_gate = [plan(), analysis(), aux(), jl1(), verdict(), gate(attempt = 2)]
  @test action(only_gate; attempt = 2, elapsed = 10) == :wait
  @test action(only_gate; attempt = 2, elapsed = 90) == :pass
  failed = [plan(), analysis(), aux(), jl1("completed", "failure"), verdict("completed", "failure"), gate(attempt = 2)]
  @test action(failed; attempt = 2, elapsed = 90) == :fail
  # as GitHub lists them (ProximalBase #445): a new attempt shows the jobs it keeps under its own
  # number and leaves out the jobs it re-runs until they are created
  @test action([plan(attempt = 2), analysis(attempt = 2), aux(attempt = 2), jl1("in_progress"; attempt = 2),
                gate(attempt = 2)]; attempt = 2, elapsed = 5) == :wait
  @test action([plan(attempt = 2), analysis(attempt = 2), aux(attempt = 2), jl1(attempt = 2),
                gate(attempt = 2)]; attempt = 2, settled_for = 30) == :wait
  @test action([plan(attempt = 3), analysis(attempt = 3), aux(attempt = 3), jl1(attempt = 3),
                verdict(attempt = 3), gate(attempt = 3)]; attempt = 3, elapsed = 2) == :pass
  @test action([plan("in_progress"; attempt = 4), analysis(attempt = 4), gate(attempt = 4)];
               attempt = 4, elapsed = 5) == :wait
  # a verdict newer than the gate's attempt
  @test action([gate(), verdict(attempt = 3)]; attempt = 2) == :fail
end

@testset "gate: the run must be this commit's run" begin
  @test isempty(identity_problems("abc", "pull_request", "abc", "pull_request"))
  @test length(identity_problems("abc", "push", "abd", "pull_request")) == 2
  args = ["--repo=o/n", "--run-id=1", "--attempt=1", "--sha=abc", "--event=pull_request", "--gate=$G", "--verdict=$V"]
  @test CIGate.options(args)["verdict"] == V
  @test_throws ErrorException CIGate.options(args[1:(end - 1)]) # the verdict's name is required
end

@testset "gate: job list from the API" begin
  text = "Test plan\tcompleted\tsuccess\t1\nJulia 1 - ubuntu-latest - x64 - quick\tin_progress\t\t2\n\n"
  @test parse_jobs(text) == [Job("Test plan", "completed", "success", 1),
                             Job("Julia 1 - ubuntu-latest - x64 - quick", "in_progress", "", 2)]
  @test isempty(parse_jobs(""))
  @test_throws ErrorException parse_jobs("Test plan\tcompleted\n")
end

# A fake clock: sleep advances it, and fetch returns the states in turn (an exception
# stands for an API error).
function simulate(states; attempt = 1, deadline = 10_000, api_budget = 900)
  clock = Ref(0.0)
  i = Ref(0)
  fetch() = (i[] = min(i[] + 1, length(states)); s = states[i[]]; s isa Exception ? throw(s) : s)
  result = watch(fetch; attempt, verdict = V, gate = G, deadline, api_budget,
                 now = () -> clock[], sleep = s -> (clock[] += s), log = _ -> nothing)
  return result, clock[]
end

@testset "gate: polling" begin
  running = [gate(), plan(), analysis(), aux("in_progress"), jl1("in_progress")]
  passed = [gate(), plan(), analysis(), aux(), jl1(), verdict()]
  (r, m), t = simulate([running, running, passed])
  @test r == :pass
  # API errors in between are retried and never pass on their own
  (r, m), t = simulate([ErrorException("HTTP 502"), running, ErrorException("timeout"), passed])
  @test r == :pass
  (r, m), t = simulate([running, ErrorException("HTTP 502")]; api_budget = 300)
  @test r == :fail && occursin("API failed", m) && t >= 300
  # a failed verdict fails at once
  (r, m), t = simulate([running, [gate(), plan(), analysis(), aux(), jl1("completed", "failure"),
                                  verdict("completed", "failure")]])
  @test r == :fail && occursin("failure", m)
  # a run that never decides fails at the deadline
  (r, m), t = simulate([running]; deadline = 3600)
  @test r == :fail && occursin("no decision", m) && 3600 <= t < 3700
  # every job finished but no verdict appears: fails after the grace period, not at the deadline
  (r, m), t = simulate([[gate(), plan(), analysis(), aux(), jl1()]])
  @test r == :fail && occursin("no job `PR required jobs`", m) && t < 200
  # the fast interval keeps the gate within seconds of the verdict
  states = [fill(running, 30); [[gate(), plan(), analysis(), aux(), jl1(), verdict("queued")]]; [passed]]
  (r, m), t = simulate(states)
  @test r == :pass
end

const CV = CIVerdict
const QUICK = Dict(name => "success" for name in CV.expected_jobs("quick"))
const FULL = Dict(name => "success" for name in CV.expected_jobs("full"))
ok(; plan = "success", analysis = "success", tests = "success", run_tests = "true", tier = "quick", jobs = QUICK,
   labels = nothing, event = "pull_request") = CV.problems(; plan, analysis, tests, run_tests, tier, jobs, labels, event)

@testset "verdict: the jobs a tier needs" begin
  @test CV.expected_jobs("none") == String[]
  @test CV.expected_jobs("quick") == ["Julia 1 - ubuntu-latest - x64 - quick"]
  @test CV.expected_jobs("standard") == ["Julia 1 - ubuntu-latest - x64 - standard"]
  @test CV.expected_jobs("full") == ["Julia 1 - ubuntu-latest - x64 - full"]
  @test_throws ArgumentError CV.expected_jobs("thorough")
  # the job names the workflow gives: "Julia <version> - <os> - <arch> - <tier>"
  workflow = replace(read(joinpath(dirname(@__DIR__), ".github", "workflows", "CI.yml"), String), "\r\n" => "\n")
  @test occursin("name: Julia \${{ matrix.version }} - \${{ matrix.os }} - \${{ matrix.arch }} - \${{ needs.plan.outputs.tier }}", workflow)
  # All events and tiers use the same one-element matrix; no conditional expansion.
  matrix = split(split(workflow, "\n      matrix:\n"; limit = 2)[2], "\n    steps:\n"; limit = 2)[1]
  @test occursin("version:\n          - '1'", matrix)
  @test occursin("os:\n          - ubuntu-latest", matrix)
  @test occursin("arch:\n          - x64", matrix)
  @test occursin("ptr_jobs:\n          - '4'", matrix)
  @test count(r"(?m)^          - ", matrix) == 4 # exactly one value for each axis
  @test !occursin("\${{", matrix) # no event- or tier-dependent matrix expansion
  @test !occursin("include:", matrix) && !occursin("exclude:", matrix)
  @test !occursin("macos-latest", workflow) && !occursin("windows-latest", workflow)
  @test !occursin("version: '1.10'", workflow) && !occursin("env110", workflow)
end

@testset "workflow: properties the checks rely on" begin
  # LF text: a Windows checkout has CRLF line endings
  workflow = replace(read(joinpath(dirname(@__DIR__), ".github", "workflows", "CI.yml"), String), "\r\n" => "\n")
  # a new base branch starts a new run, so checks computed against another base never count
  @test occursin("types: [opened, synchronize, reopened, edited, labeled, unlabeled]", workflow)
  @test !occursin("paths-ignore", workflow) && !occursin("pull_request_target", workflow)
  # no checkout leaves the token in .git/config for PR code
  @test count("uses: actions/checkout@", workflow) == count("persist-credentials: false", workflow)
  # the environment is recorded before the dependencies the tests use are resolved
  @test findfirst("name: Record the resolved test environment", workflow).start <
        findfirst("name: Resolve registered dependencies", workflow).start
  # the job that runs the PR's code has a read-only token, and the cache action deletes nothing
  test = workflow[findfirst("\n  test:\n", workflow).start:findfirst("\n  analysis:\n", workflow).start]
  @test !occursin(r"\n\s+[a-z-]+: write", test) && occursin("\n      actions: read", test)
  @test occursin("uses: julia-actions/cache@v3\n        with:\n          delete-old-caches: false", test)
    # the record is uploaded only after passing tests
  @test occursin("if: steps.environment.outcome == 'success' && steps.tests.outcome == 'success'", workflow)
  # the gate has no `needs`, and the verdict always runs
  gate = workflow[findfirst("\n  gate:\n", workflow).start:findfirst("\n  report:\n", workflow).start]
  @test !occursin("needs:", gate) && occursin("--deadline=9600", gate)
  verdict = workflow[findfirst("\n  verdict:\n", workflow).start:findfirst("\n  gate:\n", workflow).start]
  @test occursin("if: always()", verdict) && occursin("needs: [plan, test, analysis]", verdict)
end

@testset "verdict: every planned job must pass" begin
  @test isempty(ok())
  @test isempty(ok(tier = "full", jobs = FULL))
  @test isempty(ok(tier = "none", run_tests = "false", tests = "skipped", jobs = Dict{String, String}()))
  # the plan or the benchmark controls failed
  @test !isempty(ok(plan = "failure")) && !isempty(ok(plan = "cancelled"))
  @test !isempty(ok(analysis = "failure")) && !isempty(ok(analysis = "skipped"))
  # a failed, cancelled, skipped, unfinished or missing test job
  for c in ("failure", "cancelled", "skipped", "timed_out", "")
    @test !isempty(ok(jobs = merge(QUICK, Dict("Julia 1 - ubuntu-latest - x64 - quick" => c))))
  end
  @test only(ok(jobs = Dict{String, String}())) ==
        "Julia 1 - ubuntu-latest - x64 - quick: missing."
  @test length(ok(tier = "full", jobs = QUICK)) == 1 # the jobs of another tier do not count
  @test !isempty(ok(tier = "full", jobs = Dict{String, String}()))
  for c in ("failure", "cancelled", "skipped", "timed_out", "")
    @test !isempty(ok(tier = "full", jobs = Dict("Julia 1 - ubuntu-latest - x64 - full" => c)))
  end
  # Older workflows and their re-runs keep their old job set: unexpected full jobs
  # cannot hide a failed platform behind the now-required Linux success.
  @test !isempty(ok(tier = "full", jobs = merge(FULL, Dict("Julia 1 - macos-latest - aarch64 - full" => "failure"))))
  # the test jobs as a whole were cancelled or skipped, even if the listing shows successes
  @test !isempty(ok(tests = "cancelled")) && !isempty(ok(tests = "skipped"))
  # the plan's outputs disagree or are missing
  @test !isempty(ok(run_tests = "false"))
  @test !isempty(ok(tier = "none", run_tests = "true", tests = "skipped"))
  @test !isempty(ok(tier = "none", run_tests = "false", tests = "success"))
  @test !isempty(ok(tier = "", run_tests = "", plan = "failure"))
  @test !isempty(ok(tier = "thorough"))
  # a test job of the tier that the expected list does not name must pass as well
  extra = "Julia 1.11 - ubuntu-latest - x64 - quick"
  @test occursin("not an expected job", only(ok(jobs = merge(QUICK, Dict(extra => "failure")))))
  @test isempty(ok(jobs = merge(QUICK, Dict(extra => "success"))))
  # leftovers of another tier from an earlier attempt do not count
  @test isempty(ok(jobs = merge(QUICK, Dict("Julia 1 - windows-latest - x64 - full" => "failure"))))
end

@testset "verdict: the tier each event must run" begin
  none = (; tier = "none", run_tests = "false", tests = "skipped", jobs = Dict{String, String}())
  # pushes to master and tags: full only
  @test isempty(ok(event = "push", tier = "full", jobs = FULL))
  @test only(ok(event = "push")) == "A push must run the full tier, not 'quick'."
  @test !isempty(ok(; event = "push", none...))
  # the nightly run: full, or none after a verified earlier full run
  @test isempty(ok(event = "schedule", tier = "full", jobs = FULL)) && isempty(ok(; event = "schedule", none...))
  @test !isempty(ok(event = "schedule")) && !isempty(ok(event = "schedule", tier = "standard"))
  # manual runs and pull requests: the plan's tier
  @test isempty(ok(event = "workflow_dispatch")) && isempty(ok(; event = "pull_request", none...))
end

@testset "verdict: the PR's current labels" begin
  @test isempty(ok(labels = String[]))
  @test isempty(ok(labels = ["bug", "documentation"]))
  standard = Dict(name => "success" for name in CV.expected_jobs("standard"))
  @test isempty(ok(tier = "standard", jobs = standard, labels = ["test:standard"]))
  @test isempty(ok(tier = "full", jobs = FULL, labels = ["test:standard", "test:full"]))
  # a label added after the plan (an older run re-run after the label): fails
  @test occursin("asks for at least full", only(ok(labels = ["test:full"])))
  @test occursin("asks for at least standard", only(ok(labels = ["test:standard"])))
  @test length(ok(tier = "none", run_tests = "false", tests = "skipped", jobs = Dict{String, String}(),
                  labels = ["test:standard"])) == 1
  # a label that names no tier above quick
  @test !isempty(ok(labels = ["test:quick"])) && !isempty(ok(labels = ["test:thorough"]))
end

# A fake `gh api`: the job lines and the label lines; `fail` names the calls that throw.
function fakeapi(jobs, labels; fail = String[], calls = Vector{String}[])
  return function (args)
    push!(calls, String.(args))
    kind = occursin("/labels", args[1]) ? "labels" : "jobs"
    kind in fail && error("gh: HTTP 502")
    return kind == "jobs" ? ["$k\t$v" for (k, v) in jobs] : labels
  end
end

@testset "verdict: the step" begin
  env(; kw...) = Dict("PLAN" => "success", "ANALYSIS" => "success", "TESTS" => "success", "RUN_TESTS" => "true",
                      "TIER" => "quick", "GITHUB_REPOSITORY" => "o/n", "GITHUB_RUN_ID" => "7",
                      "GITHUB_EVENT_NAME" => "pull_request", "PR" => "12", (string(k) => v for (k, v) in kw)...)
  quietly(f) = redirect_stdout(f, devnull)
  main(e, gh) = quietly(() -> CV.main(e; gh, wait = 0))
  calls = Vector{String}[]
  @test main(env(), fakeapi(QUICK, String[]; calls)) == 0
  @test any(c -> c[1] == "repos/o/n/actions/runs/7/jobs?filter=latest&per_page=100", calls)
  @test any(c -> c[1] == "repos/o/n/issues/12/labels", calls)
  @test main(env(), fakeapi(QUICK, ["test:full"])) == 1
  @test main(env(TIER = "full"), fakeapi(QUICK, String[])) == 1
  # an API that keeps failing fails the verdict
  @test main(env(), fakeapi(QUICK, String[]; fail = ["jobs"])) == 1
  @test main(env(), fakeapi(QUICK, String[]; fail = ["labels"])) == 1
  # other events read no labels; tier none lists no jobs
  calls = Vector{String}[]
  @test main(env(GITHUB_EVENT_NAME = "schedule", TIER = "none", RUN_TESTS = "false", TESTS = "skipped"),
             fakeapi(QUICK, ["test:full"]; fail = ["labels", "jobs"], calls)) == 0
  @test isempty(calls)
  @test main(env(GITHUB_EVENT_NAME = "schedule", TIER = "full"), fakeapi(FULL, String[]; fail = ["labels"])) == 0
  @test main(env(GITHUB_EVENT_NAME = "push", TIER = "none", RUN_TESTS = "false", TESTS = "skipped"),
             fakeapi(QUICK, String[])) == 1
  @test main(env(GITHUB_EVENT_NAME = "push", TIER = "full"), fakeapi(FULL, String[])) == 0
  @test_throws ErrorException CV.parse_jobs(["no tab"])
  # two jobs of one name never count as success, whatever the order
  for order in (["X\tfailure", "X\tsuccess"], ["X\tsuccess", "X\tfailure"], ["X\tsuccess", "X\tsuccess"])
    @test CV.parse_jobs(order)["X"] == "duplicated"
  end
  dup = ["Julia 1 - ubuntu-latest - x64 - quick\tfailure", "Julia 1 - ubuntu-latest - x64 - quick\tsuccess"]
  @test main(env(), fakeapi(Dict{String, String}(), String[]) |> f -> (args -> occursin("/labels", args[1]) ? String[] : dup)) == 1
end

end
