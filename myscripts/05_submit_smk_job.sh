#!/bin/bash
#SBATCH -J snpA
#SBATCH -o /scratch/gpfs/CAMPBELLSTATON/ml9889/elephant/snpArcher/logs/%J.out
#SBATCH -e /scratch/gpfs/CAMPBELLSTATON/ml9889/elephant/snpArcher/logs/%J.err
#SBATCH --cpus-per-task=1        # cpu-cores per task (>1 if multi-threaded tasks)
#SBATCH --mem=4G                # memory per cpu-core (4G is default)
#SBATCH --time 01-00:00:00       # DAYS-HOURS:MINUTES:SECONDS
#SBATCH --mail-type=end          # send email when job ends
#SBATCH --mail-user=ml9889@princeton.edu

# let compute node know where conda is installed
source ~/miniforge3/etc/profile.d/conda.sh
conda activate snparcherV2

BASE_DIR=/scratch/gpfs/CAMPBELLSTATON/ml9889/elephant

snakemake \
 --workflow-profile ${BASE_DIR}/snpArcher/workflow-profiles/slurm \
 --snakefile ${BASE_DIR}/snpArcher/workflow/Snakefile \
 --directory ${BASE_DIR}/snpArcher --rerun-incomplete