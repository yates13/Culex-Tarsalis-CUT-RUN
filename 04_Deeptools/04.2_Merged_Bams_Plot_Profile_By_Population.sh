#!/usr/bin/env bash

#SBATCH --partition=amilan
#SBATCH --job-name=PlotProfile_Merged_Bams_By_Pop
#SBATCH --output=out_log/%x.%A-%a.log
#SBATCH --error=err_log/%x.%A-%a.err
#SBATCH --time=2:00:00
#SBATCH --qos=normal
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=2
#SBATCH --mem=16G
#SBATCH --mail-type=END,FAIL
#SBATCH --mail-user=c832500103@colostate.edu

# ============================================================
# DEEPTOOLS PLOT PROFILE - Culex tarsalis CUT&RUN
# Merged Bams, split into one plot per population (BF/MP/SF/ZH)
# ============================================================
# Each population's plot shows all 6 of its samples
# (AC/ME/SR x D1/D3) together, instead of cramming all 24
# samples from every population onto a single overloaded plot.
#
# Sample labels/order are pulled live from bigwiglist_Merged_Bams.txt,
# same dynamic-naming approach as the other 04.2/04.3 scripts.
#
# USAGE:
#   sbatch 04.2_Merged_Bams_Plot_Profile_By_Population.sh "Your Title"
# ============================================================

set -e
SCRATCH=/scratch/alpine/.colostate.edu/c832500103
source ${SCRATCH}/miniconda3/etc/profile.d/conda.sh
conda activate ${SCRATCH}/conda_envs/deeptools_kernel_v2

DEEPTOOLS_DIR="${SCRATCH}/Cxt_Cut_Run_Pipeline/Round1_Round2_With_Duplicates/04_Deeptools"
BW_LIST="${DEEPTOOLS_DIR}/bigwiglist_Merged_Bams.txt"
MATRIX="${DEEPTOOLS_DIR}/bigwiglist_Merged_Bams_gene_only_bed_file.gz"
OUTDIR="${DEEPTOOLS_DIR}/Figures_Merged_Samples"
mkdir -p "$OUTDIR" out_log err_log

# Verify deeptools tools are installed
if ! command -v plotProfile &> /dev/null; then
    echo "ERROR: plotProfile not found. Install with: conda install deeptools"
    exit 1
fi
if ! command -v computeMatrixOperations &> /dev/null; then
    echo "ERROR: computeMatrixOperations not found. Install with: conda install deeptools"
    exit 1
fi

# ============================================================
# INPUT VALIDATION
# ============================================================

if [[ $# -lt 1 ]]; then
    echo "ERROR: Missing title argument"
    echo "USAGE: sbatch 04.2_Merged_Bams_Plot_Profile_By_Population.sh 'Your Title'"
    exit 1
fi
TITLE_BASE=$1

if [[ ! -f "$MATRIX" ]]; then
    echo "ERROR: Matrix file not found: $MATRIX"
    exit 1
fi

if [[ ! -f "$BW_LIST" ]]; then
    echo "ERROR: Bigwig list not found: $BW_LIST"
    exit 1
fi

echo "============================================================"
echo "DEEPTOOLS PLOT PROFILE - Merged Bams, by population"
echo "============================================================"
echo "Matrix: $(basename $MATRIX)"
echo "Sample list: $BW_LIST"
echo "Title base: $TITLE_BASE"
echo ""

# ============================================================
# DERIVE SAMPLE LABELS DIRECTLY FROM THE MATRIX
# ============================================================
# computeMatrixOperations subset needs EXACT sample names as
# stored inside the matrix, which may differ from the bigwig
# filenames (e.g. computeMatrix may keep "_inputsubtracted" or
# a full path-derived string as the label). Pulling from
# `computeMatrixOperations info` guarantees an exact match.

INFO_OUTPUT=$(computeMatrixOperations info -m "$MATRIX")
mapfile -t ALL_SAMPLES < <(echo "$INFO_OUTPUT" | awk '/^Samples:/{f=1; next} /^[A-Za-z]+:/{f=0} f{gsub(/^[ \t]+|[ \t]+$/, ""); print}')

if [[ ${#ALL_SAMPLES[@]} -eq 0 ]]; then
    echo "ERROR: Could not parse sample labels from matrix info. Raw output:"
    echo "$INFO_OUTPUT"
    exit 1
fi

echo "Found ${#ALL_SAMPLES[@]} total samples:"
for s in "${ALL_SAMPLES[@]}"; do
    echo "  - $s"
done
echo ""

if [[ ${#ALL_SAMPLES[@]} -ne 24 ]]; then
    echo "WARNING: Expected 24 samples (4 pops x AC/ME/SR x D1/D3), found ${#ALL_SAMPLES[@]}."
fi

# ============================================================
# COLOR ASSIGNMENT: population -> color family, D1=light, D3=dark
# ============================================================

get_color() {
    local s="$1"
    case "$s" in
        BF-AC-D1-*) echo "#1E90FF" ;;
        BF-AC-D3-*) echo "#0047AB" ;;
        BF-ME-D1-*) echo "#6495ED" ;;
        BF-ME-D3-*) echo "#4169E1" ;;
        BF-SR-D1-*) echo "#ADD8E6" ;;
        BF-SR-D3-*) echo "#87CEEB" ;;
        MP-AC-D1-*) echo "#FFA500" ;;
        MP-AC-D3-*) echo "#CC7000" ;;
        MP-ME-D1-*) echo "#FFD580" ;;
        MP-ME-D3-*) echo "#FFB347" ;;
        MP-SR-D1-*) echo "#FFEC8B" ;;
        MP-SR-D3-*) echo "#DAA520" ;;
        SF-AC-D1-*) echo "#228B22" ;;
        SF-AC-D3-*) echo "#006400" ;;
        SF-ME-D1-*) echo "#90EE90" ;;
        SF-ME-D3-*) echo "#32CD32" ;;
        SF-SR-D1-*) echo "#C6E2C6" ;;
        SF-SR-D3-*) echo "#66CDAA" ;;
        ZH-AC-D1-*) echo "#FF6347" ;;
        ZH-AC-D3-*) echo "#B22222" ;;
        ZH-ME-D1-*) echo "#FF7F7F" ;;
        ZH-ME-D3-*) echo "#DC143C" ;;
        ZH-SR-D1-*) echo "#FFA07A" ;;
        ZH-SR-D3-*) echo "#8B0000" ;;
        *) echo "#808080" ;;  # gray fallback if a sample doesn't match any known pattern
    esac
}

# ============================================================
# PROFILE PLOT SETTINGS
# ============================================================

Y_LABEL="Reads per Genomic Content"
REF_POINT_LABEL="TSS"

# ============================================================
# LOOP THROUGH POPULATIONS
# ============================================================

for POP in BF MP SF ZH; do
    for DAY in D1 D3; do
        echo "============================================================"
        echo "POPULATION: $POP   DAY: $DAY"
        echo "============================================================"

        # This population+day's subset of the full sample list, in matrix order
        POP_SAMPLES=()
        for s in "${ALL_SAMPLES[@]}"; do
            [[ "$s" == ${POP}-*-${DAY}-* ]] && POP_SAMPLES+=("$s")
        done

        if [[ ${#POP_SAMPLES[@]} -eq 0 ]]; then
            echo "  No $POP $DAY samples found - skipping"
            continue
        fi
        echo "  Samples: ${POP_SAMPLES[*]}"

        # Colors for just this population+day's samples
        POP_COLORS=()
        for s in "${POP_SAMPLES[@]}"; do
            POP_COLORS+=("$(get_color "$s")")
        done

        # Subset the full matrix down to this population+day
        MATRIX_POP="${DEEPTOOLS_DIR}/matrix_Merged_Bams_${POP}_${DAY}.gz"
        computeMatrixOperations subset \
            -m "$MATRIX" \
            --samples "${POP_SAMPLES[@]}" \
            -o "$MATRIX_POP"

        plotProfile \
            -m "$MATRIX_POP" \
            -out "${OUTDIR}/${POP}_${DAY}_Merged_Bams_profile.png" \
            --perGroup \
            --colors "${POP_COLORS[@]}" \
            --refPointLabel "$REF_POINT_LABEL" \
            -T "${TITLE_BASE} — ${POP} ${DAY} Only" \
            --samplesLabel "${POP_SAMPLES[@]}" \
            -y "$Y_LABEL" \
            --regionsLabel " " \
            --legendLocation "best" \
            --plotHeight 8 \
            --plotWidth 14 \
            --dpi 300

        echo "  ✔ Created: ${OUTDIR}/${POP}_${DAY}_Merged_Bams_profile.png"
        echo ""
    done
done

echo "All population/day profile plots complete."
echo "Output files in ${OUTDIR}/:"
ls -lh "${OUTDIR}/"*_Merged_Bams_profile.png 2>/dev/null | awk '{print "  " $9 " (" $5 ")"}'
