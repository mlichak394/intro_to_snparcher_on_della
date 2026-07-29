# snpArcher: What is is and how it works

[snpArcher](https://snparcher.readthedocs.io/en/latest/index.html) is a pipeline that takes short-read whole-genome sequencing data and turns it into a file containing genotypes for each of your samples. It's a way to *efficiently* go from raw data to a file you can analyze without messing with a bunch of steps in between. It's awesome!

The snpArcher paper can be found [here](https://academic.oup.com/mbe/article/41/1/msad270/7466717).

## Some common terms

If you're new to bioinformatics, here are a couple of files and programs to know about. In general, this guide is written for someone who can navigate the terminal, but you don't necessarily need to have any major coding or bioinformatics skills t ofollow along.

**fastq**: file type that stores raw sequencing read data along with quality scores. Each row is a sequencing read. For paired-end sequencing (the kind you're probably working with) these come in pairs, with a forward and a reverse read.

**BAM**: file type that stores information about sequencing reads mapped to a reference genome. This is a compressed file type (the B in BAM stands for "Binary"), so they are small and easy for computer software to read. Encodes reads, their position relative to the reference, and a string that tells you how many matches, mismatches, deletions or insertions there are in the alignment.

**VCF**: a "Variant Call File". Stores information about where individuals have sequence variants like SNPs and indels, compared to a reference genome. Each line is a variant. Can be compressed ("BCF") or indexed for faster parsing. Can be analyzed with tools like `bcftools` and `vcftools`, and many more!

**Snakemake**: a workflow managment system. It's based in python. Snakemake lets you string together different steps of a pipeline, and keeps track of what has already been done, so you don't have to. Without snakemake, you'd have to first quality check your raw data, then map that data to a reference genome using another script, then call variants. You'd be the one managing the transition between the steps and making sure the previous step completed properly. With snakemake, you define a workflow, and then snakemake creates a tree of jobs that need to be run (the "DAG"). On a cluster like Della, a snakemake pipeline can submit its own jobs: you set it up, and it runs itself! 

## A brief overview of the snpArcher pipeline

Consider reading the [snpArcher paper](https://academic.oup.com/mbe/article/41/1/msad270/7466717), which contains a helpful diagram showing the flow of steps. snpArcher takes you from sequencing data to VCF, using tools and workflows that are standard in the field. 

1. fastqs are processed and quality checked

2. Sequencing reads are mapped to a reference genome to generate BAM files

3. Variants are defined ("called") per sample

4. All samples from your dataset are genotyped at the same time, using information from the rest of the dataset to decide how accurate the information at any site is likely to be

## A more detailed look at what's going on below the hood 

FYI: Not fully updated. I'm working on this section

### Step 0: Prepping the reference genome

A quick step that runs once. snpArcher takes the reference genome you've given it, makes a copy and indexes it. Indexing is like making a "table of contents" for the reference. It makes it easy to go to a certain part of the reference genome later, speeding up downstream computation.

### Step 1: Read filtering

For each input read pair, the tool `fastp` trims off adapter sequences and removes low-quality reads. Outputs to `results/filtered_fastqs`.

### Step 2: Alignment (aka Mapping)

Reads are aligned to the reference genome using `bwa mem` and sorted by position using `samtools sort`. Rule: `bwa_mem`. Alignment happens per set of read pairs, and generates a BAM for each.

The mapping stage takes into account mappability (computed in rules: genmap and mappability_bed). This is how easy it would be to confidently map something to that part of the reference genome. Reads that align to regions of the genome with poor mappability (e.g. highly repetitive regions) will recieve lower mapping quality scores. These lower quality alignments are annotated as such.

### Step 3: Merging and duplicate marking

1. The per-read pair BAMs are merged into a per-library BAM using `samtools merge`. Rule: `merge_library_bams`.

2. PCR and optical duplicates are flagged with `sambamba markdup`. Rule: `markdup_library`.

3. Deduplicated per-library BAMs are merged to create one BAM per sample. Rule: `merge_dedup_libraries`. Outputs to `results/bams/markdup`.

All intermediate BAMs are removed, avoiding storage bloat. BAMs are generally smaller than raw data, but for poorer quality samples (ancient DNA, fecal DNA, degraded samples), or samples mapped to a reference genome from a different species, BAMs can be huge. This is because BAMs store information about how reads align. If they align really well, there's little additional info to retain. If they don't (because the reference is a diverged species, or because the sequencing is crappy) there's a lot of mismatches that need to be recorded, inflating the size of the BAM.

### Step 4: Creating chunks for parallelization

snpArcher is so efficient because it splits the reference genome into chunks ("intervals") and then runs downstream variant calling and genotyping steps on these chunks rather than the whole genome all at once, which would take a lot longer.

1. Per-sample variant calling is performed in chunks. Intervals created in rule: `x`

2. Joint genotyping is performed in different chunks, with more chunks if there are more individuals in your dataset. Intervals are created in rule: `x`.

### Step 5: Per-sample variant calling

`GATK Haplotypecaller` is used to call variants for each sample's mapped reads, in intervals as defined above. HaplotypeCaller will call both SNPs and indels at the same time. If you tell snpArcher you have low coverage data, it adjusts the pruning standards, so that sites with less data aren't discarded. The output files are gVCFs, one per interval per sample. Rule: `x`. Outputs to `x`. 

Interval gvcfs are then concatenated per sample, to give you one gVCF per sample. Rule: `x`. Outputs to `x`.

### Step 6: Consolidating samples for genotyping

Joint genotyping needs all samples' gVCFs organized by genomic region rather than by sample. For each interval that will be used for joint genotyping, `GATK GenomicsDBImport` loads every sample's data for that interval into a GenomicsDB workspace. Now, data is organized by interval rather than by sample. Rule: `x`.

### Step 7: Joint genotyping

Using these DB Intervals, `GATK GenotypeGVCFs` is then used to do the actual genotyping. "Joint" genotyping means information is shared across samples. So, a site that's clearly variable in the cohort can be genotyped more confidently in an individual with lower coverage at that site, because we have more information. Rule: `x`.

Of note: variant calling is intentionally lenient. It aims to maximize sensitivity (the chance you will pick up on a variant) at the expense of accuracy (you will probably call some variants with little evidence to support them being "real"). While you may include some false positives through this process, you reduce the risk of throwing out true positives.

RETURN HERE AT END OF RUNNING PROCESS TO CONFIRM BEHAVIOR. ASK CLAUDE TO FIND ABOVE RULE NAMES (X). 

After each interval is genotyped, everything is concatenated into one raw VCF. The output is `results/vcfs/raw.vcf.gz`.  


NOT UPDATED AFTER HERE





### Step 8: Annotating Called Variants with Filters

The raw VCF will contain a lot of sites with crappy support. `GATK VariantFiltration` applies GATK's best-practice hard-filter thresholds (on QD, FS, SOR, MQ, MQRankSum, ReadPosRankSum, QUAL, with different
cutoffs for SNPs vs indels). Importantly, this annotates the FILTER column rather than removing sites — flagged records stay in the file but are marked as failing. The result is `results/vcfs/filtered.vcf.gz` (CHECK ONCE MINE COMPLETES, GUESSING).

If a variant gets a filter flag it did not "pass" that filter. Variants with filter flags are ones you should consider removing, but again it's up to you to do this later. You should use the filtered.vcf.gz for downstream analyses, because it contains these filter annotations.

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




