"""Regenerate both scientific summaries and compare them with retained evidence."""
import tempfile
from pathlib import Path
from summarize import evaluate

root = Path(__file__).resolve().parent / "evidence" / "20261025"
with tempfile.TemporaryDirectory() as temporary:
    for phase in ("main", "accuracy_control", "confirmation"):
        output = Path(temporary) / phase
        evaluate(root / phase, phase, output)
        summaries = root / f"{phase}-summary"
        assert {f.name for f in summaries.iterdir()} == {f.name for f in output.iterdir()}
        for saved in summaries.iterdir():
            assert saved.read_bytes() == (output / saved.name).read_bytes(), saved
print("SLOPE_EVIDENCE_REPRODUCTION_PASSED")
