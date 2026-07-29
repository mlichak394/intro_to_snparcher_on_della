# Setting up and running snpArcher on Della

I highly recommend reading the [snpArcher docs](https://snparcher.readthedocs.io/en/latest/setup.html), especially if it's been a few months since this guide has been updated. Just know that the docs are readable and helpful, but they aren't super detailed, and are often behind new version releases.

## (1) Setting up the main snparcher environment

The current command for creating the main snparcher environment is below, but check the docs to make sure these are still the versions of snakemake and python the pipeline needs

```bash
mamba create -c conda-forge -c bioconda -n snparcher "snakemake>=9" "python==3.11.4"
```

Then, run the following to prevent an error on Della:

```bash
mamba install -n snparcher -c conda-forge mamba
```

Once you create this main environment, you won't need to do it again the next time you use snpArcher, unless one of the main tools needs to be updated to a newer version.

Next, clone the snpArcher github repo, which contains the pipeline and code:

```bash
git clone https://github.com/harvardinformatics/snpArcher.git
```

Clone a new repo each time you start a new project. e.g., if you ran snpArcher before on anole samples, and now you want to run it on some bird samples, clone a new repo. 

## (2) snpArcher /config

You will need to get a couple of things set up prior to running snpArcher.

### config/samples.csv 

samples.csv gives the pipeline information about all of your input data. Each row in samples.csv is a read pair. This table has 5 columns:

1. sample_id

    The name of the sample, as you want it to appear in the VCF. You may have multiple lines with the same sample_id if the same individual was sequenced multiple times.

2. input_type

    The file type. Options are `fastq` or `srr`. We can't use srr because compute nodes don't have internet access for snparcher to download data. It looks like there should be support for starting from BAM in the future.

3. input

    Full paths to the forward and reverse read for each read pair, separated by a semicolon and no space. e.g.:

    ```bash
    /scratch/gpfs/CAMPBELLSTATON/ml9889/elephant/raw_data/sample1_R1.fastq.gz;/scratch/gpfs/CAMPBELLSTATON/ml9889/elephant/raw_data/sample1_R2.fastq.gz
    ```

4. library_id

    For samples sequenced from a single library, just use the sample_id. For samples sequenced from multiple libraries, append some value that distinguishes which read pairs (rows) come from which library. e.g. `sample1_lib1` and `sample1_lib2`

5. mark_duplicates

    An optional column, and it defaults to true if you don't specify. I include this column and set all rows to `true`, just to document that I did mark duplicates. You may wish to think about the trade offs of duplicate marking, and whether you want to do this, if you're working with ultra low coverage samples, or capture sequencing designed to sequence the same region(s) to very high coverage.

### config/sample_metadata.csv 

If you plan to run the QC and/or postprocessing module you'll need this as well. You probably want to run the QC module on your full dataset (it's neat and provides some nice visualizations!), but you can choose to not provide a `sample_metadata.csv` if you're just doing a test run on a few samples. In this one, each row is a sample, and there are 5 possible columns, though the documentation here is minimal. 

1. sample_id

    Must match `sample_id` values from `samples.csv`. Each should appear only once in `sample_metadata.csv`.

2. exclude

    Set to `true` for samples you want to exclude from the QC and postprocessing module. Set to `false` for samples that *should* enter QC and postprocessing. There is no harm to setting all to `false` and reassessing after the pipeline completes. If the QC module reveals a crappy sample you want to drop from downstream analyses, you can always remove that sample from the raw VCF yourself.

3. outgroup

    Optional. Set to `true` if this sample represents an outgroup sample for MK tests. Otherwise, set all to `false`.

4. lat

    Optional. If you have latitude data for this sample you can include it here. This will place the sample on a map in the QC module. As of right now this is a neat little visualization, but doesn't serve a greater purpose than that. If this isn't info you have easily at hand, just don't include this column.

5. long

    Optional. Same as above, if you have longitude data for this sample you can include it here.

### config/config.yaml

The pipeline supplies a template config file, which you will need to lightly edit before running.

Under `reference:` 

1. Set `name:` to your reference organism name (no spaces allowed, e.g. `"mLoxAfr1.hap2"`). 

2. Provide the full path to your reference genome to `source:`

Under `variant_calling:`

1. Set `expected_coverage:` based on the depth of coverage you expect your data to have. In general, I use `"low"` for datasets where most samples have <10X coverage, and `"high"` for datasets with >10X coverage.

2. Set `tool:` to the variant calling tool you want to use. `"gatk"` remains the gold standard for variant calling, but other options are provided that you may wish to consider. `"bcftools"` is supposed to be significantly faster, for example. Note that this guide does not currently have any info about variant callers other than gatk, so expect to do more troubleshooting if you're trying one of these for the first time.

Under `intervals:`

You can probably leave these at defaults for a test run. However, if you have a ton of samples (several hundreds) and/or a less-than-amazing reference genome, you may want to do some back of the envelope calculations to get a sense of whether the default parameters are likely to work for you. 

`intervals:` defines how the genome is split into chunks for variant calling. Each sample will be split into chunks that can be run in parallel, which theoretically speeds things up. However, if you have too many chunks, you may run into scheduling problems. And, Snakemake will need to hold the entire tree of possible jobs and their dependencies in memory. Traversing this tree (the DAG) each instance a rule is run can quickly become very, very slow if there are 10s of thousands of jobs in the tree.

The number of chunks that are created is defined by `num_gvcf_intervals:`. Note that this is a maximum. For a genome with few gaps, the pipeline will likely choose to chunk each sample into far fewer than the default specification of 50 intervals. A reference genome with a lot of gaps or missing data means that the pipeline is more likely to need a number of chunks closer to the max defined in the config. 

As an example, I once ran snpArcher on 800 samples. With the default parameters, snparcher could split each sample into *up to* `num_gvcf_intervals: 50`. 800 * 50 means up to 40,000 jobs trying to get scheduled! Even though each was only split into 17 chunks, 800 * 17 = 13,600. That's still a LOT of jobs.

On a test run, just try the default parameters. See how many chunks the pipeline actually creates. You probably want to keep the number of variant calling jobs to something <10,000. If needed to process the full dataset, you can set `num_gvcf_intervals:` to something <50.

Note, if you try to change `num_gvcf_intervals:` or `db_scatter_factor:` after some gvcfs have already been created, the pipeline will rerun all variant calling and genotyping steps. This can really suck, so think carefully about the values you want to use here before you start running the pipeline.

Under `modules:`

You can set `enabled:` to `true` for both `qc:` and `postprocessing:`. This will run the QC and postprocessing modules. If you're doing a test run or have <10 samples you should leave these at `false`. Otherwise, they will error out (the developers seem to be planning to fix this, but right now it's not fixed). If you have these set to `true` you will need to supply the `sample_metadata.csv`.


## (3) Configuring slurm parameters

snpArcher does not come with a slurm-specific workflow-profile config. You'll need to create this so that slurm knows what resources you want jobs for each rule to run with. There is an example this github under `madison_config/workflow_profiles/config.yaml`.

Move into the workflow-profiles directory of your snpArcher directory:

```bash
cd snpArcher/workflow-profiles
```

Then, create a new directory for your slurm config file:

```bash
mkdir slurm
```

Finally, make a new config.yaml file in this new directory:

```bash
touch config.yaml
```

You can copy the contents of the example slurm config to this file. Now, you can alter the resources your jobs will request in this file. 

If you're doing a test run on a few samples, the resources in the example file are probably going to be fine to use for your test run. After your test run completes, you can revise this based on what your test jobs actually need. For more on this, see 4_troubleshooting.md.


## (4) Create the environments snpArcher needs to run

Snakemake will create the environments a pipeline needs to run from within the main process. However, on Della, we don't have internet access on the compute nodes, so snpArcher can't download any of the software it needs to run. 

To get around this, we'll make the environments it needs on the login node, then snpArcher can use these environments once we start running the pipeline as its own job. For this step, you'll need the `01_install_conda_envs.sh` script. I put this, another scripts I use, in a new subdirectory within the snpArcher directory called `myscripts`.

Most of this section comes courtesy of Brian Arnold, who provided us with the first ever (extremely excellent!) introduction to snpArcher. This section comes from him, with some light revision by me. 

1. Make a 'screen' using `screen -S smk`. This creates a seperate terminal instance that will run even if you need to close your computer.

2. Install conda environments using `bash myscripts/01_install_conda_envs.sh`

3. Press `ctrl+A` then `D` to 'detatch' from the session, which should run in the background even if you close your terminal window.

4. To go back into the screen to check progess, type `screen -r smk`, where `-r` is to resume.

5. When it's finally done, kill the screen by pressing `ctrl+A` then `K`, and respond yes.

If you type `mamba env list`, you should see a bunch of new environments were created in a hidden directory `.snakemake`. These environments don't have names, and are defined by a crazy string of numbers and letters.

Note that unlike step 1 above, you have to do this step for every snpArcher directory you have. Again, I have separate snpArcher directories for each of my projects. This means I have a lot of these environments, which you can see if you do `mamba env list`. 
        
## (5) Dry run 

To make sure everything is configured correctly, you can do a "dry run" and see what rules snpArcher will run. 

This requires `myscripts/02_dry_run.sh`, which you can run with `bash myscripts/02_dry_run.sh`.

If the dry run completes successfully and shows some rules that need to be run, then everything is good to go. However, the number of rules shown isn't *all* of the rules that will run, since some rules are executed only under some conditions that are determined at runtime. 

## (6) Running snpArcher!

Submit the actual run with `sbatch myscripts/03_submit_smk_job.sh`. In the slurm header, make sure you're specifying the longest time interval possible, 6 days, to ensure it doesn't time out. This job will submit many additional jobs, one for each rule that needs to get run. 

Note that snpArcher will chastise you for running the main snpArcher process as a slurm job. Running a snakemake pipeline within a slurm job is not recommended and may produce some funky behavior (see [this github issue](https://snakemake.readthedocs.io/en/stable/project_info/faq.html#why-do-my-global-variables-behave-strangely-when-i-run-my-job-on-a-cluster)). We can't run anything on the login node, though, so there isn't much we can do about this. 

Some additional tips: 

- This may be a job to have an email set up to alert you if it errors out/finishes

- With large dataset, snpArcher can absolutely take more than 6 days to run. If you need more time, you can email cses@princeton.edu and politely ask them to add X amount more time to your main job (give them the job id). It's also not the end of the world if the main job times out. Pending and running jobs will continue to run. Once all of these are finished, you can resubmit the main job and it will pick up where it left off.

- Make sure to plan your submission around the annoying della downtimes. 

- Keep an eye on whats happening with `squeue -u $USER` Make sure your jobs aren't languishing in the queue because you've asked for a lot of resources -- this slows you down! 

- Keep an eye on the error log. Scroll to the bottom to see recently submitted jobs. You can `CMD-F` and search for "error" to see if there have been any issues. You don't need to watch it like a hawk, but check in once or twice a day and see where you are in the pipeline and if any issues have come up.

## Getting help

The snpArcher github "issues" page is an excellent resource if you ever run into problems. Check the resolved threads. If you need to ask a new question, the developers seem really friendly and willing to help. 

Additionally, ask someone in the lab who has run snpArcher recently! Snakemake version changes can break things that used to work, so see if someone else already solved your problem!

Finally, some important considerations and troubleshooting tips can be found in 4_troubleshooting.md