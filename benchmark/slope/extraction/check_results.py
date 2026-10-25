"""Regenerate the extraction summary, retaining complete request accounting."""
import csv
import json
import math
import re
from pathlib import Path
from statistics import median

ROOT=Path(__file__).resolve().parent
DATA=ROOT/'evidence/20261025'

def summarize(data):
    rows=[]
    for process in (1,2,3):
        with (data/f'process-{process}.tsv').open() as stream:
            rows.extend(csv.DictReader(stream,delimiter='\t'))
    expected={(str(process),str(seed),rho,prepared,backend,str(block))
              for process in (1,2,3) for seed in (1,2,3) for rho in ('0.0','0.9')
              for prepared in ('false','true') for backend in ('legacy','engine','wrapper')
              for block in (1,2,3)}
    def key(r):
        return tuple(r[k] for k in ('process','seed','rho','intercept','backend','block'))
    assert len(rows)==len(expected)==324
    assert len({key(r) for r in rows})==len(rows)
    assert {key(r) for r in rows}==expected
    for r in rows:
        assert r['intercept']==r['standardize']
        assert int(r['levels'])==int(r['valid_levels'])==12
        assert r['metadata_equal']=='true'
        for field in ('seconds','bytes','max_residual','coefficient_error','prediction_error'):
            assert math.isfinite(float(r[field])) and float(r[field])>=0,(field,r)
        assert float(r['seconds'])>0
        assert float(r['max_residual'])<=1e-7*(1+1e-5)
        assert float(r['coefficient_error'])<=2e-6
        assert float(r['prediction_error'])<=2e-5
    pairs={}
    for r in rows:
        k=tuple(r[f] for f in ('process','seed','rho','intercept','block'))
        pairs.setdefault(k,{})[r['backend']]=r
    strata=[]
    for rho in ('0.0','0.9'):
        for prepared in ('false','true'):
            subset=[backends for k,backends in pairs.items() if k[2:4]==(rho,prepared)]
            assert len(subset)==27
            strata.append({'rho':float(rho),'intercept_and_standardize':prepared=='true','paired_requests':len(subset),
                           'wrapper_over_legacy':median(float(p['wrapper']['seconds'])/float(p['legacy']['seconds']) for p in subset),
                           'engine_over_legacy':median(float(p['engine']['seconds'])/float(p['legacy']['seconds']) for p in subset),
                           'wrapper_bytes_over_legacy':median(float(p['wrapper']['bytes'])/float(p['legacy']['bytes']) for p in subset)})
    return {'paths':len(rows),'valid_paths':len(rows),'points':sum(int(r['levels']) for r in rows),
            'valid_points':sum(int(r['valid_levels']) for r in rows),'process_repetitions':3,'seeds':[1,2,3],
            'randomized_blocks':3,'all_metadata_equal':True,
            'max_residual':max(float(r['max_residual']) for r in rows),
            'max_coefficient_error':max(float(r['coefficient_error']) for r in rows),
            'max_prediction_error':max(float(r['prediction_error']) for r in rows),
            'strata':strata}

if __name__=='__main__':
    result=summarize(DATA/'final')
    previous=summarize(DATA)
    for folder, worker_file in ((DATA/'validation', 'workers.tsv'),
                                (DATA/'final/validation', 'workers-final.tsv')):
        with (folder/worker_file).open() as stream:
            workers=list(csv.DictReader(stream,delimiter='\t'))
        assert len(workers)==3
        assert all(w['Exitval']=='0' and w['Signal']=='0' for w in workers)
    for version in ('1.13.2','1.10.12'):
        receipt=(DATA/'final/validation'/f'tests-final-{version}.log').read_text()
        assert re.search(r'\|\s+53\s+53\s+',receipt)
    assert previous==json.loads((ROOT/'summary_before_input_guards.json').read_text())
    import sys
    summary=ROOT/'summary.json'
    if '--write' in sys.argv:
        summary.write_text(json.dumps(result,indent=2,sort_keys=True)+'\n')
    else:
        assert result==json.loads(summary.read_text()),'Summary differs from complete raw records'
    print(json.dumps(result,indent=2,sort_keys=True))
