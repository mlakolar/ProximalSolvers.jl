# P14 reset test summary (exploratory; not a measurement)

`test_p14_reset.jl` run at the port commit fb9b1692069dec4778f24a6732a325ab1c05f1b7. Stack `a`: ProximalBase registered 0.5.4 (release tree 1226119eb2cc6144f7345c727f0e7682632f7826). Stack `b`: ProximalBase development commit 233c11cc284284fbd29df487308b4ee962f875a1 (a probe identity, not a 0.6 candidate). Stack `base`: the same development commit with the harness reset as it was before the port (`fill!(x, 0.0)` for the sparse iterate), to show that the test can fail.

| Julia | stack | exit | header | sparse reset | dense reset | real path cases | solver RNG | verdict |
|:--|:--|--:|:--|:--|:--|:--|:--|:--|
| 1.10.12 | a | 0 | ProximalBase 0.5.4, Julia 1.10.12, threads 1 | PASS | PASS | PASS | PASS | PASS |
| 1.10.12 | b | 0 | ProximalBase 0.6.0-DEV, Julia 1.10.12, threads 1 | PASS | PASS | PASS | PASS | PASS |
| 1.10.12 | base | 1 | ProximalBase 0.6.0-DEV, Julia 1.10.12, threads 1 | FAIL | PASS | PASS | PASS | FAIL |
| 1.13.3 | a | 0 | ProximalBase 0.5.4, Julia 1.13.3, threads 1 | PASS | PASS | PASS | PASS | PASS |
| 1.13.3 | b | 0 | ProximalBase 0.6.0-DEV, Julia 1.13.3, threads 1 | PASS | PASS | PASS | PASS | PASS |
| 1.13.3 | base | 1 | ProximalBase 0.6.0-DEV, Julia 1.13.3, threads 1 | FAIL | PASS | PASS | PASS | FAIL |

Observation: on the development commit the real path cases also pass with the pre-port reset (the path output after a second call is bitwise equal to the first). The pre-port reset is detected by the sparse reset group, which shows that on a used iterate it leaves the working set active (4, 3 and 7 active coordinates in the three non-empty synthetic cases); what that does to the work of a real timed path call was not measured here.
