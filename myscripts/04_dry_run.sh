#!/bin/bash

# let compute node know where conda is installed
source ~/miniforge3/etc/profile.d/conda.sh
conda activate snparcherV2

# dry run
snakemake  --snakefile /scratch/gpfs/CAMPBELLSTATON/ml9889/elephant/snpArcher/workflow/Snakefile \
 --directory /scratch/gpfs/CAMPBELLSTATON/ml9889/elephant/snpArcher \
 --workflow-profile /scratch/gpfs/CAMPBELLSTATON/ml9889/elephant/snpArcher/workflow-profiles/slurm \
 --dry-run > /scratch/gpfs/CAMPBELLSTATON/ml9889/elephant/snpArcher/logs/dry_run_minimal.out
