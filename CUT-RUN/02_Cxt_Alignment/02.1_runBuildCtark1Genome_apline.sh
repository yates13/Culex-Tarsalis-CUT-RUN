#!/bin/bash
#SBATCH --partition=amilan
#SBATCH --job-name=Ctark1Build
#SBATCH --output=%x.%j.out
#SBATCH --error=%x.%j.err
#SBATCH --time=4:00:00
#SBATCH --qos=normal
#SBATCH --nodes=1
#SBATCH --cpus-per-task=16
#SBATCH --mail-type=ALL
#SBATCH --mail-user=c832500103@colostate.edu

module purge

# Load conda
source /scratch/alpine/c832500103@colostate.edu/miniconda3/etc/profile.d/conda.sh
conda activate rnaPseudo

# Move into genome directory
cd Cxt_Genome

# Build HISAT2 index
hisat2-build -p 8 CtarK1.fa ../CtarK1_index
