#!/usr/bin/env bash
#SBATCH --qos=cpu-normal
#SBATCH --job-name=computeMatrix_merge
#SBATCH --output=out_log/%x.%A_%a.log
#SBATCH --error=err_log/%x.%A_%a.err
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=4
#SBATCH --mem=8G
#SBATCH --time=06:00:00
#SBATCH --partition=acpu
#SBATCH --mail-type=END,FAIL
#SBATCH --mail-user=c832500103@colostate.edu

set -e

SCRATCH=/scratch/alpine/c832500103@colostate.edu
source ${SCRATCH}/miniconda3/etc/profile.d/conda.sh
conda activate ${SCRATCH}/conda_envs/deeptools_kernel_v2

computeMatrixOperations cbind -m matrix_BF.gz matrix_MP.gz matrix_SF.gz matrix_ZH.gz -o matrix_combined_gene_only_bed_file.gz
#computeMatrixOperations rbind -m matrix_BF.gz matrix_MP.gz matrix_SF.gz matrix_ZH.gz -o matrix_combined_gene_only_bed_file.gz
