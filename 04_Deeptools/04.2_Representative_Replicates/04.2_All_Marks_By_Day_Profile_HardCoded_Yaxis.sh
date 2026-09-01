#!/usr/bin/env bash
#SBATCH --partition=acpu
#SBATCH --job-name=All_Marks_By_Day_Profile
#SBATCH --output=out_log/%x.%A-%a.log
#SBATCH --error=err_log/%x.%A-%a.err
#SBATCH --time=1:00:00
#SBATCH --qos=cpu-normal
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=2
#SBATCH --mem=64G
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
OUTDIR="${DEEPTOOLS_DIR}/04.2_Representative_Replicates/Figures/All_Marks_By_Day"
mkdir -p "$OUTDIR" out_log err_log

# Hard-coded shared y-axis range for every graph (from visual inspection of prior plots)
YMIN="-0.10"
YMAX="0.55"

# ============================================================
# One color per mark (BF, MP, ZH, SF) — consistent across every plot
# ============================================================
declare -A MARK_COLORS=(
    [BF]="darkorange"
    [MP]="forestgreen"
    [ZH]="crimson"
    [SF]="purple"
)

# ============================================================
# Representative replicate for every MARK_TARGET_DAY combination
# Note: actual sample names use "R1", "R2", "R3"... not "Rep1", "Rep2"...
# ============================================================
declare -A REP_MAP=(
    [BF_AC_D1]="R2"  [BF_AC_D3]="R4"  [BF_ME_D1]="R2"  [BF_ME_D3]="R3"  [BF_SR_D1]="R3"  [BF_SR_D3]="R2"
    [MP_AC_D1]="R2"  [MP_AC_D3]="R1"  [MP_ME_D1]="R1"  [MP_ME_D3]="R1"  [MP_SR_D1]="R3"  [MP_SR_D3]="R3"
    [ZH_AC_D1]="R3"  [ZH_AC_D3]="R3"  [ZH_ME_D1]="R3"  [ZH_ME_D3]="R3"  [ZH_SR_D1]="R1"  [ZH_SR_D3]="R3"
    [SF_AC_D1]="R2"  [SF_AC_D3]="R3"  [SF_ME_D1]="R2"  [SF_ME_D3]="R3"  [SF_SR_D1]="R3"  [SF_SR_D3]="R2"
)

# ============================================================
# For every TARGET + DAY, gather one representative sample per MARK
# and plot all four marks together in a single graph, sharing a
# fixed y-axis range across every graph
# ============================================================
for TARGET in AC ME SR; do
    for DAY in D1 D3; do
        echo "============================================================"
        echo "TARGET: $TARGET   DAY: $DAY"
        echo "============================================================"

        SAMPLES=()
        LABELS=()
        COLORS=()

        for MARK in BF MP ZH SF; do
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
            COLORS+=("${MARK_COLORS[$MARK]}")
        done

        if [[ ${#SAMPLES[@]} -eq 0 ]]; then
            echo "  No marks found for ${TARGET} ${DAY} — skipping"
            continue
        fi

        DAY_DIR="${OUTDIR}/${DAY}"
        mkdir -p "$DAY_DIR"

        MATRIX_TD="${DEEPTOOLS_DIR}/matrix_${TARGET}_${DAY}_AllMarks.gz"
        computeMatrixOperations subset \
            -m "$MATRIX" \
            --samples "${SAMPLES[@]}" \
            -o "$MATRIX_TD"

        plotProfile \
            -m "$MATRIX_TD" \
            -out "${DAY_DIR}/${TARGET}_${DAY}_AllMarks.png" \
            --perGroup \
            --colors "${COLORS[@]}" \
            --samplesLabel "${LABELS[@]}" \
            --regionsLabel "" \
            -T "${TARGET} ${DAY} — All Marks (BF, MP, ZH, SF)" \
            -y "Reads per Genomic Content" \
            --yMin "$YMIN" \
            --yMax "$YMAX" \
            --plotHeight 8 \
            --plotWidth 12 \
            --dpi 300

        echo "  Created: ${DAY_DIR}/${TARGET}_${DAY}_AllMarks.png"
    done
done

echo "All target/day AllMarks plots complete with fixed y-axis (${YMIN} to ${YMAX})."
