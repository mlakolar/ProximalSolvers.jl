import csv,collections,statistics
from pathlib import Path
r=Path('..')
def rows(p):return list(csv.DictReader((r/p).open(),delimiter='\t'))
b=rows('out/baseline_1.13.tsv');print('BASE',collections.Counter(x['class'] for x in b));print('codesmiss',collections.Counter(x['cert_code'] for x in b if x['class']=='missed-cert(156)'))
for T in ['Float64','Float32']:
 rr=[x for x in b if x['T']==T];print(T,collections.Counter(x['class'] for x in rr))
print('nonopt all min median max',*[f([float(x['excess']) for x in b if x['class']=='nonoptimal(155)']) for f in [min,statistics.median,max]])
real=rows('out/realistic.tsv');print('REAL',len(real))
for fac in ['1.0','0.5','0.25']:
 for T in ['Float64','Float32']:
  a=[x for x in real if x['lamfac']==fac and x['T']==T];print(fac,T,len(a),collections.Counter(x['class'] for x in a),collections.Counter(x['opt_exact'] for x in a))
  if fac=='0.25':
   a=[x for x in a if x['class']=='nonoptimal(155)'];v=[float(x['excess']) for x in a];print(min(v),statistics.median(v),max(v))
d=rows('out/orch_d2_rigorous.tsv')
for T in ['Float64','Float32']:
 a=[x for x in d if x['T']==T];v=sorted(int(x['passes']) for x in a);print('D2',T,'N',len(a),'passes med',statistics.median(v),'p90nearest',v[round(.9*(len(v)-1))],'max',max(v),'false',sum(x['false_cert']=='true' for x in a));print('budgets',[sum(x['outcome']=='certified' and int(x['passes'])<=k for x in a) for k in [500,1000,2000,5000,20000]])
 print('missed breakdown',collections.Counter((x['outcome'],x['via']) for x in a if x['class0']=='missed-cert(156)'))
u=rows('agents/A/out/unify.tsv');print('184same set?',all((x['v_ok']=='true')==(x['prod_code']=='certified') for x in u));print('same ratios',sum(x['prod_ratio']==x['v_ratio'] for x in u if x['v_ok']=='true'))
v=rows('agents/A/out/verify_dual.tsv');print('dual N',len(v),'tau abs max',max(abs(float(x['tauC'])-float(x['normXd'])) for x in v),'theta max',max(float(x['thetadiff']) for x in v))
m=rows('agents/A/out/m81_stats.tsv');m=[x for x in m if x['set']=='M81' and x['T']=='Float32'];print('rPmax',max(float(x['rP']) for x in m))
for f in ['A1_113','A2_113','B113','Cm_big','E113','L1','K7']:
 a=rows('agents/B/out/'+f+'.tsv')
 for T in ['Float64','Float32']:
  aa=[x for x in a if x['T']==T and x['trig']=='true'];print('candidate',f,T,len(aa),collections.Counter(x['final_class'] for x in aa))
b110=rows('agents/C/out/baseline_1.10.tsv');print('baseline110',collections.Counter(x['class'] for x in b110))
