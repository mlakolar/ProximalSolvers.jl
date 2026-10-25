"""Reproduce committed control/profiling summaries from complete raw tables."""
import contextlib
import io
import json
import tempfile
from pathlib import Path
from summarize import analyze

root=Path(__file__).resolve().parent/"evidence"/"20261025"
record=json.loads((root/"run.json").read_text())
assert record["native_source"]=="a9899cbf3677ea63236d54dc18626ad3a5aeddc6"
assert record["decision"]=="Hybrid deferred; usefulness and maintainability determine any future prototype, not matching libslope runtime"
for phase in ("canary","main","confirmation"):
    with tempfile.TemporaryDirectory() as temporary:
        out=Path(temporary)
        with contextlib.redirect_stdout(io.StringIO()):coverage=analyze(root/phase,phase,out)
        for file in out.glob("*.json"):
            assert file.read_bytes()==(root/(phase+"-summary")/file.name).read_bytes(),(phase,file.name)
        saved=record["coverage"][phase]
        for field in ("paths","valid_paths","points","valid_points","profile_pairs"):
            assert coverage[field]==saved[field],(phase,field)
print("FIRST_ORDER_EVIDENCE_CHECKS_PASSED")
