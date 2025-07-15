#!/bin/bash

#SBATCH -J snpA
#SBATCH -o /scratch/gpfs/ml9889/intro_to_snparcher_on_della/snpArcher/logs/PALLASCAT_TEST_out.txt
#SBATCH -e /scratch/gpfs/ml9889/intro_to_snparcher_on_della/snpArcher/logs/PALLASCAT_TEST_err.txt
#SBATCH --nodes=1                # node count
#SBATCH --ntasks=1               # total number of tasks across all nodes
#SBATCH --cpus-per-task=1        # cpu-cores per task (>1 if multi-threaded tasks)
#SBATCH --mem=12G                # memory per cpu-core (somewhere between 12 and 96 GB, depending on number of samples and coverage)
#SBATCH --time 06-00:00:00       # DAYS-HOURS:MINUTES:SECONDS (max is 6 days -- I would recommend using the max no matter how long you think this will take)
#SBATCH --mail-type=end          # send email when job ends
#SBATCH --mail-user=NETID@princeton.edu

# NOTE: For 7 samples at areound 10X coverage, I could've used 8 GB of memory and 4 days of time, if that's a helpful orientation point
# for 800 samples I requested 96 GB of memory and 6 days of time. I had to add time.

##############

# if you're running this in a directory where you've already fully or partially run the pipeline, you may need to unlock the directory or rerun incomplete jobs

    # if it throws you an unlock error you can run this with the --unlock argument. Note that this will unlock and then kill the job, so you will then have to resubmit without the --unlock
    # Or, to save time, you can just delete the locks directory in .snakemake and rerun as normal without that flag

    # if there is anything in .snakemake/incomplete, run this with the --rerun-incomplete flag

# define the base directory for snpArcher so we don't have to use such long paths
BASE_DIR=/scratch/gpfs/ml9889/intro_to_snparcher_on_della

###############################

# let compute node know where conda is installed
source ~/miniforge3/etc/profile.d/conda.sh
conda activate snparcher

snakemake \
 --workflow-profile ${BASE_DIR}/snpArcher/workflow-profiles/slurm \
 --snakefile ${BASE_DIR}/snpArcher/workflow/Snakefile \
 --directory ${BASE_DIR}/snpArcher \
 # --rerun-incomplete # --unlock  

