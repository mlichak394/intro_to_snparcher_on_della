# Setting up and running snpArcher on Della

I highly recommend reading the [snpArcher docs](https://snparcher.readthedocs.io/en/latest/setup.html), especially if it's been a few months since this guide has been updated. The docs aren't super detailed, but they are readable and helpful. 

Additionaly, the snpArcher github "issues" page is an excellent resource if you ever run into problems. Check the resolved threads. If you need to ask a new question, the guys who are currently developing snpArcher seem friendly and willing to help. 

## (1) Setting up the main snparcher environment

The first thing the setup guide in the docs recommends is making a new snparcher conda environment. The current command is below, but check the docs to make sure these are still the versions of snakemake and python it wants you using

`mamba create -c conda-forge -c bioconda -n snparcher "snakemake>=8" "python==3.11.4"`

In Brian's tutorial he suggests then doing the following, to circumvent an error on Della.

`mamba install -n snparcher -c conda-forge mamba`

Once you do this, you won't need to do it again the next time you use snpArcher. 

Then, you'll need to clone the snpArcher github repo, which contains the pipeline and code. Do this with

`git clone https://github.com/harvardinformatics/snpArcher.git`

I've always cloned a new repo for each project. I think this helps prevent me from accidentally overwriting some outputs. It also means you're always getting the newest version of the pipeline when you run it. This is a good and a bad thing -- you'll always get the latest features, but sometimes updates break the set up and this requires tinkering. It also means you'll have to do some of the setup steps below every time you reclone the repo. 

## (2) Configuring snpArcher  

You will need to get a couple of things set up prior to running snpArcher.

1. The most important is creating a samples.csv file, which you'll need to add to the `config` subdirectory. This gives the pipeline all of the metadata it needs to run. Some tips:

    - There is a script,  `workflow/snparcher_utils/write_samples.py` that can help you create this, but I find it's only suitable in a few situations. I almost always make mine at least semi by hand, often using formulas in excel or google sheets. 

    - See the docs for the required columns. You will want to specify absolute paths.

    - The SampleType column is optional, but you need to have it if you want to generate the cool QC html at the end of the pipeline. Include this column in your samples.csv and set its value to `include` for all samples (unless you know some samples are bad, then you could set these to `exclude`).

    - I don't recommend changing the name of this file -- just call it `samples.csv` and stick it in the `config` subdirectory

2. The `config.yaml` file in this `config` subdirectory contains a lot of parameters you can adjust. Brian's workshop suggests just leaving most of these at the default. Here are the things you need to change, or may want to change:
    - `samples` -- ESSENTIAL, the absolute path to your samples.csv 

    - `final_prefix` -- ESSENTIAL, this is the prefix your results files will have

    - The pipeline was originally written for low coverage data, so the low coverage options will be selected by default. If you're working with data that has higher coverage than say, 10X, you should comment these lines out and uncomment the ones for high coverage data

    - I remove the string in `scaffolds_to_exclude`, unless you know the name of some scaffolds or chromosomes you don't want in the final VCF

    - You either need to set `generate_trackhub` to FALSE or specify your email address in trackhub_email. I don't know how genome browser trackhubs work, so I never generate this.

    - OPTIONAL: If you have a lot of samples (like >100 ish), I would consider reducing the db_scatter_factor and maybe the num_gvcf_intervals. 
        - In the past, I've had trouble with the pipeline lagging or stalling if the DAG contains thousands and thousands of jobs it needs to traverse. Do some back of the envelope calculations to determine how many variant calling jobs will run by doing `# of samples * num_gvcf_intervals value` and how many genotype calling jobs will run with `# of samples * num_gvcf_intervals value * db_scatter_factor value`. e.g. I once ran the pipeline on 800 samples and tried to keep these parameter values at the defaults. This meant 800 * 50 = 40,000 bam2gvcf jobs and 800 * 50 * 0.15 = 6000 gvcf2DB jobs. This is a **ton** of jobs! When figuring out which rules to run, Snakemake will assess dependencies and hold the entire tree of possible jobs in memory. Traversing this tree (the DAG) each instance a rule is run can quickly become very, very slow.
        - I recommend setting a value that keeps the number of variant calling jobs to less than, idk, 5000-10000, and database creation and genotype calling jobs to ≤1000 ish. So for this example, I might try num_gvcf_intervals: 15 and db_scatter_factor: 0.02. Each job will take longer to run, but there will be fewer of them, reducing memory needs and time needed for the pipeline to traverse the DAG.
        - Note, if you try to change these parameters after gvcfs have already been created, ie, you get trhough the 40,000 jobs but stall at the 6000 jobs and want to reduce the db_scatter_factor, this will force the rerun of the earlier GATK steps. If one of these parameters is changed, Snakemake sees the gvcf, DB or vcf outputs as out of date and will recompute them. This can really suck. Think carefully about the values you want to use here before you start running the pipeline.
        

3. The biggest changes since Brian's workshop are in the slurm config file. If you look at his workshop, this info was in `resources.yaml` and the slurm `config.yaml`. Then, there was a new `profiles/slurm/config.yaml` which combined these and added a bunch of options. This improved the pipeline a lot but also meant there was more to do to get it set up. Now, snpArcher just provides you with a `workflow-profiles/default/config.yaml`. This is pretty bare bones imo, and unlikely to work without a lot of trial and error, especially on Della where you can't get away with requesting a ton of resources just to be safe. I would continue to use the old config, which I've included here in `workflow-profiles/slurm/config.yaml`

Here are some of the settings you will probably want to know about and consider altering to fit your use case.

- `retries` allows you to specify a number of times you want each rule to try to run before the pipeline errors out. I set this to 3. If any step errors out because of memory, the pipeline will resubmit that step with more memory and try again, up to the number of times you specify here. 
        
    - NOTE: This is very helpful, but can also cause you to waste a lot of time. snpArcher will keep resubmitting jobs even if you've not given it anywhere close to the resources needed to succeed. Keep an eye on the log file output, and check on any errors as the pipeline is running. If you see OOM errors, check that those same resubmitted rules aren't continuing to OOM error after subsequent retries. If you suspect you've set up your config to put snpArcher in a loop of submitting doomed jobs, you may want to kill your main job, wait for running processes to finish, change some things in the config, and resubmit.

- `default resources` specifies the memory that will be used for any rule not given a specific amount of memory below. I set this to 4000 (both `mem_mb` and in `mem_mb_reduced`) and `runtime` to a day, 1440 minutes. The higher you set this the less likely you are to fail steps because of timeouts or OOM errors. But, the higher you set this the longer your jobs may sit in the queue waiting for resources. 

- For the threads section, I copied over the resources Brian specified in the old resources file to start, and determined others through trial and error. These shouldn't need to be changed much. 
    
- You can set resources for specific rules after this. You should leave anything you aren't changing commented out. I made a lot of changes here. This is the part that took a lot of trial and error. 
       
    - If you want to change any resources for a rule, you need to uncomment the rule line, e.g. `index_reference:` and then whatever you're changing e.g. `mem_mb: attempt * 20000`. If you're not changing the slurm partition (you aren't, as we can't specify these on Della) or the runtime, leave these lines commented. 
       
    - The changes I made are too lengthy to detail here. You may need to tweak these depending on how much data you have, how big the genome is, how high coverage your data are etc. E.g., if you set your dv_scatter_factor to a lower number, you will run fewer gvcf2DB jobs, but each will require more memory. These are the values I used on my elephant data, which included 100 samples at 10-30X coverage.

4. Be sure to save all of these files: `sample.csv`, `config/config.yaml` and `slurm/config.yaml` before running anything! 

## (3) More Della specific set up (script 01)

Copying the rest of this pretty much directly from Brian, with only minor modifications. Brian provided us with three scripts:
1. One for setting up environments on Della
2. One for a dry run to test the rules snakemake thinks it needs to submit
3. One for actually submitting the main snparcher job. 

The versions on my repo have been modified by me to make them work after the updates. 

Okay, here's Brian:

Snakemake can create it's own mamba environments, and snpArcher automatically installs all the relevant software specified in `snpArcher/workflow/envs`. However, Della has a quirk in that compute nodes *do not* have access to internet, which is needed to download software. Thus, conda environments need to be created on login nodes, which *do* have internet, before we run anything.

1. In case it takes a while and you need to close your computer, let's make a 'screen' using `screen -S smk` that creates a seperate terminal instance

2. Now that we are in this separate screen, install conda environments using `bash 01_install_conda_envs.sh`. We may have to make some changes here, if someone runs this and can confirm it works/doesn't work, please let me know so I can update this page :)

3. Press `ctrl+A` then `D` to 'detatch' from the session, which should run in the background even if you close your terminal window.

4. To go back into the screen to check progess, type `screen -r smk`, where `-r` is to resume.

5. When it's finally done, kill the screen by pressing `ctrl+A` then `K`, and respond yes.

If you type `mamba env list`, you should see a bunch of new environments were created in a hidden directory `.snakemake` that you can only see using `ls -a`. These environments don't have names like the ones we created by hand.

NOTE: You could also do this directly on the command line on the login node, but using screen allows you to close your computer and it continues the process.

MADISON'S NOTE: You have to do this for every snpArcher directory you have. Again, I have separate ones for each of my projects. This means I have a lot of these environments, which you can see if you do `conda list envs`. 
        
## (4) Dry run to test snpArcher (script 02)

Next, let's do a dry run to see if we have everything configured correctly.

`bash 02_dry_run.sh`

If the dry run completes successfully and shows some rules that need to be run, then everything is good to go. However, the number of rules is shows that need to be run isn't the entire story, since some rules are executed only under some conditions that are determined at runtime. In practice, snparcher will likely run thousands of rules and submit thousands of jobs.

## (5) Running snpArcher! (script 03)

Lastly, we can submit the last script `03_submit_smk_job.sh` as a job using the `sbatch` command, specifying the longest time interval possible to ensure it doesn't time out. This job that gets submitted will essentially submit many additional jobs, one for each rule that needs to get run. 

MADISON'S NOTE: I think the new version of snparcher will chastise you for submitting the main job as a slurm job, but to avoid using too many resources on the login node I'm not sure how else to do this. There are [documented downsides](https://snakemake.readthedocs.io/en/stable/project_info/faq.html#why-do-my-global-variables-behave-strangely-when-i-run-my-job-on-a-cluster) to slurming the main job, but we gotta do what we gotta do when it comes to Della. 

Some more notes: 

- This may be a job to have an email set up to alert you if it errors out/finishes

- Sometimes, if you have a lot of data, this may take more than 6 days to run. Make sure to plan your submission around the annoying della downtimes. And, if you need to add more time you can write to cses@princeton.edu and politely ask them to add X amount more time to your main job (give them the job id). 

- Keep an eye on whats happening with `squeue -u YOUR_NETID` Make sure your jobs aren't languishing in the queue because you've asked for a lot of resources -- this slows you down! Note that sometimes snpArcher will be submitting jobs like crazy and sometimes you may see only one thing running. Both are normal, and more info about what it's doing now can be found in the error log

- Keep an eye on the error log. Scroll to the bottom to see recently submitted jobs. You can `CMD-F` and search for "error" to see if there have been any issues. You don't need to watch it like a hawk, but check in once or twice a day and see where you are in the pipeline and if any issues have come up.

