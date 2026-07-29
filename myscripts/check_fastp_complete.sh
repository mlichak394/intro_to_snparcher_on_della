#!/bin/bash
#SBATCH --job-name=check_fastp
#SBATCH --account=campbellstaton
#SBATCH --cpus-per-task=1
#SBATCH --mem=4G
#SBATCH --time=16:00:00
#SBATCH --output=check_fastp_%j.out
#SBATCH --error=check_fastp_%j.err

# For every fastp JSON under results/fastp, compare raw R1 reads x2 against
# the reads fastp reported reading. Mismatch = fastp dropped/lost reads.
set -euo pipefail

fastp_dir=/scratch/gpfs/CAMPBELLSTATON/ml9889/elephant/snpArcher/results/fastp

printf "%s\t%s\t%s\t%s\n" "unit" "raw_x2" "fastp_reported" "match"

find "$fastp_dir" -name '*.json' | while read -r j; do
  # input R1 path: pull the argument after --in1 from the command stored in the json
  in1=$(grep -o -- '--in1 [^ ]*' "$j" | head -1 | awk '{print $2}')
  raw=$(( $(zcat "$in1" | wc -l) / 4 * 2 ))
  rep=$(jq '.summary.before_filtering.total_reads' "$j")
  [ "$raw" -eq "$rep" ] && m=OK || m=MISMATCH
  printf "%s\t%s\t%s\t%s\n" "$j" "$raw" "$rep" "$m"
done