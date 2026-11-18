from pathlib import Path
import gzip,csv,json,collections,hashlib
B=Path('<RUN>/evidence')
counts=collections.Counter();early=[]
for f in sorted((B/'sweep-r-epyc').glob('scalar_Float32_*.tsv.gz')):
 with gzip.open(f,'rt') as z:
  for r in csv.DictReader(z,delimiter='\t'):
   if r['converged']!='true' or r['relative']!='true':continue
   false=r['informative']=='true' and float(r['subopt_lo'])>1e-5 and float(r['E'])>int(r['p'])*float(r['tolerance'])
   if false:
    counts['false']+=1
    counts['A_without_floor_caught']+=float(r['A'])>=float(r['tolerance'])
    counts['A_c64_caught']+=float(r['Aq'])>=64
    if r['design']!='rankdef' and r['start']=='adv' and int(r['j'])<=4:
     early.append({'file':f.name,'row':r,'sum_start_images_over_response':float(r['P0'])/(2**-23*float(r['resp']))})
root=Path('.codex-orchestrator/review378');hashbad=[];nh=0
for l in (root/'checksums/sweep-l-xeon.SHA256SUMS').read_text().splitlines():
 h,p=l.split(None,1);nh+=1
 if hashlib.sha256((B/'sweep-l-xeon'/p).read_bytes()).hexdigest()!=h:hashbad.append(p)
x={'counts':dict(counts),'early_cases':early,'fourth_raw_hashes_checked':nh,'fourth_raw_hash_mismatches':hashbad}
json.dump(x,open('.codex-orchestrator/review-probes-r2/edge-claims.json','w'),indent=2)
print('counts',dict(counts));print('A_without_floor_percent',100*counts['A_without_floor_caught']/counts['false']);print('A_c64_percent',100*counts['A_c64_caught']/counts['false'])
for e in early:print('early case',e['file'],{k:e['row'][k] for k in ['design','loss','j','dir','container','order','momentum','seed','tol','subopt_lo','E','tolerance']},'sum start image ratio',e['sum_start_images_over_response'])
print('fourth_raw_hashes_checked',nh,'mismatches',hashbad)
