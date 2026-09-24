# Remove the Env
conda env remove -p /scratch/alpine/.colostate.edu/c832500103/conda_envs/deeptools_kernel_v2

# Make the new Env
conda create -p /scratch/alpine/.colostate.edu/c832500103/conda_envs/deeptools_kernel_v2 \
    -c bioconda -c conda-forge \
    python=3.10 deeptools -y
