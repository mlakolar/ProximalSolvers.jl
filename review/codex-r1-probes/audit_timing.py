import pathlib,csv
B=pathlib.Path('.codex-orchestrator/review378/timing')
K=['design','T','pen','frac','container','order','start']
def read(p):
 ls=p.read_text().splitlines();h=next(i for i,l in enumerate(ls) if l.startswith('design\t'))
 return {tuple(r[k] for k in K):r for r in csv.DictReader([l for l in ls[h:] if len(l.split('\t'))==len(ls[h].split('\t'))],delimiter='\t')}
def median(v):
 v=sorted(v);return v[(len(v)-1)//2]
for tag in ['r-epyc','r-xeon','l-epyc','l-xeon']:
 a=read(B/f'time3-{tag}.txt'); b=read(B/f'time3b-{tag}.txt')
 print(tag)
 for m in ['S256','S1024']:
  def flagged(d):return {k for k,r in d.items() if .98<=float(r['control med'])<=1.02 and float(r[m+' med'])>1.05}
  f,g=flagged(a),flagged(b);print(m,'initial',len(f),'repeat',len(g),'intersection',len(f&g))
  for k in sorted(f&g):print('repeated',k,a[k][m+' med'],b[k][m+' med'],'controls',a[k]['control med'],b[k]['control med'])
  rs=list(a.values());v=[float(r[m+' med']) for r in rs];w=[float(r[m+' med']) for r in rs if r['start']=='warm'];print('table:',median(v),median(w),max(v),len(f))
  ns=[(float(r[m+' med'])-1)*float(r['master ns']) for r in rs if r['start']=='warm' and r['pen']!='group' and float(r['master ns'])<10000];print('median warm extra ns:',round(median(ns)))
