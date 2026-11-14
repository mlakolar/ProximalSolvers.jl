# Selection decision (written 2026-11-14T10:19:32-08:00, before any conf file was opened)

Rule as preregistered, applied to sel draws 1–4, each Julia version separately and pooled (identical decisions):

```
pg F64: P1: eligible=False false_success=53 missed_reachable=53 return_gm_ms=1.091 n=240; P2: eligible=True false_success=0 missed_reachable=0 return_gm_ms=1.342 n=240  => P2
pg F32: P1: eligible=False false_success=55 missed_reachable=53 return_gm_ms=0.341 n=240; P2: eligible=False false_success=6 missed_reachable=5 return_gm_ms=0.901 n=240  => none
apg F64: P1: eligible=False false_success=58 missed_reachable=58 return_gm_ms=0.796 n=240; P2: eligible=True false_success=0 missed_reachable=0 return_gm_ms=1.079 n=240  => P2
apg F32: P1: eligible=False false_success=64 missed_reachable=64 return_gm_ms=0.363 n=240; P2: eligible=False false_success=5 missed_reachable=5 return_gm_ms=1.293 n=240  => none
```

- PGD Float64: P2. APG Float64: P2.
- PGD Float32 and APG Float32: no candidate is eligible. Every P2 false success is on ill/low/cold: the relative gradient test fires with gaps of 1e-5 to 1e-4. Confirmation still reports all profiles for Float32, as controls and as a check that the failure reproduces.
