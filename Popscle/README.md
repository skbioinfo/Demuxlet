# popscle (demuxlet) – Multi-run scRNA-seq Demultiplexing

This module provides a reproducible workflow to demultiplex pooled scRNA-seq using **popscle**:
- `dsc-pileup` → generates SNP pileups per barcode
- `demuxlet` → assigns each cell barcode to a donor using genotype VCFs (and detects doublets)

Designed for **multiple sequencing runs/batches**, processed automatically in a loop.

---

## When to use popscle/demuxlet?

Use this workflow when you have **donor genotypes** (VCF with `GT` fields):
- SNP array genotypes
- WGS/WES genotypes
- Imputed genotypes

demuxlet provides:
- donor assignment per cell
- doublet calls
- assignment likelihoods

---

## Inputs (per sample)

From Cell Ranger `count` output:
- `outs/possorted_genome_bam.bam`
- `outs/filtered_feature_bc_matrix/barcodes.tsv.gz`

Genotypes:
- bgzipped + tabix-indexed VCF: `donors.vcf.gz` and `donors.vcf.gz.tbi`

> Important: VCF build must match the BAM reference build (e.g., GRCh38/hg38).

---

## Clone and build popscle

```bash
git clone https://github.com/statgen/popscle.git
cd popscle
git submodule update --init --recursive
make

