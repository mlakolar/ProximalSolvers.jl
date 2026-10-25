"""Prepare copied pinned environments on Discovery; no numerical execution.

Usage: python3 harness/prepare.py /absolute/run/path [--final]
Extract the PS snapshot into source/ (old) or source335/ (final), HDM into
hdm/, and the harness files into harness/ beforehand.
"""
from pathlib import Path
import re
import sys
run=Path(sys.argv[1]).resolve()
prior=Path('/home1/mkolar/juliaPkg/runs/20261025-cd82-compare/env')
final='--final' in sys.argv[2:]
env=run/('combined-env335' if final else 'combined-env')
env.mkdir(exist_ok=True)
project=(prior/'Project.toml').read_text()
# Only add direct standard-library imports for the comparison harness.
project=project.replace('[deps]','[deps]\nLinearAlgebra = "37e2e46d-f89d-539d-b4ee-838fcccc9c8e"\nRandom = "9a3f8284-a2c9-5f02-9a11-845980a1fd5c"\nSparseArrays = "2f01184e-e22b-5df5-ae63-d93ebab69eaf"\nStatistics = "10745b16-79ce-11e8-11f9-7d13ad32a3b2"\nTest = "8dfed614-e22c-5e08-85e1-65c5234f0b40"')
(env/'Project.toml').write_text(project)
manifest=(prior/'Manifest.toml').read_text()
for name,path in {
    'CoordinateDescent':run/'hdm',
    'ProximalSolvers':run/('source335' if final else 'source'),
    'ProximalBase':Path('/home1/mkolar/juliaPkg/runs/20261025T0850Z-ps-slope/base'),
}.items():
    pattern=r'(\[\[deps\.'+name+r'\]\]\n)(.*?)(?=\n\[\[deps\.|\Z)'
    def replace(match,path=path):
        block=match[2]
        block=re.sub(r'^(?:path|repo-url|repo-rev|git-tree-sha1|registries) = .*\n','',block,flags=re.M)
        return match[1]+'path = "'+str(path)+'"\n'+block
    manifest,count=re.subn(pattern,replace,manifest,flags=re.S)
    assert count==1,name
(env/'Manifest.toml').write_text(manifest)
