"""Regression check: scientific failures must survive the summary."""
import csv,json,subprocess,sys,tempfile
from pathlib import Path
from check_evidence import FIELDS, expected_identities, validate_grid

# A row-count check alone cannot detect a missing configuration replaced by an
# unexpected one. Exercise exact-grid validation without numerical work.
for phase, count in (("main", 11160), ("confirmation", 1800)):
    grid = [dict(zip(FIELDS, map(str, key))) for key in sorted(expected_identities(phase))]
    assert len(grid) == count
    validate_grid(grid, phase)
    for malformed in (grid[:-1], grid + [grid[0]], [dict(grid[0], seed="999")] + grid[1:]):
        try:
            validate_grid(malformed, phase)
        except AssertionError:
            pass
        else:
            raise AssertionError("malformed experiment grid accepted")

with tempfile.TemporaryDirectory() as td:
    root=Path(td);raw=root/'fixture.csv'
    fields=('family','p','kappa','seed','lambda_fraction','round','method','initialization','valid','seconds','kkt','gap','status')
    with raw.open('w') as h:
        w=csv.writer(h,lineterminator='\n');w.writerow(fields)
        for seed,(ada,base) in enumerate(((True,True),(True,False),(False,True),(False,False)),1):
            for method in ('adaPGM','APG','PG'):
                ok=ada if method=='adaPGM' else base
                w.writerow(('ls',10,1,seed,.05,1,method,'reference' if method=='adaPGM' else 'default',str(ok).lower(),.5 if method=='adaPGM' else 1.,0 if ok else 1.,0 if ok else 1.,'target' if ok else 'time_limit'))
    script=Path(__file__).with_name('summarize.py')
    subprocess.run([sys.executable,str(script),str(raw),'--out',str(root/'out'),'--expected','12'],check=True,capture_output=True)
    primary=json.loads((root/'out'/'primary.json').read_text())
    for record in primary:
        assert record['pairs']==4 and record['both_valid']==1
        assert record['adaptive_only']==1 and record['baseline_only']==1 and record['unresolved']==1
        assert record['median_failure_aware_ratio']==.5
    gate=json.loads((root/'out'/'gate.json').read_text())
    assert gate['primary_success_rate']==.5 and not gate['main_gate']
    duplicate=subprocess.run([sys.executable,str(script),str(raw),str(raw),'--out',str(root/'bad')],capture_output=True)
    assert duplicate.returncode!=0
print('SUMMARY_FAILURE_ACCOUNTING_PASSED')
