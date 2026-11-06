"""Offline tests of check_reset_probes.py: the recorded probe outputs pass, and each
synthetic defect is refused. Run: python3 -m unittest test_check_reset_probes -v"""

import contextlib
import io
import os
import tempfile
import unittest

import check_reset_probes as chk

HERE = os.path.dirname(os.path.abspath(__file__))
RESULTS = os.path.join(HERE, "results")


def read(name):
    with open(os.path.join(RESULTS, name), encoding="utf-8") as handle:
        return handle.read()


def run(a_text, b_text=None):
    """Run the checker on texts; return (exit code, stdout, stderr)."""
    with tempfile.TemporaryDirectory() as tmp:
        argv = []
        for flag, text in (("--a", a_text), ("--b", b_text)):
            if text is None:
                continue
            path = os.path.join(tmp, flag[2:] + ".tsv")
            with open(path, "w", encoding="utf-8") as handle:
                handle.write(text)
            argv += [flag, path]
        out, err = io.StringIO(), io.StringIO()
        with contextlib.redirect_stdout(out), contextlib.redirect_stderr(err):
            code = chk.main(argv)
        return code, out.getvalue(), err.getvalue()


def replace_value(text, key, value):
    lines = []
    seen = False
    for line in text.splitlines():
        if line.split("\t", 1)[0] == key:
            line = f"{key}\t{value}"
            seen = True
        lines.append(line)
    assert seen, key
    return "\n".join(lines) + "\n"


def drop_key(text, key):
    kept = [l for l in text.splitlines() if l.split("\t", 1)[0] != key]
    assert len(kept) < len(text.splitlines()), key
    return "\n".join(kept) + "\n"


class RecordedProbes(unittest.TestCase):
    def test_recorded_outputs_pass_on_each_julia_version(self):
        for version in ("1.10.12", "1.13.3"):
            code, out, _ = run(read(f"reset-{version}-054.tsv"), read(f"reset-{version}-master.tsv"))
            self.assertEqual(code, 0, out)
            self.assertIn("RESET PROBE: PASS", out)

    def test_p14_needs_the_port_on_master_only(self):
        code, out, _ = run(read("reset-1.13.3-054.tsv"), read("reset-1.13.3-master.tsv"))
        self.assertEqual(code, 0, out)
        a, b = out.split("## B")
        self.assertIn("P14 reviewed port needed: no", a)
        self.assertIn("P14 reviewed port needed: yes", b)
        self.assertIn("P14 active coordinates kept by the historical reset: 4", b)

    def test_master_facts_are_reported(self):
        _, out, _ = run(read("reset-1.13.3-054.tsv"), read("reset-1.13.3-master.tsv"))
        b = out.split("## B")[1]
        self.assertIn("QUIC LogDetLoss throws on an asymmetric matrix: yes", b)
        self.assertIn("symmetric owner is an AbstractMatrix: true", b)


class SyntheticDefects(unittest.TestCase):
    def setUp(self):
        self.a = read("reset-1.13.3-054.tsv")
        self.b = read("reset-1.13.3-master.tsv")

    def refused(self, a, b=None, needle=None):
        code, out, _ = run(a, b)
        self.assertEqual(code, 1, out)
        self.assertIn("RESET PROBE: FAIL", out)
        if needle:
            self.assertIn(needle, out)

    def test_ported_reset_that_keeps_active_coordinates(self):
        bad = replace_value(self.b, "sparse.fill0_dropzeros.nactive", "4")
        bad = replace_value(bad, "sparse.fill0_dropzeros.matches_fresh_workingset", "false")
        self.refused(self.a, bad, "sparse.fill0_dropzeros")

    def test_atom_reset_that_changes_the_layout(self):
        bad = replace_value(self.b, "atom.warm_start.after.matches_start_active", "false")
        self.refused(self.a, bad, "atom.warm_start.after.matches_start_active")

    def test_atom_reset_that_is_not_idempotent(self):
        bad = replace_value(self.b, "atom.cold_start.repeat.matches_start_values", "false")
        self.refused(self.a, bad, "repeat.matches_start_values")

    def test_error_value_is_a_failure_not_a_skip(self):
        bad = replace_value(self.b, "atom.warm_overlap.after.matches_start_values", "ERROR MethodError")
        self.refused(self.a, bad, "raised")

    def test_missing_observation(self):
        self.refused(self.a, drop_key(self.b, "atom.cold_start.after.matches_start_active"), "missing")

    def test_a_and_b_end_in_different_working_sets(self):
        bad = replace_value(self.b, "atom.cold_start.after.active", "1,2,3")
        self.refused(self.a, bad, "atom.cold_start.after.active differs")

    def test_probes_of_different_julia_versions_are_not_compared(self):
        self.refused(self.a, read("reset-1.10.12-master.tsv"), "compare probes of one Julia version")

    def test_all_finite_but_invalid_still_refused(self):
        # Every value present and well formed, yet the ported reset is wrong.
        bad = replace_value(self.a, "sparse.fill0_dropzeros.all_values_zero", "false")
        self.refused(bad, None, "sparse.fill0_dropzeros.all_values_zero")

    def test_missing_reset_status(self):
        self.refused(self.a, drop_key(self.b, "atom.warm_start.copyto.status"), "missing observation atom.warm_start.copyto.status")

    def test_reset_status_error(self):
        bad = replace_value(self.b, "atom.warm_start.copyto.status", "ERROR MethodError")
        self.refused(self.a, bad, "atom.warm_start.copyto.status")

    def test_status_of_the_ported_reset_error_with_state_flags_true(self):
        bad = replace_value(self.b, "sparse.fill0_dropzeros.status", "ERROR DomainError")
        self.refused(self.a, bad, "sparse.fill0_dropzeros.status")

    def test_status_of_the_repeated_reset_error(self):
        bad = replace_value(self.b, "atom.cold_start.repeat.status", "ERROR BoundsError")
        self.refused(self.a, bad, "atom.cold_start.repeat.status")

    def test_equal_error_values_for_the_state_on_both_sides(self):
        a = replace_value(self.a, "sparse.fresh.active", "ERROR MethodError")
        b = replace_value(self.b, "sparse.fresh.active", "ERROR MethodError")
        a = replace_value(a, "sparse.fill0_dropzeros.active", "ERROR MethodError")
        b = replace_value(b, "sparse.fill0_dropzeros.active", "ERROR MethodError")
        self.refused(a, b, "sparse.fresh.active raised")

    def test_error_state_is_refused_without_a_second_stack(self):
        self.refused(replace_value(self.a, "sparse.fresh.active", "ERROR MethodError"), None, "raised")

    def test_different_values_restored_on_the_two_stacks(self):
        bad = replace_value(self.b, "atom.warm_start.start.values_hash", "123")
        bad = replace_value(bad, "atom.warm_start.after.values_hash", "123")
        self.refused(self.a, bad, "atom.warm_start.start.values_hash differs")

    def test_reset_restores_other_values_than_the_start_within_a_stack(self):
        bad = replace_value(self.b, "atom.warm_overlap.after.values_hash", "123")
        self.refused(self.a, bad, "differs from the start")

    def test_the_same_stack_given_as_a_and_b(self):
        self.refused(self.b, self.b, "not a cross-version comparison")

    def test_a_is_not_the_historical_stack(self):
        self.refused(self.b, None, "A must be ProximalBase 0.5.4")

    def test_error_operand_in_a_matches_line(self):
        bad = replace_value(self.b, "atom.cold_start.after.matches_start_active", "ERROR operand")
        self.refused(self.a, bad, "atom.cold_start.after.matches_start_active")

    def test_duplicate_key_is_a_format_error(self):
        code, _, err = run(self.a + "probe.julia\t1.13.3\n")
        self.assertEqual(code, 2)
        self.assertIn("duplicate key", err)

    def test_line_without_a_tab_is_a_format_error(self):
        code, _, err = run(self.a + "garbage line\n")
        self.assertEqual(code, 2)
        self.assertIn("no tab", err)


if __name__ == "__main__":
    unittest.main()
