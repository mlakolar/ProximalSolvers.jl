import csv,sys,collections,statistics as S
rows=list(csv.DictReader(open(sys.argv[1]),delimiter='\t'))
by=collections.defaultdict(list)
for r in rows: by[r['rule']].append(r)
fam=sys.argv[2] if len(sys.argv)>2 else 'random'
for rule in ['B','A1','A2','A3','A5','A10','A20','A50','A100','A200']:
    rs=[r for r in by[rule] if r['family']==fam]
    fired=[r for r in rs if r['stop']!='0']
    prem=[r for r in fired if r['premature']=='true']
    hitbase=[r for r in rs if r['base_hit']!='0']
    saved=[1-int(r['prods_stop'])/int(r['prods_end']) for r in fired]
    lost=[r for r in fired if r['base_hit']!='0' and float(r['gap_stop'])>1e-5]
    print(f"{rule:5s} n={len(rs)} fired={len(fired)} premature={len(prem)} target-lost={len(lost)} baseline-hit={len(hitbase)} "
          f"mean saved(fired)={S.mean(saved)*100 if saved else 0:.1f}% median stop={S.median([int(r['stop']) for r in fired]) if fired else '-'}")
    for r in prem[:4]:
        print("    PREMATURE",r['case'],"stop",r['stop'],"gap_stop",r['gap_stop'],"later_min",r['later_gap_min'],"gain",r['later_P_gain'],"base_hit",r['base_hit'])
