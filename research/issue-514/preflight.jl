using LinearAlgebra, Pkg, SHA, TOML
import ProximalBase as PB
import ProximalSolvers as PS
BLAS.set_num_threads(1)
root = @__DIR__
for (label, mod, expected, expected_tree) in (
        ("pb", PB, "050aca8bdd12a7f6174ad6acfeab29be3d76ffdb", "5f6efa04b67810f6fa0bea2795bff3a15bdb49ce"),
        ("ps", PS, "4988a16161dfb4e95b7a9fadc148104f3f023686", "7069c7d4ddff7e89bacb1c1b85dd471137b52594"))
    loaded = dirname(dirname(realpath(pathof(mod))))
    @assert loaded == realpath(joinpath(root, label))
    rev = readchomp(`git -C $loaded rev-parse HEAD`)
    tree = readchomp(`git -C $loaded rev-parse 'HEAD^{tree}'`)
    @assert (rev, tree) == (expected, expected_tree)
    @assert isempty(readchomp(`git -C $loaded status --porcelain --untracked-files=no`))
    sha = bytes2hex(open(sha256, pathof(mod)))
    println("source\t", label, "\t", relpath(pathof(mod), root), "\t", rev, "\t", tree, "\t", sha)
end
@assert PS.LeastSquaresLoss === PB.LeastSquaresLoss && PS.leastsquares_data === PB.leastsquares_data
pin = TOML.parsefile(joinpath(root, "ps", "Project.toml"))["sources"]["ProximalBase"]["rev"]
println("committed_pb_pin\t", pin)
println("julia\t", VERSION, "\tthreads\t", Threads.nthreads(), "\tblas_threads\t", BLAS.get_num_threads(),
        "\tblas\t", BLAS.get_config(), "\tcpu\t", Sys.CPU_NAME, "\topt_level\t", Base.JLOptions().opt_level,
        "\tbounds\t", Base.JLOptions().check_bounds)
@assert Threads.nthreads() == BLAS.get_num_threads() == 1
for T in (Float32, Float64)
    for (g, u) in ((PB.IndBallL1(T(0.1)), T[1, 1]), (PB.IndBallL2(one(T)), T[T == Float32 ? 1 : 3, 11, 0, 0]))
        y, z = similar(u), similar(u)
        PB.prox!(y, g, u, one(T))
        v = PB.value_and_prox!(z, g, u, one(T))
        @assert bitstring.(y) == bitstring.(z) && isequal(v, g(y))
        println("projection\t", T, "\t", nameof(typeof(g)), "\t", v, "\t", join(bitstring.(y), ","))
    end
end
