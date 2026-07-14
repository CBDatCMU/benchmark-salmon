#!/usr/bin/env bash
# Builds the Salmon index once per node (index build time is recorded separately
# from quantification time -- see "index vs quant time" metric).
#
# Usage: bash build_index.sh <transcripts.fa> <index_out_dir> [threads]

set -euo pipefail

TRANSCRIPTS_FA="${1:?usage: build_index.sh <transcripts.fa> <index_out_dir> [threads]}"
INDEX_DIR="${2:?missing index_out_dir}"
THREADS="${3:-8}"

echo "Building Salmon index -> ${INDEX_DIR} (threads=${THREADS})"

START=$(date +%s.%N)
salmon index -t "${TRANSCRIPTS_FA}" -i "${INDEX_DIR}" -k 31 -p "${THREADS}"
END=$(date +%s.%N)

ELAPSED=$(echo "${END} - ${START}" | bc)
echo "Index build wall time: ${ELAPSED}s"
echo "${ELAPSED}" > "${INDEX_DIR}/../index_build_time.txt"
