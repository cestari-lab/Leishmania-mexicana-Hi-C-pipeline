#!/bin/bash
#SBATCH --job-name=hic_map_filter
#SBATCH --cpus-per-task=24
#SBATCH --time=0-48:00:00
#SBATCH --mem=180G
#SBATCH --mail-type=ALL
#SBATCH --output=logs/02_map_filter-%j.log
# -----------------------------------------------------------------------------
# Step 2 — Hi-C mapping with BWA-MEM (-5SP), BAM sorting and filtering.
# Input : $TRIM_DIR/<sample>_R{1,2}.trim.paired.fastq.gz
# Output: $MAP_DIR/<sample>.sam            (used by step 3, pairtools)
#         $MAP_DIR/<sample>.sorted.bam(.bai)
#         $FILT_DIR/<sample>.primary.sorted.bam(.bai)  (MAPQ>=30, primary only)
# -----------------------------------------------------------------------------
set -euo pipefail
CONFIG="${SLURM_SUBMIT_DIR:-.}/config.sh"
[[ -f "$CONFIG" ]] || { echo "config.sh not found — run: cp config.example.sh config.sh" >&2; exit 1; }
source "$CONFIG"

# shellcheck disable=SC2086
[[ -n "$MAPPING_MODULES" ]] && module load $MAPPING_MODULES

CPUS="${SLURM_CPUS_PER_TASK:-24}"
mkdir -p "$MAP_DIR" "$FILT_DIR"

for R1 in "$TRIM_DIR"/*_R1.trim.paired.fastq.gz; do
    R2="${R1/_R1.trim.paired.fastq.gz/_R2.trim.paired.fastq.gz}"
    prefix=$(basename "$R1" _R1.trim.paired.fastq.gz)
    echo "======================================"
    echo "[$(date)] Processing $prefix"
    echo "======================================"

    SAM="$MAP_DIR/${prefix}.sam"
    BAM="$MAP_DIR/${prefix}.bam"
    SORTBAM="$MAP_DIR/${prefix}.sorted.bam"

    # --- Mapping (-5: lowest-coordinate split = primary, -S/-P: no mate rescue/pairing; Hi-C mode)
    bwa mem -5SP -t "$CPUS" "$GENOME_FASTA" "$R1" "$R2" > "$SAM"

    # --- SAM -> sorted, indexed BAM
    samtools view -@ "$CPUS" -b "$SAM" > "$BAM"
    samtools sort -@ "$CPUS" -m 3G -o "$SORTBAM" "$BAM"
    samtools index "$SORTBAM"
    rm -f "$BAM"

    # --- Filtering: MAPQ >= 30, drop secondary (256) + supplementary (2048) = -F 2304
    Q30="$FILT_DIR/${prefix}.q30.bam"
    PRIMARY="$FILT_DIR/${prefix}.primary.bam"
    PRIMARY_SORTED="$FILT_DIR/${prefix}.primary.sorted.bam"

    samtools view -@ "$CPUS" -b -q 30 "$SORTBAM" > "$Q30"
    samtools view -@ "$CPUS" -b -F 2304 "$Q30" > "$PRIMARY"
    samtools sort -@ "$CPUS" -m 3G -o "$PRIMARY_SORTED" "$PRIMARY"
    samtools index "$PRIMARY_SORTED"
    rm -f "$Q30" "$PRIMARY"

    echo "[$(date)] Finished $prefix"
done

echo "[$(date)] Mapping and filtering complete"
