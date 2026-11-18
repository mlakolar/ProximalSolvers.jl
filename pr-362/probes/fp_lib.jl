# Bit-identity fingerprint library: compare solver outcomes of several source trees loaded as modules
# in ONE process (see loader.jl). Everything is compared with bit equality (isequal + signbit for
# floats, so NaN == NaN and -0.0 != 0.0), recursively over every field of a result except `method`
# (a solver object with an rng) and `trace`.
using ProximalBase, Random, Logging, Test, SparseArrays, LinearAlgebra
using ProximalBase: SparseIterate, BlockIterate, GroupNormL2, LeastSquaresLoss, SqrtLeastSquaresLoss, Scaled,
  NormL1, ElasticNet

# first difference between a and b as a string, or nothing
function ddiff(a, b, path = "")
  if a isa AbstractFloat || b isa AbstractFloat
    (typeof(a) === typeof(b) && isequal(a, b) && signbit(a) == signbit(b)) ? nothing : "$path: $(repr(a)) vs $(repr(b))"
  elseif a isa AbstractArray && b isa AbstractArray
    size(a) == size(b) || return "$path: size $(size(a)) vs $(size(b))"
    eltype(a) === eltype(b) || return "$path: eltype $(eltype(a)) vs $(eltype(b))"
    for i in eachindex(a)
      d = ddiff(a[i], b[i], "$path[$i]"); d === nothing || return d
    end
    nothing
  elseif a isa SparseIterate && b isa SparseIterate
    ddiff((ncoordinates(a), collect(activecoordinates(a)), collect(activevalues(a))),
          (ncoordinates(b), collect(activecoordinates(b)), collect(activevalues(b))), path)
  elseif a isa BlockIterate && b isa BlockIterate
    ddiff(Vector(a), Vector(b), path)
  elseif a isa Tuple && b isa Tuple
    length(a) == length(b) || return "$path: tuple length"
    for i in eachindex(a)
      d = ddiff(a[i], b[i], "$path.$i"); d === nothing || return d
    end
    nothing
  elseif a isa Union{Integer, Bool, Symbol, AbstractString, Nothing} || b isa Union{Integer, Bool, Symbol, AbstractString, Nothing}
    isequal(a, b) && typeof(a) === typeof(b) ? nothing : "$path: $(repr(a)) vs $(repr(b))"
  elseif isstructtype(typeof(a)) && isstructtype(typeof(b))
    nameof(typeof(a)) === nameof(typeof(b)) || return "$path: type $(nameof(typeof(a))) vs $(nameof(typeof(b)))"
    for f in fieldnames(typeof(a))
      f in (:method, :trace) && continue
      d = ddiff(getfield(a, f), getfield(b, f), "$path.$f"); d === nothing || return d
    end
    nothing
  else
    isequal(a, b) ? nothing : "$path: $(repr(a)) vs $(repr(b))"
  end
end

# run c.run(PS) capturing the result (or the error text) and the log records
function outcome(PS, run)
  logger = Test.TestLogger(min_level = Logging.Debug)
  r = with_logger(logger) do
    try run(PS) catch e; "ERROR: " * first(split(sprint(showerror, e), '\n')) end
  end
  (r, [(l.level, string(l.message)) for l in logger.logs])
end

mutable struct Tally
  n::Int
  mismatches::Vector{String}
  errors::Int       # cases where the base run threw (the same error is then compared)
  converged::Int
  errmsgs::Dict{String,Int}
  Tally() = new(0, String[], 0, 0, Dict{String,Int}())
end

function compare!(t::Tally, label, mods, run)
  base = outcome(mods[1][2], run)
  base[1] isa AbstractString && (t.errors += 1; k = first(base[1], 110); t.errmsgs[k] = get(t.errmsgs, k, 0) + 1)
  for (name, PS) in mods[2:end]
    o = outcome(PS, run)
    d = ddiff(base, o, label)
    t.n += 1
    d === nothing || push!(t.mismatches, "[$name] $d")
  end
  if !(base[1] isa AbstractString)
    r = base[1] isa Tuple ? base[1][1] : base[1]
    t.converged += (hasproperty(r, :converged) && r.converged) ? 1 : 0
  end
  nothing
end

# ---- data ----------------------------------------------------------------
function lsdata(rng, ::Type{T}, n, p; nnz = max(1, p ÷ 5), scale = 1.0, noise = 0.1, corr = false) where T
  X = randn(rng, T, n, p)
  corr && (X .+= T(0.5) .* randn(rng, T, n, 1))
  β = zeros(T, p); for k in randperm(rng, p)[1:min(nnz, p)]; β[k] = T(randn(rng) * 2); end
  y = X * β .+ T(noise) .* randn(rng, T, n)
  X .*= T(scale); y .*= T(scale)
  X, y, β
end
