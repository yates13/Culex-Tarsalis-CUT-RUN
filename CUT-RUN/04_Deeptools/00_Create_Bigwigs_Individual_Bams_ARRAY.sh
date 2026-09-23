#!/usr/bin/env bash
#SBATCH --partition=acpu
#SBATCH --job-name=BamToBigwig_Individual_bams
#SBATCH --output=logs/%x.%A_%a.log
#SBATCH --error=logs/%x.%A_%a.err
#SBATCH --time=5:00:00
#SBATCH --qos=cpu-normal
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=8
#SBATCH --mem=32G
#SBATCH --mail-type=END,FAIL
#SBATCH --mail-user=c832500103@colostate.edu
#SBATCH --array=1-72

set -e

#FORCE=1 sbatch 00_Create_Bigwigs_Individual_Bams_ARRAY.sh --array=1-72

SCRATCH=/scratch/alpine/c832500103@colostate.edu
source ${SCRATCH}/miniconda3/etc/profile.d/conda.sh
conda activate ${SCRATCH}/conda_envs/deeptools_kernel_v2
BAM_INPUT_DIR="${SCRATCH}/Cxt_Cut_Run_Pipeline/Round1_Round2_With_Duplicates/02_Cxt_Alignment/02.3_Cxt_BamConverted"
BW_OUTPUT_DIR="${SCRATCH}/Cxt_Cut_Run_Pipeline/Round1_Round2_With_Duplicates/04_Deeptools/00_BigWig_Files_Individual_Bams"
TREATMENT_LIST="${SCRATCH}/Cxt_Cut_Run_Pipeline/Round1_Round2_With_Duplicates/04_Deeptools/treatment_bam_list.txt"

mkdir -p "$BW_OUTPUT_DIR"
mkdir -p logs

# ===========================================================================
# ARRAY VERSION: each task grabs ONE treatment BAM by line number instead of
# looping through all of them serially. Old serial-loop code kept below,
# commented out, for reference / in case we ever need to revert.
# ===========================================================================

treatment_bam=$(sed -n "${SLURM_ARRAY_TASK_ID}p" "$TREATMENT_LIST")

if [[ -z "$treatment_bam" ]]; then
    echo "ERROR: No treatment BAM found for array index $SLURM_ARRAY_TASK_ID"
    exit 1
fi

# --- OLD SERIAL VERSION (built + looped through ALL treatments in one job) ---
# declare -a TREATMENTS
# for bam_file in "${BAM_INPUT_DIR}"/*-Cxt.bam; do
#     basename=$(basename "$bam_file")
#     if [[ "$basename" == *"-IN-"* ]]; then
#         continue
#     fi
#     TREATMENTS+=("$bam_file")
# done
# total=${#TREATMENTS[@]}
# echo "Found $total treatment samples"
# echo ""
# count=0
# for treatment_bam in "${TREATMENTS[@]}"; do
#     count=$((count + 1))
# -------------------------------------------------------------------------

basename=$(basename "$treatment_bam" -Cxt.bam)
treatment=$(echo "$basename" | cut -d'-' -f1)

#-------------------------------------------------------------------------------------------------------
#These are for merged bams
#
#    input_bam="${BAM_INPUT_DIR}/${treatment}-IN-D1-rep"*"-merged-sorted.bam"
#    input_bam=$(ls "${BAM_INPUT_DIR}/${treatment}-IN-D1-rep"*"-merged-sorted.bam" 2>/dev/null | head -1)
#-------------------------------------------------------------------------------------------------------
#-------------------------------------------------------------------------------------------------------
# TEMPORARY: pairing to ANY available input replicate for this treatment site,
# not matched by replicate number - not every treatment rep has a same-numbered
# input yet. Revisit once all input replicates exist and switch to exact
# rep-matched pairing (see commented-out version below).
input_bam=$(ls "${BAM_INPUT_DIR}/${treatment}-IN-D1-"*"-Cxt.bam" 2>/dev/null | head -1)
# --- exact rep-matched version to swap back in later ---
# rep=$(echo "$basename" | cut -d'-' -f4)
# input_bam="${BAM_INPUT_DIR}/${treatment}-IN-D1-${rep}-Cxt.bam"
#---------------------------------------------------------------------------------------------------------

echo "Task $SLURM_ARRAY_TASK_ID: $basename"
echo "  treatment: $treatment_bam"
echo "  input:     $input_bam"

if [[ -z "$input_bam" || ! -f "$input_bam" ]]; then
    echo "SKIP: $basename (no input control)"
    exit 0
fi

output_bw="${BW_OUTPUT_DIR}/${basename}_inputsubtracted.bw"
if [[ -f "$output_bw" ]]; then
    echo "EXISTS: $basename"
    exit 0
fi

echo "Creating: $basename (treatment=$treatment_bam, input=$input_bam)"
bamCompare \
    -b1 "$treatment_bam" \
    -b2 "$input_bam" \
    -o "$output_bw" \
    --normalizeUsing BPM \
    --scaleFactorsMethod None \
    --operation subtract \
    -p 8 \
    --extendReads 150
echo "Done: $basename"

# --- OLD SERIAL VERSION continued (closing loop + final summary) ---
# done
# echo ""
# echo "BigWigs created in: $BW_OUTPUT_DIR"
# ls -lh "$BW_OUTPUT_DIR"/*.bw
# -------------------------------------------------------------------------
