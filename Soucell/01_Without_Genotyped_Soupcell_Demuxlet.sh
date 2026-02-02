#!/usr/bin/env bash
set -euo pipefail

RUN_DIR="data/run_001"
META="${RUN_DIR}/metadata.tsv"
OUTDIR="results/souporcell/run_001"
FASTA="/path/to/genome.fa"
THREADS=16
K=4

mkdir -p "${OUTDIR}"

tail -n +2 "${META}" | while read -r SAMPLE BAM BARCODE VCF
do
  echo "Processing ${SAMPLE}"

  SAMPLE_OUT="${OUTDIR}/${SAMPLE}"
  mkdir -p "${SAMPLE_OUT}"

  zcat "${BARCODE}" > "${SAMPLE_OUT}/barcodes.txt"

  souporcell_pipeline.py \
    -i "${BAM}" \
    -b "${SAMPLE_OUT}/barcodes.txt" \
    -f "${FASTA}" \
    -t "${THREADS}" \
    -k "${K}" \
    -o "${SAMPLE_OUT}"

done

