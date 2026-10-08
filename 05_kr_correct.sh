#!/bin/bash
#SBATCH --job-name=hic_kr
#SBATCH --time=04:00:00
#SBATCH --cpus-per-task=4
#SBATCH --mem=32G
#SBATCH --output=logs/05_kr_correct-%j.log
# -----------------------------------------------------------------------------
# Step 5 — KR (Knight-Ruiz) balancing of each 5 kb replicate matrix,
#          then report weight columns and total sums for QC.
# Input : $COOL_5KB_DIR/<sample>_5kb.cool
# Output: $KR_DIR/<sample>_5kb_KR.cool
# -----------------------------------------------------------------------------
set -euo pipefail
CONFIG="${SLURM_SUBMIT_DIR:-.}/config.sh"
[[ -f "$CONFIG" ]] || { echo "config.sh not found — run: cp config.example.sh config.sh" >&2; exit 1; }
source "$CONFIG"
activate_python_env

mkdir -p "$KR_DIR"

for sample in "${SAMPLES[@]}"; do
    echo "[$(date)] KR correcting ${sample}..."
    hicCorrectMatrix correct \
        --matrix "$COOL_5KB_DIR/${sample}_5kb.cool" \
        --correctionMethod KR \
        --filterThreshold -1.5 5 \
        --outFileName "$KR_DIR/${sample}_5kb_KR.cool"
done

echo ""
echo "=== QC: matrix info ==="
for sample in "${SAMPLES[@]}"; do
    echo "--- ${sample} ---"
    hicInfo --matrices "$KR_DIR/${sample}_5kb_KR.cool" 2>&1 \
        | grep -E "columns|Non-zero|Bin_length" || true
done

echo ""
echo "=== QC: total contact sums ==="
python3 "${SLURM_SUBMIT_DIR:-.}/scripts/utils/cool_sums.py" "$KR_DIR"/*_5kb_KR.cool

echo "[$(date)] KR correction done"
