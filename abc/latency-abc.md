
### Julia 1.10.13

| solver | T | loss | order | A s | B s | C s | C/A | C/B |
|---|---|---|---|---|---|---|---|---|
| cd | Float32 | raw | raw-scaled | 0.057 | 0.050 | 0.042 | 0.729 | 0.837 |
| cd | Float32 | raw | scaled-raw | 0.057 | 0.049 | 0.041 | 0.724 | 0.841 |
| cd | Float64 | raw | raw-scaled | 0.059 | 0.052 | 0.044 | 0.747 | 0.853 |
| cd | Float64 | raw | scaled-raw | 0.059 | 0.052 | 0.044 | 0.739 | 0.850 |
| pg | Float32 | raw | raw-scaled | 0.364 | 0.364 | 0.199 | 0.548 | 0.547 |
| pg | Float32 | raw | scaled-raw | 0.363 | 0.363 | 0.208 | 0.574 | 0.574 |
| pg | Float64 | raw | raw-scaled | 0.315 | 0.309 | 0.176 | 0.558 | 0.570 |
| pg | Float64 | raw | scaled-raw | 0.308 | 0.308 | 0.176 | 0.570 | 0.569 |
| apg | Float32 | raw | raw-scaled | 0.559 | 0.559 | 0.286 | 0.511 | 0.512 |
| apg | Float32 | raw | scaled-raw | 0.559 | 0.558 | 0.295 | 0.528 | 0.528 |
| apg | Float64 | raw | raw-scaled | 0.554 | 0.546 | 0.281 | 0.506 | 0.514 |
| apg | Float64 | raw | scaled-raw | 0.546 | 0.547 | 0.281 | 0.514 | 0.514 |
| **six-solve sum** | | raw | raw-scaled | 1.908 | 1.879 | 1.027 | 0.539 | 0.547 |
| **six-solve sum** | | raw | scaled-raw | 1.892 | 1.877 | 1.045 | 0.552 | 0.557 |
| **six-solve sum** | | scaled | raw-scaled | 0.000 | 0.000 | 0.000 | 1.081 | 1.092 |
| **six-solve sum** | | scaled | scaled-raw | 0.001 | 0.001 | 0.001 | 0.817 | 0.912 |

| arm | PB precompile s | PS precompile s | PB cache MB | PS cache MB | `using` s |
|---|---|---|---|---|---|
| A | 6.47 | 5.34 | 10.59 | 6.74 | 0.331 |
| B | 8.87 | 5.47 | 14.37 | 6.89 | 0.338 |
| C | 8.95 | 5.33 | 14.38 | 6.84 | 0.338 |

largest scaled first-call median s: {'A': 0.0003, 'B': 0.0003, 'C': 0.0003}

### Julia 1.13.3

| solver | T | loss | order | A s | B s | C s | C/A | C/B |
|---|---|---|---|---|---|---|---|---|
| cd | Float32 | raw | raw-scaled | 0.091 | 0.084 | 0.087 | 0.954 | 1.035 |
| cd | Float32 | raw | scaled-raw | 0.091 | 0.083 | 0.086 | 0.952 | 1.044 |
| cd | Float64 | raw | raw-scaled | 0.090 | 0.082 | 0.086 | 0.950 | 1.044 |
| cd | Float64 | raw | scaled-raw | 0.090 | 0.083 | 0.091 | 1.013 | 1.105 |
| pg | Float32 | raw | raw-scaled | 0.461 | 0.460 | 0.271 | 0.587 | 0.588 |
| pg | Float32 | raw | scaled-raw | 0.461 | 0.457 | 0.271 | 0.586 | 0.592 |
| pg | Float64 | raw | raw-scaled | 0.423 | 0.408 | 0.236 | 0.558 | 0.579 |
| pg | Float64 | raw | scaled-raw | 0.422 | 0.407 | 0.236 | 0.558 | 0.580 |
| apg | Float32 | raw | raw-scaled | 0.798 | 0.796 | 0.414 | 0.519 | 0.520 |
| apg | Float32 | raw | scaled-raw | 0.798 | 0.818 | 0.414 | 0.518 | 0.506 |
| apg | Float64 | raw | raw-scaled | 0.788 | 0.777 | 0.395 | 0.501 | 0.508 |
| apg | Float64 | raw | scaled-raw | 0.790 | 0.779 | 0.395 | 0.500 | 0.507 |
| **six-solve sum** | | raw | raw-scaled | 2.651 | 2.607 | 1.488 | 0.561 | 0.571 |
| **six-solve sum** | | raw | scaled-raw | 2.653 | 2.626 | 1.493 | 0.563 | 0.568 |
| **six-solve sum** | | scaled | raw-scaled | 0.000 | 0.001 | 0.000 | 1.067 | 0.753 |
| **six-solve sum** | | scaled | scaled-raw | 0.002 | 0.002 | 0.002 | 0.871 | 0.824 |

| arm | PB precompile s | PS precompile s | PB cache MB | PS cache MB | `using` s |
|---|---|---|---|---|---|
| A | 7.23 | 5.82 | 9.57 | 5.14 | 0.417 |
| B | 9.51 | 5.95 | 12.00 | 5.20 | 0.424 |
| C | 9.15 | 5.86 | 12.00 | 5.16 | 0.423 |

largest scaled first-call median s: {'A': 0.0005, 'B': 0.0005, 'C': 0.0004}
