#!/bin/bash

# let compute node know where conda/mamba is installed, following miniforge instructions
source ~/miniforge3/etc/profile.d/conda.sh
# activate conda environment
conda activate snparcher

# run the following command to install all conda environments on the login node, which has internet access
snakemake --directory /scratch/gpfs/ml9889/deer/snpArcher \
 --snakefile /scratch/gpfs/ml9889/deer/snpArcher/workflow/Snakefile \
 --cores 1 \
 --use-conda \
 --conda-frontend mamba \
 --conda-create-envs-
