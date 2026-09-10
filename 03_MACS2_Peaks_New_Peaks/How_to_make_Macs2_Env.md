# Delete broken Env
conda env remove -p /scratch/alpine/.colostate.edu/c832500103/conda_envs/macs2_env

# Install new Env 
conda create -p /scratch/alpine/.colostate.edu/c832500103/conda_envs/macs2_env \
    -c bioconda -c conda-forge \
    python=3.10 macs2 -y
