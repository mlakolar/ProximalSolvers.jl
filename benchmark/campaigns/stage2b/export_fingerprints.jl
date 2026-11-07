# Stage 2B (#110) untimed fingerprint exporter: writes the `fingerprints.tsv` of one stack (schema of
# MIGRATION_COMPARE_SPEC.md section 14) from the REAL case states of the benchmark harness of that stack.
#
#   JULIA_NUM_THREADS=1 julia --project=ENV export_fingerprints.jl \
#     --harness DIR --expected-package-root DIR --schedule schedule.toml [--reps 1-8] \
#     --expected-harness-hash HEX40 --out FILE
#
#   --harness DIR                 directory with run.jl, problems.jl, cases.jl, certificates.jl
#   --expected-package-root DIR   the loaded ProximalSolvers root must equal it (realpath); else abort
#   --schedule FILE               suite, groups, case_filter, reps and the declared Julia versions
#   --reps 1-8                    repetition IDs (default: the schedule's); a list "1,3-4" is accepted
#   --expected-harness-hash HEX40 SHA-1 of the four harness files, as run.jl computes it
#   --out FILE                    created exclusively; FILE.datahash.tsv and FILE.summary.toml beside it
#
# Exit status: 0 written; 1 usage; 2 verification failure (fail closed, nothing written); 3 internal error.
#
# What is fingerprinted. For every selected case and repetition the exporter builds the case state with the
# harness's own `spec.make(rep)` and reads what the state's closures captured (the harness exposes only
# CaseState(reset!, call!, certify, problem_hash)): the problem NamedTuple `a` (and the path grid) from the
# `certify` closure, the iterate and the solver from `reset!` and `call!`. It never rebuilds a state from `start`
# or a fresh iterate; a missing or unexpected field fails closed. The state fingerprinted is the one every timed
# call starts from: `reset!`, one untimed `call!`, `reset!`, then the snapshot (run.jl runs one untimed validation
# call before its samples). The snapshot taken right after the first `reset!` (cold) goes to the summary sidecar
# with a note of every difference; a difference is reported, not fatal. Nothing is drawn from the global RNG
# between a `reset!` and its snapshot.
#
# Rows (in this order per case and repetition; fixture rows sorted by name):
#   fixture/<field>      every field of `a`, and `grid` of a path case: canonical encoding of the value
#   reset/values         canonical encoding of the iterate right after `reset!` (and of the task-local RNG state
#                        when the solver uses it); `none` only for the setup case
#   reset/active_ids     sorted PB.activecoordinates ids of a SparseIterate/AtomIterate (the empty set is a hash,
#                        never `none`); `none` for a dense Vector/Matrix iterate and for the setup case
#   config/solver        canonical encoding of the solver object
#   config/options       canonical encoding of the options passed to the solve (`nothing` when the solver owns its
#                        options). Sources by family (cases.jl): call phase: `method` and, unless `own_options`, the
#                        `options` of `call!`; workspace phase: the fields `method` and `options` of the
#                        SolverWorkspace; paths: `method` and the descriptor (call = "solve_path", screening = true,
#                        levels = length(grid)), which mirrors the literal `solve_path(...; screening = true)` of
#                        path_case_state; primal-dual: `method` and `options`; setup case: the descriptor
#                        (setup = <solver>) for both rows (it has no solver object and no options)
#   file/certificates.jl plain SHA-256 of the raw bytes of <harness dir>/certificates.jl
#
# Canonical encoding `ps-stage2b-fp-v1` (a row value is the lowercase hex SHA-256 of
# "ps-stage2b-fp-v1" 0x00 kind 0x00 name 0x00 enc(payload)). enc is tagged and length-prefixed with explicit
# little-endian bytes (htol); it never uses Base.hash, repr, printing or addresses. A length or count is an Int64;
# a string is its Int64 byte length and its UTF-8 bytes.
#   0x01 nothing                  0x02 Bool (one byte)
#   0x03 integer                  type name, the bits of the value
#   0x04 float                    type name, the bits by reinterpret (-0.0 and NaN payloads kept; Float32 != Float64)
#   0x05 String, 0x06 Symbol      the string
#   0x07 Tuple                    count, each element
#   0x08 NamedTuple               count, each (name string, value) in order
#   0x09 dense Array{T,N}         T from a fixed list (Float64, Float32, Float16, Int8..Int64, UInt8..UInt64, Bool),
#                                 type name, ndims, each dimension, the elements column-major
#   0x0a array of arrays          element type name, ndims, each dimension, each element (Vector{Vector{Int}} groups)
#   0x0b SparseMatrixCSC          value and index type names, rows, columns, the stored count and the three vectors
#                                 of the (row, column, value) triples in stored order, explicit zeros included (rows
#                                 must be strictly increasing within a column, else an error)
#   0x0c struct                   module name and type name (`nameof`), the field count, each (field name, value) in
#                                 declaration order; only types of ProximalSolvers, ProximalBase and Random
#   0x0d TaskLocalRNG             by name only (its state goes into reset/values)
# Anything else (Function, Ptr, Module, IO, Type, Core.Box, Dict, a mutable struct of another module) is an error.
#
# P03/P06 note (workspace phase of CDSolver cases): the coordinate-descent working set inside
# `workspace.buffers` is cleared inside the timed solve and is not visible to the spec rows; the summary records
# a diagnostic of it (never compared).
module ExportFingerprints

using SHA, TOML, Random, LinearAlgebra, SparseArrays
import ProximalBase, ProximalSolvers

const PB = ProximalBase
const ENCODING = "ps-stage2b-fp-v1"
const HEADER = "julia\tid\trep\tkind\tname\tvalue"
const HARNESS_FILES = ("problems.jl", "certificates.jl", "cases.jl", "run.jl")
const ALLOWED_MODULES = (:ProximalSolvers, :ProximalBase, :Random)
const MAX_DEPTH = 40

struct UsageError <: Exception
  msg::String
end
struct VerifyError <: Exception
  msg::String
end
struct EncodeError <: Exception
  msg::String
end
for T in (UsageError, VerifyError, EncodeError)
  @eval Base.showerror(io::IO, e::$T) = print(io, e.msg)
end

# ---------------------------------------------------------------------------------- canonical encoding

const Numeric = Union{Float64, Float32, Float16, Int64, Int32, Int16, Int8, UInt64, UInt32, UInt16, UInt8, Bool}
bits_type(::Type{T}) where {T} =
  sizeof(T) == 1 ? UInt8 : sizeof(T) == 2 ? UInt16 : sizeof(T) == 4 ? UInt32 : UInt64

const T_NOTHING, T_BOOL, T_INT, T_FLOAT, T_STRING, T_SYMBOL = 0x01, 0x02, 0x03, 0x04, 0x05, 0x06
const T_TUPLE, T_NAMEDTUPLE, T_ARRAY, T_ARRAYS, T_SPARSE, T_STRUCT, T_TLRNG =
  0x07, 0x08, 0x09, 0x0a, 0x0b, 0x0c, 0x0d

mutable struct Ctx
  io::IOBuffer
  tls::Bool          # a TaskLocalRNG was met
end
Ctx() = Ctx(IOBuffer(), false)

put_i64(c::Ctx, n::Integer) = write(c.io, htol(Int64(n)))
function put_str(c::Ctx, s::AbstractString)
  bytes = codeunits(s)
  put_i64(c, length(bytes))
  write(c.io, bytes)
end
put_scalar(c::Ctx, x::T) where {T<:Numeric} = write(c.io, htol(reinterpret(bits_type(T), x)))

function put_bits(c::Ctx, a::Array{T}) where {T<:Numeric}
  U = bits_type(T)
  if ENDIAN_BOM == 0x04030201
    write(c.io, reinterpret(UInt8, vec(a)))
  else
    for element in reinterpret(U, vec(a))
      write(c.io, htol(element))
    end
  end
end

function enc_array!(c::Ctx, x::Array{E}, depth) where {E}
  isconcretetype(E) || throw(EncodeError("array of the non-concrete element type $E"))
  if E <: Numeric
    write(c.io, T_ARRAY)
    put_str(c, string(E))
    put_i64(c, ndims(x))
    foreach(d -> put_i64(c, d), size(x))
    put_bits(c, x)
  elseif E <: Array
    write(c.io, T_ARRAYS)
    put_str(c, string(E))
    put_i64(c, ndims(x))
    foreach(d -> put_i64(c, d), size(x))
    for element in x
      enc!(c, element, depth + 1)
    end
  else
    throw(EncodeError("array of the unsupported element type $E"))
  end
end

function enc_sparse!(c::Ctx, x::SparseMatrixCSC{Tv, Ti}, depth) where {Tv, Ti}
  (Tv <: Numeric && Ti <: Union{Int64, Int32, UInt64, UInt32}) ||
    throw(EncodeError("sparse matrix of the unsupported types $Tv, $Ti"))
  m, n = size(x)
  pointer, rows, values = x.colptr, rowvals(x), nonzeros(x)
  count = Int(pointer[n + 1]) - 1
  I, J, V = Vector{Ti}(undef, count), Vector{Ti}(undef, count), Vector{Tv}(undef, count)
  k = 0
  for j in 1:n
    last = 0
    for q in pointer[j]:(pointer[j + 1] - 1)
      row = Int(rows[q])
      1 <= row <= m && row > last ||
        throw(EncodeError("sparse matrix rows are not strictly increasing within column $j"))
      last = row
      k += 1
      I[k], J[k], V[k] = rows[q], Ti(j), values[q]
    end
  end
  write(c.io, T_SPARSE)
  put_str(c, string(Tv))
  put_str(c, string(Ti))
  put_i64(c, m)
  put_i64(c, n)
  put_i64(c, count)
  enc!(c, I, depth + 1)
  enc!(c, J, depth + 1)
  enc!(c, V, depth + 1)
end

function enc!(c::Ctx, x, depth::Int = 0)
  depth > MAX_DEPTH && throw(EncodeError("nesting deeper than $MAX_DEPTH levels"))
  io = c.io
  if x === nothing
    write(io, T_NOTHING)
  elseif x isa Bool
    write(io, T_BOOL, UInt8(x))
  elseif x isa Integer
    typeof(x) <: Numeric || throw(EncodeError("unsupported integer type $(typeof(x))"))
    write(io, T_INT)
    put_str(c, string(typeof(x)))
    put_scalar(c, x)
  elseif x isa AbstractFloat
    typeof(x) <: Numeric || throw(EncodeError("unsupported float type $(typeof(x))"))
    write(io, T_FLOAT)
    put_str(c, string(typeof(x)))
    put_scalar(c, x)
  elseif x isa String
    write(io, T_STRING)
    put_str(c, x)
  elseif x isa Symbol
    write(io, T_SYMBOL)
    put_str(c, String(x))
  elseif x isa Tuple
    write(io, T_TUPLE)
    put_i64(c, length(x))
    foreach(element -> enc!(c, element, depth + 1), x)
  elseif x isa NamedTuple
    write(io, T_NAMEDTUPLE)
    put_i64(c, length(x))
    for name in keys(x)
      put_str(c, String(name))
      enc!(c, getfield(x, name), depth + 1)
    end
  elseif x isa SparseMatrixCSC
    enc_sparse!(c, x, depth)
  elseif x isa Array
    enc_array!(c, x, depth)
  elseif x isa Random.TaskLocalRNG
    c.tls = true
    write(io, T_TLRNG)
    put_str(c, "TaskLocalRNG")
  elseif x isa Function || x isa Type || x isa Core.Box
    throw(EncodeError("unsupported value of type $(typeof(x))"))
  else
    T = typeof(x)
    (isstructtype(T) && !isprimitivetype(T)) || throw(EncodeError("unsupported value of type $T"))
    owner = nameof(parentmodule(T))
    owner in ALLOWED_MODULES ||
      throw(EncodeError("unsupported type $T of module $(owner); allowed modules: $(join(ALLOWED_MODULES, ", "))"))
    write(io, T_STRUCT)
    put_str(c, String(owner))
    put_str(c, String(nameof(T)))
    names = fieldnames(T)
    put_i64(c, length(names))
    for (i, name) in enumerate(names)
      isdefined(x, i) || throw(EncodeError("field $name of $T is undefined"))
      put_str(c, String(name))
      enc!(c, getfield(x, i), depth + 1)
    end
  end
  nothing
end

"""
    fingerprint(kind, name, payload) -> hex

The row value of `kind/name` for `payload`: SHA-256 of the versioned prefix and the canonical encoding.
"""
function fingerprint_tls(kind::AbstractString, name::AbstractString, payload)
  c = Ctx()
  write(c.io, ENCODING)
  write(c.io, 0x00)
  write(c.io, kind)
  write(c.io, 0x00)
  write(c.io, name)
  write(c.io, 0x00)
  enc!(c, payload)
  bytes2hex(sha256(take!(c.io))), c.tls
end
fingerprint(kind, name, payload) = first(fingerprint_tls(kind, name, payload))

# ---------------------------------------------------------------------------------------- the harness

hex_file(path) = bytes2hex(sha256(read(path)))

"""SHA-1 of the four harness files of `dir`, computed as run.jl does."""
function harness_hash(dir)
  io = IOBuffer()
  for file in sort([joinpath(dir, name) for name in HARNESS_FILES])
    write(io, relpath(file, dir), '\0', read(file), '\0')
  end
  bytes2hex(sha1(take!(io)))
end

function loaded_roots()
  (; solvers = realpath(dirname(dirname(pathof(ProximalSolvers)))),
     base = realpath(dirname(dirname(pathof(ProximalBase)))))
end

const HARNESS_COUNT = Ref(0)

function check_harness_files(dir)
  isdir(dir) || throw(VerifyError("harness directory $dir does not exist"))
  for name in HARNESS_FILES
    isfile(joinpath(dir, name)) || throw(VerifyError("harness file $name is missing in $dir"))
  end
end

"""Load run.jl of `dir` into a fresh module (defines functions only: `main()` runs only as the program)."""
function load_harness(dir)
  check_harness_files(dir)
  HARNESS_COUNT[] += 1
  harness = Core.eval(Main, Expr(:module, true, Symbol("ExportHarness", HARNESS_COUNT[]), Expr(:block)))
  Base.include(harness, abspath(joinpath(dir, "run.jl")))
  harness
end

"""The generic `certify` of the harness must have every method in <dir>/certificates.jl."""
function check_certify_methods(H, dir)
  isdefined(H, :certify) || throw(VerifyError("the harness defines no certify function"))
  want = realpath(joinpath(dir, "certificates.jl"))
  found = collect(methods(H.certify))
  isempty(found) && throw(VerifyError("the harness certify function has no method"))
  for m in found
    file = String(m.file)
    (isfile(file) && realpath(file) == want) ||
      throw(VerifyError("a method of certify is defined in $file, not in $want"))
  end
  length(found)
end

# ---------------------------------------------------------------------------------- closure inspection

"""The captured variable `name` of closure `f` (a Core.Box is opened); a missing field fails closed."""
function cap(id, f, name::Symbol, role)
  T = typeof(f)
  name in fieldnames(T) ||
    throw(VerifyError("$id: the $role closure has no captured field $name; its fields are $(collect(fieldnames(T)))"))
  isdefined(f, name) || throw(VerifyError("$id: the field $name of the $role closure is undefined"))
  value = getfield(f, name)
  if value isa Core.Box
    isdefined(value, :contents) || throw(VerifyError("$id: the boxed field $name of the $role closure is empty"))
    value = value.contents
  end
  value
end

has_field(f, name) = name in fieldnames(typeof(f))

function family(meta)
  meta.phase == "setup" && return :setup
  meta.group == "paths" && return :path
  meta.group == "primal_dual" && return :primal_dual
  meta.phase == "workspace" && return :workspace
  meta.phase == "call" && return :call
  throw(VerifyError("$(meta.id): no known state family for phase $(meta.phase), group $(meta.group)"))
end

const ITERATE_TYPES = Union{Vector{Float64}, Matrix{Float64}, PB.SparseIterate, PB.AtomIterate}

struct Parts
  id::String
  family::Symbol
  a::NamedTuple
  grid::Union{Nothing, Vector{Float64}}
  iterate::Any          # the iterate; for primal-dual a tuple (x, y); nothing for the setup case
  solver::Any
  options::Any
  workspace::Any
  certificates::String  # SHA-256 of certificates.jl
end

function same(id, what, a, b)
  a === b || throw(VerifyError("$id: $what is not the same object in reset! and call!"))
end

function check_iterate(id, x, what)
  x isa ITERATE_TYPES ||
    throw(VerifyError("$id: the captured iterate $what has the unexpected type $(typeof(x))"))
  x
end

function extract_parts(H, meta, state, certificates)
  id = String(meta.id)
  state isa H.CaseState || throw(VerifyError("$id: the state is a $(typeof(state)), not a CaseState"))
  reset, call, certify = state.reset!, state.call!, state.certify
  fam = family(meta)
  a = cap(id, certify, :a, "certify")
  a isa NamedTuple || throw(VerifyError("$id: the captured problem is a $(typeof(a)), not a NamedTuple"))
  grid = nothing
  iterate = solver = options = workspace = nothing
  if fam == :setup
    isempty(fieldnames(typeof(reset))) ||
      throw(VerifyError("$id: the reset! of a setup case captures state: $(collect(fieldnames(typeof(reset))))"))
    same(id, "the problem a", a, cap(id, call, :a, "call!"))
    solver = options = (; setup = String(meta.solver))
  elseif fam == :call
    x = cap(id, reset, :x, "reset!")
    cap(id, reset, :start, "reset!")
    method = cap(id, reset, :method, "reset!")
    same(id, "the iterate x", x, cap(id, call, :x, "call!"))
    same(id, "the solver", method, cap(id, call, :method, "call!"))
    own = cap(id, call, :own_options, "call!")
    own isa Bool || throw(VerifyError("$id: own_options is a $(typeof(own)), not a Bool"))
    own == (method isa Union{ProximalSolvers.CDSolver, ProximalSolvers.ProxNewton, ProximalSolvers.SLOPEAPG,
                             ProximalSolvers.SLOPEHybrid}) ||
      throw(VerifyError("$id: own_options = $own does not match the solver type $(typeof(method))"))
    iterate = check_iterate(id, x, "x")
    solver = method
    options = own ? nothing : cap(id, call, :options, "call!")
  elseif fam == :workspace
    ws = cap(id, reset, :workspace, "reset!")
    cap(id, reset, :start, "reset!")
    method = cap(id, reset, :method, "reset!")
    same(id, "the workspace", ws, cap(id, call, :workspace, "call!"))
    for name in (:x, :method, :options)
      name in fieldnames(typeof(ws)) ||
        throw(VerifyError("$id: the workspace has no field $name; its fields are $(collect(fieldnames(typeof(ws))))"))
    end
    same(id, "the solver", method, ws.method)
    iterate = check_iterate(id, ws.x, "workspace.x")
    solver, options, workspace = ws.method, ws.options, ws
  elseif fam == :path
    x = cap(id, reset, :x, "reset!")
    same(id, "the iterate x", x, cap(id, call, :x, "call!"))
    has_field(reset, :method) && same(id, "the solver", cap(id, reset, :method, "reset!"), cap(id, call, :method, "call!"))
    grid = cap(id, certify, :grid, "certify")
    grid isa Vector{Float64} || throw(VerifyError("$id: the grid is a $(typeof(grid)), not a Vector{Float64}"))
    same(id, "the grid", grid, cap(id, call, :grid, "call!"))
    iterate = check_iterate(id, x, "x")
    solver = cap(id, call, :method, "call!")
    options = (; call = "solve_path", screening = true, levels = length(grid))
  elseif fam == :primal_dual
    x, y = cap(id, reset, :x, "reset!"), cap(id, reset, :y, "reset!")
    same(id, "the iterate x", x, cap(id, call, :x, "call!"))
    same(id, "the iterate y", y, cap(id, call, :y, "call!"))
    same(id, "the problem a", a, cap(id, call, :a, "call!"))
    same(id, "the problem a of the gap evaluator", a, cap(id, cap(id, call, :gap, "call!"), :a, "gap"))
    iterate = (check_iterate(id, x, "x"), check_iterate(id, y, "y"))
    solver = cap(id, call, :method, "call!")
    options = cap(id, call, :options, "call!")
  end
  if fam != :path
    haskey(a, :grid) && throw(VerifyError("$id: a non-path problem has a field grid"))
  elseif haskey(a, :grid)
    throw(VerifyError("$id: the path problem already has a field grid"))
  end
  Parts(id, fam, a, grid, iterate, solver, options, workspace, certificates)
end

fixture_items(p::Parts) = sort!(vcat([(String(k), getfield(p.a, k)) for k in keys(p.a)],
                                     p.grid === nothing ? Tuple{String,Any}[] : [("grid", p.grid)]); by = first)

function check_data_hash(H, p::Parts, state)
  fixture = p.grid === nothing ? p.a : merge(p.a, (; grid = p.grid))
  hash = H.data_hash(fixture)
  hash == state.problem_hash ||
    throw(VerifyError("$(p.id): data_hash of the captured fixture is $hash, problem_hash is $(state.problem_hash)"))
  hash
end

# ------------------------------------------------------------------------------------------ the snapshot

dense_values(x::Array) = copy(x)
dense_values(x) = collect(Float64, x)
iterate_payload(x) = (; type = String(nameof(typeof(x))), values = dense_values(x))
active_ids(x::Union{PB.SparseIterate, PB.AtomIterate}) = sort!(collect(Int, PB.activecoordinates(x)))
active_ids(x) = nothing

tls_copy() = copy(Random.default_rng())

const ROW_ORDER = (("reset", "values"), ("reset", "active_ids"), ("config", "solver"), ("config", "options"),
                   ("file", "certificates.jl"))

"""Every row of the state as it is now: a Dict (kind, name) => value. `tls` is the task-local RNG state read
right after the reset."""
function snapshot_rows(p::Parts, tls)
  rows = Dict{Tuple{String,String}, String}()
  for (name, value) in fixture_items(p)
    rows[("fixture", name)] = fingerprint("fixture", name, value)
  end
  rows[("file", "certificates.jl")] = p.certificates
  solver, tls_solver = fingerprint_tls("config", "solver", p.solver)
  options, tls_options = fingerprint_tls("config", "options", p.options)
  rows[("config", "solver")], rows[("config", "options")] = solver, options
  if p.family == :setup
    rows[("reset", "values")] = rows[("reset", "active_ids")] = "none"
  else
    rng = (tls_solver || tls_options) ? tls : nothing
    payload = p.family == :primal_dual ? (; x = iterate_payload(p.iterate[1]), y = iterate_payload(p.iterate[2])) :
      iterate_payload(p.iterate)
    rows[("reset", "values")] = fingerprint("reset", "values", (; iterate = payload, rng))
    ids = p.family == :primal_dual ? nothing : active_ids(p.iterate)
    rows[("reset", "active_ids")] = ids === nothing ? "none" : fingerprint("reset", "active_ids", ids)
  end
  rows
end

row_keys(rows) = vcat(sort!([k for k in keys(rows) if k[1] == "fixture"]; by = last), collect(ROW_ORDER))

"""A note on the hidden working set of a CD workspace (P03/P06); never compared."""
function cd_buffer_note(p::Parts)
  p.workspace === nothing && return "none"
  buffers = p.workspace.buffers
  hasfield(typeof(buffers), :iterate) || return "no iterate in $(nameof(typeof(buffers)))"
  try
    ids = active_ids(buffers.iterate)
    ids === nothing ? "iterate $(typeof(buffers.iterate)) has no working set" :
      "buffers.iterate $(nameof(typeof(buffers.iterate))) nactive=$(length(ids)) ids=$(fingerprint("diagnostic", "cd_buffers", ids))"
  catch err
    "unavailable: $(typeof(err))"
  end
end

# ----------------------------------------------------------------------------------------- one case, one rep

struct CaseResult
  id::String
  rep::Int
  family::Symbol
  rows::Vector{Tuple{String, String, String}}   # kind, name, value
  data_hash::String
  cold_differences::Vector{String}
  note::String
end

"""
    export_case(H, meta, make, rep) -> CaseResult

reset!, one untimed call!, reset!, snapshot (cold snapshot after the first reset!, compared and reported).
Call it through `Base.invokelatest` after `load_harness` (the harness functions are newer than the caller).
"""
function export_case(H, meta, make, rep::Integer, certificates::AbstractString)
  id = String(meta.id)
  try
    state = make(rep)
    parts = extract_parts(H, meta, state, String(certificates))
    hash = check_data_hash(H, parts, state)
    state.reset!()
    tls = tls_copy()
    cold = snapshot_rows(parts, tls)
    note_cold = cd_buffer_note(parts)
    state.call!()
    state.reset!()
    tls = tls_copy()
    warm = snapshot_rows(parts, tls)
    note_warm = cd_buffer_note(parts)
    check_data_hash(H, parts, state)
    for key in keys(warm)
      key[1] == "fixture" && cold[key] != warm[key] &&
        throw(VerifyError("$id rep $rep: the untimed call changed the fixture field $(key[2])"))
    end
    # A second make must give identical inputs, field by field.
    state2 = make(rep)
    parts2 = extract_parts(H, meta, state2, String(certificates))
    state2.problem_hash == state.problem_hash ||
      throw(VerifyError("$id rep $rep: a second make gave another problem_hash"))
    check_data_hash(H, parts2, state2)
    again = snapshot_rows(parts2, tls)
    for key in union(keys(warm), keys(again))
      key[1] == "fixture" && get(warm, key, "") != get(again, key, "x") &&
        throw(VerifyError("$id rep $rep: a second make gave another fixture field $(key[2])"))
    end
    differences = String[kind * "/" * name for (kind, name) in row_keys(warm)
                         if kind != "fixture" && cold[(kind, name)] != warm[(kind, name)]]
    rows = [(kind, name, warm[(kind, name)]) for (kind, name) in row_keys(warm)]
    note = "cold: $note_cold; warm: $note_warm"
    CaseResult(id, Int(rep), parts.family, rows, hash, differences, note)
  catch err
    err isa EncodeError && throw(VerifyError("$id rep $rep: $(err.msg)"))
    rethrow()
  end
end

# ------------------------------------------------------------------------------------------ the CLI

function parse_reps(text)
  reps = Int[]
  for part in split(text, ',')
    m = match(r"^(\d+)(?:-(\d+))?$", strip(part))
    m === nothing && throw(UsageError("--reps expects numbers and ranges such as 1-8, got \"$text\""))
    lo = parse(Int, m[1])
    hi = m[2] === nothing ? lo : parse(Int, m[2])
    lo <= hi || throw(UsageError("--reps range $lo-$hi is empty"))
    append!(reps, lo:hi)
  end
  isempty(reps) && throw(UsageError("--reps is empty"))
  allunique(reps) || throw(UsageError("--reps repeats a repetition"))
  sort!(reps)
end

const REQUIRED_OPTIONS = ("--harness", "--expected-package-root", "--schedule", "--expected-harness-hash", "--out")
const USAGE = "usage: export_fingerprints.jl --harness DIR --expected-package-root DIR --schedule FILE " *
              "[--reps 1-8] --expected-harness-hash HEX40 --out FILE"

function parse_args(args)
  opts = Dict{String, String}()
  i = 1
  while i <= length(args)
    key = args[i]
    key in (REQUIRED_OPTIONS..., "--reps") || throw(UsageError("unknown argument $key\n$USAGE"))
    i < length(args) || throw(UsageError("$key needs a value\n$USAGE"))
    haskey(opts, key) && throw(UsageError("$key given twice"))
    opts[key] = args[i + 1]
    i += 2
  end
  for key in REQUIRED_OPTIONS
    haskey(opts, key) || throw(UsageError("missing $key\n$USAGE"))
  end
  occursin(r"^[0-9a-f]{40}$", opts["--expected-harness-hash"]) ||
    throw(UsageError("--expected-harness-hash must be 40 lowercase hex characters"))
  (; harness = abspath(opts["--harness"]), root = opts["--expected-package-root"],
     schedule = opts["--schedule"], reps = haskey(opts, "--reps") ? parse_reps(opts["--reps"]) : nothing,
     hash = opts["--expected-harness-hash"], out = abspath(opts["--out"]))
end

function read_schedule(path)
  isfile(path) || throw(UsageError("schedule file $path does not exist"))
  t = TOML.parsefile(path)
  try
    s, sched = t["settings"], t["schedule"]
    versions = String[v["version"] for (_, v) in t["julia"]]
    (; suite = String(s["suite"]), groups = String(s["groups"]), case_filter = String(s["case_filter"]),
       reps = Int.(sched["reps"]), versions)
  catch err
    err isa KeyError || rethrow()
    throw(VerifyError("the schedule $path lacks $(err.key)"))
  end
end

function select_specs(H, sched)
  groups = sort!(unique(String[strip(g) for g in split(sched.groups, ',')]))
  catalog = H.build_catalog(sched.suite, groups)
  selected = H.select_cases(catalog, sched.case_filter)
  patterns = [strip(p) for p in split(sched.case_filter, ',') if !isempty(strip(p))]
  if !any(p -> occursin('*', p), patterns)
    length(selected) == length(patterns) ||
      throw(VerifyError("the case filter names $(length(patterns)) cases, the harness selected $(length(selected))"))
  end
  selected
end

function check_name(text)
  occursin(r"[\t\n\r]", text) && throw(VerifyError("a row key contains a tab or line break: $(repr(text))"))
  text
end

function render(julia, results)
  io = IOBuffer()
  print(io, HEADER, '\n')
  sidecar = IOBuffer()
  print(sidecar, "julia\tid\trep\tdata_hash\n")
  for r in results
    for (kind, name, value) in r.rows
      print(io, julia, '\t', check_name(r.id), '\t', r.rep, '\t', kind, '\t', check_name(name), '\t', value, '\n')
    end
    print(sidecar, julia, '\t', r.id, '\t', r.rep, '\t', r.data_hash, '\n')
  end
  take!(io), take!(sidecar)
end

function summary_table(cfg, sched, results, harness_hash_value, certificates, certify_methods)
  roots = loaded_roots()
  Dict{String, Any}(
    "encoding" => ENCODING,
    "exporter_sha256" => hex_file(@__FILE__),
    "julia" => string(VERSION),
    "harness_hash" => harness_hash_value,
    "certificates_sha256" => certificates,
    "certify_methods" => certify_methods,
    "proximalsolvers_root" => roots.solvers,
    "proximalsolvers_version" => string(pkgversion(ProximalSolvers)),
    "proximalbase_root" => roots.base,
    "proximalbase_version" => string(pkgversion(ProximalBase)),
    "suite" => sched.suite, "groups" => sched.groups, "case_filter" => sched.case_filter,
    "reps" => cfg.reps, "cases" => length(unique(r.id for r in results)),
    "rows" => sum(length(r.rows) for r in results),
    "cold_differences" => count(r -> !isempty(r.cold_differences), results),
    "note_p03_p06" => "the hidden coordinate-descent working set inside workspace.buffers is cleared inside the " *
      "timed solve and is not visible to the spec rows; the per-case note records a diagnostic that is never compared",
    "case" => [Dict{String, Any}("id" => r.id, "rep" => r.rep, "family" => String(r.family),
                                 "cold_equals_warm" => isempty(r.cold_differences),
                                 "cold_differences" => r.cold_differences, "note" => r.note) for r in results])
end

function create_exclusive(path, bytes)
  flags = Base.Filesystem.JL_O_WRONLY | Base.Filesystem.JL_O_CREAT | Base.Filesystem.JL_O_EXCL
  file = try
    Base.Filesystem.open(path, flags, 0o644)
  catch err
    throw(VerifyError("cannot create $path exclusively: $(sprint(showerror, err))"))
  end
  try
    write(file, bytes)
  finally
    close(file)
  end
end

"""Everything after the harness is loaded; call through `Base.invokelatest`."""
function export_all(H, cfg, sched, certificates, certify_methods, harness_hash_value)
  specs = select_specs(H, sched)
  results = CaseResult[]
  for spec in specs, rep in cfg.reps
    result = export_case(H, spec.meta, spec.make, rep, certificates)
    push!(results, result)
    println(stderr, "EXPORTED ", result.id, " rep ", rep, " (", result.family, ", ", length(result.rows), " rows",
            isempty(result.cold_differences) ? "" : ", cold differs: " * join(result.cold_differences, ","), ")")
  end
  main_bytes, sidecar_bytes = render(string(VERSION), results)
  summary = IOBuffer()
  TOML.print(summary, summary_table(cfg, sched, results, harness_hash_value, certificates, certify_methods);
             sorted = true)
  create_exclusive(cfg.out, main_bytes)
  create_exclusive(cfg.out * ".datahash.tsv", sidecar_bytes)
  create_exclusive(cfg.out * ".summary.toml", take!(summary))
  (; results, bytes = main_bytes)
end

function run(args)
  cfg = parse_args(args)
  for path in (cfg.out, cfg.out * ".datahash.tsv", cfg.out * ".summary.toml")
    ispath(path) && throw(VerifyError("refusing to overwrite $path"))
  end
  Threads.nthreads() == 1 || throw(VerifyError("run with JULIA_NUM_THREADS=1"))
  BLAS.set_num_threads(1)
  loaded = loaded_roots().solvers
  expected = try
    realpath(cfg.root)
  catch
    throw(VerifyError("--expected-package-root $(cfg.root) does not exist"))
  end
  loaded == expected || throw(VerifyError("loaded ProximalSolvers from $loaded; expected $expected"))
  check_harness_files(cfg.harness)
  computed = harness_hash(cfg.harness)
  computed == cfg.hash ||
    throw(VerifyError("the harness hash of $(cfg.harness) is $computed; expected $(cfg.hash)"))
  sched = read_schedule(cfg.schedule)
  string(VERSION) in sched.versions ||
    throw(VerifyError("Julia $(VERSION) is not a declared version of the schedule: $(sched.versions)"))
  cfg = merge(cfg, (; reps = cfg.reps === nothing ? sched.reps : cfg.reps))
  all(in(sched.reps), cfg.reps) ||
    throw(VerifyError("--reps $(cfg.reps) is not a subset of the schedule's repetitions $(sched.reps)"))
  certificates = hex_file(joinpath(cfg.harness, "certificates.jl"))
  H = load_harness(cfg.harness)
  Base.invokelatest(run_loaded, H, cfg, sched, certificates, computed)
end

"""Everything that touches the loaded harness (newer than the caller: reached through `invokelatest`)."""
function run_loaded(H, cfg, sched, certificates, computed)
  # Cross-check of the harness's own fingerprint function against the one computed here.
  mine = H.fingerprint(cfg.harness, [joinpath(cfg.harness, n) for n in HARNESS_FILES])
  mine == computed || throw(VerifyError("run.jl's fingerprint $mine differs from the recomputed $computed"))
  certify_methods = check_certify_methods(H, cfg.harness)
  out = export_all(H, cfg, sched, certificates, certify_methods, computed)
  println(stderr, "WROTE ", cfg.out, " (", count(==(UInt8('\n')), out.bytes) - 1, " rows)")
  0
end

function main(args)
  try
    return run(args)
  catch err
    if err isa UsageError
      println(stderr, "USAGE ERROR: ", err.msg)
      return 1
    elseif err isa VerifyError || err isa EncodeError
      println(stderr, "FINGERPRINT FAILURE: ", err.msg)
      return 2
    end
    println(stderr, "INTERNAL ERROR: ", sprint(showerror, err, catch_backtrace()))
    return 3
  end
end

end # module

if abspath(PROGRAM_FILE) == @__FILE__
  exit(ExportFingerprints.main(ARGS))
end
