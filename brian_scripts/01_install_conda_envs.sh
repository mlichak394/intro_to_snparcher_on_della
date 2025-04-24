#!/bin/bash

# let compute node know where conda/mamba is installed, following miniforge instructions
source ~/miniforge3/etc/profile.d/conda.sh
# activate conda environment
conda activate snparcher

# run the following command to install all conda environments on the login node, which has internet access
# this might throw an error (I think --use-conda is depreciated). If it doesn't work and you need to update this
# script let me know so I can change this on the github
snakemake --directory /scratch/gpfs/ml9889/intro_to_snparcher_on_della/snpArcher \
 --snakefile /scratch/gpfs/ml9889/intro_to_snparcher_on_della/snpArcher/workflow/Snakefile \
 --cores 1 \
 --use-conda \
 --conda-frontend mamba \
 --conda-create-envs-
