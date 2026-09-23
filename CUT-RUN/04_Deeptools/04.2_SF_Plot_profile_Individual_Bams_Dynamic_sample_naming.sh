#!/usr/bin/env bash
#SBATCH --partition=acpu
#SBATCH --job-name=SF_Targets_Individual_Bams_dynamic_naming
#SBATCH --output=out_log/%x.%A-%a.log
#SBATCH --error=err_log/%x.%A-%a.err
#SBATCH --time=1:00:00
#SBATCH --qos=cpu-normal
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=2
#SBATCH --mem=16G
#SBATCH --mail-type=END,FAIL
#SBATCH --mail-user=c832500103@colostate.edu
set -e
SCRATCH=/scratch/alpine/.colostate.edu/c832500103
source ${SCRATCH}/miniconda3/etc/profile.d/conda.sh
conda activate ${SCRATCH}/conda_envs/deeptools_kernel_v2
DEEPTOOLS_DIR="${SCRATCH}/Cxt_Cut_Run_Pipeline/Round1_Round2_With_Duplicates/04_Deeptools"
BW_DIR="${DEEPTOOLS_DIR}/00_BigWig_Files_Individual_Bams"
#MATRIX="${DEEPTOOLS_DIR}/bigwiglist_Individual_Bams_gene_only_bed_file.gz"
MATRIX="${DEEPTOOLS_DIR}/matrix_combined_gene_only_bed_file.gz"
OUTDIR="${DEEPTOOLS_DIR}/Figures"
mkdir -p "$OUTDIR" out_log err_log
COLOR_PALETTE=(forestgreen seagreen mediumseagreen darkgreen limegreen olivedrab yellowgreen springgreen)
# ============================================================
# Loop through targets and days, building sample lists live
# from whatever bigwigs actually exist on disk
# ============================================================
for TARGET in AC ME SR; do
    for DAY in D1 D3; do
        echo "============================================================"
        echo "TARGET: $TARGET   DAY: $DAY"
        echo "============================================================"
        # All sites, this target + day
        mapfile -t ALL_SAMPLES < <(
            ls "${BW_DIR}"/*-${TARGET}-${DAY}-*_inputsubtracted.bw 2>/dev/null \
                | xargs -n1 basename \
                | sed 's/_inputsubtracted\.bw$//' \
                | sort
        )
        if [[ ${#ALL_SAMPLES[@]} -eq 0 ]]; then
            echo "  No samples found for ${TARGET} ${DAY} — skipping"
            continue
        fi
        echo "  Found ${#ALL_SAMPLES[@]} samples: ${ALL_SAMPLES[*]}"
        # SF-only subset of the above
        SF_SAMPLES=()
        for s in "${ALL_SAMPLES[@]}"; do
            [[ "$s" == SF-* ]] && SF_SAMPLES+=("$s")
        done
        if [[ ${#SF_SAMPLES[@]} -eq 0 ]]; then
            echo "  No SF samples for ${TARGET} ${DAY} — skipping SF plot"
            continue
        fi
        echo "  SF samples: ${SF_SAMPLES[*]}"
        # Step 1 — subset all-samples matrix down to this target+day
        MATRIX_TARGET="${DEEPTOOLS_DIR}/matrix_${TARGET}_${DAY}_ALL.gz"
        computeMatrixOperations subset \
            -m "$MATRIX" \
            --samples "${ALL_SAMPLES[@]}" \
            -o "$MATRIX_TARGET"
        # Step 2 — subset down further to SF only
        MATRIX_SF="${DEEPTOOLS_DIR}/matrix_${TARGET}_${DAY}_SF.gz"
        computeMatrixOperations subset \
            -m "$MATRIX_TARGET" \
            --samples "${SF_SAMPLES[@]}" \
            -o "$MATRIX_SF"
        # Enough colors for however many SF reps exist this round
        n=${#SF_SAMPLES[@]}
        PLOT_COLORS=("${COLOR_PALETTE[@]:0:$n}")
        plotProfile \
            -m "$MATRIX_SF" \
            -out "${OUTDIR}/${TARGET}_${DAY}_SF_profile.png" \
            --perGroup \
            --colors "${PLOT_COLORS[@]}" \
            --samplesLabel "${SF_SAMPLES[@]}" \
            --regionsLabel "" \
            -T "${TARGET} ${DAY} — SF Only" \
            -y "Reads per Genomic Content" \
            --yMin -0.3 \
            --yMax 0.8 \
            --plotHeight 8 \
            --plotWidth 12 \
            --dpi 300
        echo "  ✔ Created: ${OUTDIR}/${TARGET}_${DAY}_SF_profile.png"
    done
done
echo "All SF-only target/day plots complete."
