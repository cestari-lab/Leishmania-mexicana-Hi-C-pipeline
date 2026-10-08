#!/bin/bash
#SBATCH --job-name=hic_pairtools
#SBATCH --time=12:00:00
#SBATCH --cpus-per-task=16
#SBATCH --mem=120G
#SBATCH --mail-type=ALL
#SBATCH --output=logs/03_pairtools_cool-%j.log
# -----------------------------------------------------------------------------
# Step 3 — SAM -> .pairs -> deduplicated .pairs -> 1 kb .cool
# Input : $MAP_DIR/<sample>.sam
# Output: $COOL_1KB_DIR/<sample>.cool
#         $COOL_1KB_DIR/<sample>_pairs_stats.txt, <sample>_dedup_stats.txt
#         $COOL_1KB_DIR/<sample>.dedup.pairs / .dup.pairs / .unmapped.pairs
# -----------------------------------------------------------------------------
set -euo pipefail
CONFIG="${SLURM_SUBMIT_DIR:-.}/config.sh"
[[ -f "$CONFIG" ]] || { echo "config.sh not found — run: cp config.example.sh config.sh" >&2; exit 1; }
source "$CONFIG"
activate_python_env

CPUS="${SLURM_CPUS_PER_TASK:-16}"
KEEP_INTERMEDIATE="${KEEP_INTERMEDIATE:-0}"   # set to 1 to keep raw/sorted .pairs
mkdir -p "$COOL_1KB_DIR"

for SAM in "$MAP_DIR"/*.sam; do
    PREFIX=$(basename "$SAM" .sam)
    OUT="$COOL_1KB_DIR/$PREFIX"

    echo "======================================"
    echo "[$(date)] Processing $PREFIX"
    echo "======================================"

    # 1. Parse SAM -> pairs
    pairtools parse \
        --walks-policy all \
        -c "$CHRSIZES" \
        -o "${OUT}.pairs" \
        --output-stats "${OUT}_pairs_stats.txt" \
        "$SAM"

    # 2. Sort pairs
    pairtools sort \
        --nproc "$CPUS" \
        -o "${OUT}.sorted.pairs" \
        "${OUT}.pairs"

    # 3. Remove PCR/optical duplicates
    pairtools dedup \
        -p "$CPUS" \
        --output "${OUT}.dedup.pairs" \
        --output-stats "${OUT}_dedup_stats.txt" \
        --output-dups "${OUT}.dup.pairs" \
        --output-unmapped "${OUT}.unmapped.pairs" \
        "${OUT}.sorted.pairs"

    # 4. Bin into a 1 kb cooler (columns: chrom1 pos1 chrom2 pos2)
    cooler cload pairs \
        -c1 2 -p1 3 -c2 4 -p2 5 \
        "${CHRSIZES}:${BASE_RES}" \
        "${OUT}.dedup.pairs" \
        "${OUT}.cool"

    if [[ "$KEEP_INTERMEDIATE" != "1" ]]; then
        rm -f "${OUT}.pairs" "${OUT}.sorted.pairs"
    fi

    echo "[$(date)] Finished $PREFIX"
done

echo "======================================"
echo "All Hi-C matrices completed"
echo "======================================"
