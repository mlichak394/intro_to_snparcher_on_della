# Getting published data on Della 

To run snpArcher you need sequencing data and a reference genome to map it to. 

snpArcher has the capability to pull data and a reference genome from e.g. NCBI for you, but Della doesn't have internet access on the compute nodes. THis means that all of your data--reference genome, generated sequencing data and any published sequencing data you might want to use--must be downloaded locally to Della before you can run snpArcher. 

## (1) Downloading a reference genome

I have a directory in /scratch called `reference_genomes` where I store reference genomes. To find the reference genome for your species, you can go to the [NCBI Genomes resource](https://www.ncbi.nlm.nih.gov/home/genomes/) and type in the scientific name of your species in the search bar. Or, a quick google of "species name genome ncbi" usually does the trick. 

Once you're on the NCBI page for your species look for a genome with a "reference" tag and/or a green checkmark. This is what NCBI considers the current reference, but there may be other options like older genome assemblies created with older technology or newer assemblies that haven't yet been fully vetted/processed. There may be reasons to use an older or newer reference genome than the one NCBI considers standard, so do consider your downstream plans and the field standards before you make a choice.

I download reference genomes hosted on NCBI using ftp:

1. Click on the link for the assembly you want to download, then click on "FTP" at the top of the page. 

2. Find the link ending in .fna.gz and copy this link (right click and "copy link")

    - This the ftp (file transfer protocol) for your reference genome sequence. 

    - The other stuff here might link to an annotation file, QC files for the assembly, coding sequences files, RNA transcript sequences, etc. You might need these later for other analyses, but we don't need them for snpArcher.

3. Once you have the ftp link to the reference genome you want to download copied, navigate to the directory where you're going to put your reference genome on Della. 

     ```bash
     cd /scratch/gpfs/CAMPBELLSTATON/ml9889/reference_genomes
     ```

4. Use `wget` to pull this genome using the ftp link. Here I'm pulling the genome for one of my favorite animals, the Pallas Cat (_Otocolobus manul_). 

    ```bash
    wget https://ftp.ncbi.nlm.nih.gov/genomes/all/GCA/028/564/725/GCA_028564725.2_OtoMan_p1.0/GCA_028564725.2_OtoMan_p1.0_genomic.fna.gz
    ```

5. Tools like GATK require an unzipped reference genome, so unzip the one you just downloaded.

    ```bash
    gunzip GCA_028564725.2_OtoMan_p1.0_genomic.fna.gz
    ```

There are other ways to download reference genomes. NCBI has a datasets tool -- this allows you to pull several different files all at once if you maybe wanted to pull the genomic sequence as well as the annotation file and RNA transcripts, etc. 

If there's a specific reference you're interested in, it might be hosted somewhere other than NCBI. In that case, follow download instructions given by the repository or group that has the genome you want.

## (2) Pulling data from a sequence repository

Beyond sequencing data you generate yourself, you may also want to pull published data to genotype along side your data. In general, having more data increases the power of the mapping and calling algorithms that snpArcher uses. Plus you never know when having published data ready to analyze might become useful! 

There are several different approaches you might take for looking for published data. One approach is to search the NCBI Sequence Read Archive (SRA). If there is a lot of published data for your species, it might be easier to sort through by clicking on the "Send to Run Selector" link at the top of the SRA page for the species of interest. On Run Selector you can use the check boxes and filters to find relevant data.

Once you have some data you know you want to download, you can click the "Accession List" option under "Selected Data". This will give you a text file with a list of accession numbers for the runs you selected. 

From here you'll need to use the [SRA-toolkit](https://github.com/ncbi/sra-tools/wiki) to download the data. This is because NCBI stores sequencing data in this special SRA format. 

For data on ENA, you can use Globus to download to Della.

I store my sequencing data in a project subdirectory called `raw_seq_data`.