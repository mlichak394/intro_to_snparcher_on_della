#!/bin/bash

# let compute node know where conda/mamba is installed, following miniforge instructions
source ~/miniforge3/etc/profile.d/conda.sh
# activate conda environment
conda activate snparcherV2

# run the following command to install all conda environments on the login node, which has internet access
snakemake --directory /scratch/gpfs/CAMPBELLSTATON/ml9889/elephant/snpArcher \
 --snakefile /scratch/gpfs/CAMPBELLSTATON/ml9889/elephant/snpArcher/workflow/Snakefile \
 --cores 1 \
 --conda-create-envs
