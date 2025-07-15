#!/bin/bash

# let compute node know where conda is installed
source ~/miniforge3/etc/profile.d/conda.sh
conda activate snparcher

mkdir -p /scratch/gpfs/ml9889/intro_to_snparcher_on_della/snpArcher/logs

# dry run
snakemake  --snakefile /scratch/gpfs/ml9889/intro_to_snparcher_on_della/snpArcher/workflow/Snakefile \
 --workflow-profile /scratch/gpfs/ml9889/intro_to_snparcher_on_della/snpArcher/workflow-profiles/slurm \
 --directory /scratch/gpfs/ml9889/intro_to_snparcher_on_della/snpArcher \
 --dry-run > /scratch/gpfs/ml9889/intro_to_snparcher_on_della/snpArcher/logs/PALLASCAT_TEST_dry_run.out
