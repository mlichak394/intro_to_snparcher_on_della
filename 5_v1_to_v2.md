# Migrating from from v1 to v2

If you've run snpArcher before, but not since v2 (introduced Q1 of 2026, I think), there are some significant changes. 

The good news is that v2 is *wayyyy* more streamlined and easier to navigate than v1. The bad news is that the documentation for v2 is not really complete. 

### Here's an overview of the main changes that I've noticed:
- `samples.csv` is more pared down

- Some of the information that used to be in `samples.csv` is in `config.yaml`, or a new file called `sample_metadata.csv`. You need `sample_metadata.csv` if you want to run QC and postprocessing.

- The main output (error) log is far easier to read now!! 

- Rules have been restructured and renamed. They generally better match the directories created in `results` and `logs`, which makes tracking down issues much easier. Yay! However, it means you can't use your old `slurm/config.yaml`, because the rule names won't match anymore. 

- There are options for different variant calling/genotyping tools. I haven't used any of these yet. Please let me know how it goes if you do.

- There also appears to be support for starting from BAM files, rather than fastqs. I can't tell if this is fully implemented yet, or just something they're planning to add. If anyone tries this, please tell me whether or not it works. I'm very curious!

### Things to watch out for

The directions in 2_running_snparcher.md are up to date, so check there for a full v2 compliant set up. 

Some known things you'll need to contend with:

- You'll need to update your main snparcher conda environment to have snakemake version ≥9. I had trouble getting conda to update mine, so I just made a new snpArcher environment.

- You'll need to revise your samples.csv or alter code you have used to create this in the past.

- You'll need to make a slurm config file. There's an updated example here on this github that uses the new rule names. 
