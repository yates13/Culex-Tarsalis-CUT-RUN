# Culex tarsalis CUT&RUN and RNA-seq Analysis

This repository holds the analysis pipeline for a study of chromatin regulation in *Culex tarsalis* during infection with Rift Valley Fever Virus (RVFV). We used **CUT&RUN** and **RNA-seq** data to compare infection with two RVFV strains, **ZH501** and **MP12**.

## Study overview

- **Virus strains:** RVFV ZH501 and MP12
- **CUT&RUN targets:**
  - H3K27ac (active regulatory regions)
  - H3K9me (repressive chromatin)
  - SREBP (transcription factor)
- **Additional data:** RNA-seq, for comparing chromatin changes with gene expression
- **Timepoints:** Day 1 and Day 3
- **Compute:** CU/CSU Alpine HPC, jobs run with SLURM

## Pipeline

Run the steps in order. Each folder has its own scripts, numbered in run order.

| Step | Folder | What it does |
|------|--------|--------------|
| 1 | [`CUT-RUN/01_Cxt_FastP`](CUT-RUN/01_Cxt_FastP) | Read trimming with fastp and QC |
| 2 | [`CUT-RUN/02_Cxt_Alignment`](CUT-RUN/02_Cxt_Alignment) | HISAT2 alignment, BAM conversion, replicate merging, MultiQC |
| 3 | [`CUT-RUN/03_MACS2_Peaks_New_Peaks`](CUT-RUN/03_MACS2_Peaks_New_Peaks) | Peak calling with MACS2 |
| 4 | [`CUT-RUN/04_Deeptools`](CUT-RUN/04_Deeptools) | bigWigs, signal matrices, heatmaps and profiles with deepTools |
| 5 | [`CUT-RUN/05_HomerAnnotation`](CUT-RUN/05_HomerAnnotation) | Peak annotation with HOMER |

To view tracks in IGV, see [`IGV_ChIP-Seq_Instructions.pdf`](CUT-RUN/IGV_ChIP-Seq_Instructions.pdf).

## Setup

Each step activates its own conda environment from `${SCRATCH}/conda_envs/`.

| Environment | Used in |
|-------------|---------|
| `fastp_env` | Step 1, trimming |
| `rnaPseudo_clean` | Step 2, alignment and BAM processing |
| `macs2_env` | Step 3, peak calling |
| `deeptools_kernel_v2` | Step 4, see `How_to_make_deeptools_kernel_env.md` |

Scripts load conda like this. Set `SCRATCH` to your own scratch path first:

```bash
SCRATCH=/scratch/alpine/<your_username>
source ${SCRATCH}/miniconda3/etc/profile.d/conda.sh
conda activate ${SCRATCH}/conda_envs/<env_name>
```

## Running

1. Edit the paths at the top of each script to match your directory.
2. Submit each step with `sbatch <script>.sh` and check outputs before moving on.
3. See the `How_to_make_*` files in each folder for building sample and treatment lists.

## Data

- **Reference genome:** [assembly and annotation]
- **Raw data:** [location or accession]

## Notes
- Large outputs (BAMs, bigWigs, matrices, logs) are not tracked in this repo.
- Contact: [Shawn / shawn.yates@colostate.edu]
