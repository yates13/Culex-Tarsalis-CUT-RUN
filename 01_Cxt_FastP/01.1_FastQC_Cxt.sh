#!/bin/bash
#SBATCH --partition=acpu
#SBATCH --job-name=FastP_Cxt_array
#SBATCH --output=logs/%x.%j.out
#SBATCH --error=logs/%x.%j.err
#SBATCH --time=2:00:00
#SBATCH --qos=cpu-normal
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --mem=8G
#SBATCH --array=1-96
#SBATCH --cpus-per-task=8
#SBATCH --mail-type=ALL
#SBATCH --mail-user=c832500103@colostate.edu


# Run this before submitting the job
# mkdir -p logs
#cd /scratch/alpine/c832500103@colostate.edu/Cxt_Cut_Run_Raw_Files
#ls *R1_001.fastq.gz | grep -v '\.md5$' | sort > r1_file_list.txt
#wc -l r1_file_list.txt

SCRATCH=/scratch/alpine/.colostate.edu/c832500103
source ${SCRATCH}/miniconda3/etc/profile.d/conda.sh || { echo "ERROR: conda.sh not found at ${SCRATCH}/miniconda3"; exit 1; }
conda activate ${SCRATCH}/conda_envs/fastp_env || { echo "ERROR: conda activate rnaPseudo failed"; exit 1; }

#source /scratch/alpine/c832500103@colostate.edu/miniconda3/etc/profile.d/conda.sh
#conda activate fastp_env
#conda activate



# Directory containing your FASTQ files
INDIR="/scratch/alpine/c832500103@colostate.edu/Cxt_Cut_Run_Raw_Files"
OUTDIR="/scratch/alpine/c832500103@colostate.edu/Cxt_Cut_Run_Pipeline/Round1_Round2_With_Duplicates/01_Cxt_FastP/01.1_Cxt_fastp_out"
R1_LIST="${INDIR}/r1_file_list.txt"

mkdir -p $OUTDIR


# Move into the FASTQ directory
cd "$INDIR"

######################## Loop through each file (takes to long) 
# Loop through all R1 files
#for R1 in *R1_001.fastq.gz; do

 # Skip md5 files
 #   [[ "$R1" == *.md5 ]] && continue

    # Derive the matching R2 filename
  #  R2=${R1/_R1_/_R2_}

   # if [[ ! -f "$R2" ]]; then
    #    echo "⚠️  No R2 found for $R1 — skipping."
     #   continue
   # fi
########################

######################## Run as an array
R1=$(sed -n "${SLURM_ARRAY_TASK_ID}p" "$R1_LIST")

if [[ -z "$R1" ]]; then
    echo "ERROR: No R1 file found for array index $SLURM_ARRAY_TASK_ID"
    exit 1
fi

R2=${R1/_R1_/_R2_}
if [[ ! -f "$INDIR/$R2" ]]; then
    echo "No R2 found for $R1 - skipping."
    exit 0
fi

    # Extract sample name prefix (everything before _R1)
    SAMPLE=${R1%%_R1_001.fastq.gz}
    echo "Task $SLURM_ARRAY_TASK_ID: Processing sample: $SAMPLE"
#    echo "Processing sample: $SAMPLE"

    fastp \
        -i "$INDIR/$R1" \
        -I "$INDIR/$R2" \
        -o "$OUTDIR/${SAMPLE}_R1_trimmed.fastq.gz" \
        -O "$OUTDIR/${SAMPLE}_R2_trimmed.fastq.gz" \
        --html "$OUTDIR/${SAMPLE}_fastp.html" \
        --json "$OUTDIR/${SAMPLE}_fastp.json" \
        --thread 8
#done


