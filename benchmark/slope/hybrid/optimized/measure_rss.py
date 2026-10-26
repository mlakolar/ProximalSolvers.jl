#!/usr/bin/env python3
"""Record Linux child peak RSS and elapsed time without a GNU time dependency."""
import resource
import subprocess
import sys
from pathlib import Path
from time import perf_counter

output = Path(sys.argv[1])
start = perf_counter()
result = subprocess.run(sys.argv[2:], check=False)
elapsed = perf_counter() - start
peak_kib = resource.getrusage(resource.RUSAGE_CHILDREN).ru_maxrss
output.write_text(f'{peak_kib}\t{elapsed:.6f}\t{result.returncode}\n')
sys.exit(result.returncode)
