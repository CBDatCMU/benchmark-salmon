#!/usr/bin/env bash
# Small reference for validating the pipeline before scaling to full human
# GENCODE: Saccharomyces cerevisiae (R64-1-1) from Ensembl. Genome is ~12Mb,
# ~6000 transcripts -- fast to simulate and fast to index.
#
# Uses Ensembl's "current_release" symlinks so this doesn't go stale, and
# resolves the exact GTF filename (which embeds a release number) via
# directory listing.

set -euo pipefail

OUTDIR="$(dirname "$0")"
FASTA_BASE="https://ftp.ensembl.org/pub/current_fasta/saccharomyces_cerevisiae"
GTF_BASE="https://ftp.ensembl.org/pub/current_gtf/saccharomyces_cerevisiae"

echo "[1/3] Downloading yeast genome FASTA..."
curl -L -o "${OUTDIR}/genome.fa.gz" "${FASTA_BASE}/dna/Saccharomyces_cerevisiae.R64-1-1.dna.toplevel.fa.gz"
gunzip -f "${OUTDIR}/genome.fa.gz"

echo "[2/3] Resolving + downloading GTF annotation..."
GTF_FILENAME=$(curl -s "${GTF_BASE}/" | grep -oE 'Saccharomyces_cerevisiae\.R64-1-1\.[0-9]+\.gtf\.gz' | head -1)
if [ -z "${GTF_FILENAME}" ]; then
  echo "Could not resolve GTF filename automatically -- check ${GTF_BASE}/ manually." >&2
  exit 1
fi
curl -L -o "${OUTDIR}/annotation.gtf.gz" "${GTF_BASE}/${GTF_FILENAME}"
gunzip -f "${OUTDIR}/annotation.gtf.gz"

echo "[3/3] Downloading transcript (cDNA) FASTA for salmon index..."
curl -L -o "${OUTDIR}/transcripts.fa.gz" "${FASTA_BASE}/cdna/Saccharomyces_cerevisiae.R64-1-1.cdna.all.fa.gz"
gunzip -f "${OUTDIR}/transcripts.fa.gz"

echo "Done. Files in ${OUTDIR}: genome.fa, annotation.gtf, transcripts.fa"
