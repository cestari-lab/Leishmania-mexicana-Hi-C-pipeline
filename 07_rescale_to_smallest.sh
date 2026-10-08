#!/bin/bash
#SBATCH --job-name=hic_rescale
#SBATCH --time=01:00:00
#SBATCH --cpus-per-task=4
#SBATCH --mem=16G
#SBATCH --output=logs/07_rescale-%j.log
# -----------------------------------------------------------------------------
# Step 7 — Depth-match all merged conditions by scaling them down to the
#          condition with the smallest total contact sum.
#          factor(condition) = smallest_sum / sum(condition)
#          WT remains the biological reference for comparisons, but every
#          matrix ends up at the same numerical depth.
#
# Factors are computed automatically from the merged matrices. To use fixed
# values instead, set them in MANUAL_FACTORS below (e.g. from a previous run).
#
# Input : $MERGED_DIR/<CONDITION>_merged.cool
# Output: $SCALED_DIR/<CONDITION>_norm_scaled.cool
# -----------------------------------------------------------------------------
set -euo pipefail
CONFIG="${SLURM_SUBMIT_DIR:-.}/config.sh"
[[ -f "$CONFIG" ]] || { echo "config.sh not found — run: cp config.example.sh config.sh" >&2; exit 1; }
source "$CONFIG"
activate_python_env

UTILS="${SLURM_SUBMIT_DIR:-.}/scripts/utils"
mkdir -p "$SCALED_DIR"

# Optional manual override (leave empty to compute automatically). Example
# from a 5 kb run, smallest = CAS9 at 94,560,616:
#   MANUAL_FACTORS=([WT]=0.806 [CAS9]=1.000 [DAC3]=0.982 [DAC3_ab]=0.872 [DAC4]=0.728 [DAC4_ab]=0.738)
declare -A MANUAL_FACTORS=()

declare -A FACTORS
if (( ${#MANUAL_FACTORS[@]} > 0 )); then
    echo "Using manual scaling factors"
    for c in "${!MANUAL_FACTORS[@]}"; do FACTORS[$c]="${MANUAL_FACTORS[$c]}"; done
else
    echo "Computing scaling factors from merged matrix sums..."
    files=()
    for c in "${CONDITIONS[@]}"; do files+=("$MERGED_DIR/${c}_merged.cool"); done
    # Output lines: <condition> <sum> <factor>
    while read -r name total factor; do
        FACTORS[$name]="$factor"
        printf "  %-10s sum=%'15.0f  factor=%s\n" "$name" "$total" "$factor"
    done < <(python3 "$UTILS/scaling_factors.py" "${files[@]}")
fi

for condition in "${CONDITIONS[@]}"; do
    in="$MERGED_DIR/${condition}_merged.cool"
    out="$SCALED_DIR/${condition}_norm_scaled.cool"
    factor="${FACTORS[$condition]}"

    if [[ "$factor" == "1" || "$factor" == "1.0" || "$factor" == "1.000" || "$factor" == "1.000000" ]]; then
        echo "[$(date)] ${condition} is the reference depth — copying"
        cp "$in" "$out"
    else
        echo "[$(date)] Scaling ${condition} by ${factor}..."
        hicNormalize \
            --matrices "$in" \
            --normalize multiplicative \
            --multiplicativeValue "$factor" \
            --outFileName "$out"
    fi
done

echo ""
echo "=== Verification — all sums should now be ~equal ==="
python3 "$UTILS/cool_sums.py" --check-equal "$SCALED_DIR"/*_norm_scaled.cool

echo ""
echo "=== Bin size and columns ==="
for f in "$SCALED_DIR"/*.cool; do
    echo "--- $(basename "$f") ---"
    hicInfo --matrices "$f" 2>&1 | grep -E "Bin_length|columns|Non-zero" || true
done

echo "[$(date)] Rescaling done"
