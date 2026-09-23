#!/usr/bin/env bash
#SBATCH --partition=acpu
#SBATCH --job-name=MACS2_NewFlags_with_replicate_counts
#SBATCH --output=%x.%j.out
#SBATCH --error=%x.%j.err
#SBATCH --time=24:00:00
#SBATCH --qos=cpu-normal
#SBATCH --nodes=1
#SBATCH --ntasks=2
#SBATCH --cpus-per-task=8
#SBATCH --mem=32G
#SBATCH --mail-type=END,FAIL
#SBATCH --mail-user=c832500103@colostate.edu


set -e

SCRATCH=/scratch/alpine/.colostate.edu/c832500103
source ${SCRATCH}/miniconda3/etc/profile.d/conda.sh
conda activate ${SCRATCH}/conda_envs/macs2_env



BAMDIR=${SCRATCH}/Cxt_Cut_Run_Pipeline/Round1_Round2_With_Duplicates/02_Cxt_Alignment/02.4_Cxt_BamMerged_with_replicate_count
PEAK_OUT=${SCRATCH}/Cxt_Cut_Run_Pipeline/Round1_Round2_With_Duplicates/03_MACS2_Peaks_New_Peaks/03.1_MacsPeaks_with_replicate_count
mkdir -p ${PEAK_OUT}

GENOME_SIZE=800000000
FORMAT="BAMPE"
KEEP_DUP="all"


total=$(ls ${BAMDIR}/*-merged-sorted.bam 2>/dev/null | wc -l)
count=0


for BAM in ${BAMDIR}/*-merged-sorted.bam; do
    count=$((count + 1))
    SAMPLE=$(basename "$BAM" | sed 's/-merged-sorted\.bam$//')
#    SAMPLE=$(basename $BAM -merged-sorted.bam)

    # Skip input controls
    if [[ "$SAMPLE" == *"-IN-"* ]]; then
        echo "[$count/$total] SKIP (input): $SAMPLE"
        continue
    fi

    # Extract target (AC, ME, or SR)
    TARGET=$(echo $SAMPLE | cut -d'-' -f2)
    TREATMENT=$(echo $SAMPLE | cut -d'-' -f1)

    # Extract replicate count (rep123, rep23, rep1, etc.)
    REPS=$(echo "$SAMPLE" | grep -o 'rep[0-9]\+')

    if [[ -z "$REPS" ]]; then
        echo "[$count/$total] ERROR: No replicate count found in $SAMPLE"
        continue
    fi

    # Find matching input control
#    INPUT_BAM="${BAMDIR}/${TREATMENT}-IN-D1-${REPS}-merged-sorted.bam"
#
#    if [[ ! -f "$INPUT_BAM" ]]; then
#        echo "[$count/$total] SKIP: $SAMPLE (no input control)"
#        continue
#    fi

    INPUT_BAM=$(ls ${BAMDIR}/${TREATMENT}-IN-D1*-merged-sorted.bam 2>/dev/null | head -1)

    if [[ -z "$INPUT_BAM" ]]; then
        echo "[$count/$total] SKIP: $SAMPLE (no input control for $TREATMENT)"
        continue
    fi

    # Get the input name for logging
    INPUT_NAME=$(basename "$INPUT_BAM")


    PEAK_DIR="${PEAK_OUT}/${SAMPLE}"
    mkdir -p ${PEAK_DIR}

    echo "[$count/$total] $SAMPLE (Target: $TARGET)"

    # Set flags based on target
    if [[ "$TARGET" == "ME" ]]; then
        # H3K9me3 (methylated) - broad peaks
        MACS_FLAGS="--broad"
        echo "        Using --broad for H3K9me3 methylation marks"
    else
        # AC (H3K27ac) and SR (SREBP) - narrow peaks
        MACS_FLAGS=""
        echo "        Using narrow peaks for $TARGET"
    fi

    # Run MACS2
    macs2 callpeak \
        -t ${BAM} \
        -c ${INPUT_BAM} \
        -f ${FORMAT} \
        -g ${GENOME_SIZE} \
        -n ${SAMPLE} \
        --keep-dup ${KEEP_DUP} \
        --extsize 250 \
        --slocal 2372 \
        ${MACS_FLAGS} \
        --outdir ${PEAK_DIR} \
        2>&1 | tee -a ${PEAK_OUT}/macs2.log

    echo "     ✓ Done"
    echo ""
done

echo "Peak calling complete."
echo "Output: ${PEAK_OUT}"

