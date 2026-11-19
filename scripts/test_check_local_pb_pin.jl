using Test

const CHECKER = joinpath(@__DIR__, "check_local_pb_pin.jl")
const PIN = "405780632bb5f4f5cfbb2193798c96945db602cf"
const OLD = "c123d56ba1948e36a8fdbf183a9eea396a16e0d5"
const URL = "https://github.com/mlakolar/ProximalBase.jl"
const UUID = "0a755509-c5b1-5d6f-9b24-59bcda3c37a3"
const VERSIONED = "Manifest-v$(VERSION.major).$(VERSION.minor).toml"
const PROJECT = """
    [deps]
    ProximalBase = "$UUID"

    [sources]
    ProximalBase = {rev = "$PIN", url = "$URL"}
    """
const HEADER = "manifest_format = \"2.0\"\n\n"
const PB = "[[deps.ProximalBase]]\nuuid = \"$UUID\"\n"

git_source(rev) = PB * """
    repo-rev = "$rev"
    repo-url = "$URL"
    git-tree-sha1 = "1b6dab757300df2569e65bb09ec39e16b37ddc4f"
    """

function fixture(args...; project=PROJECT, ordinary=nothing, versioned=nothing, track_versioned=false)
    return mktempdir() do tmp
        dir = mkdir(joinpath(tmp, "checkout"))
        files = Dict("Project.toml" => project,
                     ".gitignore" => "/Manifest*.toml\n!/$VERSIONED\n")
        ordinary === nothing || (files["Manifest.toml"] = ordinary)
        versioned === nothing || (files[VERSIONED] = versioned)
        for (name, content) in files
            write(joinpath(dir, name), content)
        end

        # Use a private depot and exclude user Git configuration and repository overrides.
        config = joinpath(tmp, "empty.gitconfig")
        write(config, "")
        env = ("PATH" => ENV["PATH"], "JULIA_DEPOT_PATH" => joinpath(tmp, "depot"),
               "GIT_CONFIG_GLOBAL" => config, "GIT_CONFIG_NOSYSTEM" => "1")
        run(setenv(`git init -q --template= $dir`, env))
        if track_versioned
            run(setenv(`git -C $dir add -- $VERSIONED`, env))
        end
        cmd = `$(Base.julia_cmd()) --startup-file=no --project=@stdlib $CHECKER $args`
        out = IOBuffer()
        process = run(pipeline(ignorestatus(setenv(Cmd(cmd; dir), env)); stdout=out, stderr=out))

        @test Set(readdir(dir)) == union(keys(files), [".git"])
        @test all(read(joinpath(dir, name), String) == content for (name, content) in files)
        return process.exitcode, String(take!(out))
    end
end

function expect(status, code, args...; kwargs...)
    result, output = fixture(args...; kwargs...)
    @test result == code
    @test occursin("\n$status — ", output)
    return output
end

@testset "Local ProximalBase preflight" begin
    matching = HEADER * git_source(PIN)
    stale = HEADER * git_source(OLD)
    path = HEADER * PB * "path = \"../ProximalBase.jl\"\n"

    expect("MISSING", 0, "--strict")
    match_output = expect("MATCH", 0, "--strict"; ordinary=matching)
    @test occursin(PIN, match_output) && occursin("[Git-ignored]", match_output)

    stale_output = expect("STALE", 0; ordinary=stale)
    @test occursin(PIN, stale_output) && occursin(OLD, stale_output)
    @test occursin("Manifest.toml [Git-ignored]", stale_output)
    @test occursin("outside the repository", stale_output)
    @test occursin("Pkg.instantiate()", stale_output)
    @test occursin("using ProximalBase, ProximalSolvers", stale_output)
    expect("STALE", 1, "--strict"; ordinary=stale)

    expect("PATH / DEV WORKSPACE", 0; ordinary=path)
    expect("PATH / DEV WORKSPACE", 1, "--strict"; ordinary=path)
    expect("PATH / DEV WORKSPACE", 0, "--strict", "--allow-path"; ordinary=path)
    expect("UNVERIFIABLE", 1, "--strict", "--allow-path"; ordinary=HEADER * PB * "path = 42\n")

    expect("UNVERIFIABLE", 0; ordinary="[[deps.ProximalBase\n")
    expect("UNVERIFIABLE", 1, "--strict"; ordinary=HEADER * git_source(PIN) * git_source(PIN))
    expect("UNVERIFIABLE", 1, "--strict"; ordinary=HEADER * PB)
    expect("UNVERIFIABLE", 1, "--strict"; ordinary=replace(stale, "repo-url = \"$URL\"\n" => ""))
    expect("UNVERIFIABLE", 1, "--strict"; ordinary=replace(matching, PIN => PIN * "\\n"))
    expect("UNVERIFIABLE", 1, "--strict"; project=replace(PROJECT, "rev = \"$PIN\", " => ""),
           ordinary=matching)

    expect("STALE", 1, "--strict"; ordinary=matching, versioned=stale)
    state = VERSIONED == "Manifest-v1.10.toml" ? "MISSING" : "MATCH"
    baseline = expect(state, 0, "--strict"; ordinary=stale, versioned=matching, track_versioned=true)
    @test occursin("$VERSIONED [tracked]", baseline)
    tracked = expect("STALE", 1, "--strict"; versioned=stale, track_versioned=true)
    @test !occursin("Back up the manifest", tracked)
end
