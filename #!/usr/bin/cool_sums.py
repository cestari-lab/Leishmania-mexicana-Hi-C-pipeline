#!/usr/bin/env python3
"""Print total contact sum, non-zero pixel count and mean for .cool files.

Usage:
    python3 cool_sums.py [--check-equal] file1.cool file2.cool ...

--check-equal  flag any file whose sum differs from the median by > 5 %.
"""
import argparse
import os
import sys

import h5py
import numpy as np

SUFFIXES = ("_norm_scaled_clean.cool", "_norm_scaled.cool", "_merged.cool",
            "_5kb_KR.cool", ".cool")


def short_name(path):
    name = os.path.basename(path)
    for s in SUFFIXES:
        if name.endswith(s):
            return name[: -len(s)]
    return name


def stats(path):
    with h5py.File(path, "r") as fh:
        counts = fh["pixels"]["count"][:]
    return float(np.sum(counts, dtype=np.float64)), len(counts), float(np.mean(counts)) if len(counts) else 0.0


def main():
    p = argparse.ArgumentParser(description=__doc__,
                                formatter_class=argparse.RawDescriptionHelpFormatter)
    p.add_argument("files", nargs="+")
    p.add_argument("--check-equal", action="store_true")
    p.add_argument("--tolerance", type=float, default=0.05)
    a = p.parse_args()

    rows = [(short_name(f), *stats(f)) for f in a.files]
    median = float(np.median([r[1] for r in rows]))
    bad = 0
    for name, total, nnz, mean in rows:
        line = f"{name:<12} sum={total:>15,.0f}  nnz={nnz:>11,}  mean={mean:>8.2f}"
        if a.check_equal:
            ok = abs(total - median) <= a.tolerance * median
            bad += not ok
            line += "  [OK]" if ok else "  [CHECK]"
        print(line)
    sys.exit(1 if bad else 0)


if __name__ == "__main__":
    main()
