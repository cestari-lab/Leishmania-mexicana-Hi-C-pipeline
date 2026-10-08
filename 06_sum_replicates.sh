#!/bin/bash
#SBATCH --job-name=hic_sum
#SBATCH --time=02:00:00
#SBATCH --cpus-per-task=4
#SBATCH --mem=32G
#SBATCH --output=logs/06_sum_replicates-%j.log
# -----------------------------------------------------------------------------
# Step 6 — Sum the 3 KR-corrected replicates of each condition and report
#          the total sum per merged matrix (used to compute scaling factors).
# Input : $KR_DIR/<prefix>_{1..3}_5kb_KR.cool
# Output: $MERGED_DIR/<CONDITION>_merged.cool
# -----------------------------------------------------------------------------
set -euo pipefail
CONFIG="${SLURM_SUBMIT_DIR:-.}/config.sh"
[[ -f "$CONFIG" ]] || { echo "config.sh not found — run: cp config.example.sh config.sh" >&2; exit 1; }
source "$CONFIG"
activate_python_env

mkdir -p "$MERGED_DIR"

for condition in "${CONDITIONS[@]}"; do
    prefix="${REPLICATE_PREFIX[$condition]}"
    reps=()
    for i in $(seq 1 "$N_REPLICATES"); do
        reps+=("$KR_DIR/${prefix}_${i}_5kb_KR.cool")
    done

    echo "[$(date)] Summing ${condition}: ${reps[*]##*/}"
    hicSumMatrices \
        --matrices "${reps[@]}" \
        --outFileName "$MERGED_DIR/${condition}_merged.cool"
done

echo ""
echo "=== Merged matrix info ==="
for condition in "${CONDITIONS[@]}"; do
    echo "--- ${condition} ---"
    hicInfo --matrices "$MERGED_DIR/${condition}_merged.cool" 2>&1 \
        | grep -E "Bin_length|Non-zero|columns" || true
done

echo ""
echo "=== Total sum per condition (input for step 7) ==="
python3 "${SLURM_SUBMIT_DIR:-.}/scripts/utils/cool_sums.py" "$MERGED_DIR"/*_merged.cool

echo "[$(date)] Summing done"
