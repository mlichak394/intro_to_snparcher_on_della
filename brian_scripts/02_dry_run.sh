#!/bin/bash

# let compute node know where conda is installed
source ~/miniforge3/etc/profile.d/conda.sh
conda activate snparcher

mkdir -p /scratch/gpfs/ml9889/deer/snpArcher/logs

# dry run
snakemake  --snakefile /scratch/gpfs/ml9889/deer/snpArcher/workflow/Snakefile \
 --directory /scratch/gpfs/ml9889/deer/snpArcher \
 --use-conda \
 --dry-run > /scratch/gpfs/ml9889/deer/snpArcher/logs/Ovbor1.2_dry_run.out
