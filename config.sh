# =============================================================================
# =============================================================================

# ---- Project layout ---------------------------------------------------------
PROJECT_DIR="/path/to/project"
RAW_DIR="$PROJECT_DIR/rawdata"                    # *_R1.fastq.gz / *_R2.fastq.gz
TRIM_DIR="$PROJECT_DIR/trimmed_adap_nonml"        # trimmed reads
HIC_DIR="$PROJECT_DIR/HiC_juicer_output"

GENOME_DIR="$HIC_DIR/Genome"
GENOME_FASTA="$GENOME_DIR/L.mexicana_m927_c9t7_2026.fasta"   # must be bwa-indexed
CHRSIZES="$GENOME_DIR/LmxM379c_chr_fixed.sizes"

RUN_DIR="$HIC_DIR/DAC3"
MAP_DIR="$RUN_DIR/mapping"          # SAM / sorted BAM
FILT_DIR="$RUN_DIR/depth"           # Q30 + primary-only BAM
COOL_1KB_DIR="$RUN_DIR/cool_files"  # 1 kb .cool from pairtools/cooler

ANALYSIS_DIR="$HIC_DIR/cool_files_end"            # downstream matrix work
COOL_5KB_DIR="$ANALYSIS_DIR/cool_5kb"
KR_DIR="$COOL_5KB_DIR/corrected_KR"
MERGED_DIR="$ANALYSIS_DIR/merged_KR"
SCALED_DIR="$ANALYSIS_DIR/normalized_KR_scaled"
CLEAN_DIR="$ANALYSIS_DIR/normalized_KR_scaled_clean"

# ---- Tools ------------------------------------------------------------------
TRIMMOMATIC_JAR="/path/to/Trimmomatic-0.39/trimmomatic-0.39.jar"
ADAPTERS="/path/to/Trimmomatic-0.39/adapters/TruSeq3-PE.fa"
PYTHON_MODULE="python/3.11"                       # set to "" if your system has no module command
MAPPING_MODULES="bwa samtools"                    # modules loaded in step 2 (add versions if needed)
PAIRTOOLS_ENV="/path/to/venv"                    # venv with pairtools, cooler, HiCExplorer, h5py
EXTRA_PYTHONPATH=""                        # optional extra package dir (leave empty if unused)

# ---- Resolutions ------------------------------------------------------------
BASE_RES=1000        # bin size written by cooler cload
COARSEN_FACTOR=5     # 1 kb x 5 = 5 kb

# ---- Samples ----------------------------------------------------------------
SAMPLES=(
    Wildtype_1 Wildtype_2 Wildtype_3
    cas9_T7_1  cas9_T7_2  cas9_T7_3
    DAC4_1     DAC4_2     DAC4_3
    DAC4_ab_1  DAC4_ab_2  DAC4_ab_3
    DAC3_1     DAC3_2     DAC3_3
    DAC3_ab_1  DAC3_ab_2  DAC3_ab_3
)

# Condition name -> replicate prefix (replicates are <prefix>_1.._3)
CONDITIONS=(WT CAS9 DAC4 DAC4_ab DAC3 DAC3_ab)
declare -A REPLICATE_PREFIX=(
    [WT]=Wildtype
    [CAS9]=cas9_T7
    [DAC4]=DAC4
    [DAC4_ab]=DAC4_ab
    [DAC3]=DAC3
    [DAC3_ab]=DAC3_ab
)
N_REPLICATES=3

# Chromosomes kept after scaffold removal (LmxM379c_chr.01 .. chr.34)
CHROMOSOMES=($(for i in $(seq -w 1 34); do echo "LmxM379c_chr.${i}"; done))

# ---- Helpers ----------------------------------------------------------------
activate_python_env() {
    [[ -n "$PYTHON_MODULE" ]] && module load "$PYTHON_MODULE"
    # shellcheck disable=SC1091
    source "$PAIRTOOLS_ENV/bin/activate"
    if [[ -n "$EXTRA_PYTHONPATH" ]]; then
        export PYTHONPATH="$EXTRA_PYTHONPATH${PYTHONPATH:+:$PYTHONPATH}"
    fi
}
