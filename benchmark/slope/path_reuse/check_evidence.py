"""Reproduce the path-state summaries from every retained raw record."""
import tempfile
from pathlib import Path
from summarize import analyze

root=Path(__file__).resolve().parent/"evidence"/"20261025"
with tempfile.TemporaryDirectory() as temporary:
    for phase in ("main","confirmation"):
        out=Path(temporary)/phase
        analyze(root/phase,phase,out)
        saved=root/f"{phase}-summary"
        assert {p.name for p in saved.iterdir()}=={p.name for p in out.iterdir()}
        for file in saved.iterdir():
            assert file.read_bytes()==(out/file.name).read_bytes(),file
print("PATH_REUSE_EVIDENCE_REPRODUCED")
