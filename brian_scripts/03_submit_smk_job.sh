#!/bin/bash

#SBATCH -J deer_snparch
#SBATCH -o /scratch/gpfs/ml9889/deer/snpArcher/logs/Ovbor1.2_out5.txt
#SBATCH -e /scratch/gpfs/ml9889/deer/snpArcher/logs/Ovbor1.2_err5.txt
#SBATCH --nodes=1                # node count
#SBATCH --ntasks=1               # total number of tasks across all nodes
#SBATCH --cpus-per-task=1        # cpu-cores per task (>1 if multi-threaded tasks)
#SBATCH --mem=12G                # memory per cpu-core (4G is default)
#SBATCH --time 06-00:00:00       # DAYS-HOURS:MINUTES:SECONDS
#SBATCH --mail-type=end          # send email when job ends
#SBATCH --mail-user=ml9889@princeton.edu

##############
#    NOTE    #
##############
# for this number of samples (7), I probably could've used 4 GB of memory and 
# 1.5 to 2 days of time
##############

# let compute node know where conda is installed
source ~/miniforge3/etc/profile.d/conda.sh
conda activate snparcher

# the base directory where we installed all code and data for this workshop
# I had some troble previously with relative paths, so I'm using absolute paths here, 
# storing the base directory in a variable to make things shorter downstream
BASE_DIR=/scratch/gpfs/ml9889/deer

snakemake \
 --workflow-profile ${BASE_DIR}/snpArcher/profiles/slurm \
 --snakefile ${BASE_DIR}/snpArcher/workflow/Snakefile \
 --directory ${BASE_DIR}/snpArcher \
 --rerun-incomplete # --unlock  # comment the unlock argument out unless it's throwing you an unlock error

# --use-conda depreciated in snakemake v8.x > use --software-deployment-method conda instead
# --profile for specific workflows depreciated in snakemake v8.x > use --workflow-profile instead
# need: workflow-profile, --snakefile (-s), and --directory (-d) per snparcher docs