#!/usr/bin/env bash
# lanec2 has no job scheduler -- run directly with nohup so the sweep survives
# SSH idle timeouts. Adjust paths below to match where reference/reads/index
# live on lanec2.

set -euo pipefail

module load py3-numpy/1.26.4 || true   # matches prior lanec2 setup pattern

INDEX_DIR="${HOME}/benchmark-salmon/salmon_index"
READS_DIR="${HOME}/benchmark-salmon/flux_reads"
OUT_CSV="results/lanec2/salmon_benchmark.csv"

python3 run_salmon_benchmark.py \
  --index "${INDEX_DIR}" \
  --reads-dir "${READS_DIR}" \
  --node lanec2 \
  --out "${OUT_CSV}" \
  --index-build-time "${INDEX_DIR}/../index_build_time.txt"
