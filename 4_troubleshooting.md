# Troubleshooting

## 1. I don't know how much memory, time, or threads to request in the slurm config file
If you have more than ~25 samples, I highly recommend running the pipeline once with a test set of a few samples. This will give you some data on how long certain steps took, how many intervals the genome was split into for GATK steps, etc. that can inform your config set up. Don't just give all of the rules 4 days and 32 GB of memory and hope for the best. You will wait a long time for slurm to schedule these jobs, and overrequesting resources will affect the priority of subsequent jobs (and the jobs of other others in the lab!). I haven't specifically tested this, but I'm pretty confident that spending 2-3 days testing the pipeline will make your full run go much faster than if you just randomly specify resources and hope for the best.

To do a test run, I choose a handful of samples (~5) to run through the pipeline all the way. If you have different types of samples -- different coverage, different batches, different datasets, different species -- make sure the test set represents the different types of data you'll be working with. 

**An example:** I used snparcher to process 299 samples for my elephant project. For my test, I chose to use the following 7 samples:
  - 2 samples from Addo (1 lower coverage, 1 higher coverage)
  - 1 sample we sequenced from Kruger
  - 1 sample each from each of the 3 published datasets I used
  - 1 *E. maximus* sample

It's important to use a representative test set so that you can see how the different sample types behave during the run. For example, from this I learned that the Asian elephant sample took much longer to map than the African elephant samples did. 

Simply write the config files (e.g., samples.csv) with just these five samples, and run the pipeline as normal. Check in on the test run every once in a while to see if there are places where the pipeline hangs with a lot of pending jobs (see the next section for details on what this might look like). 

Note that if you only use a few samples the QC module will not successfully complete. As long as you have a raw.vcf.gz in /results, you are good to proceed with an analysis of your resource usage. To do this, `cd` into the snparcher directory. Then run the following on the command line:

```bash 
printf "%-28s %5s %8s %8s %9s %9s %8s\n" \
  "RULE" "N_JOBS" "MEAN_MIN" "MAX_MIN" "MEAN_RSS" "MAX_RSS" "CORES"
printf "%-28s %5s %8s %8s %9s %9s %8s\n" \
  "----------------------------" "-----" "--------" "--------" "---------" "---------" "--------"

for d in benchmarks/*/; do
  rule=$(basename "$d")

  find "$d" -name '*.txt' | tr '\n' '\0' | xargs -0 -r awk -v rule="$rule" '
    FNR == 1 { next }
    NF < 9   { next }
    {
      n++
      secs += $1
      if ($1 > maxsecs) maxsecs = $1
      rss  += $3                       # col 3 = max_rss (MB), summed for mean
      if ($3 > maxrss) maxrss = $3
      load += $9
    }
    END {
      if (n)
        printf "%-28s %5d %8.1f %8.1f %9.1f %9.1f %8.1f\n",
          rule, n, secs/n/60, maxsecs/60, (rss/n)/1024, maxrss/1024, (load/n)/100
    }
  '
done
```

This will give you a table that looks something like this:

| RULE | N_JOBS | MEAN_MIN | MAX_MIN | MEAN_RSS | MAX_RSS | CORES |
|---|---|---|---|---|---|---|
| bam_stats | 7 | 22.5 | 33.7 | 0.0 | 0.1 | 0.9 |
| bwa_mem | 7 | 256.9 | 358.6 | 36.4 | 69.5 | 17.8 |
| concat_interval_gvcfs | 14 | 20.7 | 59.8 | 0.4 | 0.8 | 0.5 |
| fastp | 7 | 19.8 | 32.8 | 1.3 | 1.3 | 6.4 |
| gatk_haplotypecaller | 126 | 70.5 | 224.1 | 2.5 | 4.0 | 1.2 |
| index_bam_csi | 7 | 4.2 | 7.4 | 0.0 | 0.0 | 0.9 |
| markdup | 7 | 16.6 | 29.5 | 2.6 | 3.8 | 8.5 |
| merge_dedup_libraries | 7 | 59.3 | 85.3 | 0.0 | 0.0 | 1.0 |
| merge_library_bams | 7 | 60.2 | 94.2 | 0.0 | 0.0 | 1.0 |
| mosdepth | 7 | 4.8 | 6.5 | 4.3 | 5.2 | 3.1 |

This tells how the average number of minutes each rule took, as well as the max. It also tells you the mean and max memory (RSS) each rule used, followed by how many cores those jobs saturated. Use these values to set your config values, allowing for some headroom. 

For example, my longest mapping job took ~6 hours. Based on this, in my config I'd set the time for the bwa_mem rule to 12 hours. I would probably give mapping jobs 20 cores, and 36 GB of memory. With this some samples may OOM, but these will restart with double the memory on the second attempt. I'd make this decision to balance time spent waiting for cluster resources and time spent restarting samples that fail a rule the first time. I recommend reading the next section as well for more about requesting resources.

You can look at the sample config in this github to see the decisions I would make based on the results of this test run. 

If you have a huge dataset, know that you still may need to make some adjustments. Some rules scale with sample size, so the test run will be less useful for setting resources for those. 

Once your config is revised, just create a new samples.csv with all of your input files and resubmit the pipeline. The test samples will have already been mapped and have a gVCF, so these samples won't need to be run again, saving you a bit of time on the full run. 

## 2. I specified 250 jobs could be running at once in my config, but way fewer are actually running

i.e., why are so many of my jobs pending?

### Option 1: Maybe it's you
There are limits to how many resources you (or anyone!) can use at one time Della. A lot of this depends on which QOS (aka, "Quality of service") is needed to run your job. A QOS is a set of scheduling rules. On Della, your job gets assigned a QOS based on the time limit you set for your job. For some QOS, there are a certain number of CPU cores (aka, threads) you can request at once for all jobs running with that QOS. 

**These are the most relevant Della QOS:**
|QOS|Time Limit|Max jobs per user|Max cores per user|Total cores on QOS|
|----|---------|-----------------|------------------|------------------|
|test|1 hour|2|no limit|no limit|
|short|24 hours|400|1400|no limit|
|medium|72 hours|200|400|3200|
|vlong|6 days|60|325|1400|

Note: the values in the [RC documentation](https://researchcomputing.princeton.edu/systems/della#Job-Scheduling--QOS-Parameters-) seem to be incorrect. To see whether the values I show above are still accurate, type `qos` in the terminal.

**An example:** Mapping (**bwa_mem**) is resource-intensive, so you might be tempted to set your config to give each of these jobs 24 cores and 36 hours. In that case, these jobs will land on the medium QOS, which has a per-user CPU-core limit of 400. 400 / 24 cores per job = 16 jobs running at once on medium! Even though there is a per-user job limit of 200 on medium, you'll hit the per-user CPU limit first. An indication that this is happening to you is if your NODELIST(REASON) is **(QOSMaxCpuPerUserLimit)**.

So, do you need 24 cores? Do you need 36 hours? If you can run these jobs on short (ie, in less than 24 hours), you could run 1400/24=58 jobs at once. Much better! 

This is why I highly recommend running the full pipeline with a few samples. You can see how long, on average, mapping took for these samples, and set your limits accordingly. See the above section for more on this. 

In general, if you have 4 samples that will probably take 36 hours to map, and 100 samples that will probably take 12 hours, it is probably best to set your config resources so that **bwa_mem** jobs run on the the most efficient QOS (i.e., short) to start, and get moved up to higher QOS if needed because of TIMEOUT failures. In this scenario, I would set jobs to have a max time of something like 20 hours, scaled by attempt. Your 12 hour samples will succeed on short, and your 36 hour samples will fail, but be put on to medium on attempt two (2*20=40 hours), where they will have enough time to restart from the beginning and finish.

Another thing to pay attention to is your fairshare value. This is a number that represents how much of the cluster's resources you are using, compared to how much you should be using. To check yours, run `sshare | grep "campbellstaton"`. The most important number is the last one on the line with your netID on it. If it's less than 0.5, you're using more resources than your "fair share". If it's higher, you are using less. This is used to determine priority on the cluster, such that people who have been using fewer resources get higher priority. If your number is low, there's nothing you can immediately do except wait and reduce your usage. Note that the lab's resource consumption as a whole is also baked into your fairshare. 

### Option 2: Maybe it's Della

Even if you KNOW you're requesting reasonable resources your jobs still might be pending, often with a **(Priority)** flag. There are a bunch of possible reasons for this. Della is a busy cluster, with non-infinite resources.

1. There are cluster-level CPU limits for some QOS, and for the cpu partition in general (i.e., Della is finite). Run `qos` and check the "Running jobs..." section. If your pending jobs are for medium and people are using 3168 total cores of the 3200 available, just sit tight and wait for other people's jobs to finish.

2. Some Della users get higher priority for their jobs. RC says this happens when departments or labs "have made substantial financial contributions to the cluster". Anyway... not us, lol. 

3. In the hours after the Della downtime, the cluster will be extra busy with users who submitted jobs before downtime that couldn't run and were put into the **(ReqNodeResMaintenance)** hold. These jobs will have higher priority than ones submitted after the cluster was released. In this case, just wait it out. You may be thinking of ways you can try to get your jobs into this higher priority queue by scheduling jobs before the downtime. In my experience, there's not a ton you can easily do to game the system in this situation. You can sbatch the script that submits the main snparcher process and have that pending before the downtime, but any jobs it creates after it starts running will have lower priority. And having an active snparcher process running submitting jobs just to get them into the queue seems like more trouble than it's worth to me. 

    **Pro tip:** if you can run any part of the pipeline in the ~24 hours before the cluster goes down, do it! Short can pick up the CPUs that aren't being used by medium and vlong (because new jobs are held until maintenance completes), so you can often run more jobs at once in the few days/hours before the cluster goes down. 

In short, Della is a busy cluster with limited resources and some users with a better chance of getting the resources that are available. I've never been able to get more than a few hundred jobs to run at once on Della. For this reason, I don't see much reason to set the number of jobs snparcher will submit at once to be higher than a couple hundred.

## 3. The main job is running but it never submits any other jobs

Make sure you have [snakemake-executor-plugin-slurm](https://snakemake.github.io/snakemake-plugin-catalog/plugins/executor/slurm.html) installed in your snparcher conda environment. 

## 4. The pipeline was submitting jobs, but now it's not even though the main job is still running 

This seems to be a known snakemake issue, possibly because the main process is running inside its own slurm job. Just kill the main job, wait for anything running to finish (or kill all jobs if you're fine with whatever is running restarting from the beginning) and resubmit. Make sure to delete the .snakemake/locks directory before you resubmit. This should kick off job submission again.

## 5. CalledProcess Errorr at bwa_mem. "Paired reads have different names"

This one took days for me to figure out. A couple of my bwa_mem steps were failing with for "unknown" reason in the main snparcher log, and "CalledProcess" Errors in the slurm_logs

    RuleException:
    CalledProcessError in file "/scratch/gpfs/CAMPBELLSTATON/ml9889/elephant/snpArcher/workflow/rules/mapping.smk", line 230:         

And, the file under logs/bwa_mem/SAMPLE had this line towards the end:

    [mem_sam_pe] paired reads have different names: "ERR14018017.133177012", "ERR14018017.133169012"

I thought this must be due to incorrect read pairing in the raw fastqs. Weird, because the 2 samples that were giving me trouble weren't from the same source: one was ENA data and the other was my own sample, and all other samples from these sources were fine. 

After checking, faw fastqs and trimmed fastqs both had equal read counts for the R1 and R2 files. The JSON fastp summaries were also sane. However, the number of read pairs that fastp had read (in the JSON summary) and the number of actual read pairs (counted from the raw fastqs) were off by 2000 in these two samples. 

I thought this might be a threading issue. However, the error was not reproducible when manually rerunning fastp on these samples with different threads -- even specifying the same number of threads as the snparcher fastp invocation could not reproduce the error. In summary: nothing wrong with the input, nothing wrong with the code, nothing wrong with the resources. 

The solution? Unplug it and plug it back in. I deleted the jsons in `results/fastp` for these samples, and their trimmed fastqs in `results/trimmed_fastqs`. Then, resubmitted. 

If you run into this same issue, or just want to check to make sure the info fastp read matches the actual read counts from your raw data, you can run the script `myscripts/check_fastp.sh` in troubleshooting. Wait until all instances of fastp have run. You can check fastp is done by counting the number of .json files in results/fastp:

```bash
cd snpArcher
find results/fastp -type f -name "*.json" | wc -l
```

and comparing this to the number of lines in your samples.csv. If they match you're good to run this, even while snpArcher is still working.

I recommend running it overnight. It's not a computationally efficient script because I didn't parallelize it. But it'll give you a table confirming that the number of read pairs in the input fastq and the number of read pairs fastp read match. 

Phew. That one sucked.

## 6. I have some rule that is OOM erroring. Should I let it resubmit or intervene?

Depends on how many times it's failed and how many jobs need to run for that rule and how "weird" your dataset is. If your dataset has samples of different quality or species, or you just have a really large dataset, the more likely you'll have to intervene and change things on the fly. 

Two anecdotes:

1) I was working with a 300 sample dataset. 295 of my samples went through bwa_mem on their first try. The other 5 failed. Looking in the main log, I was seeing that these were TIMEOUT errors. All of the jobs resubmitted with double the initial resources but this was mapping so each job was given 18 hours on the first try. TIMEOUT after 18 hours of work sucks! TIMEOUT after 36 hours of work would suck even more. In this case, I checked the bwa_mem log in /logs to see how many reads had been processed, and compared that to how many were in the trimmed fastqs. If 90% of the reads mapped in 18 hours, you'll almost certainly be fine with a 36 hour job. If only 25% mapped, you're just wasting time on attempt two. In my case, I was going to need around 2.5x the initial hour limit for these samples. Attempt 2 would be pointless and attempt 3 would be over-resourced. Because the majority of the other jobs that were running were gatk_haplotypecaller_interval jobs which take only a few hours, I decided to kill the main snparcher job, wait for the running haplotype caller jobs to finish, and resubmit with more timefor bwa_mem.

2) gatk_genotype_gvcfs was also erroring out on me, though this time these were OOM errors. After a second round of OOM, I investigated: I looked to the `tail` of files in /log/gatk_genotype_gvcfs to see the position at which a few jobs were currently working, as well as the length of their intervals in /results/intervals/db. I also looked at the html link under `jobstats` for some of the failed and running jobs to see a curve of memory usage. From this I learned that memory needs grew linearly with progress. I also learned that my third attempt jobs that were running were 75% done and were using about 75% of the memory they were probably going to need. Oof. To terminate everything and restart with resources that would definitely work, or to wait and hope they squeak by? I think either would have been a reasonable approach. Since they were already 75% done, still had one auto-attempt left, and the wait time for the next tier of resources (240 GB of memory!!) would be substantial, I decided to let all of the jobs continue running.

Some general ideas I use to guide whether or not to intervene: 
- Look to /.snakemake/slurm-logs for the type of error for each slurm job, and /log/rule_name for details of the progress of the current or most recent job

- OOM will often happen before TIMEOUT. If a 12 hour job OOM after 2 hours, maybe you didn't waste much time. If a 48 hour job hits TIMEOUT, that really sucks. Not only do you lose 48 hours of work, but you also lose the time you spent waiting for the resources to run a 48 hour job. I treat TIMEOUT errors on long jobs as high priority fixes. 



