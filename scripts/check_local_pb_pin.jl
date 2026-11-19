const FULL_SHA = r"\A[0-9a-f]{40}\z"
full_sha(value) = value isa String && occursin(FULL_SHA, value)
nonempty_string(value) = value isa String && !isempty(strip(value))
valid_path(value) = nonempty_string(value) && !occursin('\0', value)
lookup(table, key) = table isa AbstractDict ? get(table, key, nothing) : nothing

function git_state(dir, file)
    git = Sys.which("git")
    git === nothing && return "Git state unknown"
    function code(args...)
        cmd = `$git --no-optional-locks -C $dir $args`
        cmd = addenv(cmd, "GIT_DIR" => nothing, "GIT_WORK_TREE" => nothing,
                     "GIT_COMMON_DIR" => nothing, "GIT_INDEX_FILE" => nothing)
        return run(pipeline(ignorestatus(cmd); stdout=devnull, stderr=devnull)).exitcode
    end
    file = "." * Base.Filesystem.path_separator * file
    listed = code("ls-files", "--error-unmatch", "--", file)
    listed == 0 && return "tracked"
    listed == 1 || return "Git state unknown"
    ignored = code("check-ignore", "-q", "--", file)
    ignored == 0 && return "Git-ignored"
    return ignored == 1 ? "untracked" : "Git state unknown"
end

function read_toml(file)
    try
        # Use the loader's built-in TOML parser to avoid writing precompile caches.
        return Base.parsed_toml(file)
    catch err
        err isa Base.TOML.ParserError || err isa SystemError || err isa Base.IOError || rethrow()
        return nothing
    end
end

function pb_entry(manifest, uuid)
    # Format 2 nests package entries under deps. Format 1 lists them at the top level.
    format = get(manifest, "manifest_format", nothing)
    format in (nothing, "2.0", "2.1") || return nothing
    table = format === nothing ? manifest : get(manifest, "deps", nothing)
    table isa AbstractDict || return nothing
    entries = get(table, "ProximalBase", nothing)
    entries isa Vector && length(entries) == 1 || return nothing
    entry = only(entries)
    lookup(entry, "uuid") == uuid || return nothing
    for (name, group) in table
        name == "ProximalBase" && continue
        group isa Vector && any(other -> lookup(other, "uuid") == uuid, group) && return nothing
    end
    return entry
end

function check_local_pb_pin(io, dir)
    println(io, "ProximalBase local pin check (Julia $VERSION)")
    finish(status, reason) = (println(io, status, " — ", reason); status)
    project = joinpath(dir, "Project.toml")
    println(io, "  Project: ", project)
    isfile(project) || return finish("UNVERIFIABLE", "Project.toml is missing.")
    isfile(joinpath(dir, "JuliaProject.toml")) &&
        return finish("UNVERIFIABLE", "JuliaProject.toml takes precedence over Project.toml.")

    parsed_project = read_toml(project)
    parsed_project isa AbstractDict ||
        return finish("UNVERIFIABLE", "Could not parse Project.toml.")
    source = lookup(lookup(parsed_project, "sources"), "ProximalBase")
    expected, url = lookup(source, "rev"), lookup(source, "url")
    full_sha(expected) && println(io, "  Expected revision: ", expected)
    uuid = lookup(lookup(parsed_project, "deps"), "ProximalBase")
    uuid isa String && tryparse(Base.UUID, uuid) !== nothing ||
        return finish("UNVERIFIABLE", "Project.toml has no valid ProximalBase dependency UUID.")
    project_path = lookup(source, "path")
    pinned = source isa AbstractDict && length(source) == 2 && full_sha(expected) && nonempty_string(url)
    path_source = source isa AbstractDict && length(source) == 1 && valid_path(project_path)
    pinned || path_source ||
        return finish("UNVERIFIABLE", "Expected a ProximalBase Git source with a full 40-character revision or an explicit path source.")

    # Use Julia's loader to honor minor-specific precedence and workspace selection.
    manifest = try
        Base.project_file_manifest_path(project)
    catch err
        err isa InterruptException && rethrow()
        return finish("UNVERIFIABLE", "Julia could not select a manifest.")
    end
    if manifest === nothing
        println(io, "  Instantiate the project when a run needs its dependencies.")
        return finish("MISSING", "No local manifest for this Julia version.")
    end

    state = git_state(dir, relpath(manifest, dir))
    println(io, "  Manifest: ", manifest, " [", state, "]")
    ordinary = dirname(manifest) == dir && basename(manifest) in Base.manifest_names
    parsed_manifest = read_toml(manifest)
    parsed_manifest isa AbstractDict ||
        return finish("UNVERIFIABLE", "Could not parse the selected manifest.")
    entry = pb_entry(parsed_manifest, uuid)
    entry === nothing &&
        return finish("UNVERIFIABLE", "Expected exactly one ProximalBase entry with the project dependency UUID.")

    revision = lookup(entry, "repo-rev")
    revision isa String && println(io, "  Manifest revision: ", repr(revision))
    haskey(entry, "entryfile") &&
        return finish("UNVERIFIABLE", "The ProximalBase manifest entry overrides the package entry file.")

    if haskey(entry, "path")
        path = entry["path"]
        valid_path(path) && !any(key -> haskey(entry, key), ("repo-url", "repo-rev", "repo-subdir", "git-tree-sha1")) ||
            return finish("UNVERIFIABLE", "The ProximalBase path entry is malformed or has conflicting Git metadata.")
        if path_source && normpath(joinpath(dir, project_path)) != normpath(joinpath(dirname(manifest), path))
            return finish("UNVERIFIABLE", "The ProximalBase path differs between Project.toml and the manifest.")
        end
        finish("PATH / DEV WORKSPACE", "ProximalBase uses the local path $(repr(path)).")
        println(io, "  For an intentional Pkg.develop workspace, use --strict --allow-path.")
        return "PATH / DEV WORKSPACE"
    end

    pinned || return finish("UNVERIFIABLE", "The manifest has a Git entry but the project declares a ProximalBase path.")
    ordinary || return finish("UNVERIFIABLE", "The selected manifest is outside the ordinary local manifest names.")
    get(entry, "repo-url", nothing) == url && full_sha(revision) &&
        full_sha(lookup(entry, "git-tree-sha1")) && !haskey(entry, "repo-subdir") ||
        return finish("UNVERIFIABLE", "Expected the project Git URL, a full revision and a tree hash for ProximalBase.")

    if revision == expected
        if VERSION.major == 1 && VERSION.minor == 10 &&
           basename(manifest) == "Manifest-v1.10.toml" && state == "tracked"
            return finish("MISSING", "No local override is active. Julia 1.10 uses the tracked baseline.")
        end
        return finish("MATCH", "The local ProximalBase revision agrees with Project.toml.")
    end

    finish("STALE", "The local ProximalBase revision differs from Project.toml.")
    if state == "tracked"
        println(io, "  See the tracked pin policy in CONTRIBUTING.md.")
    else
        state == "Git state unknown" && println(io, "  Confirm the manifest is untracked before proceeding.")
        println(io, "  Back up the manifest shown above outside the repository. From the repository root,")
        println(io, "  substitute the same Julia binary or launcher and channel for julia in these commands:")
        println(io, "    julia --startup-file=no --project=. -e 'using Pkg; Pkg.instantiate()'")
        println(io, "  Rerun the checker, then smoke-test imports with that same Julia:")
        println(io, "    julia --startup-file=no --project=. -e 'using ProximalBase, ProximalSolvers'")
    end
    return "STALE"
end

function main(args)
    if any(arg -> arg != "--strict" && arg != "--allow-path", args)
        println(stderr, "Usage: check_local_pb_pin.jl [--strict] [--allow-path]")
        return 2
    end
    status = check_local_pb_pin(stdout, pwd())
    "--strict" in args || return 0
    status in ("MATCH", "MISSING") && return 0
    return status == "PATH / DEV WORKSPACE" && "--allow-path" in args ? 0 : 1
end

exit(main(ARGS))
