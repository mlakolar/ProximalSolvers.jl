#!/usr/bin/env python3
"""Recompute stored constraint membership from binary coefficients using integers."""
import argparse
import math
from pathlib import Path
import struct

from summarize import read_tsv


def parts(word, fraction_bits, exponent_bits):
    exponent_mask = (1 << exponent_bits) - 1
    exponent = (word >> fraction_bits) & exponent_mask
    if exponent == exponent_mask:
        raise ValueError("nonfinite coefficient")
    mantissa = word & ((1 << fraction_bits) - 1)
    if exponent:
        mantissa |= 1 << fraction_bits
    return mantissa, max(exponent - 1, 0)


def scaled_mass(words, fraction_bits, exponent_bits, power):
    value = 0
    for word in words:
        mantissa, shift = parts(word, fraction_bits, exponent_bits)
        # Scale each absolute coefficient by the reciprocal of the smallest
        # subnormal, then square for ℓ₂. The factor cancels with the radius.
        value += (mantissa ** power) << (power * shift)
    return value


def sign_from_bits(row, vector):
    target = float(row["radius"])
    if row["T"] == "Float32":
        code, target_code, frac, exponent = "<I", "<f", 23, 8
    else:
        code, target_code, frac, exponent = "<Q", "<d", 52, 11
    power = 1 if row["ball"] == "l1" else 2
    raw = bytes.fromhex(vector["x"])
    words = (x[0] for x in struct.iter_unpack(code, raw))
    (radius_bits,) = struct.unpack(code, struct.pack(target_code, target))
    mass = scaled_mass(words, frac, exponent, power)
    limit = scaled_mass((radius_bits,), frac, exponent, power)
    return (mass > limit) - (mass < limit)


def check(directory):
    count = invalid = exterior = 0
    for result_path in sorted(directory.glob("1.*")):
        solves = read_tsv(result_path / "solves.tsv")
        vectors = read_tsv(result_path / "vectors.tsv")
        for row, vector in zip(solves, vectors, strict=True):
            assert all(row[k] == vector[k] for k in ("T", "case", "method", "profile", "arm"))
            try:
                sign = sign_from_bits(row, vector)
            except ValueError:
                assert math.isnan(float(row["signed_margin"]))
                invalid += 1
                continue
            margin = float(row["signed_margin"])
            assert math.isfinite(margin) and sign == (margin > 0) - (margin < 0), row
            if row["arm"] in ("B", "C") and row["success"] == "true":
                assert row["membership"] != "inside" or sign <= 0
                assert row["membership"] != "outside" or sign > 0
            count += 1
            exterior += sign > 0
    print(f"Exact integer signs agreed for {count} finite vectors, including {exterior} exterior. {invalid} nonfinite starts.")

if __name__ == "__main__":
    cli = argparse.ArgumentParser(description=__doc__)
    cli.add_argument("results", type=Path)
    check(cli.parse_args().results)
