## souporcell: genotype-free *and* VCF-assisted workflows

souporcell supports demultiplexing pooled scRNA-seq in two practical modes:

souporcell3 : (https://github.com/wheaton5/souporcell)
[Article](https://www.nature.com/articles/s41592-020-0820-1)
### A) Genotype-free demultiplexing (no VCF)
This is the default and most widely used approach. souporcell calls variants from the scRNA-seq BAM, builds donor genotypes, clusters cells into donors, and identifies doublets.

**Inputs**
- Cell Ranger BAM: `outs/possorted_genome_bam.bam`
- Valid barcodes: `outs/filtered_feature_bc_matrix/barcodes.tsv.gz`
- Reference FASTA (matching the BAM reference build): `genome.fa`
- Expected number of donors: `-k`

**Example**
```bash
BAM="outs/possorted_genome_bam.bam"
BARCODES_GZ="outs/filtered_feature_bc_matrix/barcodes.tsv.gz"
FASTA="/path/to/GRCh38/genome.fa"
OUTDIR="souporcell_out"
THREADS=16
K=4

mkdir -p "${OUTDIR}"
zcat "${BARCODES_GZ}" > "${OUTDIR}/barcodes.txt"

souporcell_pipeline.py \
  -i "${BAM}" \
  -b "${OUTDIR}/barcodes.txt" \
  -f "${FASTA}" \
  -t "${THREADS}" \
  -k "${K}" \
  -o "${OUTDIR}"
