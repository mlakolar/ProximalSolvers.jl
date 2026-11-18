# Verbatim instrumented copy of PS._certify! generated from the source text (src/cd/sqrtlasso.jl): only the name and
# the final returns change (extra internals gap, Dlo, t are returned). Evaluated in module ProximalSolvers.
const SRC = "<WORK>/ps-353/src/cd/sqrtlasso.jl"
function gen_probe()
  lines = readlines(SRC)
  i0 = findfirst(l -> startswith(l, "function _certify!"), lines)
  i1 = findnext(l -> l == "end", lines, i0)
  body = join(lines[i0:i1], "\n")
  body = replace(body, "function _certify!(" => "function _certify_probe!(")
  o1 = "  Dlo > 0 || return :failed, NaN"
  o2 = "  ratio <= _CERT_TARGET ? (:certified, ratio) : (:failed, ratio)"
  @assert occursin(o1, body) && occursin(o2, body)
  body = replace(body, o1 => "  Dlo > 0 || return :failed, NaN, (gap = gap, Dlo = Dlo, t = t)")
  body = replace(body, o2 => "  ratio <= _CERT_TARGET ? (:certified, ratio, (gap = gap, Dlo = Dlo, t = t)) : (:failed, ratio, (gap = gap, Dlo = Dlo, t = t))")
  Core.eval(ProximalSolvers, Meta.parse(body))
end
gen_probe()
