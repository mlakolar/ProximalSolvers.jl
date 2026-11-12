import csv
import itertools
from pathlib import Path
import subprocess
import tempfile

analyzer=Path(__file__).with_name('analyze.py')
with tempfile.TemporaryDirectory() as directory:
    root=Path(directory)
    solve_header=['comparison','type','n','p','occupancy','round','side','seconds','bytes','diagnostics']
    copy_header=['operation','type','p','old_active','new_active','round','seconds','bytes']
    solves=[]
    for c,t,(n,p),o in itertools.product(('dense-base-head','dense-head-control','dense-owner'),('Float32','Float64'),((128,32),(1024,256)),('low','full')):
        for r,side in itertools.product(range(1,31),(0,1)):
            solves.append([c,t,n,p,o,r,side,.001,100,'same'])
    copies=[]
    for op,t,p in itertools.product(('copy','copyto'),('Float32','Float64'),(1000,100000,1000000)):
        for old,new in ((10,10),(p,10),(p//8-1,p//8-1),(p//8,p//8),(p,p)):
            for r in range(1,31):
                copies.append([op,t,p,old,new,r,.001,100])
    def write(name,header,rows):
        with (root/name).open('w') as file:
            writer=csv.writer(file,delimiter='\t');writer.writerow(header);writer.writerows(rows)
    def run(expect):
        result=subprocess.run(['python3','-I',str(analyzer),str(root)],capture_output=True,text=True)
        assert (result.returncode==0)==expect,(result.returncode,result.stderr)
    (root/'metadata.toml').write_text('')
    write('solve.tsv',solve_header,solves);write('copy.tsv',copy_header,copies)
    run(True)
    write('solve.tsv',solve_header,solves[60:]);run(False)
    write('solve.tsv',solve_header,solves)
    write('copy.tsv',copy_header,copies[30:]);run(False)
    write('copy.tsv',copy_header,copies)
    write('solve.tsv',solve_header,solves[1:]);run(False)
    write('solve.tsv',solve_header,solves)
    broken=[list(row) for row in solves];broken[0][-1]='changed'
    write('solve.tsv',solve_header,broken);run(False)
    broken=[list(row) for row in solves];broken[0][7]='nan'
    write('solve.tsv',solve_header,broken);run(False)
print('ANALYZER_CONTROLS_PASS complete,missing-solve-group,missing-copy-group,missing-row,changed-diagnostics,nonfinite-time')
