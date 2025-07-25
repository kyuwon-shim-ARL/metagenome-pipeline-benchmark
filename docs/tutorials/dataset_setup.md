# Dataset Setup Guide

This guide explains how to set up the benchmark datasets required for pipeline evaluation.

## Overview

The benchmarking framework uses two main types of datasets:

1. **CAMI-2**: Ground truth datasets for accuracy evaluation
2. **MetaSUB**: Real-world datasets for robustness evaluation

## CAMI-2 Dataset Setup

### What is CAMI-2?

CAMI-2 (Critical Assessment of Metagenome Interpretation) provides synthetic metagenomic datasets with known ground truth, making them perfect for accuracy benchmarking.

### Download CAMI-2 Data

```bash
# Create data directory
mkdir -p data/raw/cami2

# Download CAMI-2 Mouse Gut dataset (example)
# Note: Replace URLs with actual CAMI-2 download links
wget -O data/raw/cami2/sample1_R1.fastq.gz [CAMI2_URL]/sample1_R1.fastq.gz
wget -O data/raw/cami2/sample1_R2.fastq.gz [CAMI2_URL]/sample1_R2.fastq.gz

# Download ground truth data
wget -O data/reference/cami2_ground_truth.tar.gz [CAMI2_URL]/ground_truth.tar.gz
cd data/reference && tar -xzf cami2_ground_truth.tar.gz
```

### CAMI-2 Ground Truth Structure

The ground truth data includes:
- **Genome sequences**: Reference genomes used to create synthetic data
- **Taxonomic assignments**: Species/strain level classifications
- **Functional annotations**: Gene functions and pathways
- **Abundance profiles**: True relative abundances

### Configuration

Create sample sheet for CAMI-2 data:

```csv
# data/raw/cami2/samplesheet.csv
sample,short_reads_1,short_reads_2,ground_truth
cami2_sample1,data/raw/cami2/sample1_R1.fastq.gz,data/raw/cami2/sample1_R2.fastq.gz,data/reference/cami2/sample1_truth.txt
```

## MetaSUB Dataset Setup

### What is MetaSUB?

MetaSUB (Metagenomics & Metadesign of Subways & Urban Biomes) provides real-world urban environment metagenomic samples for robustness testing.

### Download MetaSUB Data

```bash
# Create MetaSUB data directory
mkdir -p data/raw/metasub

# Example: Download from SRA (replace with actual accession numbers)
# Install SRA Toolkit first if not available
sratoolkit.3.1.1/bin/fastq-dump --split-files --gzip SRR8650234 -O data/raw/metasub/
```

### Sample Selection Criteria

For robustness testing, select samples with:
- **Different environments**: Subway, park, beach, etc.
- **Varying complexity**: Low to high microbial diversity
- **Geographic diversity**: Different cities/countries
- **Seasonal variation**: Different collection times

### Configuration

Create MetaSUB sample sheet:

```csv
# data/raw/metasub/samplesheet.csv
sample,short_reads_1,short_reads_2,environment,location,complexity
metasub_subway_nyc,data/raw/metasub/SRR8650234_1.fastq.gz,data/raw/metasub/SRR8650234_2.fastq.gz,subway,NYC,high
metasub_park_boston,data/raw/metasub/SRR8650235_1.fastq.gz,data/raw/metasub/SRR8650235_2.fastq.gz,park,Boston,medium
```

## Automated Download Script

Use the provided script for automated dataset download:

```bash
# Download all required datasets
./bin/download_datasets.sh

# Options:
./bin/download_datasets.sh --cami2-only      # CAMI-2 only
./bin/download_datasets.sh --metasub-only    # MetaSUB only
./bin/download_datasets.sh --small-test      # Small test datasets
```

## Dataset Configuration

### Global Dataset Settings

Edit `configs/benchmark.config`:

```nextflow
params {
    datasets {
        cami2 {
            enabled = true
            path = './data/raw/cami2'
            samplesheet = './data/raw/cami2/samplesheet.csv'
            ground_truth = './data/reference/cami2'
            type = 'accuracy_benchmark'
        }
        metasub {
            enabled = true
            path = './data/raw/metasub'  
            samplesheet = './data/raw/metasub/samplesheet.csv'
            type = 'robustness_benchmark'
        }
    }
}
```

### Dataset-Specific Configurations

Create specific config files:

```bash
# CAMI-2 specific settings
# configs/datasets/cami2.config
params {
    // CAMI-2 specific parameters
    ground_truth_available = true
    evaluation_metrics = ['checkm', 'busco', 'amber', 'gtdbtk']
    complexity = 'high'
}

# MetaSUB specific settings  
# configs/datasets/metasub.config
params {
    // MetaSUB specific parameters
    ground_truth_available = false
    evaluation_metrics = ['checkm', 'busco', 'gtdbtk']
    focus = 'robustness'
}
```

## Storage Requirements

### Disk Space Estimates

| Dataset | Raw Data | Processed | Total |
|---------|----------|-----------|-------|
| CAMI-2 (5 samples) | ~50 GB | ~100 GB | ~150 GB |
| MetaSUB (10 samples) | ~100 GB | ~200 GB | ~300 GB |
| **Total Minimum** | **~150 GB** | **~300 GB** | **~450 GB** |

### Recommendations

- Use **fast SSD storage** for active processing
- Archive raw data to **slower/cheaper storage** after processing  
- Set up **automated cleanup** of intermediate files
- Consider **cloud storage** for large dataset sharing

## Quality Control

### Pre-processing Checks

Before benchmarking, verify:

```bash
# Check file integrity
md5sum -c data/raw/*/checksums.md5

# Basic quality metrics
fastqc data/raw/*/*.fastq.gz

# Sequence statistics
seqkit stats data/raw/*/*.fastq.gz
```

### Sample Filtering

Filter samples based on:
- **Read count**: Minimum 1M paired reads
- **Quality**: Mean Q-score > 20
- **Contamination**: Human DNA < 10%
- **Complexity**: Shannon diversity index

## Troubleshooting

### Common Issues

**Download failures**:
```bash
# Retry with resume capability
wget -c -t 3 [URL]
```

**Storage space issues**:
```bash
# Check available space
df -h

# Clean up temporary files
find data/ -name "*.tmp" -delete
```

**Corrupt files**:
```bash
# Verify integrity
gunzip -t *.fastq.gz

# Re-download if needed
rm corrupt_file.fastq.gz
wget [URL]
```

For more help, see the [FAQ](../faq.md) or open an issue on GitHub.