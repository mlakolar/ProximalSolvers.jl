import csv,collections,sys,statistics as st
def load(f): return list(csv.DictReader(open(f),delimiter='\t'))
base={ (r['id'],r['T'],r['start'],r['config']):r for r in csv.DictReader(open(__import__('os').path.join(__import__('os').path.dirname(__import__('os').path.abspath(__file__)),'../../out/baseline_1.13.tsv')),delimiter='\t')}
def summary(f,label=None):
    rows=load(f)
    trig=[r for r in rows if r['trig']=='true']
    print(f, 'rows',len(rows),'triggered',len(trig))
    # stage-1 consistency with baseline
    mm=collections.Counter()
    for r in rows:
        b=base[(r['id'],r['T'],r['start'],r['config'])]
        same=abs(float(r['base_excess'])-float(b['excess']))<=1e-9*(1+abs(float(b['excess'])))
        mm[(r['config'],same)]+=1
    print('  stage1 == baseline:',dict(mm))
    for T in ('Float64','Float32'):
        c=collections.Counter(r['final_class'] for r in trig if r['T']==T)
        b=collections.Counter(r['base_class'] for r in trig if r['T']==T)
        print('  ',T,'base:',dict(b),'\n        final:',dict(c))
    esc=[float(r['fb_seconds']) for r in trig]
    print('   fb seconds median %.4f max %.3f total %.1f; fb MB median %.3f'%(st.median(esc),max(esc),sum(esc),st.median(float(r['fb_bytes']) for r in trig)/1e6))
    print('   esc accepted total',sum(int(r['esc']) for r in trig),'att',sum(int(r['att']) for r in trig),'escpasses med',st.median(int(r['escpasses']) for r in trig),'respasses med',st.median(int(r['respasses']) for r in trig))
    print('   worse than base (excess>base*(1+1e-9)):',sum(float(r['excess'])>float(r['base_excess'])*(1+1e-9)+1e-15 for r in trig))
if __name__=='__main__':
    for f in sys.argv[1:]: summary(f)
