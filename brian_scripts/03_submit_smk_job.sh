#!/bin/bash

#SBATCH -J pcat_snpa
#SBATCH -o /scratch/gpfs/ml9889/intro_to_snparcher_on_della/snpArcher/logs/PALLASCAT_TEST_out.txt
#SBATCH -e /scratch/gpfs/ml9889/intro_to_snparcher_on_della/snpArcher/logs/PALLASCAT_TEST_err.txt
#SBATCH --nodes=1                # node count
#SBATCH --ntasks=1               # total number of tasks across all nodes
#SBATCH --cpus-per-task=1        # cpu-cores per task (>1 if multi-threaded tasks)
#SBATCH --mem=12G                # memory per cpu-core (somewhere between 12 and 48 GB, depending on number of samples and coverage)
#SBATCH --time 06-00:00:00       # DAYS-HOURS:MINUTES:SECONDS (max is 6 days -- I would recommend using the max no matter how long you think this will take)
#SBATCH --mail-type=end          # send email when job ends
#SBATCH --mail-user=ml9889@princeton.edu

# NOTE: For 7 samples at areound 10X coverage, I could've used 8 GB of memory and 4 days of time, if that's a helpful orientation point

##############

# let compute node know where conda is installed
source ~/miniforge3/etc/profile.d/conda.sh
conda activate snparcher

# the base directory where we installed all code and data for this workshop
# storing the base directory in a variable to make things shorter downstream
BASE_DIR=/scratch/gpfs/ml9889/intro_to_snparcher_on_della

snakemake \
 --workflow-profile ${BASE_DIR}/snpArcher/profiles/slurm \
 --snakefile ${BASE_DIR}/snpArcher/workflow/Snakefile \
 --directory ${BASE_DIR}/snpArcher \
 # --rerun-incomplete # --unlock  

# comment out the --rerun-incomplete argument unless the main job errored out at some point, or the cluster crashed, or whatever
# if this happened, you'll probably need to uncomment the unlock argument to unlock the directory (takes just a few minutes). Then, re-comment 
# the unlock argument and submit this script again.

# these are probably no longer needed, but at one point these flags needed to be specified. keeping them here for posterity.
# per snparcher docs, all you NEED now is: workflow-profile, --snakefile (-s), and --directory (-d) 

# --use-conda depreciated in snakemake v8.x > use --software-deployment-method conda instead
# --profile for specific workflows depreciated in snakemake v8.x > use --workflow-profile instead
