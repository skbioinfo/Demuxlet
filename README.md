# scRNA-seq Demultiplexing Pipelines: popscle (demuxlet) and souporcell

This repository provides reproducible scripts and notes for **donor assignment (demultiplexing)** in pooled scRNA-seq experiments using:

- **popscle** (`dsc-pileup` + `demuxlet`) — genotype-based demultiplexing with donor VCFs
- **souporcell** — genotype-free demultiplexing (clusters donors directly from expressed SNPs)

Both approaches support **doublet detection** and are widely used for multiplexed scRNA-seq.

---

## When to use which tool?

### ✅ popscle / demuxlet (VCF available)
Use when you have donor genotypes in a VCF (e.g., SNP array or WGS).
- Strong donor labeling (known donors)
- Doublet detection
- Typical inputs: Cell Ranger BAM + donor VCF

popscle overview recommends a 2-step flow:
1) `dsc-pileup`  
2) `demuxlet` (with genotypes) or `freemuxlet` (without genotypes)

### ✅ souporcell (no VCF needed)
Use when you **do not** have genotypes for donors.
- Clusters donors from expressed SNPs
- Includes doublet calling and ambient RNA estimation
- Typical inputs: Cell Ranger BAM + barcodes

---

## Inputs (common)

From **Cell Ranger `count`** output:
- `outs/possorted_genome_bam.bam`
- `outs/filtered_feature_bc_matrix/barcodes.tsv.gz`

> Note: `cellranger aggr` does not produce a merged BAM. If you pooled libraries with `aggr`, you may need to merge BAMs (e.g., `samtools merge`) before demultiplexing.

---

## Clone the upstream tools

### 1) Clone and build popscle (demuxlet)

```bash
git clone https://github.com/statgen/popscle.git
cd popscle
git submodule update --init --recursive
make
# popscle binary will be created in the repo (depends on build setup)


## souporcell: genotype-free *and* VCF-assisted workflows

souporcell supports demultiplexing pooled scRNA-seq in two practical modes:

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

