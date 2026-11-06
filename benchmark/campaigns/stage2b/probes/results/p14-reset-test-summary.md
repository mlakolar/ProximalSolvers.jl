# P14 reset test summary (exploratory; not a measurement)

`test_p14_reset.jl` at commit 21f6e87b (the test that reads the iterate captured by the real `reset!` closure), harness files of the port commit fb9b1692069dec4778f24a6732a325ab1c05f1b7. Julia 1.10.12 and 1.13.3, one thread, on a cluster.

Stacks:
- `a`: ProximalBase registered 0.5.4 (release tree 1226119eb2cc6144f7345c727f0e7682632f7826).
- `b`: ProximalBase development commit 233c11cc284284fbd29df487308b4ee962f875a1 (a probe identity, not a 0.6 candidate), harness as in the PR.
- `base` (negative control 1): `b` with the harness helper's sparse branch replaced by `fill!(x, 0.0)` (the pre-port operation), closure still calling the helper.
- `wire` (negative control 2): `b` with the helper intact but `path_case_state`'s `reset!` closure rewired to `fill!(x, 0.0)`.

| Julia | stack | exit | sparse reset (helper) | dense reset | real path cases (closure state, repeats, grid8 and grid16) | solver RNG | verdict |
|:--|:--|--:|:--|:--|:--|:--|:--|
| 1.10.12 | a | 0 | PASS | PASS | PASS | PASS | PASS |
| 1.10.12 | b | 0 | PASS | PASS | PASS | PASS | PASS |
| 1.10.12 | base | 1 | FAIL | PASS | FAIL | PASS | FAIL |
| 1.10.12 | wire | 1 | PASS | PASS | FAIL | PASS | FAIL |
| 1.13.3 | a | 0 | PASS | PASS | PASS | PASS | PASS |
| 1.13.3 | b | 0 | PASS | PASS | PASS | PASS | PASS |
| 1.13.3 | base | 1 | FAIL | PASS | FAIL | PASS | FAIL |
| 1.13.3 | wire | 1 | PASS | PASS | FAIL | PASS | FAIL |

Observations (Julia 1.13.3, stack `wire`): the real reset closure leaves the previous working set active after a used path solve (for `paths/lasso/cd/grid8/call` repetition 1 the captured iterate keeps 5 active coordinates after `reset!()`), and the closure-state group fails while the helper group passes; on the development commit with the port (`b`) every group passes. On the development commit the path output after a second call is bitwise equal to the first with the old reset as well, so the old reset differs in the starting working set, not in the path output; what that does to the work of a timed call was not measured here.
