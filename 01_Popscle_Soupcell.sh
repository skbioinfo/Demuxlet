#!/usr/bin/env bash
set -euo pipefail

###############################################################################
# Run demultiplexing for ALL runs automatically (no per-run submission)
#
# Expected input structure:
#   data/<RUN_ID>/metadata.tsv
#
# metadata.tsv columns (tab-separated):
#   sample_id    bam_path    barcode_path    vcf_path
#
# Tools supported:
#   - popscle: dsc-pileup + demuxlet  (requires vcf_path)
#   - souporcell: genotype-free OR VCF-assisted (sites VCF optional)
###############################################################################

# ----------------------- USER CONFIG -----------------------
DATA_ROOT="data"                     # contains run folders: data/run_001, data/run_002, ...
RESULTS_ROOT="results"               # outputs go here
LOG_ROOT="logs"                      # logs go here

MODE="both"                          # demuxlet | souporcell | both

# popscle (demuxlet)
POPSCLE="/path/to/popscle"
DEMUXLET_THREADS=8

# souporcell
SOUP_FASTA="/path/to/GRCh38/genome.fa"
SOUP_THREADS=16
SOUP_K=4                             # expected number of donors
SOUP_SITES_VCF=""                    # optional: sites.vcf.gz (leave empty to run genotype-free)

# parallel options
PARALLEL_SAMPLES=0                   # 0 = run sequentially; >0 uses background jobs per run
# -----------------------------------------------------------

mkdir -p "${RESULTS_ROOT}" "${LOG_ROOT}"

log() { echo "$(date)  $*" | tee -a "${LOG_ROOT}/run_all_runs.log" ; }

run_demuxlet_one_sample() {
  local run_id="$1"
  local sample_id="$2"
  local bam="$3"
  local barcode_gz="$4"
  local vcf="$5"

  local outdir="${RESULTS_ROOT}/demuxlet/${run_id}/${sample_id}"
  local logdir="${LOG_ROOT}/demuxlet/${run_id}/${sample_id}"
  mkdir -p "${outdir}" "${logdir}"

  # Basic checks
  [[ -e "${bam}" ]] || { echo "Missing BAM: ${bam}" >&2; exit 1; }
  [[ -e "${barcode_gz}" ]] || { echo "Missing barcodes: ${barcode_gz}" >&2; exit 1; }
  [[ -e "${vcf}" ]] || { echo "Missing VCF: ${vcf}" >&2; exit 1; }
  [[ -e "${vcf}.tbi" ]] || { echo "Missing VCF index: ${vcf}.tbi" >&2; exit 1; }

  zcat "${barcode_gz}" > "${outdir}/barcodes.txt"

  "${POPSCLE}" dsc-pileup \
    --sam "${bam}" \
    --vcf "${vcf}" \
    --out "${outdir}/pileup" \
    --gzip \
    --nsamples "${DEMUXLET_THREADS}" \
    > "${logdir}/dsc-pileup.log" 2>&1

  "${POPSCLE}" demuxlet \
    --plp "${outdir}/pileup" \
    --vcf "${vcf}" \
    --field GT \
    --out "${outdir}/demuxlet" \
    --group-list "${outdir}/barcodes.txt" \
    > "${logdir}/demuxlet.log" 2>&1
}

run_souporcell_one_sample() {
  local run_id="$1"
  local sample_id="$2"
  local bam="$3"
  local barcode_gz="$4"

  local outdir="${RESULTS_ROOT}/souporcell/${run_id}/${sample_id}"
  local logdir="${LOG_ROOT}/souporcell/${run_id}/${sample_id}"
  mkdir -p "${outdir}" "${logdir}"

  [[ -e "${bam}" ]] || { echo "Missing BAM: ${bam}" >&2; exit 1; }
  [[ -e "${barcode_gz}" ]] || { echo "Missing barcodes: ${barcode_gz}" >&2; exit 1; }
  [[ -e "${SOUP_FASTA}" ]] || { echo "Missing FASTA: ${SOUP_FASTA}" >&2; exit 1; }

  zcat "${barcode_gz}" > "${outdir}/barcodes.txt"

  if [[ -n "${SOUP_SITES_VCF}" ]]; then
    [[ -e "${SOUP_SITES_VCF}" ]] || { echo "Missing sites VCF: ${SOUP_SITES_VCF}" >&2; exit 1; }
    [[ -e "${SOUP_SITES_VCF}.tbi" ]] || { echo "Missing sites VCF index: ${SOUP_SITES_VCF}.tbi" >&2; exit 1; }

    # VCF-assisted mode (sites-only VCF)
    souporcell_pipeline.py \
      -i "${bam}" \
      -b "${outdir}/barcodes.txt" \
      -f "${SOUP_FASTA}" \
      -t "${SOUP_THREADS}" \
      -k "${SOUP_K}" \
      -o "${outdir}" \
      --vcf "${SOUP_SITES_VCF}" \
      > "${logdir}/souporcell.log" 2>&1
  else
    # Genotype-free mode
    souporcell_pipeline.py \
      -i "${bam}" \
      -b "${outdir}/barcodes.txt" \
      -f "${SOUP_FASTA}" \
      -t "${SOUP_THREADS}" \
      -k "${SOUP_K}" \
      -o "${outdir}" \
      > "${logdir}/souporcell.log" 2>&1
  fi
}

process_one_run() {
  local run_dir="$1"
  local run_id
  run_id="$(basename "${run_dir}")"
  local meta="${run_dir}/metadata.tsv"

  [[ -e "${meta}" ]] || { log "[SKIP] ${run_id}: missing metadata.tsv"; return; }

  log "[RUN] ${run_id} -> reading ${meta}"

  # Read metadata (skip header)
  local pids=()
  tail -n +2 "${meta}" | while IFS=$'\t' read -r sample_id bam_path barcode_path vcf_path; do
    # Allow relative paths inside metadata
    local bam="${run_dir}/${bam_path}"
    local bc="${run_dir}/${barcode_path}"
    local vcf="${vcf_path}"

    # If vcf_path is relative, resolve from run_dir
    if [[ "${vcf}" != /* ]]; then
      vcf="${run_dir}/${vcf}"
    fi

    log "  [SAMPLE] ${run_id}/${sample_id}"

    if [[ "${PARALLEL_SAMPLES}" -gt 0 ]]; then
      (
        if [[ "${MODE}" == "demuxlet" || "${MODE}" == "both" ]]; then
          run_demuxlet_one_sample "${run_id}" "${sample_id}" "${bam}" "${bc}" "${vcf}"
        fi
        if [[ "${MODE}" == "souporcell" || "${MODE}" == "both" ]]; then
          run_souporcell_one_sample "${run_id}" "${sample_id}" "${bam}" "${bc}"
        fi
      ) &
      pids+=("$!")
      # throttle
      while (( ${#pids[@]} >= PARALLEL_SAMPLES )); do
        wait "${pids[0]}"
        pids=("${pids[@]:1}")
      done
    else
      if [[ "${MODE}" == "demuxlet" || "${MODE}" == "both" ]]; then
        run_demuxlet_one_sample "${run_id}" "${sample_id}" "${bam}" "${bc}" "${vcf}"
      fi
      if [[ "${MODE}" == "souporcell" || "${MODE}" == "both" ]]; then
        run_souporcell_one_sample "${run_id}" "${sample_id}" "${bam}" "${bc}"
      fi
    fi
  done

  # wait for remaining background jobs
  if [[ "${PARALLEL_SAMPLES}" -gt 0 ]]; then
    wait
  fi

  log "[DONE] ${run_id}"
}

log "Starting multi-run processing in ${DATA_ROOT}"
for run_dir in "${DATA_ROOT}"/*; do
  [[ -d "${run_dir}" ]] || continue
  process_one_run "${run_dir}"
done
log "All runs completed."

