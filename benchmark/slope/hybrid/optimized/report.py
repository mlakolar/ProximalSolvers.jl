#!/usr/bin/env python3
"""Render the bounded Discovery comparison from validated reporting inputs."""
import argparse
import json
from pathlib import Path
from statistics import median
from summarize import read, METHODS


def render(folder):
    summary = json.loads((folder / 'summary.json').read_text())
    rows = [r for path in sorted(folder.glob('worker-[1-4].tsv')) for r in read(path)]
    levels = [r for path in sorted(folder.glob('worker-[1-4].tsv.levels.tsv')) for r in read(path)]
    bycase = {i: {m: [r for r in rows if int(r['case']) == i and r['method'] == m]
                  for m in METHODS} for i in range(1, 221)}
    output = ['# Discovery results: reusable-state SLOPE hybrid', '',
              'These are empirical results on bounded synthetic workloads. Use `SLOPEHybrid()` explicitly; screened APG remains the default.', '',
              'The optimized hybrid uses reusable cluster state and an APG fallback with the existing stopping rules. The original prototype and its adverse results remain in the parent directory. See [the protocol](README.md) for fixtures, stopping targets, allocation scope, versions and recreation.', '',
              f"Coverage: {len(rows):,} requested path fits across 220 workloads and three repetitions per method. {len(levels):,} returned levels out of {summary['requested_levels_all_methods']:,} requested. Every returned level has independent gap and full-residual records.", '',
              '## Accuracy and retained failures', '',
              'A fit passes the common targets only when every requested level has relative feasible dual gap <= 1e-6 and null-gradient-normalized fixed-point residual <= 1e-7. A profiled request additionally requires valid native allocation replay and unchanged inputs. Internal Julia stopping flags are stricter and are reported separately; native flags are unavailable.', '',
              '| Method | Fits passing common accuracy / 660 | Valid profiled requests / 660 | Internal flag failures | Protocol failures | Returned levels |',
              '|---|---:|---:|---:|---:|---:|']
    for method in METHODS:
        strata = [s['methods'][method] for s in summary['strata']]
        fitted = sum(s['fit_accuracy_blocks'] for s in strata)
        profiled = sum(s['certified_blocks'] for s in strata)
        flags = 'unknown' if method == 'libslope' else str(sum(s['internal_flag_failure_blocks'] for s in strata))
        protocol = sum(s['protocol_failure_blocks'] for s in strata)
        output.append(f"| {method} | {fitted} | {profiled} | {flags} | {protocol} | {sum(r['method'] == method for r in levels):,} |")
    output += ['', 'All failures and internal flags remain in `evidence/summary.json` and the raw TSVs. Native fits are bounded by a soft 10-second path cap. A native cap or replay failure is not evidence of inability to converge with more time. No speed claim is made for an uncertified pair.', '',
               '## Paired time and Julia allocation ratios', '',
               'Ratios are hybrid/APG or libslope/APG; below one favors that method. Each case uses the median of three randomized timing blocks. Every repetition of both methods must be a valid profiled request. Cases with false internal flags remain eligible if the common external target passes. Seeds 1–3 are main; 11–12 are confirmation.', '',
               '| Cohort | Seeds | rho | Storage | Hybrid certified pairs | Hybrid time ratio | Hybrid wins | Hybrid Julia bytes ratio | Native certified pairs | Native time ratio |',
               '|---|---|---:|---|---:|---:|---:|---:|---:|---:|']
    fmt = lambda x: 'n/a' if x is None else f'{x:.3f}'
    for s in summary['strata']:
        h, n = (s['paired_over_apg'][m] for m in ('hybrid', 'libslope'))
        output.append(f"| {s['cohort']} | {s['phase']} | {s['rho']:g} | {s['storage']} | {h['certified_cases']}/{s['requested_cases']} | {fmt(h['median_time_ratio'])} | {h['time_wins']} | {fmt(h['median_julia_allocation_ratio'])} | {n['certified_cases']}/{s['requested_cases']} | {fmt(n['median_time_ratio'])} |")
    output += ['', 'Overall paired summaries are descriptive across this fixture mix, not estimates for an application workload:', '',
               '| Seeds | Comparator | Certified pairs | Median time ratio | Time wins | Median Julia byte ratio | Allocation wins |',
               '|---|---|---:|---:|---:|---:|---:|']
    for phase in ('main', 'confirmation'):
        selected = [v for v in bycase.values() if (int(v['apg'][0]['seed']) <= 3) == (phase == 'main')]
        for method in ('hybrid', 'libslope'):
            valid = [v for v in selected if all(r['certified'] == 'true' for m in ('apg', method) for r in v[m])]
            ratios = [median(float(r['seconds']) for r in v[method]) / median(float(r['seconds']) for r in v['apg']) for v in valid]
            allocations = [median(int(r['julia_bytes']) for r in v[method]) / median(int(r['julia_bytes']) for r in v['apg']) for v in valid] if method == 'hybrid' else []
            output.append(f"| {phase} | {method} | {len(valid)}/{len(selected)} | {fmt(median(ratios) if ratios else None)} | {sum(v < 1 for v in ratios)} | {fmt(median(allocations) if allocations else None)} | {sum(v < 1 for v in allocations) if allocations else 'n/a'} |")
    output += ['', '## Allocation traffic and process memory', '',
               'Julia allocation bytes include output snapshots and bridge buffers. Native requested bytes/calls are from a separate instrumented replay of the unchanged pinned static library; allocations internal to dynamic libraries are outside that counter. These are cumulative requested bytes, not live memory. No native/Julia heap-byte ratio is asserted.', '',
               '| Method | Median Julia MiB per valid request | Median wrapped native MiB requested | Median native allocation calls |',
               '|---|---:|---:|---:|']
    for method in METHODS:
        selected = [r for r in rows if r['method'] == method and r['certified'] == 'true']
        julia = median(int(r['julia_bytes']) for r in selected) / 2**20 if selected else None
        native = median(int(r['cpp_bytes']) for r in selected) / 2**20 if selected and method == 'libslope' else None
        calls = str(int(median(int(r['cpp_calls']) for r in selected))) if selected and method == 'libslope' else 'n/a'
        output.append(f'| {method} | {fmt(julia)} | {fmt(native)} | {calls} |')
    if 'rss' in summary:
        output += ['', 'Peak RSS below includes startup, imports, compilation, fixture creation and a warm-up plus repeated fit in a separate process for each method. It is not solver workspace alone. Saved solutions are certified in a different process.', '',
                   '| Case | Method | Peak process MiB | Levels | Common accuracy | Native tolerance |', '|---:|---|---:|---:|---|---|']
        for r in summary.get('rss_primary', summary['rss']):
            output.append(f"| {r['case']} | {r['method']} | {r['peak_process_mib']:.1f} | {r['returned']} | {r['certified']} | {r.get('native_tolerance', '1e-8' if r['method']=='libslope' else 'n/a')} |")
        if 'rss_primary' in summary:
            output += ['', 'The uniform native RSS followup used tolerance 1e-10 with the same 10-second soft cap. It did not make every native path accurate: tighter convergence work can hit the cap. These results supplement the original measurements and do not replace the primary timing/allocation data. Failed rows are not matched-accuracy memory comparisons.', '',
                       '| Case | Native peak process MiB | Levels | Common accuracy | Native tolerance |', '|---:|---:|---:|---|---|']
            for r in summary['rss']:
                if r['method'] == 'libslope':
                    output.append(f"| {r['case']} | {r['peak_process_mib']:.1f} | {r['returned']} | {r['certified']} | {r.get('native_tolerance', '1e-8')} |")
    hybrids = [r for r in rows if r['method'] == 'hybrid']
    output += ['', '## Work and interpretation', '',
               f"Hybrid requests recorded {sum(max(0,int(r['pg_steps'])) for r in hybrids):,} PG/APG steps, {sum(max(0,int(r['cd_sweeps'])) for r in hybrids):,} complete cluster sweeps and {sum(max(0,int(r['fallbacks'])) for r in hybrids):,} fallback events. These units have different costs and are summed across repairs and repetitions. They are not exact design-product counts.", '',
               'Reusable state reduces the prototype\'s allocation burden, but it does not guarantee fewer bytes than APG on every case. The fallback limits wasted hybrid trials; it does not guarantee a speedup. Read the independent controls and confirmation rows as well as the strongly correlated rows. Selection remains explicit and problem-dependent.', '',
               'This implementation specializes single-response least-squares SLOPE. It does not introduce a general cluster solver for other penalties or losses. Numerical certificates do not establish statistical FDR guarantees.', '',
               'Validation, job IDs, source snapshots and the failed development attempts are recorded in `RUN.md`. Plain timing, level certificates, allocation replay diagnostics and memory outputs are retained in `evidence/`.', '']
    return '\n'.join(output)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--input', type=Path, required=True)
    parser.add_argument('--output', type=Path, required=True)
    args = parser.parse_args()
    args.output.write_text(render(args.input))


if __name__ == '__main__':
    main()
