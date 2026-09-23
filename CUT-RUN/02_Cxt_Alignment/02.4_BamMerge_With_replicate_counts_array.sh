#!/usr/bin/env bash
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=8
#SBATCH --mem=16G
#SBATCH --time=04:00:00
#SBATCH --qos=cpu-normal
#SBATCH --partition=acpu
#SBATCH --job-name=BamMerge_with_replicate_count
#SBATCH --mail-user=shawn.yates@colostate.edu
#SBATCH --mail-type=ALL
#SBATCH --output=%x.%A_%a.log
#SBATCH --error=%x.%A_%a.err
#SBATCH --array=1-32

#
# ARRAY VERSION - one array task per condition, run in parallel instead of
# looping through conditions serially.
#
# SLURM needs the array size (number of conditions) at SUBMIT time, before
# this script ever runs, so this can't discover conditions and set its own
# --array range internally. Two-step process:
#
#   1) Generate the conditions list first:
#        bamdir=/path/to/02.3_Cxt_BamConverted
#        mergedir=/path/to/02.4_Cxt_BamMerged_with_replicate_count
#        mkdir -p $mergedir
#        ls ${bamdir}/*.bam | xargs -n1 basename | sed 's/-R[0-9]-Cxt\.bam//' \
#            | sort -u > ${mergedir}/conditions.txt
#
#   2) Submit with the array range set from that file's line count:
#        sbatch --array=1-$(wc -l < ${mergedir}/conditions.txt) \
#            02.4_BamMerge_With_replicate_counts_array.sh

set -euo pipefail

# -----------------------------
# Load environment
# -----------------------------
#module purge
SCRATCH=/scratch/alpine/.colostate.edu/c832500103
source ${SCRATCH}/miniconda3/etc/profile.d/conda.sh
conda activate ${SCRATCH}/conda_envs/rnaPseudo_clean
date
nthreads=$SLURM_CPUS_PER_TASK

# -----------------------------
# Define directories
# -----------------------------
samdir=${SCRATCH}/Cxt_Cut_Run_Pipeline/Round1_Round2_With_Duplicates/02_Cxt_Alignment/02.2_Cxt_HisatAligned_Cleaned
bamdir=${SCRATCH}/Cxt_Cut_Run_Pipeline/Round1_Round2_With_Duplicates/02_Cxt_Alignment/02.3_Cxt_BamConverted
mergedir=${SCRATCH}/Cxt_Cut_Run_Pipeline/Round1_Round2_With_Duplicates/02_Cxt_Alignment/02.4_Cxt_BamMerged_with_replicate_count
mkdir -p $mergedir

CONDITIONS_LIST=${mergedir}/conditions.txt
if [ ! -s "$CONDITIONS_LIST" ]; then
    echo "ERROR: $CONDITIONS_LIST missing or empty. Run the prep step (see header comment) before submitting this array job." >&2
    exit 1
fi

# -----------------------------
# Pick this task's condition from the pre-built list
# -----------------------------
cond=$(sed -n "${SLURM_ARRAY_TASK_ID}p" "$CONDITIONS_LIST")
if [ -z "$cond" ]; then
    echo "ERROR: no condition found for array index ${SLURM_ARRAY_TASK_ID} in $CONDITIONS_LIST" >&2
    exit 1
fi

echo "----------------------------------------"
echo "Array task ${SLURM_ARRAY_TASK_ID}: merging condition: $cond"

# Find BAMs for this condition
bams=$(ls ${bamdir}/${cond}-R*-Cxt.bam)

# Extract replicate numbers (R1, R2, R3 -> 1 2 3)
reps=$(echo "$bams" | sed -E 's/.*-R([0-9]+)-Cxt\.bam/\1/' | tr '\n' ' ')
repstring="rep$(echo $reps | tr -d ' ')"

# Count replicates
count=$(echo "$reps" | wc -w)
echo "Found $count replicate(s): $repstring"

# Output filename includes repstring
merged_base="${mergedir}/${cond}-${repstring}-merged.bam"

if [ "$count" -gt 1 ]; then
    echo "Merging $count BAM files..."
    samtools merge -f "$merged_base" $bams
    merge_status="merged"
else
    echo "Only one BAM found - copying instead of merging."
    cp $bams "$merged_base"
    merge_status="copied"
fi

# Sort + index
sorted="${mergedir}/${cond}-${repstring}-merged-sorted.bam"
samtools sort -@$nthreads -o "$sorted" "$merged_base"
samtools index "$sorted"

echo "Completed: $sorted"
echo "Condition $cond: $count replicate(s) ($repstring) were $merge_status."
date
