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

<If .yml files exist for these in the repo (e.g. CondaEnvs/), create each with:>
conda env create --file YourCondaEnv.yml --prefix ${SCRATCH}/conda_envs/<env_name>

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

## How to use Slurm

Common commands: sbatch, srun, scancel, sacct, squeue, sinfo

### Common Slurm commands

sbatch [options] script [args]   — submit a job
  e.g. sbatch 04_deeptools.sh path/to/bams/folder

scancel 12345                    — cancel job 12345
scancel {31415..31425}           — cancel a range of sequential job IDs

squeue | grep <your_username>    — just yours

### Writing a Slurm job script

nano YourNewJob.sh

Header (don't put any code above this):

#!/bin/bash
#SBATCH --partition=acpu
#SBATCH --qos=cpu-normal
#SBATCH --job-name=YourJobNameHere
#SBATCH --output=%x.%j.out
#SBATCH --nodes=1
#SBATCH --ntasks=1

## Reference genome

- **Assembly:** *Culex tarsalis* CtarK1 [add source/citation]
- **Annotation:** `Culex-tarsalis_knwr_BASEFEATURES_CtarK1.gff3`
- **Derived files:** `genes_only.gff3`, `CtarK1_TSS.bed`, and `Culex-tarsalis_knwr_CtarK1.bed`, built with the steps in `Bed_file_instructions.txt` and `Gene_only_bed_instructions.txt`
- The HISAT2 index is built in step 2 (`02.1_runBuildCtark1Genome_apline.sh`)

## Data

Raw sequencing reads are not included in this repository.

## Notes
- Large outputs (BAMs, bigWigs, matrices, logs) are not tracked in this repo.
- Contact: [Shawn / shawn.yates@colostate.edu]
