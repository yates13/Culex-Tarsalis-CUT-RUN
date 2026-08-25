#!/usr/bin/env bash

#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=4
#SBATCH --mem=16G
#SBATCH --time=4:00:00
#SBATCH --qos=cpu-normal
#SBATCH --partition=acpu
#SBATCH --job-name=HisatArrayCxt
#SBATCH --mail-user=shawn.yates@colostate.edu
#SBATCH --mail-type=all
#SBATCH --output=slurm_logs/%x.%A-%a.log
#SBATCH --error=slurm_logs/%x.%A-%a.err
#SBATCH --array=0-95%20

# ============================================================
# HISAT2 ALIGNMENT (SLURM ARRAY SCRIPT)
# ------------------------------------------------------------
# This script:
# 1. Reads paired-end FASTQ files (R1/R2)
# 2. Aligns reads using HISAT2
# 3. Outputs SAM files
#
# Designed for SLURM array jobs:
#   sbatch --array=0-N script.sh
#
# Each task processes ONE sample
# ============================================================

echo "[$0] Job: $SLURM_JOB_NAME | Task ID: $SLURM_ARRAY_TASK_ID"

# ----------------------------
# Environment setup
# ----------------------------
module purge

# Load conda
SCRATCH=/scratch/alpine/.colostate.edu/c832500103
source ${SCRATCH}/miniconda3/etc/profile.d/conda.sh || { echo "ERROR: conda.sh not found at ${SCRATCH}/miniconda3"; exit 1; }
conda activate ${SCRATCH}/conda_envs/rnaPseudo_clean || { echo "ERROR: conda activate rnaPseudo failed"; exit 1; }

date

# ----------------------------
# Input/output paths
# ----------------------------
#/scratch/alpine/c832500103@colostate.edu/Cxt_Cut_Run_Pipeline/Round1_Round2_With_Duplicates/01_Cxt_FastP/01.1_Cxt_fastp_out
#/scratch/alpine/c832500103@colostate.edu/Cxt_Cut_Run_Pipeline/With_Duplicates/01_Cxt_FastP/01.1_Cxt_fastp_out
FASTQ_DIR=${SCRATCH}/Cxt_Cut_Run_Pipeline/Round1_Round2_With_Duplicates/01_Cxt_FastP/01.1_Cxt_fastp_out
OUT_DIR=${SCRATCH}/Cxt_Cut_Run_Pipeline/Round1_Round2_With_Duplicates/02_Cxt_Alignment/02.2_Cxt_HisatAligned_Cleaned
INDEX=${SCRATCH}/Cxt_Cut_Run_Pipeline/00_Cxt_Indexed_Genome/CtarK1_index
filename=${SCRATCH}/Cxt_Cut_Run_Pipeline/Round1_Round2_With_Duplicates/02_Cxt_Alignment/FastqTrimmed.txt
mkdir -p $OUT_DIR
mkdir -p ${SCRATCH}/Cxt_Cut_Run_Pipeline/Round1_Round2_With_Duplicates/02_Cxt_Alignment/slurm_logs

# =========================
# Build file list (WORKING METHOD)
# =========================

#ls ${FASTQ_DIR} | grep "_R1_" | grep "trimmed" > ${filename}
if [[ ! -f "$filename" ]]; then
    echo "ERROR: $filename not found — build it first with:"
    echo "  ls ${FASTQ_DIR} | grep '_R1_' | grep 'trimmed' > ${filename}"
    exit 1
fi


# Debug (VERY helpful)
echo "Total files found: $(wc -l < ${filename})"

# =========================
# Select file for this task
# =========================
linenum=0
while read -r line
do
  if [ $SLURM_ARRAY_TASK_ID -eq $linenum ]
  then
    R1=${FASTQ_DIR}/${line}
    R2=${R1/_R1_/_R2_}
    BASE=$(basename $R1)
    SAMPLE=${BASE%%_R1_trimmed*}

    # Safety check
    if [[ ! -f "$R1" || ! -f "$R2" ]]; then
      echo "ERROR: Missing FASTQ files"
      exit 1
    fi

    # =========================
    # Run HISAT2
    # =========================
    hisat2 \
      --phred33 \
      --mm \
      --no-mixed \
      --no-spliced-alignment \
      -p $SLURM_CPUS_PER_TASK \
      -x $INDEX \
      -1 $R1 \
      -2 $R2 \
      -S $OUT_DIR/${SAMPLE}.sam \
      2> $OUT_DIR/${SAMPLE}.hisat2.log
    echo "Completed: $SAMPLE"
  fi

  linenum=$((linenum + 1))
done < ${filename}

date
echo "Job complete"
