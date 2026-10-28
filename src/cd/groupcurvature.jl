####################################
#
#  The curvature of a loss over a group of coordinates
#
####################################

# Block coordinate descent on an AtomIterate majorizes the loss over a group G
# with its curvature, the largest eigenvalue of a |G| × |G| Gram matrix: of the
# centered, weighted columns X[:, G] for least squares, A[G, G] for a quadratic.
# eigmax(Symmetric(C)) finds it with LAPACK's syevr, but allocates a copy of C
# and syevr's work arrays on every call, besides the copy of X[:, G] that forms
# C. The workspace keeps all of them, sized for the largest group: it is grown on
# the first curvature that needs it, so a solve allocates it once. It calls
# syevr with the arguments of eigmax, on the matrix that eigmax would get.
mutable struct _GroupEig{T}
  nmax::Int                 # the largest group it has room for
  B::Matrix{T}              # n × nmax: the centered, weighted columns of a group
  C::Vector{T}              # nmax²: the Gram matrix of a group, as a |G| × |G| matrix
  w::Vector{T}              # the eigenvalue found by syevr
  isuppz::Vector{BlasInt}
  work::Vector{T}
  iwork::Vector{BlasInt}
  m::Base.RefValue{BlasInt}
  info::Base.RefValue{BlasInt}
end

_GroupEig{T}() where {T} =
  _GroupEig{T}(0, Matrix{T}(undef, 0, 0), T[], T[], BlasInt[], T[], BlasInt[], Ref{BlasInt}(0), Ref{BlasInt}(0))

for (syevr, T) in ((:dsyevr_, :Float64), (:ssyevr_, :Float32))
  @eval function _syevr_max!(ws::_GroupEig{$T}, n::Int, lwork::Integer, liwork::Integer)
    ccall((@blasfunc($syevr), libblastrampoline), Cvoid,
          (Ref{UInt8}, Ref{UInt8}, Ref{UInt8}, Ref{BlasInt}, Ptr{$T}, Ref{BlasInt},
           Ref{$T}, Ref{$T}, Ref{BlasInt}, Ref{BlasInt}, Ref{$T}, Ptr{BlasInt}, Ptr{$T},
           Ptr{$T}, Ref{BlasInt}, Ptr{BlasInt}, Ptr{$T}, Ref{BlasInt}, Ptr{BlasInt}, Ref{BlasInt},
           Ptr{BlasInt}, Clong, Clong, Clong),
          'N', 'I', 'U', n, ws.C, max(1, n), zero($T), zero($T), n, n, -one($T), ws.m, ws.w,
          ws.w, max(1, n), ws.isuppz, ws.work, lwork, ws.iwork, liwork, ws.info, 1, 1, 1)
    ws.info[]
  end
end

# room for groups of up to nmax entries, with nrows rows of centered columns
function _reserve!(ws::_GroupEig{T}, nmax::Int, nrows::Int) where {T<:Union{Float32, Float64}}
  ws.nmax >= nmax && size(ws.B, 1) == nrows && return ws
  nmax = max(nmax, ws.nmax)
  ws.B = Matrix{T}(undef, nrows, nmax)
  ws.C = zeros(T, nmax^2)
  ws.w = zeros(T, nmax)
  ws.isuppz = zeros(BlasInt, 2nmax)
  # the sizes of the work arrays for nmax suffice for any smaller matrix
  resize!(ws.work, 1); resize!(ws.iwork, 1)
  info = _syevr_max!(ws, nmax, -1, -1)
  info == 0 || throw(LAPACKException(info))
  resize!(ws.work, max(1, round(Int, ws.work[1])))
  resize!(ws.iwork, max(1, Int(ws.iwork[1])))
  ws.nmax = nmax
  ws
end

# the largest eigenvalue of the symmetric n × n matrix in ws.C[1:n²] (its upper
# triangle), destroying it; nothing when syevr fails to converge to that one
# eigenvalue (info > 0), as some LAPACK builds do on a near-identity matrix,
# such as the Gram matrix of an orthonormalized group
function _eigmax!(ws::_GroupEig, n::Int)
  info = _syevr_max!(ws, n, length(ws.work), length(ws.iwork))
  info < 0 && throw(LAPACKException(info))
  info == 0 ? ws.w[1] : nothing
end

# the largest eigenvalue of the symmetric matrix C (dense or sparse) from all of
# its eigenvalues, where _eigmax! fails: computing all of them converges on
# those matrices
_eigmax_all(C) = maximum(eigvals(Symmetric(Matrix(C))))

_maxgroup(x::AtomIterate) = maximum(length, x.groups; init = 0)
