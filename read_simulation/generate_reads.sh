#!/usr/bin/env bash
# Generates synthetic paired-end reads for all (read_count x read_length)
# combinations using dwgsim, simulating directly from the transcript FASTA.
# Salmon quantifies against transcripts directly, so no genome/GTF/chromosome
# splitting is needed -- this replaces the earlier flux-simulator approach,
# which is unmaintained (last release ~2012-2013) and required a dedicated
# Java 8 environment to work around InaccessibleObjectException crashes.
#
# We disable simulated mutations/indels (-r 0 -R 0) since our goal is
# PERFORMANCE benchmarking (wall time / CPU / memory), not accuracy -- we
# just need realistic-length reads at realistic depth, not a ground-truth
# variant set to check quantification correctness against.
#
# Requires: dwgsim on PATH (mamba install -c bioconda dwgsim)
#
# Usage: bash generate_reads.sh <transcripts_fasta> <output_dir>

set -euo pipefail

TRANSCRIPTS_FASTA="$(realpath "${1:?usage: generate_reads.sh <transcripts_fasta> <output_dir>}")"
OUTDIR="$(realpath -m "${2:?missing output_dir}")"

if ! command -v dwgsim > /dev/null 2>&1; then
  echo "ERROR: dwgsim not found on PATH." >&2
  echo "Install it with: mamba install -c bioconda dwgsim" >&2
  exit 1
fi

READ_COUNTS=(1000000 10000000 50000000)   # 1M, 10M, 50M (total reads, both mates combined)
READ_LENGTHS=(76 100 150)

mkdir -p "${OUTDIR}"

for reads in "${READ_COUNTS[@]}"; do
  for len in "${READ_LENGTHS[@]}"; do
    label="${reads}reads_${len}bp"
    work_dir="${OUTDIR}/${label}"
    mkdir -p "${work_dir}"

    if [ -s "${work_dir}/simulation_1.fastq.gz" ] && [ -s "${work_dir}/simulation_2.fastq.gz" ]; then
      echo "=== Skipping ${label} (already complete) ==="
      continue
    fi

    pairs=$((reads / 2))
    echo "=== Simulating ${label} (${pairs} read pairs) ==="

    dwgsim -N "${pairs}" -1 "${len}" -2 "${len}" \
           -r 0 -R 0 -e 0.001 -E 0.001 \
           "${TRANSCRIPTS_FASTA}" "${work_dir}/simulation"

    mv "${work_dir}/simulation.bwa.read1.fastq.gz" "${work_dir}/simulation_1.fastq.gz"
    mv "${work_dir}/simulation.bwa.read2.fastq.gz" "${work_dir}/simulation_2.fastq.gz"
    rm -f "${work_dir}/simulation.bfast.fastq.gz" "${work_dir}/simulation.mutations.txt" "${work_dir}/simulation.mutations.vcf"
  done
done

echo "All 9 datasets generated under ${OUTDIR}/<reads>reads_<len>bp/ (simulation_1.fastq.gz / simulation_2.fastq.gz)"
