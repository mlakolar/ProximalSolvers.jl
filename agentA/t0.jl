for T in (Float32, Float64)
  println(T, " floatmin/eps=", floatmin(T)/eps(T), " sqrt=", sqrt(floatmin(T)/eps(T)), " floatmax sqrt=", sqrt(floatmax(T)))
end
