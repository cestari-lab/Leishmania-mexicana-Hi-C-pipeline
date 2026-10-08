#!/bin/bash
#SBATCH --job-name=hic_coarsen
#SBATCH --time=02:00:00
#SBATCH --cpus-per-task=4
#SBATCH --mem=16G
#SBATCH --output=logs/04_coarsen-%j.log
# -----------------------------------------------------------------------------
# Step 4 — Coarsen 1 kb coolers to 5 kb (factor set in config.sh).
# Input : $COOL_1KB_DIR/<sample>.cool
# Output: $COOL_5KB_DIR/<sample>_5kb.cool
# Note  : sample names in later steps must match SAMPLES in config.sh, so the
#         1 kb .cool files should be named e.g. Wildtype_1.cool.
# -----------------------------------------------------------------------------
set -euo pipefail
CONFIG="${SLURM_SUBMIT_DIR:-.}/config.sh"
[[ -f "$CONFIG" ]] || { echo "config.sh not found — run: cp config.example.sh config.sh" >&2; exit 1; }
source "$CONFIG"
activate_python_env

RES_LABEL="$(( BASE_RES * COARSEN_FACTOR / 1000 ))kb"
mkdir -p "$COOL_5KB_DIR"

for f in "$COOL_1KB_DIR"/*.cool; do
    base=$(basename "$f" .cool)
    echo "[$(date)] Coarsening $base -> ${RES_LABEL}"
    cooler coarsen -k "$COARSEN_FACTOR" \
        -o "$COOL_5KB_DIR/${base}_${RES_LABEL}.cool" \
        "$f"
done

echo "[$(date)] Coarsening done"
