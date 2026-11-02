# Summarize the output of scripts/test.jl (a ParallelTestRunner run) as Markdown:
#
#   julia scripts/test.jl --verbose 2>&1 | tee test.log
#   julia scripts/test_report.jl test.log [step-seconds]
#
# CI appends the result to the job summary. `step-seconds` is the elapsed time of the whole
# test command; without it the startup share is not shown. The compile share needs --verbose
# and Julia 1.11 or later. No packages are needed. Adapted from ProximalBase.jl.

const ANSI = r"\e\[[0-9;]*[A-Za-z]"

struct Row
  name::String
  worker::String
  time::Float64
  init::Float64      # NaN unless --verbose
  compile::Float64   # percent; NaN unless --verbose on Julia 1.11+
  gc::Float64
  alloc::Float64
  rss::Float64
  status::Symbol     # :passed, :failed or :crashed
end

number(s) = something(tryparse(Float64, strip(s)), NaN)

function parse_rows(lines)
  rows = Dict{String, Row}()
  for line in lines
    m = match(r"^(\S+)\s+\((\d+)\)\s+│(.*)$", line)
    m === nothing && continue
    name, worker, rest = m.captures
    fields = strip.(split(rest, '│'))
    filter!(!isempty, fields)
    isempty(fields) && continue
    if occursin("started at", rest)
      continue
    elseif occursin("crashed at", rest)
      rows[name] = Row(name, worker, NaN, NaN, NaN, NaN, NaN, NaN, :crashed)
    elseif occursin("failed at", rest)
      init = length(fields) >= 3 ? number(fields[2]) : NaN
      rows[name] = Row(name, worker, number(fields[1]), init, NaN, NaN, NaN, NaN, :failed)
    else
      v = number.(fields)
      any(isnan, v) && continue
      # time, [init, [compile %]], GC (s), GC %, alloc, RSS
      if length(v) == 5
        rows[name] = Row(name, worker, v[1], NaN, NaN, v[2], v[4], v[5], :passed)
      elseif length(v) == 6
        rows[name] = Row(name, worker, v[1], v[2], NaN, v[3], v[5], v[6], :passed)
      elseif length(v) == 7
        rows[name] = Row(name, worker, v[1], v[2], v[3], v[4], v[6], v[7], :passed)
      end
    end
  end
  return collect(values(rows))
end

# "28m19.1s", "1h02m03.0s", "8.3s" -> seconds
function duration(s)
  total = 0.0
  for m in eachmatch(r"([\d.]+)([hms])", s)
    total += parse(Float64, m.captures[1]) * Dict("h" => 3600, "m" => 60, "s" => 1)[m.captures[2]]
  end
  return total
end

function summary_counts(lines)
  i = findlast(l -> startswith(lstrip(l), "Test Summary:"), lines)
  i === nothing && return nothing
  header = strip.(split(split(lines[i], '|'; limit = 2)[2]))
  for line in lines[(i + 1):end]
    occursin(r"^\s*Overall\s*\|", line) || continue
    values = split(strip(split(line, '|'; limit = 2)[2]))
    names = filter(!isempty, header)
    counts = Dict{String, String}()
    # the columns with no count for this run are blank, so match from both ends
    counts["Time"] = values[end]
    for (k, v) in zip(names[1:(end - 1)], values[1:(end - 1)])
      counts[k] = v
    end
    return counts
  end
  return nothing
end

fmt(x; digits = 1) = isnan(x) ? "" : string(round(x; digits))
function minutes(s)
  isnan(s) && return ""
  t = round(Int, s)
  return t < 60 ? "$t s" : "$(div(t, 60)) min $(lpad(rem(t, 60), 2, '0')) s"
end

function report(io, path, step)
  lines = map(l -> replace(l, ANSI => ""), readlines(path))
  rows = sort!(parse_rows(lines); by = r -> isnan(r.time) ? Inf : r.time, rev = true)
  selection = findfirst(startswith("ProximalSolvers tests:"), lines)
  jobs = findfirst(l -> occursin(r"^Running \d+ tests using \d+ parallel jobs", l), lines)
  counts = summary_counts(lines)
  runner = counts === nothing ? NaN : duration(counts["Time"])
  precompile = sum((parse(Float64, m.captures[1]) for l in lines
                    for m in (match(r"precompiled in ([\d.]+) seconds", l),) if m !== nothing); init = 0.0)
  worker = sum((r.time for r in rows if !isnan(r.time)); init = 0.0)
  compiled = [(r.time, r.compile) for r in rows if !isnan(r.compile)]
  title = get(ENV, "TEST_REPORT_TITLE", "Test timing")
  println(io, "### ", title, "\n")
  println(io, "| | |\n|---|---|")
  selection === nothing || println(io, "| Selection | ", replace(lines[selection], "ProximalSolvers tests: " => ""), " |")
  jobs === nothing || println(io, "| Workers | ", match(r"using (\d+) parallel", lines[jobs]).captures[1], " |")
  step === nothing || println(io, "| Test step (setup, precompilation and tests) | ", minutes(step), " |")
  precompile > 0 && println(io, "| Package precompilation | ", minutes(precompile), " |")
  println(io, "| ParallelTestRunner wall time | ", minutes(runner), " |")
  step === nothing || isnan(runner) || println(io, "| Before the runner (Julia, test environment, precompilation) | ", minutes(step - runner), " |")
  println(io, "| Worker time, sum over $(length(rows)) files | ", minutes(worker), " |")
  rss = [r.rss for r in rows if !isnan(r.rss)]
  isempty(rss) || println(io, "| Largest worker RSS after a file | ", round(Int, maximum(rss)), " MB |")
  if !isempty(compiled)
    share = sum(t * c / 100 for (t, c) in compiled) / sum(t for (t, _) in compiled)
    println(io, "| Compilation share of worker time | ", round(Int, 100 * share), "% |")
  end
  counts === nothing || println(io, "| Results | ", join(("$k $(counts[k])" for k in ("Pass", "Fail", "Error", "Broken") if haskey(counts, k)), ", "), " |")
  bad = filter(r -> r.status != :passed, rows)
  if !isempty(bad)
    println(io, "\n**Failed or crashed:** ", join(("`$(r.name)` ($(r.status))" for r in bad), ", "))
  end
  table(rows) = begin
    println(io, "| File | Time (s) | Compile (%) | Init (s) | GC (s) | Alloc (MB) | RSS (MB) |")
    println(io, "|---|---:|---:|---:|---:|---:|---:|")
    for r in rows
      println(io, "| `$(r.name)` | $(fmt(r.time)) | $(fmt(r.compile; digits = 0)) | $(fmt(r.init)) | $(fmt(r.gc)) | $(fmt(r.alloc; digits = 0)) | $(fmt(r.rss; digits = 0)) |")
    end
  end
  println(io, "\nSlowest files:\n")
  table(first(rows, 10))
  println(io, "\n<details><summary>All $(length(rows)) files</summary>\n")
  table(rows)
  println(io, "\n</details>")
end

isempty(ARGS) && error("usage: julia scripts/test_report.jl LOG [STEP_SECONDS]")
report(stdout, ARGS[1], length(ARGS) >= 2 ? parse(Float64, ARGS[2]) : nothing)
