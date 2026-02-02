#!/usr/bin/env bash
set -euo pipefail

RUN_DIR="data/run_001"
META="${RUN_DIR}/metadata.tsv"
OUTDIR="results/demuxlet/run_001"
POPSCLE="/path/to/popscle"
THREADS=8

mkdir -p "${OUTDIR}"

tail -n +2 "${META}" | while read -r SAMPLE BAM BARCODE VCF
do
  echo "Processing ${SAMPLE}"

  SAMPLE_OUT="${OUTDIR}/${SAMPLE}"
  mkdir -p "${SAMPLE_OUT}"

  zcat "${BARCODE}" > "${SAMPLE_OUT}/barcodes.txt"

  # Pileup
  ${POPSCLE} dsc-pileup \
    --sam "${BAM}" \
    --vcf "${VCF}" \
    --out "${SAMPLE_OUT}/pileup" \
    --gzip \
    --nsamples "${THREADS}"

  # Demuxlet
  ${POPSCLE} demuxlet \
    --plp "${SAMPLE_OUT}/pileup" \
    --vcf "${VCF}" \
    --field GT \
    --out "${SAMPLE_OUT}/demuxlet" \
    --group-list "${SAMPLE_OUT}/barcodes.txt"

done

