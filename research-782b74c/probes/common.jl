# common.jl: shared by every probe script of issue #279 (disposable; never part of a package tree).
# Usage in a script (run as `julia --project=<tree> script.jl`):
#   include(joinpath(@__DIR__, "common.jl")); ensure_env()
#   using ProximalBase: ...; using ProximalSolvers
#   env_header()
import Pkg, TOML, SHA
using LinearAlgebra
using Printf

const PB_UUID = Base.UUID("0a755509-c5b1-5d6f-9b24-59bcda3c37a3")
const PB_PIN_REV = "c123d56ba1948e36a8fdbf183a9eea396a16e0d5"
const PB_PIN_TREE_PREFIX = "c2e2ddde"

# Offline instantiation of the active project (a no-op when everything is installed). Never
# `scripts/instantiate.jl`, which resolves from local master checkouts.
function ensure_env()
  println("COMMON instantiate ", Base.active_project())
  flush(stdout)
  Pkg.instantiate()
  nothing
end

"""
    env_header(io = stdout)

Prints the environment header and fails loudly unless the loaded ProximalBase is the PS pin.
Call after `using ProximalSolvers`.
"""
function env_header(io::IO = stdout)
  println(io, "ENV julia_version ", VERSION)
  println(io, "ENV cpu_name ", Sys.CPU_NAME)
  println(io, "ENV blas_config ", BLAS.get_config())
  BLAS.set_num_threads(1)
  println(io, "ENV blas_threads_after_set_num_threads(1) ", BLAS.get_num_threads())
  println(io, "ENV hostname ", gethostname())
  println(io, "ENV active_project ", Base.active_project())
  pbid = Base.PkgId(PB_UUID, "ProximalBase")
  haskey(Base.loaded_modules, pbid) || error("env guard: ProximalBase is not loaded")
  PB = Base.loaded_modules[pbid]
  pbdir = pkgdir(PB)
  println(io, "ENV pkgdir_ProximalBase ", pbdir)
  println(io, "ENV pkgversion_ProximalBase ", pkgversion(PB))
  PSmod = Base.loaded_modules[Base.PkgId(Base.UUID("fc4971f5-6616-4709-9bfc-89a819252f6b"), "ProximalSolvers")]
  println(io, "ENV pkgdir_ProximalSolvers ", pkgdir(PSmod))
  mpath = Base.project_file_manifest_path(Base.active_project())
  mpath === nothing && error("env guard: the active project has no manifest")
  println(io, "ENV manifest ", mpath)
  ent = TOML.parsefile(mpath)["deps"]["ProximalBase"][1]
  rev = get(ent, "repo-rev", "")
  tree = get(ent, "git-tree-sha1", "")
  println(io, "ENV PB manifest repo-rev ", rev)
  println(io, "ENV PB manifest git-tree-sha1 ", tree)
  println(io, "ENV PB manifest version ", get(ent, "version", ""))
  disk = try
    h = Pkg.GitTools.tree_hash(pbdir)
    h isa AbstractVector{UInt8} ? bytes2hex(h) : string(h)
  catch e
    "unavailable: " * sprint(showerror, e)
  end
  println(io, "ENV PB loaded-directory tree hash ", disk)
  slug = try
    expect = Base.version_slug(PB_UUID, Base.SHA1(tree))
    basename(pbdir) == expect ? "ok ($expect)" : "MISMATCH (dir $(basename(pbdir)), expected $expect)"
  catch e
    "unavailable: " * sprint(showerror, e)
  end
  println(io, "ENV PB depot slug check ", slug)
  ok = rev == PB_PIN_REV && startswith(tree, PB_PIN_TREE_PREFIX) && !startswith(slug, "MISMATCH") &&
       (startswith(disk, "unavailable") || disk == tree)
  println(io, "ENV PB_GUARD ", ok ? "PASS" : "FAIL")
  flush(io)
  ok || error("env guard failed: the loaded ProximalBase is not the pinned $PB_PIN_REV / $PB_PIN_TREE_PREFIX*")
  nothing
end

# ---- canonical text helpers -------------------------------------------------------------
sha1hex(x::AbstractVector{UInt8}) = bytes2hex(SHA.sha1(x))
sha1hex(s::AbstractString) = bytes2hex(SHA.sha1(String(s)))

function vsig(v::AbstractArray{T}) where {T<:AbstractFloat}
  a = v isa Array ? v : Array(v)
  h = if T === BigFloat
    sha1hex(join(string.(a), ","))
  else
    GC.@preserve a sha1hex(unsafe_wrap(Array, convert(Ptr{UInt8}, pointer(a)), sizeof(a)))
  end
  head = T === BigFloat ? "" : join((bitstring(a[i]) for i in 1:min(3, length(a))), ",")
  string(size(a), ":", h, ":", head)
end

const TREE_DIR_REF = Ref("")
esc_str(s::AbstractString) = begin
  t = String(s)
  isempty(TREE_DIR_REF[]) || (t = replace(t, TREE_DIR_REF[] => "<TREE>"))
  replace(replace(t, "\\" => "\\\\"), "\n" => "\\n")
end

function ser_value(io::IO, key::AbstractString, v)
  if v isa BigFloat
    println(io, key, " BigFloat ", precision(v), " ", string(v))
  elseif v isa AbstractFloat
    println(io, key, " ", typeof(v), " ", bitstring(v))
  elseif v isa Bool || v isa Integer
    println(io, key, " ", typeof(v), " ", v)
  elseif v isa AbstractArray{<:AbstractFloat}
    println(io, key, " ", typeof(v), " ", vsig(v))
  elseif v isa AbstractString || v isa Symbol
    println(io, key, " ", esc_str(string(v)))
  elseif v === nothing
    println(io, key, " nothing")
  else
    println(io, key, " ", typeof(v), " ", esc_str(repr(v)))
  end
end

ser_exc(io::IO, key::AbstractString, e) = println(io, key, " ", typeof(e), " ", esc_str(sprint(showerror, e)))

# Runs f with stdout redirected to a temporary file; returns (result, exception, text).
function capture_stdout(f)
  path, io = mktemp()
  res = nothing
  exc = nothing
  try
    res = redirect_stdout(f, io)
  catch e
    exc = e
  finally
    close(io)
  end
  txt = read(path, String)
  rm(path; force = true)
  (res, exc, txt)
end
