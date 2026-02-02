# Inputs
BAM="outs/possorted_genome_bam.bam"
VCF="donors.vcf.gz"
BARCODES_GZ="outs/filtered_feature_bc_matrix/barcodes.tsv.gz"
OUTDIR="demuxlet_out"
mkdir -p "${OUTDIR}"

# Extract barcodes
zcat "${BARCODES_GZ}" > "${OUTDIR}/barcodes.txt"

# Step 1: pileup
popscle dsc-pileup \
  --sam "${BAM}" \
  --vcf "${VCF}" \
  --out "${OUTDIR}/pileup" \
  --gzip

# Step 2: demuxlet
popscle demuxlet \
  --plp "${OUTDIR}/pileup" \
  --vcf "${VCF}" \
  --field GT \
  --out "${OUTDIR}/demuxlet" \
  --group-list "${OUTDIR}/barcodes.txt"

