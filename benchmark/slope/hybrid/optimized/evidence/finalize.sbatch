#!/bin/bash
#SBATCH --account=mkolar_1314
#SBATCH --partition=main
#SBATCH --constraint=epyc-7513
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=1
#SBATCH --mem=4G
#SBATCH --time=00:05:00
#SBATCH --job-name=ps95-hybrid-v2-finalize
#SBATCH --output=finalize-%j.out
set -euo pipefail
cd "$SLURM_SUBMIT_DIR"
python3 analysis/summarize.py --input . --output summary.json
python3 analysis/summarize.py --input . --output summary.json --check
python3 analysis/report.py --input . --output RESULTS.md
for check in \
  benchmark/adaptive/broad/check_summary.py \
  benchmark/adaptive/broad/check_evidence.py \
  benchmark/slope/check_summary.py \
  benchmark/slope/check_evidence.py \
  benchmark/slope/path_reuse/check_summary.py \
  benchmark/slope/path_reuse/check_evidence.py \
  benchmark/slope/first_order/check_summary.py \
  benchmark/slope/first_order/check_evidence.py \
  benchmark/slope/extraction/check_results.py \
  benchmark/slope/hybrid/summarize.py; do
  python3 "integrity/$check"
done
printf 'FINALIZATION_COMPLETE\n'
