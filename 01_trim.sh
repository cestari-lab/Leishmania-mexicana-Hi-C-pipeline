#!/bin/bash
#SBATCH --job-name=hic_trim
#SBATCH --cpus-per-task=12
#SBATCH --time=0-24:00:00
#SBATCH --mem=72G
#SBATCH --mail-type=ALL
#SBATCH --output=logs/01_trim-%j.log
# -----------------------------------------------------------------------------
# Step 1 — Adapter / quality trimming with Trimmomatic (paired-end).
# Input : $RAW_DIR/<sample>_R1.fastq.gz, <sample>_R2.fastq.gz
# Output: $TRIM_DIR/<sample>_R{1,2}.trim.{paired,unpaired}.fastq.gz
# -----------------------------------------------------------------------------
set -euo pipefail
CONFIG="${SLURM_SUBMIT_DIR:-.}/config.sh"
[[ -f "$CONFIG" ]] || { echo "config.sh not found — run: cp config.example.sh config.sh" >&2; exit 1; }
source "$CONFIG"

THREADS="${SLURM_CPUS_PER_TASK:-12}"
mkdir -p "$TRIM_DIR"

echo "[$(date)] Starting trimming..."

for R1 in "$RAW_DIR"/*_R1.fastq.gz; do
    BASE=$(basename "$R1" _R1.fastq.gz)
    R2="$RAW_DIR/${BASE}_R2.fastq.gz"
    echo "Processing $BASE"

    java -jar "$TRIMMOMATIC_JAR" PE \
        -threads "$THREADS" \
        -phred33 \
        "$R1" "$R2" \
        "$TRIM_DIR/${BASE}_R1.trim.paired.fastq.gz" "$TRIM_DIR/${BASE}_R1.trim.unpaired.fastq.gz" \
        "$TRIM_DIR/${BASE}_R2.trim.paired.fastq.gz" "$TRIM_DIR/${BASE}_R2.trim.unpaired.fastq.gz" \
        ILLUMINACLIP:"${ADAPTERS}":2:30:10:2:keepBothReads \
        HEADCROP:2 \
        SLIDINGWINDOW:4:5
done

echo "[$(date)] All samples trimmed"
