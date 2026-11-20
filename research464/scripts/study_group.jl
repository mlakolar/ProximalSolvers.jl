# #464 GroupNormL2 section (record only), with an exactly orthogonal equal-norm design (Hadamard columns), so the
# BigFloat block coordinate-descent reference is exact. v0 = shipped rule; gv1 = per-group max(cₖ, Λ) analogue.
ENV["STUDY_NO_MAIN"] = "1"
include(joinpath(@__DIR__, "study464.jl"))
function hadamard(k)
  H = ones(1, 1)
  for _ in 1:k; H = [H H; H -H]; end
  H
end
function main_group(out)
  println(HEADER)
  y5 = [0.0, 1.0, 1.0, 1.0, 1.0]
  runcase("M group LS one free (B4 analogue)", :ls, [fill(1e150, 5) zeros(5)], y5, 1e300, [0.0, 1.0], LS2;
          groups = [1:1, 2:2])
  H = hadamard(6)[:, 2:11]                      # 64 × 10, orthogonal columns of norm 8
  gr = [1:2, 3:4, 5:6, 7:8, 9:10]
  for T in (Float64, Float32)
    yq = H * vcat(2.0, -1.0, 1.0, 0.5, zeros(6)) + 0.5 * randn(MersenneTwister(5), 64)
    Λ = maximum(norm((H' * yq)[G]) for G in gr)
    for W in (1.0, 1e6, 1e12)
      runcase("M group excluded group W=$(W)", :ls, T.(H), T.(yq), T(0.1Λ), T[0, 1, 1, 1, W], LS2; groups = gr)
    end
    runcase("M group ordinary weights", :ls, T.(H), T.(yq), T(0.1Λ), T[0.5, 1, 1.5, 2, 1], LS2; groups = gr)
  end
  open(out, "w") do io
    println(io, HEADER); foreach(r -> println(io, r), ROWS)
  end
end
main_group(isempty(ARGS) ? "study_group.tsv" : ARGS[1])
