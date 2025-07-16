# Making snpArcher less of a black box

## A brief overview of the pipeline

First off, consider reading the [snpArcher paper](https://academic.oup.com/mbe/article/41/1/msad270/7466717), which contains a helpful diagram showing the flow of steps.

It's probably important to understand the steps that get you from FASTQ to VCF so that you have a basic idea of what's going on at each step. The output of this multi-step process is a raw vcf file that you should consider filtering in different ways. As the snpArcher paper notes, this workflow is pretty much standard in the field. The default parameters are used in most of these steps, per GATK Best Practices.

### Step 1: Mapping
Sequence reads (FASTQs) are mapped to the reference genome (rule: bwa_map). The mapping stage takes into account mappability (computed in rules: genmap and mappability_bed). This is how easy it would be to confidently map something to that part of the reference genome. Reads that align to regions of the genome with poor mappability (e.g. highly repetitive regions) will recieve lower mapping quality scores. These lower quality alignments are annotated as such.

### Step 2: Calling Variants
After mapping, GATK is used to call variants for each sample's mapped reads. snpArcher uses HaplotypeCaller for this process. HaplotypeCaller is the recommended variant caller in almost all cases, according to GATK Best Practices, and I believe it's the only caller that snpArcher uses. HaplotypeCaller will call both SNPs and indels at the same time (rule: bam2gvcf). 

Nothing is filtered at this stage. Instead, calls are simply not made if there is not enough confidence for them. The snpArcher code for this step uses the GATK defaults for call confidence, which you can view [here, in the variant calling tutorial](https://currentprotocols.onlinelibrary.wiley.com/doi/10.1002/0471250953.bi1110s43). The outputs for this step are gvcfs, which includes reference confidence scores (support for the variant at that site). Parameters that also affect calls are `--min-pruning` and `--min-dangling-branch-length` which are semi-set in the config file. These are set when you decide whether to use the low-coverage pipeline (<10X) or the higher coverage one (>10X). 

Note that the process of calling variants occurs _per sample_. Each sample is processed in intervals, which allows many parallel jobs to be working at the same time. This step generates a lot of jobs: number of samples x number of intervals, which is set with `num_gvcf_intervals` in the config.

Interval gvcfs are then concatenated per sample (rule: concat_gvcfs), so you end up with one gvcf per sample. This gvcf is normalized (rule: bcftools_norm) which splits multiallelic sites into multiple biallelic sites for genotyping.  

### Step 3: Calling Genotypes
To make genotype calling more efficient, snpArcher first uses GATK's GenomicsDBImport to create databases of efficiently stored data that's easier to work with. DBs are also made in intervals. Parameters used to create these intervals are `num_gvcf_intervals` and `db_scatter_factor` in the config. So, the genome is split up into sections, and each DB contains all of the variant call info for all of the samples in that section (rule: gvcf2DB).

GenotypeGVCFs is then used to do the actual calling, which also happens in these sections specified when the DBs are created (rule: DB2vcf). Default call confidence thresholds are used (see the tutorial above, or ask chatGPT what they are). The one parameter that is used that you set is the prior probability of heterozygosity (`het_prior`), which is set in the config file. The default value in the config (0.005) is higher that GATK's default (0.001). I don't really understand the implications of this, or why they made the decision to have this as the default.

Of note: variant calling is intentionally lenient. It aims to maximize sensitivity (the chance you will pick up on a variant) at the expense of accuracy (you will probably call some variants with little evidence to support them being "real"). While you may include some false positives through this process, you reduce the risk of throwing out true positives.

### Step 4: Annotating Called Variants with Filters
snpArcher then takes these vcfs, still in intervals, and which may contain a lot of low quality calls, and filters them (rule:filterVcfs). I think the language used in the field can be misleading at these steps. In the snpArcher pipeline, nothing is actually removed (removal is often referred to as "hard filtering", and snpArcher does this at a later step). Instead, you're just flagging variants that don't pass certain filters (ie, "soft filtering"). You can choose whether to hard filter them--actually remove them from your dataset--later. 

GATK Best Practices are used here. 
- **RPRS_filter**: flags variants supported by reads aligned in suboptimal positions or that have poor quality relative to their depth
    - for SNPs, `ReadPosRankSum` <-8.0 (for indels < -20.0)
    - for both SNPs and indels, anything with quality by depth (`QD`) < 2.0
- **FS_SOR_filter**: flags sites with strand bias (e.g. sequencing preferred the forward or reverse strand, so there is more skewed evidence for het or homozygosity compared to what you'd see if both strands were equally likely to be sequenced)
    - For SNPs, if Fisher Strand `FS` > 60.0 or Strand Odds Ratio `SOR` > 3.0
    - For indels or mixed sites, if `FS` > 200.0 or `SOR` > 10.0
- **MQ_filter**: annotates areas with low average mapping quality
    - For SNPs, if Mapping Quality `MQ` < 40.0 or `MQRankSum` < -12.5.
- **QUAL_filter**: annotates areas with low quality scores
    - `QUAL` less than 30.0

If a variant gets a filter flag it did not "pass" that filter. Variants with filter flags are ones you should consider removing, but again it's up to you to do this later. 

After all of this you get a bunch of interval vcfs that are concatted (rule: sort_gatherVcfs) into a raw.vcf.gz, which has these flags on sites that didn't pass filtering.

This may be where the pipeline completes. If you set sampleType to "include" in the samples.csv, this will trigger the postprocessing and QC modules, which will further filter and visualize your outputs. More about these below.

## Interpreting the outputs in the results directory

As I mentioned above, the main snpArcher pipeline gives you a final vcf file that ends with raw.vcf.gz. This vcf contains all of the samples you input and variants (SNPs and indels) called. 

If you set SampleType to "include" in your sample.csv, snpArcher will run its postprocesisng module. If you've already run the pipeline and identified samples that are very low coverage, contaiminated, etc. with the QC module, you can set those samples to "exclude" in the samples.csv and they will be filtered out in the postprocessing module. You can also just set everything to "include" in the samples.csv and further filtering will be performed on the entire dataset. 

Here are the steps the postprocessing module performs:

### Step 1: Basic Filtering
At this step, snpArcher does three things:

1. removes those samples that you told it to exclude in the sample.csv file, if any

2. hard filters out sites that were flagged above (ie, sites that don't have a . or PASS in the FILTER COLUMN)

    - in my vcf, no sites are marked with PASS. You can check the FILTER.summary in results for a summary of what was marked. I also ran the following on the command line to confirm:

    `zgrep -v "^#" 202405_AENP_GNP_NCBI_raw.vcf.gz | head -n 10000 | awk -F'\t' '$7 == "PASS" {count++} END {print count+0}'` 
    
    This printed 0 for me.

    `zgrep -v "^#" 202405_AENP_GNP_NCBI_raw.vcf.gz | head -n 10000 | awk -F'\t' '$7 == "MQ_filter" {count++} END {print count+0}'`

     You should get something >0 for this one (unless your dataset is super good I guess?)

    `zgrep -v "^#" 202405_AENP_GNP_NCBI_raw.vcf.gz | head -n 10000 | awk -F'\t' '$7 == "." {count++} END {print count+0}'`
    
    Should definitely be >0, these are the unlabelled PASSes

3. removes from the vcf any sites that are not polymorphic, or where the ref genome has an unknown (N) base

    - sites that don't have any variation (all samples have the same sequence)

    - sites where the reference has an N or where the alternate is . (no alternate allele)

    - sites with allele frequency = 0 (no alternate alleles observed)

The output here is the filtered.vcf.gz file.

### Step 2: Strict Filtering
Then snpArcher will use bcftools to filter according to the parameters you specify in the config file, and split the vcf into one for SNPs and one for indels. 

1. excludes variants in regions of the genome comprised of small contigs 

2. removes variants with "missingness" above the threshold specified in the config.yaml

3. removes variants with a minor allele frequency below the threshold specified in the config.yaml

4. removes variants on chromosomes you specify in the config.yaml

The output of this is a TEMP file that is then just subsetted in the next snakemake rules. This TEMP file gets split into a SNP file and an indel file. 




