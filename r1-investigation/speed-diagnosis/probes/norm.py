#!/usr/bin/env python3
"""Normalize a native listing (strip labels' numbers, addresses, comments) and print a diff summary of two listings."""
import re, sys, difflib
def norm(path):
    out=[]
    for ln in open(path):
        s=ln.split('#')[0].strip() if not ln.strip().startswith('.') else ''
        if not s or s.endswith(':') or s.startswith('.') or s.startswith(';'): continue
        s=re.sub(r'\.LBB\d+_\d+','L',s); s=re.sub(r'0x[0-9a-f]+','H',s); s=re.sub(r'\bjl_[a-z_0-9]+','jl_',s); s=re.sub(r'\s+',' ',s)
        out.append(s)
    return out
a,b=norm(sys.argv[1]),norm(sys.argv[2])
print(len(a),len(b))
d=[l for l in difflib.unified_diff(a,b,lineterm='',n=0) if not l.startswith('@@')]
print(len(d)); print('\n'.join(d[:int(sys.argv[3]) if len(sys.argv)>3 else 60]))
