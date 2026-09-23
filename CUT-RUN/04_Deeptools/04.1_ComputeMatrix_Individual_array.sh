#!/usr/bin/env bash
#SBATCH --qos=cpu-normal
#SBATCH --job-name=computeMatrix_array
#SBATCH --output=out_log/%x.%A_%a.log
#SBATCH --error=err_log/%x.%A_%a.err
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=4
#SBATCH --mem=16G
#SBATCH --time=06:00:00
#SBATCH --partition=acpu
#SBATCH --mail-type=END,FAIL
#SBATCH --mail-user=c832500103@colostate.edu
#SBATCH --array=0-3

set -e
SCRATCH=/scratch/alpine/c832500103@colostate.edu
source ${SCRATCH}/miniconda3/etc/profile.d/conda.sh
conda activate ${SCRATCH}/conda_envs/deeptools_kernel_v2

POPS=(BF MP SF ZH)
POP=${POPS[$SLURM_ARRAY_TASK_ID]}
CHUNK="bw_chunks/chunk_${POP}.txt"
BIGWIGS=$(cat "$CHUNK")

REFERENCE_BED="/scratch/alpine/c832500103@colostate.edu/Cxt_Cut_Run_Pipeline/00_Cxt_Genome/Genome_gff/CtarK1_TSS.bed"

LABELS=()
for bw in $BIGWIGS; do
    LABELS+=("$(basename "$bw" _inputsubtracted.bw)")
done

echo "Population: $POP  |  Files: $(echo $BIGWIGS | wc -w)"

computeMatrix reference-point \
    --referencePoint TSS \
    -b 2000 -a 2000 \
    -R "$REFERENCE_BED" \
    -S $BIGWIGS \
    --skipZeros \
    -o "matrix_${POP}.gz" \
    -p 4 \
    --outFileSortedRegions "region_${POP}.bed" \
    --samplesLabel "${LABELS[@]}"

echo "Done: $POP"
