using Random
r = Xoshiro(7); println(VERSION, " rand: ", rand(r, 3), " randperm(8): ", randperm(copy(r), 8), " shuffle!: ", shuffle!(copy(r), collect(1:8)))
