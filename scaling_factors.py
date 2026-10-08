#!/usr/bin/env python3
"""Compute depth-matching factors: factor = smallest_sum / sum(file).

Usage:
    python3 scaling_factors.py WT_merged.cool CAS9_merged.cool ...

Prints one line per file:  <condition> <sum> <factor>
The condition name is the file name with "_merged.cool" stripped.
"""
import os
import sys

import h5py
import numpy as np


def total(path):
    with h5py.File(path, "r") as fh:
        return float(np.sum(fh["pixels"]["count"][:], dtype=np.float64))


def main():
    files = sys.argv[1:]
    if not files:
        sys.exit(__doc__)
    sums = {os.path.basename(f).replace("_merged.cool", "").replace(".cool", ""): total(f)
            for f in files}
    smallest = min(sums.values())
    for name, s in sums.items():
        factor = smallest / s
        print(f"{name} {s:.0f} {'1.000000' if s == smallest else f'{factor:.6f}'}")


if __name__ == "__main__":
    main()
