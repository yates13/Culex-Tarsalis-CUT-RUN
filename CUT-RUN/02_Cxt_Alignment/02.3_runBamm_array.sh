#!/usr/bin/env bash
#SBATCH --partition=acpu
#SBATCH --job-name=BamConvert_array
#SBATCH --output=out_log/%x.%A_%a.log
#SBATCH --error=err_log/%x.%A_%a.err
#SBATCH --time=3:00:00
#SBATCH --qos=cpu-normal
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=8
#SBATCH --mem=32G
#SBATCH --mail-type=END,FAIL
#SBATCH --mail-user=shawn.yates@colostate.edu
#SBATCH --array=1-96

# ----------------------------
# Environment setup
# ----------------------------
module purge
SCRATCH=/scratch/alpine/.colostate.edu/c832500103
source ${SCRATCH}/miniconda3/etc/profile.d/conda.sh
conda activate ${SCRATCH}/conda_envs/rnaPseudo_clean
date
nthreads=$SLURM_CPUS_PER_TASK

# ----------------------------
# Input/output paths
# ----------------------------
samdir=${SCRATCH}/Cxt_Cut_Run_Pipeline/Round1_Round2_With_Duplicates/02_Cxt_Alignment/02.2_Cxt_HisatAligned_Cleaned
outdir=${SCRATCH}/Cxt_Cut_Run_Pipeline/Round1_Round2_With_Duplicates/02_Cxt_Alignment/02.3_Cxt_BamConverted
SAM_LIST=${samdir}/sam_file_list.txt

mkdir -p "$outdir" out_log err_log

# Build the list once before submitting, if it doesn't already exist:
#   ls ${samdir}/*.sam > ${samdir}/sam_file_list.txt
#   wc -l ${samdir}/sam_file_list.txt
if [[ ! -f "$SAM_LIST" ]]; then
    echo "ERROR: $SAM_LIST not found — build it first with:"
    echo "  ls ${samdir}/*.sam > ${SAM_LIST}"
    exit 1
fi

# ----------------------------
# Select this task's SAM file
# ----------------------------
file=$(sed -n "${SLURM_ARRAY_TASK_ID}p" "$SAM_LIST")

if [[ -z "$file" ]]; then
    echo "ERROR: No SAM file found for array index $SLURM_ARRAY_TASK_ID"
    exit 1
fi

base=$(basename "$file" .sam)
echo "Task $SLURM_ARRAY_TASK_ID: Processing $base"

# ----------------------------
# Skip if already done
# ----------------------------
if [[ -f "${outdir}/${base}.bam.bai" && "${outdir}/${base}.bam.bai" -nt "$file" ]]; then
    echo "EXISTS: ${base} — skipping"
    exit 0
fi

# ----------------------------
# Bam creation, sorting, and indexing
# ----------------------------
samtools view -bS -@$nthreads "$file" | \
samtools sort -@$nthreads -o ${outdir}/${base}.bam
samtools flagstat ${outdir}/${base}.bam > ${outdir}/${base}_flagstat.txt
samtools index -@$nthreads ${outdir}/${base}.bam

echo "Completed: $base"
date
