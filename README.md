# Leishmania mexicana Hi-C pipeline

A SLURM pipeline that takes paired-end Hi-C reads from *L. mexicana* M379 all the way to depth-matched, KR-balanced 5 kb contact matrices, one per condition.

Cestari Lab · McGill University · Lissa Cruz-Saavedra
**Conditions** (3 biological replicates each): `WT`, `CAS9` (cas9_T7), `DAC4`, `DAC4_ab`, `DAC3`, `DAC3_ab`

## Workflow

```
raw FASTQ
  │ 01_trim.sh               Trimmomatic (adapters, HEADCROP:2, SLIDINGWINDOW:4:5)
  ▼
trimmed FASTQ
  │ 02_map_filter.sh         bwa mem -5SP → sorted BAM; MAPQ≥30 + primary-only BAM
  ▼
SAM
  │ 03_pairtools_cool.sh     pairtools parse → sort → dedup → cooler cload (1 kb)
  ▼
1 kb .cool (per replicate)
  │ 04_coarsen_5kb.sh        cooler coarsen ×5
  ▼
5 kb .cool
  │ 05_kr_correct.sh         hicCorrectMatrix KR (filter −1.5 … 5) + QC
  ▼
KR-balanced replicates
  │ 06_sum_replicates.sh     hicSumMatrices (3 replicates → 1 per condition)
  ▼
merged .cool (per condition)
  │ 07_rescale_to_smallest.sh  scale every condition to the smallest total sum
  ▼
depth-matched .cool
  │ 08_remove_scaffolds.sh   keep LmxM379c_chr.01 – chr.34
  ▼
FINAL: normalized_KR_scaled_clean/<CONDITION>_norm_scaled_clean.cool
```

## Repository layout

```
.
├── config.example.sh         # template: paths, sample names, conditions, chromosomes
├── envs/requirements.txt     # Python packages (pairtools, cooler, HiCExplorer…)
├── logs/                     # SLURM logs land here
└── scripts/
    ├── 01_trim.sh
    ├── 02_map_filter.sh
    ├── 03_pairtools_cool.sh
    ├── 04_coarsen_5kb.sh
    ├── 05_kr_correct.sh
    ├── 06_sum_replicates.sh
    ├── 07_rescale_to_smallest.sh
    ├── 08_remove_scaffolds.sh
    └── utils/
        ├── cool_sums.py        # sum / nnz / mean of .cool files (QC)
        └── scaling_factors.py  # smallest_sum / sum per condition
```

## Setup

1. **Create your config:**
   ```bash
   cp config.example.sh config.sh
   ```
   Edit `config.sh` to set `PROJECT_DIR`, the genome FASTA, the chromosome sizes file, the Trimmomatic path, the Python environment and the module names for your cluster. `config.sh` is listed in `.gitignore`, so your local paths stay off GitHub.
2. **Index the genome** (once):
   ```bash
   module load bwa
   bwa index L.mexicana_m927_c9t7_2026.fasta
   ```
3. **Create the Python environment** (once):
   ```bash
   module load python/3.11
   python -m venv /path/to/venv
   source /path/to/venv/bin/activate
   pip install -r envs/requirements.txt
   ```

**Software used:** Trimmomatic 0.39, BWA 0.7.17, SAMtools 1.18, pairtools, cooler, HiCExplorer (`hicCorrectMatrix`, `hicSumMatrices`, `hicNormalize`, `hicConvertFormat`, `hicInfo`), Python 3.11 with h5py and numpy.

## Running

Always submit from the repository root, so the scripts can find `config.sh` and write to `logs/`. Set your SLURM account once per session (or add `--account=<your-account>` to each `sbatch` command):

```bash
mkdir -p logs
export SBATCH_ACCOUNT=<your-account>
sbatch scripts/01_trim.sh
sbatch scripts/02_map_filter.sh
# ...and so on in order
```

To chain the steps so each one starts when the previous one finishes:

```bash
j1=$(sbatch --parsable scripts/01_trim.sh)
j2=$(sbatch --parsable --dependency=afterok:$j1 scripts/02_map_filter.sh)
j3=$(sbatch --parsable --dependency=afterok:$j2 scripts/03_pairtools_cool.sh)
j4=$(sbatch --parsable --dependency=afterok:$j3 scripts/04_coarsen_5kb.sh)
j5=$(sbatch --parsable --dependency=afterok:$j4 scripts/05_kr_correct.sh)
j6=$(sbatch --parsable --dependency=afterok:$j5 scripts/06_sum_replicates.sh)
j7=$(sbatch --parsable --dependency=afterok:$j6 scripts/07_rescale_to_smallest.sh)
sbatch --dependency=afterok:$j7 scripts/08_remove_scaffolds.sh
```

## Notes

- **Sample naming.** Steps 5–8 look files up by the names in `SAMPLES` / `REPLICATE_PREFIX` (e.g. `Wildtype_1`, `cas9_T7_2`). The FASTQ base names should match these, so the 1 kb `.cool` files come out as `Wildtype_1.cool` and so on.
- **Intermediate files.** Step 3 deletes the raw and sorted `.pairs` once the cooler is built. To keep them, submit with `sbatch --export=ALL,KEEP_INTERMEDIATE=1 scripts/03_pairtools_cool.sh`.
- **Scaling factors (step 7)** are computed automatically: `factor = smallest_sum / condition_sum`, and the smallest condition is copied unchanged. To reuse fixed factors from an earlier run, fill in `MANUAL_FACTORS` at the top of the script. For example, in one 5 kb run CAS9 was smallest (94,560,616 contacts), which gave WT 0.806, DAC3 0.982, DAC3_ab 0.872, DAC4 0.728 and DAC4_ab 0.738.
- **Verification.** Step 7 marks each matrix `[OK]`, or `[CHECK]` if its sum is more than 5% away from the median, and exits with an error if any matrix fails.
- **Downstream comparisons** use `statsmodels` (multiple-testing correction). If you install it outside the venv with `pip install --target=<dir>`, set `EXTRA_PYTHONPATH` in `config.sh` to that folder.

## Author

Lissa Cruz Saavedra — McGill University
