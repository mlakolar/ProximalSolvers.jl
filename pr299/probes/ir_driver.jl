# ir_driver.jl tree1 [tree2 ...]: warms each tree, writes the IR file of each in a fresh process, normalizes, and
# compares trees 2.. with tree 1 per function (identical / differs only in the define line and SSA numbering / body difference).
include(joinpath(@__DIR__, "common.jl"))
child(tree, rest...) = `$(Base.julia_cmd()) --project=$(abspath(tree)) --startup-file=no $(joinpath(@__DIR__, "ir_child.jl")) $(collect(rest))`

# ---- normalization ----------------------------------------------------------------------------------------------
# Level 1 (the brief): drop comments, strip the numeric suffix of function and global names, plus process-dependent
# constants (object addresses, jl_global#N.jit numbering).
function normalize_ir(s::AbstractString)
  out = String[]
  for line in split(s, '\n')
    l = replace(line, r";.*$" => "")                       # comments
    l = replace(l, r"\s+$" => "")
    isempty(strip(l)) && continue
    l = replace(l, r"#\d+\.jit" => ".jit")                                 # @"jl_global#1711.jit"
    l = replace(l, r"@\"([^\"]*?)(?:#\d+|_\d+)\"" => s"@\"\1\"")        # quoted global / function names: drop numeric suffix
    l = replace(l, r"(julia_[A-Za-z0-9_$.#!<>]*?)_\d+\b" => s"\1")      # julia_foo_123 -> julia_foo
    l = replace(l, r"@(jl_[A-Za-z0-9_.]*?)(?:#\d+|_\d+)\b" => s"@\1")
    l = replace(l, r"@(j\d*_[A-Za-z0-9_$.#!<>]*?)_\d+\b" => s"@\1")        # j_foo_1234 (callee of code_llvm) -> j_foo
    l = replace(l, r"(jlplt_[A-Za-z0-9_$.#!<>]*?)_\d+_got" => s"\1_got")  # PLT stub numbering
    l = replace(l, r"inttoptr \(i64 \d+ to" => "inttoptr (i64 PTR to")  # embedded addresses differ per process
    l = replace(l, r"i64 \d{12,}" => "i64 PTR")                           # type tags in allocations and stores
    push!(out, l)
  end
  out
end

# Level 2: canonical local names. Julia's codegen assigns local value names, GC frame slots, attribute-group and metadata
# numbers in an order that is not stable between processes (and shifts when an argument is dropped), so local names,
# labels, `#N` attribute groups, `!N` metadata ids and the offsets of GEPs on the GC frame are renamed by first appearance.
function renumber(lines::Vector{String})
  seen = Dict{String,Int}(); lab = Dict{String,Int}(); att = Dict{String,Int}(); md = Dict{String,Int}()
  canon(d, p) = m -> (get!(d, m, length(d) + 1); string(p, d[m]))
  out = String[]
  # GC frame slots: values defined as GEPs on %gcframe are interchangeable (the slot a root gets is arbitrary)
  slots = Set{String}()
  for l0 in lines
    m = match(r"^\s*(%(?:\"[^\"]*\"|[A-Za-z_][A-Za-z0-9_.$]*|\d+)) = getelementptr[^,]*, ptr %gcframe[A-Za-z0-9_.]*, i64 \d+", l0)
    m === nothing || push!(slots, String(m.captures[1]))
  end
  tokre = r"%(?:\"[^\"]*\"|[A-Za-z_][A-Za-z0-9_.$]*|\d+)"
  for l00 in lines
    l0 = isempty(slots) ? l00 : replace(l00, tokre => (m -> String(m) in slots ? "%GCSLOT" : String(m)))
    l = replace(l0, r"(getelementptr[^,]*, ptr %gcframe[A-Za-z0-9_.]*, i64) \d+" => s"\1 K")
    l = replace(l, r"%(\"[^\"]*\"|[A-Za-z_][A-Za-z0-9_.$]*|\d+)" => canon(seen, "%v"))
    l = replace(l, r"\bL\d+\b" => canon(lab, "L"))
    l = replace(l, r"(?<=\s)#\d+\b" => canon(att, "#A"))
    l = replace(l, r"!\d+\b" => canon(md, "!M"))
    push!(out, l)
  end
  out
end


# multiset summaries of a normalized body: instruction mnemonics and callees
function ops_and_callees(lines)
  ops = Dict{String,Int}(); callees = Dict{String,Int}()
  for l in lines
    t = strip(l)
    (isempty(t) || startswith(t, "define") || t == "}" || endswith(t, ":") || startswith(t, "L")) && continue
    body = occursin(" = ", t) ? split(t, " = "; limit = 2)[2] : t
    op = first(split(body, ' '; limit = 2))
    ops[op] = get(ops, op, 0) + 1
    if op == "call" || op == "invoke" || startswith(body, "tail call")
      m = match(r"@(\"[^\"]+\"|[A-Za-z0-9_.!#<>$]+)", body)
      m === nothing || (callees[m.captures[1]] = get(callees, m.captures[1], 0) + 1)
    end
  end
  (ops, callees)
end
function diff_ms(a::Dict{String,Int}, b::Dict{String,Int})
  out = String[]
  for k in sort!(collect(union(keys(a), keys(b))))
    x, y = get(a, k, 0), get(b, k, 0)
    x == y || push!(out, string(k, " ", x, "->", y))
  end
  out
end

function split_sections(path)
  secs = Dict{String,String}()
  order = String[]
  other = String[]
  cur = nothing
  buf = IOBuffer()
  for line in eachline(path; keep = true)
    if startswith(line, "@@@IR ")
      cur = rstrip(line)[7:end]
      push!(order, cur)
      buf = IOBuffer()
    elseif startswith(line, "@@@END ")
      secs[cur] = String(take!(buf)); cur = nothing
    elseif cur !== nothing
      write(buf, line)
    else
      push!(other, rstrip(line))
    end
  end
  (order, secs, other)
end

function main(trees)
  println("DRIVER julia ", VERSION, " cpu ", Sys.CPU_NAME, " host ", gethostname())
  mkpath(joinpath(abspath(@__DIR__), "out"))
  outdir = mktempdir(joinpath(abspath(@__DIR__), "out"); cleanup = false)
  for t in trees           # serial warm-up: instantiate, precompile, header and PB guard (parallel instantiation races on the PB clone)
    println("DRIVER warm ", basename(abspath(t))); flush(stdout)
    run(child(t, "warm"))
  end
  files = String[]
  procs = []
  logs = String[]
  for (j, t) in enumerate(trees)
    f = joinpath(outdir, string("t", j, "-", basename(abspath(t)), ".ir"))
    lg = f * ".log"
    println("DRIVER spawn tree ", j, " ", basename(abspath(t))); flush(stdout)
    push!(procs, run(pipeline(child(t, f); stdout = lg, stderr = lg); wait = false))
    push!(files, f); push!(logs, lg)
  end
  for p in procs
    wait(p)
  end
  for (j, t) in enumerate(trees)
    println("DRIVER log of ", basename(abspath(t)), " (exit ", procs[j].exitcode, ")")
    for line in eachline(logs[j])
      (startswith(line, "ENV ") || startswith(line, "IR_CHILD") || startswith(line, "Error") || occursin("ERROR", line)) && println("[", j, "] ", first(line, 240))
    end
  end
  all(success, procs) || error("an IR child failed")
  (ord1, secs1, oth1) = split_sections(files[1])
  println("DRIVER IR sections in base: ", length(ord1))
  for l in oth1
    startswith(l, "IRNOCANDIDATE") && println("IRNOCANDIDATE(base) ", l)
  end
  for j in 2:length(trees)
    (ordj, secsj, othj) = split_sections(files[j])
    label = basename(abspath(trees[j]))
    println("DRIVER ==== compare ", basename(abspath(trees[1])), " vs ", label)
    nid = nargs = nreal = nmod = noff = 0
    for key in ord1
      haskey(secsj, key) || (println("IR ", label, " ", key, " MISSING in candidate"); nreal += 1; continue)
      a, b = normalize_ir(secs1[key]), normalize_ir(secsj[key])
      if a == b
        println("IR ", label, " ", key, " IDENTICAL"); nid += 1; continue
      end
      isdef(l) = startswith(l, "define ")
      da, db = renumber(filter(!isdef, a)), renumber(filter(!isdef, b))     # bodies alone: the argument list does not shift the numbering
      defa, defb = renumber(filter(isdef, a)), renumber(filter(isdef, b))
      if da == db && defa == defb
        println("IR ", label, " ", key, " SAME-MODULO-NAMES (identical after canonical local names, GC slots, metadata ids)"); nmod += 1; continue
      end
      if da == db
        println("IR ", label, " ", key, " DEFINE-ONLY (argument list differs; body identical after canonical local names)"); nargs += 1; continue
      end
      maskgep(ls) = [occursin("getelementptr", l) ? replace(l, r"i64 -?\d+" => "i64 N") : l for l in ls]
      if maskgep(da) == maskgep(db)
        println("IR ", label, " ", key, " GEP-OFFSETS-ONLY (", defa == defb ? "" : "argument list differs; ", "body identical except the constant offsets in getelementptr, i.e. struct field offsets)"); noff += 1; continue
      end
      nreal += 1
      println("IR ", label, " ", key, " BODY-DIFFERS (", length(da), " vs ", length(db), " lines)")
      shown = 0
      for i in 1:max(length(da), length(db))
        (i <= length(da) && i <= length(db) && da[i] == db[i]) && continue
        println("   @", i, " base: ", i <= length(da) ? first(da[i], 200) : "<none>")
        println("   @", i, " cand: ", i <= length(db) ? first(db[i], 200) : "<none>")
        (shown += 1) >= 6 && break
      end
      (oa, ca), (ob, cb) = ops_and_callees(a), ops_and_callees(b)
      od, cd = diff_ms(oa, ob), diff_ms(ca, cb)
      println("   instruction multiset (base->cand): ", isempty(od) ? "IDENTICAL (same instructions, different order/operands)" : first(join(od, "; "), 400))
      println("   callee multiset (base->cand): ", isempty(cd) ? "IDENTICAL" : first(join(cd, "; "), 500))
    end
    # extra functions present only in the candidate
    for key in ordj
      haskey(secs1, key) || println("IR ", label, " ", key, " ONLY-IN-CANDIDATE (", length(split(secsj[key], '\n')), " lines)")
    end
    println("IRSUMMARY ", label, " identical=", nid, " same-modulo-names=", nmod, " define-only=", nargs, " gep-offsets-only=", noff, " body-differs-or-missing=", nreal)
    # methods found by name (informational: a changed signature shows here)
    ma = Dict(split(l, ' '; limit = 3)[2] => split(l, ' '; limit = 3)[3] for l in oth1 if startswith(l, "IRMETHODS "))
    mb = Dict(split(l, ' '; limit = 3)[2] => split(l, ' '; limit = 3)[3] for l in othj if startswith(l, "IRMETHODS "))
    nmeth_same = count(k -> get(mb, k, nothing) == ma[k], keys(ma))
    println("IRMETHODS ", label, " method lists identical for ", nmeth_same, " of ", length(ma), " name/tag entries")
    for k in sort!(collect(keys(ma)))
      get(mb, k, nothing) == ma[k] || println("IRMETHODS ", label, " ", k, " DIFFERS", "\n   base: ", first(ma[k], 400), "\n   cand: ", first(get(mb, k, "<none>"), 400))
    end
    for l in othj
      startswith(l, "IRNOCANDIDATE") && println("IRNOCANDIDATE(", label, ") ", l)
    end
    # state types and inference
    ia = filter(l -> startswith(l, "STATETYPE") || startswith(l, "INFER"), oth1)
    ib = filter(l -> startswith(l, "STATETYPE") || startswith(l, "INFER"), othj)
    println("INFERSUMMARY ", label, " ", ia == ib ? "state types and inference results EQUAL to base" : "state types or inference results DIFFER from base")
    if ia != ib
      for (x, y) in zip(ia, ib)
        x == y || (println("   base: ", first(x, 300)); println("   cand: ", first(y, 300)))
      end
    end
  end
  println("DRIVER base inference lines:")
  for l in oth1
    startswith(l, "INFER") && println("  ", first(l, 300))
  end
  println("IR_DRIVER DONE")
end
main(ARGS)
