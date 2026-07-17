#!/usr/bin/env bash
# Generates synthetic RNA-seq reads for all (read_count x read_length) combinations
# using Flux Simulator. We borrow ONLY the data-generation method from the Salmon
# papers (Patro et al. 2017) -- their goal was accuracy, ours is performance.
#
# Requires:
#   - flux-simulator on PATH, running under Java 8 (newer JDKs break Flux
#     Simulator's XStream usage with InaccessibleObjectException). Create a
#     dedicated env and activate it before running this script:
#       mamba create -n flux-sim -c bioconda -c conda-forge flux-simulator openjdk=8 -y
#       conda activate flux-sim
#
# Usage: bash generate_reads.sh <genome_fasta> <annotation.gtf> <output_dir>
#
# <genome_fasta> is a single multi-sequence FASTA (e.g. reference/genome.fa).
# Flux Simulator requires one FASTA file per chromosome (named to match the
# GTF's seqname column, e.g. IV.fa) -- this script splits it automatically
# into <output_dir>/genome_chroms/ the first time, and reuses it afterward.

set -euo pipefail

GENOME_FASTA="${1:?usage: generate_reads.sh <genome_fasta> <annotation.gtf> <output_dir>}"
GTF_FILE="${2:?missing annotation.gtf}"
OUTDIR="${3:?missing output_dir}"

if ! command -v flux-simulator > /dev/null 2>&1; then
  echo "ERROR: flux-simulator not found on PATH." >&2
  echo "Activate the dedicated env first: conda activate flux-sim" >&2
  exit 1
fi

READ_COUNTS=(1000000 10000000 50000000)   # 1M, 10M, 50M
READ_LENGTHS=(76 100 150)

CONFIG_DIR="$(dirname "$0")/configs"
CHROM_DIR="${OUTDIR}/genome_chroms"
mkdir -p "${CONFIG_DIR}" "${OUTDIR}" "${CHROM_DIR}"

# Split genome into per-chromosome FASTA files (only if not already done).
if [ -z "$(ls -A "${CHROM_DIR}" 2>/dev/null)" ]; then
  echo "Splitting ${GENOME_FASTA} into per-chromosome files under ${CHROM_DIR}..."
  awk -v dir="${CHROM_DIR}" '/^>/{filename=dir"/"substr($1,2)".fa"} {print > filename}' "${GENOME_FASTA}"
else
  echo "Reusing existing per-chromosome files in ${CHROM_DIR}"
fi

for reads in "${READ_COUNTS[@]}"; do
  for len in "${READ_LENGTHS[@]}"; do
    label="${reads}reads_${len}bp"
    par_file="${CONFIG_DIR}/${label}.par"
    work_dir="${OUTDIR}/${label}"
    mkdir -p "${work_dir}"

    cat > "${par_file}" <<EOF
REF_FILE_NAME   ${GTF_FILE}
GEN_DIR         ${CHROM_DIR}
NB_MOLECULES    5000000
READ_NUMBER     ${reads}
READ_LENGTH     ${len}
PAIRED_END      YES
FASTA           YES
EOF

    echo "=== Simulating ${label} ==="
    pushd "${work_dir}" > /dev/null
    cp "${par_file}" ./simulation.par
    # `yes` auto-answers the "overwrite existing .pro?" prompt on reruns
    yes | flux-simulator -p simulation.par -x -l -s

    # Flux Simulator writes both mates interleaved in one FASTA, distinguished
    # by a /1 or /2 header suffix. Salmon's -1/-2 need separate files, so split:
    echo "Splitting into mate1/mate2 FASTA files..."
    awk '
      /^>/ {
        if ($0 ~ /\/1$/) out="simulation_1.fasta"; else out="simulation_2.fasta"
        print > out; next
      }
      { print > out }
    ' simulation.fasta
    popd > /dev/null
  done
done

echo "All 9 datasets generated under ${OUTDIR}/<reads>reads_<len>bp/ (simulation_1.fasta / simulation_2.fasta)"

