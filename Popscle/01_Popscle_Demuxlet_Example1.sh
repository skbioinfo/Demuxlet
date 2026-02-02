#!/usr/bin/env bash
set -euo pipefail

###############################################################################
# popscle demuxlet pipeline
# - Runs dsc-pileup then demuxlet for each Cell Ranger sample
#
# Requirements:
#   - popscle installed (https://github.com/statgen/popscle)
#   - bgzipped & tabix-indexed VCF (.vcf.gz + .tbi)
#   - Cell Ranger BAM: outs/possorted_genome_bam.bam
#   - Cell Ranger barcodes: filtered_feature_bc_matrix/barcodes.tsv.gz
#
# Output:
#   - per-sample folder containing pileup + demuxlet outputs and logs
###############################################################################

# ------------ User configuration ------------
RUNDATE="10162024"
RUNNAME="2ndBatch"
WORKDIR="Project/ProcessedData/Demuxlet/${RUNNAME}"

POPSCLE="/software/popscle/bin/popscle"

# Recommended: set THREADS for dsc-pileup (if desired); demuxlet itself is light.
THREADS=8

# If you want parallel execution across samples:
#   PARALLEL=1 will run all samples in background and wait at end.
PARALLEL=0
# -------------------------------------------

mkdir -p "${WORKDIR}"
RUNTIMES_FILE="${WORKDIR}/runtimes-demuxlet_${RUNNAME}_${RUNDATE}.log"
: > "${RUNTIMES_FILE}"

# Sample metadata (keep arrays aligned by index)
SAMPLES=(
  "Run1"
  "Run2"
  "Run3"
  "Run4"
)

BAMS=(
  "/Cellranger/Run1/outs/possorted_genome_bam.bam"
  "/Cellranger/Run2/outs/possorted_genome_bam.bam"
  "/Cellranger/Run3/outs/possorted_genome_bam.bam"
  "/Cellranger/Run4/outs/possorted_genome_bam.bam"
)

VCFS=(
  "/VCFpath/Run_1_SampleA_SampleB.vcf.gz"
  "/VCFpath/Run_2_SampleA_SampleB.vcf.gz"
  "/VCFpath/Run_3_SampleA_SampleB.vcf.gz"
  "/VCFpath/Run_4_SampleA_SampleB.vcf.gz"
)

BARCODES_GZ=(
  "/Cellranger/Run1/outs/filtered_feature_bc_matrix/barcodes.tsv.gz"
  "/Cellranger/Run2/outs/filtered_feature_bc_matrix/barcodes.tsv.gz"
  "/Cellranger/Run3/outs/filtered_feature_bc_matrix/barcodes.tsv.gz"
  "/Cellranger/Run4/outs/filtered_feature_bc_matrix/barcodes.tsv.gz"
)

check_exists () {
  local f="$1"
  [[ -e "${f}" ]] || { echo "ERROR: Missing file: ${f}" >&2; exit 1; }
}

run_one () {
  local sample="$1"
  local bam="$2"
  local vcf="$3"
  local barcodes_gz="$4"

  check_exists "${bam}"
  check_exists "${vcf}"
  check_exists "${vcf}.tbi"
  check_exists "${barcodes_gz}"
  check_exists "${POPSCLE}"

  local outdir="${WORKDIR}/${sample}"
  mkdir -p "${outdir}"

  local barcode_txt="${outdir}/valid_barcodes_${sample}_${RUNNAME}_${RUNDATE}.txt"
  local pileup_prefix="${outdir}/pileup_${sample}_${RUNNAME}_${RUNDATE}"
  local demux_prefix="${outdir}/demuxlet_${sample}_${RUNNAME}_${RUNDATE}"

  echo "$(date)  [${sample}] extracting barcodes" | tee -a "${RUNTIMES_FILE}"
  zcat "${barcodes_gz}" > "${barcode_txt}"

  echo "$(date)  [${sample}] dsc-pileup start" | tee -a "${RUNTIMES_FILE}"
  "${POPSCLE}" dsc-pileup \
    --sam "${bam}" \
    --vcf "${vcf}" \
    --out "${pileup_prefix}" \
    --gzip \
    --nsamples "${THREADS}" \
    > "${outdir}/dsc-pileup.log" 2>&1
  echo "$(date)  [${sample}] dsc-pileup end" | tee -a "${RUNTIMES_FILE}"

  echo "$(date)  [${sample}] demuxlet start" | tee -a "${RUNTIMES_FILE}"
  "${POPSCLE}" demuxlet \
    --plp "${pileup_prefix}" \
    --vcf "${vcf}" \
    --field GT \
    --out "${demux_prefix}" \
    --group-list "${barcode_txt}" \
    > "${outdir}/demuxlet.log" 2>&1
  echo "$(date)  [${sample}] demuxlet end" | tee -a "${RUNTIMES_FILE}"

  echo "$(date)  [${sample}] DONE -> ${outdir}" | tee -a "${RUNTIMES_FILE}"
}

# Main loop
pids=()
for i in "${!SAMPLES[@]}"; do
  if [[ "${PARALLEL}" -eq 1 ]]; then
    run_one "${SAMPLES[$i]}" "${BAMS[$i]}" "${VCFS[$i]}" "${BARCODES_GZ[$i]}" &
    pids+=("$!")
  else
    run_one "${SAMPLES[$i]}" "${BAMS[$i]}" "${VCFS[$i]}" "${BARCODES_GZ[$i]}"
  fi
done

# Wait for parallel jobs
if [[ "${PARALLEL}" -eq 1 ]]; then
  for pid in "${pids[@]}"; do
    wait "${pid}"
  done
fi

echo "$(date) All samples completed." | tee -a "${RUNTIMES_FILE}"

