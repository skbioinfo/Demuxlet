#!/usr/bin/env bash
set -euo pipefail

DATA_ROOT="data"
RESULTS_ROOT="results/souporcell"
LOG_ROOT="logs/souporcell"

FASTA="/path/to/GRCh38/genome.fa"
THREADS=16
K=4

# Optional: VCF-assisted mode (sites-only VCF). Leave empty for genotype-free mode.
SITES_VCF=""

mkdir -p "${RESULTS_ROOT}" "${LOG_ROOT}"

log(){ echo "$(date)  $*" | tee -a "${LOG_ROOT}/souporcell_all_runs.log"; }

run_one_sample(){
  local run_id="$1" sample_id="$2" bam="$3" bc_gz="$4"

  local outdir="${RESULTS_ROOT}/${run_id}/${sample_id}"
  local logdir="${LOG_ROOT}/${run_id}/${sample_id}"
  mkdir -p "${outdir}" "${logdir}"

  [[ -e "${bam}" ]] || { echo "Missing BAM: ${bam}" >&2; exit 1; }
  [[ -e "${bc_gz}" ]] || { echo "Missing barcodes: ${bc_gz}" >&2; exit 1; }
  [[ -e "${FASTA}" ]] || { echo "Missing FASTA: ${FASTA}" >&2; exit 1; }

  zcat "${bc_gz}" > "${outdir}/barcodes.txt"

  if [[ -n "${SITES_VCF}" ]]; then
    [[ -e "${SITES_VCF}" ]] || { echo "Missing sites VCF: ${SITES_VCF}" >&2; exit 1; }
    [[ -e "${SITES_VCF}.tbi" ]] || { echo "Missing sites VCF index: ${SITES_VCF}.tbi" >&2; exit 1; }

    souporcell_pipeline.py \
      -i "${bam}" \
      -b "${outdir}/barcodes.txt" \
      -f "${FASTA}" \
      -t "${THREADS}" \
      -k "${K}" \
      -o "${outdir}" \
      --vcf "${SITES_VCF}" \
      > "${logdir}/souporcell.log" 2>&1
  else
    souporcell_pipeline.py \
      -i "${bam}" \
      -b "${outdir}/barcodes.txt" \
      -f "${FASTA}" \
      -t "${THREADS}" \
      -k "${K}" \
      -o "${outdir}" \
      > "${logdir}/souporcell.log" 2>&1
  fi

  log "[DONE] ${run_id}/${sample_id}"
}

process_run(){
  local run_dir="$1"
  local run_id
  run_id="$(basename "${run_dir}")"
  local meta="${run_dir}/metadata.tsv"

  [[ -e "${meta}" ]] || { log "[SKIP] ${run_id}: missing metadata.tsv"; return; }

  log "[RUN] ${run_id}"
  tail -n +2 "${meta}" | while IFS=$'\t' read -r sample_id bam_path bc_path; do
    local bam="${run_dir}/${bam_path}"
    local bc="${run_dir}/${bc_path}"
    run_one_sample "${run_id}" "${sample_id}" "${bam}" "${bc}"
  done
}

log "Starting souporcell across all runs in ${DATA_ROOT}"
for run_dir in "${DATA_ROOT}"/*; do
  [[ -d "${run_dir}" ]] || continue
  process_run "${run_dir}"
done
log "All runs completed."

