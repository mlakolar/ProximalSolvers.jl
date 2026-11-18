include(joinpath(@__DIR__, "common.jl"))
println("E11 _SE operation-level error (vs exact BigFloat of the _SE operands), julia ", VERSION)
rng = Xoshiro(11)
randse(T) = PS._SE{T}(rand(rng, T) * 2 + 1 |> x -> min(x, prevfloat(T(2))), rand(rng, rand(rng) < 0.5 ? (-20:20) : (-3000:3000)))
for T in (Float32, Float64)
  u = unit(T)
  worst = Dict("mul" => 0.0, "add" => 0.0, "sub(exact-rel)" => 0.0, "norm_invariant_ok" => 0.0)
  bad_invariant = 0
  for _ in 1:200000
    a, b = randse(T), randse(T)
    ea, eb = se2big(a), se2big(b)
    r = PS._se_mul(a, b);  worst["mul"] = max(worst["mul"], Float64(abs(se2big(r) / (ea * eb) - 1) / u)); (1 <= r.s < 2) || (bad_invariant += 1)
    r = PS._se_add(a, b);  worst["add"] = max(worst["add"], Float64(abs(se2big(r) / (ea + eb) - 1) / u)); (1 <= r.s < 2) || (bad_invariant += 1)
    # a - b only when a > b (the function returns max(a-b,0))
    if ea > eb
      r = PS._se_sub(a, b)
      if iszero(r.s); ea == eb || (bad_invariant += 1)
      else
        worst["sub(exact-rel)"] = max(worst["sub(exact-rel)"], Float64(abs(se2big(r) / (ea - eb) - 1) / u)); (1 <= r.s < 2) || (bad_invariant += 1)
      end
    end
    # comparison agrees with exact order
    PS._se_le(a, b) == (ea <= eb) || (bad_invariant += 1)
  end
  println("  $T: worst |rel err|/u  mul=", round(worst["mul"], digits = 3), " add=", round(worst["add"], digits = 3), " sub=", round(worst["sub(exact-rel)"], digits = 3), "   invariant/order violations=", bad_invariant)
  # zero/overflow behaviour: exponent range is an Int; zero is (0,0); products of zero
  z = PS._se_zero(T); a = PS._SE{T}(T(3))
  println("  $T: zero*a=", PS._se_mul(z, a), "  zero+a==a: ", PS._se_add(z, a) === a, "  le(0,a)=", PS._se_le(z, a), "  le(a,0)=", PS._se_le(a, z), "  sub(a,a)=", PS._se_sub(a, a))
  # constructors from non-finite input (documented as a precondition, not checked)
  for bad in (T(Inf), T(NaN), T(-1))
    r = try; PS._SE{T}(bad); catch err; typeof(err); end
    println("  $T: _SE{T}($bad) -> ", r)
  end
end
