# runner.jl: canonical text records of one case (issue #279 fingerprint harness).
# Requires common.jl and corpus.jl (Scn, PS) in Main.

function dump_obj(io::IO, prefix::AbstractString, v, depth::Int)
  if v isa AbstractFloat || v isa Bool || v isa Integer || v isa AbstractArray{<:AbstractFloat} ||
     v isa AbstractString || v === nothing || v isa Symbol
    ser_value(io, prefix, v)
  elseif depth < 3 && isstructtype(typeof(v)) && !(v isa Function) && !(v isa Type) && !(v isa AbstractDict)
    println(io, prefix, " ", typeof(v))
    for f in fieldnames(typeof(v))
      dump_obj(io, string(prefix, ".", f), getfield(v, f), depth + 1)
    end
  else
    ser_value(io, prefix, v)
  end
end

function ser_result(io::IO, r, x)
  println(io, "RESULT_TYPE ", typeof(r))
  for fld in fieldnames(typeof(r))
    v = getfield(r, fld)
    if fld === :trace
      continue
    elseif fld === :method
      println(io, "R method ", esc_str(repr(v)))
    elseif fld === :minimizer
      ser_value(io, "R minimizer", v)
      println(io, "R minimizer_aliases_x ", v === x)
    else
      ser_value(io, "R " * string(fld), v)
    end
  end
  tr = r.trace
  println(io, "TRACE ", typeof(tr), " ", length(tr))
  for s in tr
    print(io, "S ", s.iteration, " ", bitstring(s.fg_x), " ", bitstring(s.dxx), " ", bitstring(s.L))
    for k in sort!(collect(keys(s.metadata)); by = string)
      v = s.metadata[k]
      print(io, " | ", k, "=", v isa AbstractArray{<:AbstractFloat} ? vsig(v) : esc_str(repr(v)))
    end
    println(io)
  end
  println(io, "SHOWTRACE ", sha1hex(sprint(show, tr)))
  println(io, "SHOWRESULT ", sha1hex(sprint(show, r)))
  nothing
end

# solve!/_solve_gradient!/update_state! as the case asks; returns the result (or nothing)
function run_how(a, x, holder::Ref{Any}; manual::Bool = false)
  if a.how === :solve && !manual
    return PS.solve!(x, a.f, a.g, a.method, a.opts; a.kwargs...)
  end
  st = PS.initial_state(a.method, a.opts, a.f, a.g, x)
  holder[] = st
  a.prep === nothing || a.prep(st)
  if a.how === :update
    for _ in 1:3
      PS.update_state!(a.f, a.g, st, a.method)
    end
    return nothing
  end
  PS._solve_gradient!(st, a.f, a.g, a.method, a.opts)
end

# returns (res, exc, stdout_text, holder, x)
function execute(a; manual::Bool = false)
  x = a.alias ? a.x0 : (a.x0 isa AbstractArray ? copy(a.x0) : a.x0)
  holder = Ref{Any}(nothing)
  show_trace = a.opts isa ProximalOptions && a.opts.show_trace
  if show_trace
    res, exc, out = capture_stdout(() -> run_how(a, x, holder; manual))
  else
    res, exc, out = nothing, nothing, ""
    try
      res = run_how(a, x, holder; manual)
    catch e
      exc = e
    end
  end
  (res, exc, out, holder, x)
end

function result_sig(res, x)
  io = IOBuffer()
  ser_result(io, res, x)
  sha1hex(String(take!(io)))
end

dump_state_for(name::AbstractString) = sum(codeunits(name)) % 3 == 0

function opts_text(o)
  o isa ProximalOptions || return esc_str(repr(typeof(o)))
  join((f === :callback ? "callback=" * (o.callback === nothing ? "nothing" : "fn") : string(f, "=", getfield(o, f))
        for f in fieldnames(typeof(o))), ";")
end

function case_record(scn::Scn)::String
  io = IOBuffer()
  println(io, "CASE ", scn.name)
  a = nothing
  try
    a = scn.make()
  catch e
    ser_exc(io, "BUILD_THROW", e)
    println(io, "END")
    return String(take!(io))
  end
  println(io, "METHOD ", esc_str(repr(a.method)))
  ser_value(io, "X0", a.x0)
  println(io, "HOW ", a.how, " ", opts_text(a.opts))
  res, exc, out, holder, x = execute(a)
  println(io, "OUTCOME ", exc === nothing ? "ok" : "throw")
  exc === nothing || ser_exc(io, "EXC", exc)
  ser_value(io, "X_AFTER", x)
  if res !== nothing
    ser_result(io, res, x)
  end
  println(io, "STDOUT ", ncodeunits(out), " ", sha1hex(out), " ", esc_str(first(out, 120)))
  println(io, "CALLBACKS ", length(a.log))
  for l in a.log
    println(io, l)
  end
  if holder[] !== nothing && (a.how === :update || dump_state_for(scn.name))
    dump_obj(io, "ST", holder[], 0)
  end
  # the manual path (initial_state + _solve_gradient!) must reproduce a successful public solve!
  if a.how === :solve && exc === nothing && res !== nothing && dump_state_for(scn.name)
    a2 = scn.make()
    res2, exc2, out2, holder2, x2 = execute(a2; manual = true)
    same = exc2 === nothing && res2 !== nothing && result_sig(res2, x2) == result_sig(res, x) && out2 == out
    println(io, "MANUAL_SAME ", same)
    exc2 === nothing || ser_exc(io, "MANUAL_EXC", exc2)
    holder2[] === nothing || dump_obj(io, "ST2", holder2[], 0)
  end
  println(io, "END")
  String(take!(io))
end
