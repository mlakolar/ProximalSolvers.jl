import csv,glob,sys
E='<local>/ps-320/.codex-orchestrator/runs/run-20261118T0124-issue320-31d8/evidence/'
tag=sys.argv[1]
profs=sys.argv[2].split(',') if len(sys.argv)>2 else ['H']
solv=sys.argv[3] if len(sys.argv)>3 else 'pgd'
print("rev-jv  design draw prof | conv term it | gap | kkt | k* | first_prop(set,gate) nprop nrej | xcheck")
for d in sorted(glob.glob(E+tag+'/*/')):
    f=d+'run-summary.tsv'
    try: rows=list(csv.DictReader(open(f),delimiter='\t'))
    except Exception as e: print(d,'missing'); continue
    for r in rows:
        if r['T']!='Float32' or r['solver']!=solv or r['profile'] not in profs: continue
        print(d.split('/')[-2].ljust(15), r['design'],r['draw'],r['profile'],'|',r['converged'],r['termination'],r['iterations'],'| %.3e'%float(r['gap']),'| %.2e'%float(r['kkt_rel']),'|',r['kstar'],'|',r['first_prop_iter'],r['first_prop_set'],r['first_prop_gate'],r['n_prop'],r['n_gate_reject'],'|',r['xcheck'],'|',r['status'])
