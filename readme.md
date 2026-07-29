# Introduction to using snpArcher on Della

## Last update
July 29, 2026

## snpArcher

[snpArcher](https://snparcher.readthedocs.io/en/latest/) is a pipeline for processing DNA sequencing data, particularly sequencing data from non model organisms. The input is raw sequencing data and a reference genome, and the output is a VCF. snpArcher is built with Snakemake, a tool that allows several steps to be carefully chained together, streamlining a workflow. When it works perfectly, it's hands off after set up and runs very efficiently. 

Snakemake, Princeton's Della computing cluster, and snpArcher all have their quirks, and these can be challenging to work through. However, getting snpArcher set up and running is almost always faster than trying to write and troubleshoot independent scripts to process your data.

All credit to Brian Arnold -- this guide is adapted from the excellent ["Intro to Comp Bio Workflows" workshop](https://github.com/brian-arnold/intro_compbio_workflows_2024) he gave here in early 2024. If you're just getting started working on Della or doing bioinformatics, I highly recommend looking through all of the readmes in his workshop -- it's a great intro! 

snpArcher has been updated several times since Brian gave this workshop. These updates broke some things in Brian's guide. Additionally, changes to the pipeline are not always documented in a super obbvious way. I've modified the instructions for day 3 of Brian's workshop and provided some other info that should be useful to anyone trying to run snpArcher on Della.

## Overview of included guides

**01_how_it_works:** A pretty braod introduction to the architecture of the pipeline and what's happening in key rules. IN PROGRESS.

**02_getting_data:** Provides info on how to download published sequencing data or a reference genome to Della.

**03_running_snparcher:** Tutorial for getting snpArcher set up and running on Della.

**04_troubleshooting:** Some tips and issues we've run into.

**05_v1_to_v2:** A guide for those who haven't run snparcher since early 2026 and need to transition from v1 to v2.


