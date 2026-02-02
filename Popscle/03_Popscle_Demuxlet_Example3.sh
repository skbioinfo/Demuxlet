#!/usr/bin/env bash
set -euo pipefail

DATA_ROOT="data"
RESULTS_ROOT="results/demuxlet"
LOG_ROOT="logs/demuxlet"

POPSCLE="/path/to/popscle"
THREADS=8

mkdir -p "${RESULTS_ROOT}" "${LOG_ROOT}"

log(){ echo "$(date)  $*" | tee -a "${LOG_ROOT}/popscle_all_runs.log"; }

run_one_sample(){
  local run_id="$1" sample_id="$2" bam="$3" bc_gz="$4" vcf="$5"

  local outdir="${RESULTS_ROOT}/${run_id}/${sample_id}"
  local logdir="${LOG_ROOT}/${run_id}/${sample_id}"
  mkdir -p "${outdir}" "${logdir}"

  [[ -e "${bam}" ]] || { echo "Missing BAM: ${bam}" >&2; exit 1; }
  [[ -e "${bc_gz}" ]] || { echo "Missing barcodes: ${bc_gz}" >&2; exit 1; }
  [[ -e "${vcf}" ]] || { echo "Missing VCF: ${vcf}" >&2; exit 1; }
  [[ -e "${vcf}.tbi" ]] || { echo "Missing VCF index: ${vcf}.tbi" >&2; exit 1; }

  zcat "${bc_gz}" > "${outdir}/barcodes.txt"

  "${POPSCLE}" dsc-pileup \
    --sam "${bam}" \
    --vcf "${vcf}" \
    --out "${outdir}/pileup" \
    --gzip \
    --nsamples "${THREADS}" \
    > "${logdir}/dsc-pileup.log" 2>&1

  "${POPSCLE}" demuxlet \
    --plp "${outdir}/pileup" \
    --vcf "${vcf}" \
    --field GT \
    --out "${outdir}/demuxlet" \
    --group-list "${outdir}/barcodes.txt" \
    > "${logdir}/demuxlet.log" 2>&1

  log "[DONE] ${run_id}/${sample_id}"
}

process_run(){
  local run_dir="$1"
  local run_id
  run_id="$(basename "${run_dir}")"
  local meta="${run_dir}/metadata.tsv"

  [[ -e "${meta}" ]] || { log "[SKIP] ${run_id}: missing metadata.tsv"; return; }

  log "[RUN] ${run_id}"
  tail -n +2 "${meta}" | while IFS=$'\t' read -r sample_id bam_path bc_path vcf_path; do
    local bam="${run_dir}/${bam_path}"
    local bc="${run_dir}/${bc_path}"
    local vcf="${vcf_path}"
    [[ "${vcf}" == /* ]] || vcf="${run_dir}/${vcf}"

    run_one_sample "${run_id}" "${sample_id}" "${bam}" "${bc}" "${vcf}"
  done
}

log "Starting popscle demuxlet across all runs in ${DATA_ROOT}"
for run_dir in "${DATA_ROOT}"/*; do
  [[ -d "${run_dir}" ]] || continue
  process_run "${run_dir}"
done
log "All runs completed."

