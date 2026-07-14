#!/usr/bin/env bash
# Downloads the reference genome + GTF annotation used by Flux Simulator to
# simulate reads, and by Salmon to build the quantification index.
#
# Default: human GENCODE release (chromosome + comprehensive annotation).
# Swap GENCODE_RELEASE / URLs below if a smaller reference (e.g. yeast, chr21
# only) is preferred for faster pipeline iteration before scaling up.

set -euo pipefail

GENCODE_RELEASE="46"
OUTDIR="$(dirname "$0")"

GENOME_URL="https://ftp.ebi.ac.uk/pub/databases/gencode/Gencode_human/release_${GENCODE_RELEASE}/GRCh38.primary_assembly.genome.fa.gz"
GTF_URL="https://ftp.ebi.ac.uk/pub/databases/gencode/Gencode_human/release_${GENCODE_RELEASE}/gencode.v${GENCODE_RELEASE}.annotation.gtf.gz"
TRANSCRIPTS_URL="https://ftp.ebi.ac.uk/pub/databases/gencode/Gencode_human/release_${GENCODE_RELEASE}/gencode.v${GENCODE_RELEASE}.transcripts.fa.gz"

echo "[1/3] Downloading genome FASTA..."
curl -L -o "${OUTDIR}/genome.fa.gz" "${GENOME_URL}"
gunzip -f "${OUTDIR}/genome.fa.gz"

echo "[2/3] Downloading GTF annotation..."
curl -L -o "${OUTDIR}/annotation.gtf.gz" "${GTF_URL}"
gunzip -f "${OUTDIR}/annotation.gtf.gz"

echo "[3/3] Downloading transcript FASTA (used directly for salmon index)..."
curl -L -o "${OUTDIR}/transcripts.fa.gz" "${TRANSCRIPTS_URL}"
gunzip -f "${OUTDIR}/transcripts.fa.gz"

echo "Done. Files in ${OUTDIR}: genome.fa, annotation.gtf, transcripts.fa"
