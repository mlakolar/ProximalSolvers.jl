# Offline simulation of stopping-rule variants on the recorded per-iteration PGD trajectories (Float32 or
# Float64). Iterates and line search do not depend on the stop rule, so a rule is evaluated on the recorded
# quantities. The solver's computed gate residual is represented by the probe's widened recomputation
# (Gs_rel, from the solver's own gradient), so a simulated baseline can differ from the library on a
# borderline comparison; sim_vs_actual() counts those.
import csv, glob, os, math, collections, statistics as stt

E = '<local>/ps-320/.codex-orchestrator/runs/run-20261118T0124-issue320-31d8/evidence/'
EPS = {'Float32': 2.0**-23, 'Float64': 2.0**-52}

def rd(path):
    rows = []
    with open(path) as fh:
        for r in csv.DictReader(fh, delimiter='\t'):
            d = {}
            for k, v in r.items():
                if v in ('true', 'false'): d[k] = (v == 'true')
                else:
                    try: d[k] = float(v)
                    except: d[k] = v
            rows.append(d)
    return rows

def stop(rows, T, ftol=1e-15, xtol=1e-14, gradtol=1e-11, allow_incr=False, maxiter=10000,
         floor_mult=64.0, incr_c=None, gapc=None, gapsrc='gapc32', gate_off=False):
    """returns (k, converged, term) with k = stop iteration (1-based) or None when the trajectory ends first"""
    eps = EPS[T]
    tau = max(gradtol, floor_mult * eps)
    prevF = None
    for row in rows:
        k = int(row['k'])
        F = row['F']
        stalled = (ftol == 0) and row['unchanged']
        xraw = (not stalled) and row['dxx'] == 0.0 and xtol > 0 and True
        frel = ftol != 0 and row['fres'] < ftol
        fulp = ftol != 0 and row['ulp']
        r_, m_, N_, rho = row['r'], row['m'], row['N'], row['rho']
        graw = ((r_ < gradtol * m_ and rho < m_) or (r_ < gradtol * N_ and rho < N_)) and not stalled
        prop = xraw or frel or fulp or graw
        conv = False
        if prop:
            ok = row['Gs_rel'] < tau and row['Gs_rel'] == row['Gs_rel']
            if gapc is not None:
                ok = ok and (row[gapsrc] <= gapc)
            conv = ok
        incr = row['incr']
        if incr and incr_c is not None and prevF is not None:
            incr = (F - prevF) > incr_c * eps * abs(F)
        stag = (ftol == 0) and row['stagc']
        if conv: return k, True, 'conv'
        if (incr and not allow_incr): return k, False, 'f_increased'
        if stag: return k, False, 'stagnated'
        if k >= maxiter: return k, False, 'maxiter'
        prevF = F
    return None, False, 'runs_on'

PROFILES = {  # (kwargs) of the named library profiles, per type
    'H': dict(ftol=1e-15, xtol=1e-14, gradtol=1e-11, allow_incr=False),
    'D': dict(ftol=1e-6, xtol=1e-8, gradtol=1e-5, allow_incr=False, maxiter=200),
    'S': dict(ftol=0, xtol=1e-300, gradtol=1e-11, allow_incr=True),
    'A': dict(ftol=0, xtol=1e-14, gradtol=1e-10, allow_incr=True),
}
