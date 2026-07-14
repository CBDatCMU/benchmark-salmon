#!/usr/bin/env bash
# Generates synthetic RNA-seq reads for all (read_count x read_length) combinations
# using Flux Simulator. We borrow ONLY the data-generation method from the Salmon
# papers (Patro et al. 2017) -- their goal was accuracy, ours is performance.
#
# Requires: flux-simulator on PATH (mamba install -c bioconda flux-simulator)
#
# Usage: bash generate_reads.sh <genome_dir> <annotation.gtf> <output_dir>

set -euo pipefail

GENOME_DIR="${1:?usage: generate_reads.sh <genome_dir> <annotation.gtf> <output_dir>}"
GTF_FILE="${2:?missing annotation.gtf}"
OUTDIR="${3:?missing output_dir}"

READ_COUNTS=(1000000 10000000 50000000)   # 1M, 10M, 50M
READ_LENGTHS=(76 100 150)

CONFIG_DIR="$(dirname "$0")/configs"
mkdir -p "${CONFIG_DIR}" "${OUTDIR}"

for reads in "${READ_COUNTS[@]}"; do
  for len in "${READ_LENGTHS[@]}"; do
    label="${reads}reads_${len}bp"
    par_file="${CONFIG_DIR}/${label}.par"
    work_dir="${OUTDIR}/${label}"
    mkdir -p "${work_dir}"

    cat > "${par_file}" <<EOF
REF_FILE_NAME   ${GTF_FILE}
GEN_DIR         ${GENOME_DIR}
NB_MOLECULES    5000000
READ_NUMBER     ${reads}
READ_LENGTH     ${len}
PAIRED_END      YES
FASTA           NO
EOF

    echo "=== Simulating ${label} ==="
    pushd "${work_dir}" > /dev/null
    cp "${par_file}" ./simulation.par
    flux-simulator -p simulation.par -x -l -s
    popd > /dev/null
  done
done

echo "All 9 datasets generated under ${OUTDIR}/<reads>reads_<len>bp/"
