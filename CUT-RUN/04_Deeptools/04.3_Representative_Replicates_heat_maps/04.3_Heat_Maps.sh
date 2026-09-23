#!/usr/bin/env bash
#SBATCH --partition=acpu
#SBATCH --job-name=All_Marks_By_Day_Heatmap
#SBATCH --output=out_log/%x.%A-%a.log
#SBATCH --error=err_log/%x.%A-%a.err
#SBATCH --time=4:00:00
#SBATCH --qos=cpu-normal
#SBATCH --nodes=1
#SBATCH --ntasks=2
#SBATCH --cpus-per-task=8
#SBATCH --mem=64G
#SBATCH --mail-type=END,FAIL
#SBATCH --mail-user=c832500103@colostate.edu

# ============================================================
# DEEPTOOLS PLOT HEATMAP - Culex tarsalis CUT&RUN
# ONE HEATMAP PER TARGET x DAY, ONE REPRESENTATIVE REPLICATE
# PER MARK (BF, MP, ZH, SF)
# ============================================================
# For every TARGET + DAY, picks the pre-defined representative
# replicate for each mark, subsets the combined matrix to just
# those 4 samples, and plots a heatmap with all 4 marks as
# side-by-side panels.
#
# USAGE:
#   sbatch 04.3_Heat_Maps.sh "Base Title"
# ============================================================

set -e

SCRATCH=/scratch/alpine/c832500103@colostate.edu
source ${SCRATCH}/miniconda3/etc/profile.d/conda.sh
conda activate ${SCRATCH}/conda_envs/deeptools_kernel_v2

DEEPTOOLS_DIR="${SCRATCH}/Cxt_Cut_Run_Pipeline/Round1_Round2_With_Duplicates/04_Deeptools"
BW_DIR="${DEEPTOOLS_DIR}/00_BigWig_Files_Individual_Bams"
MATRIX="${DEEPTOOLS_DIR}/matrix_combined_gene_only_bed_file.gz"
OUTDIR="${DEEPTOOLS_DIR}/04.3_Representative_Replicates_heat_maps/Figures/All_Marks_By_Day_Heatmap"
mkdir -p "$OUTDIR" out_log err_log

if ! command -v plotHeatmap &> /dev/null; then
    echo "ERROR: plotHeatmap not found. Install with: conda install deeptools"
    exit 1
fi


if ! command -v computeMatrixOperations &> /dev/null; then
    echo "ERROR: computeMatrixOperations not found."
    exit 1
fi

if [[ ! -f "$MATRIX" ]]; then
    echo "ERROR: Combined matrix not found: $MATRIX"
    exit 1
fi

if [[ $# -lt 1 ]]; then
    echo "ERROR: Missing title argument"
    echo "USAGE: sbatch 04.7_All_Marks_By_Day_Heatmap.sh 'Base Title'"
    exit 1
fi
BASE_TITLE=$1

# ============================================================
# HEATMAP SETTINGS
# ============================================================

COLORMAP="RdBu"
Z_MIN="auto"
Z_MAX="auto"
REF_POINT_LABEL="TSS"
WHAT_TO_SHOW="heatmap and colorbar"

# ============================================================
# Representative replicate for every MARK_TARGET_DAY combination
# (identical to 04.6 — keep these two scripts in sync if you
# update representative reps in one, update the other)
# ============================================================
declare -A REP_MAP=(
    [BF_AC_D1]="R2"  [BF_AC_D3]="R4"  [BF_ME_D1]="R2"  [BF_ME_D3]="R3"  [BF_SR_D1]="R3"  [BF_SR_D3]="R2"
    [MP_AC_D1]="R2"  [MP_AC_D3]="R1"  [MP_ME_D1]="R1"  [MP_ME_D3]="R1"  [MP_SR_D1]="R3"  [MP_SR_D3]="R3"
    [ZH_AC_D1]="R3"  [ZH_AC_D3]="R3"  [ZH_ME_D1]="R3"  [ZH_ME_D3]="R3"  [ZH_SR_D1]="R1"  [ZH_SR_D3]="R3"
    [SF_AC_D1]="R2"  [SF_AC_D3]="R3"  [SF_ME_D1]="R2"  [SF_ME_D3]="R3"  [SF_SR_D1]="R3"  [SF_SR_D3]="R2"
)

# ============================================================
# For every TARGET + DAY, gather one representative sample per
# MARK and plot all four marks as panels in a single heatmap
# ============================================================

FAILED=0

for TARGET in AC ME SR; do
    for DAY in D1 D3; do
        echo "============================================================"
        echo "TARGET: $TARGET   DAY: $DAY"
        echo "============================================================"

        SAMPLES=()
        LABELS=()

        for MARK in SF BF MP ZH; do
            REP="${REP_MAP[${MARK}_${TARGET}_${DAY}]:-}"

            if [[ -z "$REP" ]]; then
                echo "  No representative defined for ${MARK} ${TARGET} ${DAY} — skipping mark"
                continue
            fi

            mapfile -t MARK_SAMPLES < <(
                ls "${BW_DIR}"/${MARK}-${TARGET}-${DAY}-*_inputsubtracted.bw 2>/dev/null \
                    | xargs -n1 basename \
                    | sed 's/_inputsubtracted\.bw$//' \
                    | sort
            )

            SAMPLE=""
            for s in "${MARK_SAMPLES[@]}"; do
                if [[ "$s" == *"-${REP}" || "$s" == *"-${REP}-"* ]]; then
                    SAMPLE="$s"
                    break
                fi
            done

            if [[ -z "$SAMPLE" ]]; then
                echo "  Representative '${REP}' not found among ${MARK} samples for ${TARGET} ${DAY} — skipping mark"
                continue
            fi

            echo "  ${MARK}: using ${SAMPLE}"
            SAMPLES+=("$SAMPLE")
            LABELS+=("$MARK")
        done

        if [[ ${#SAMPLES[@]} -eq 0 ]]; then
            echo "  No marks found for ${TARGET} ${DAY} — skipping"
            FAILED=1
            continue
        fi

        DAY_DIR="${OUTDIR}/${DAY}"
        mkdir -p "$DAY_DIR"

        MATRIX_TD="${DEEPTOOLS_DIR}/matrix_${TARGET}_${DAY}_AllMarks_Heatmap.gz"
        TITLE="${BASE_TITLE} - ${TARGET} ${DAY}"

        echo "  Subsetting matrix to representative samples..."
        computeMatrixOperations subset \
            -m "$MATRIX" \
            --samples "${SAMPLES[@]}" \
            -o "$MATRIX_TD"

        if [[ ! -f "$MATRIX_TD" ]]; then
            echo "  ERROR: Subset failed for ${TARGET} ${DAY}, skipping"
            FAILED=1
            continue
        fi

        echo "  Creating heatmap..."
        plotHeatmap \
            -m "$MATRIX_TD" \
            -out "${DAY_DIR}/${TARGET}_${DAY}_AllMarks_heatmap.png" \
            --colorMap "$COLORMAP" \
            --whatToShow "$WHAT_TO_SHOW" \
            --refPointLabel "$REF_POINT_LABEL" \
            --samplesLabel "${LABELS[@]}" \
            -T "$TITLE" \
            --zMin "$Z_MIN" \
            --zMax "$Z_MAX" \
            --dpi 300 \
            --regionsLabel " "

        if [[ $? -eq 0 ]]; then
            echo " Created: ${DAY_DIR}/${TARGET}_${DAY}_AllMarks_heatmap.png"
        else
            echo " Heatmap creation FAILED for ${TARGET} ${DAY}"
            FAILED=1
        fi
        echo ""
    done
done

echo "============================================================"
echo "All target/day AllMarks heatmaps complete."
echo "============================================================"

if [[ "$FAILED" -eq 1 ]]; then
    echo "One or more target/day combinations failed or were skipped - see warnings above."
    exit 1
fi
