#!/usr/bin/env bash
#SBATCH --job-name=salmon-benchmark
#SBATCH --partition=RM
#SBATCH --nodes=1
#SBATCH --ntasks-per-node=1
#SBATCH --cpus-per-task=32
#SBATCH --time=08:00:00
#SBATCH --account=cis260196p   # TODO: swap for the RM allocation once granted
#SBATCH --output=salmon_benchmark_%j.out

# NOTE: cis260196p currently only has GPU hours. This job needs an RM
# allocation -- confirm with Ivan before submitting.

module load anaconda3 2>/dev/null || true
source activate salmon-bench 2>/dev/null || true   # conda env with salmon + flux-simulator

INDEX_DIR="${HOME}/benchmark-salmon/salmon_index"
READS_DIR="${HOME}/benchmark-salmon/flux_reads"
OUT_CSV="results/bridges2_rm/salmon_benchmark.csv"

python3 run_salmon_benchmark.py \
  --index "${INDEX_DIR}" \
  --reads-dir "${READS_DIR}" \
  --node bridges2_rm \
  --out "${OUT_CSV}" \
  --index-build-time "${INDEX_DIR}/../index_build_time.txt"
