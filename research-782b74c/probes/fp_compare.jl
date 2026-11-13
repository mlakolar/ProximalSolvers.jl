# fp_compare.jl: compare two fingerprint record files byte for byte; on a difference, list the first differing records.
# library: include this file and call compare_records(a, b); CLI: julia fp_compare.jl a.rec b.rec
import SHA

function read_records(path)
  recs = Tuple{String,String}[]
  cur = nothing
  buf = IOBuffer()
  for line in eachline(path; keep = true)
    if startswith(line, "CASE ")
      cur === nothing || push!(recs, (cur, String(take!(buf))))
      cur = rstrip(line)[6:end]
    end
    write(buf, line)
  end
  cur === nothing || push!(recs, (cur, String(take!(buf))))
  recs
end

function compare_records(pa::AbstractString, pb::AbstractString; maxshow::Int = 3)
  ba, bb = read(pa), read(pb)
  println("COMPARE ", pa, " ", length(ba), " bytes sha256 ", bytes2hex(SHA.sha256(ba)))
  println("COMPARE ", pb, " ", length(bb), " bytes sha256 ", bytes2hex(SHA.sha256(bb)))
  if ba == bb
    println("COMPARE IDENTICAL (byte for byte)")
    return true
  end
  ra, rb = read_records(pa), read_records(pb)
  da, db = Dict(ra), Dict(rb)
  only_a = [id for (id, _) in ra if !haskey(db, id)]
  only_b = [id for (id, _) in rb if !haskey(da, id)]
  diff = [id for (id, t) in ra if haskey(db, id) && db[id] != t]
  println("COMPARE DIFFERENT: ", length(ra), " vs ", length(rb), " records; only in first ", length(only_a),
          ", only in second ", length(only_b), ", differing ", length(diff))
  for id in diff[1:min(maxshow, end)]
    la, lb = split(da[id], '\n'), split(db[id], '\n')
    k = findfirst(i -> i > length(la) || i > length(lb) || la[i] != lb[i], 1:max(length(la), length(lb)))
    println("COMPARE first difference in record ", id, " at line ", k)
    println("  first : ", k <= length(la) ? first(la[k], 300) : "<missing>")
    println("  second: ", k <= length(lb) ? first(lb[k], 300) : "<missing>")
  end
  false
end

if abspath(PROGRAM_FILE) == @__FILE__
  length(ARGS) == 2 || error("usage: julia fp_compare.jl a.rec b.rec")
  exit(compare_records(ARGS[1], ARGS[2]) ? 0 : 1)
end
