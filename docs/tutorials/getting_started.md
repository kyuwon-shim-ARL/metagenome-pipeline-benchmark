# Getting Started with Metagenome Pipeline Benchmarking

This guide will help you get up and running with the benchmarking framework.

## Prerequisites

- **Conda/Miniconda** installed
- **Git** for version control
- **Sufficient storage** (>100GB recommended for full datasets)
- **Computing resources** (varies by pipeline, see resource requirements)

## Quick Setup

### 1. Environment Setup

```bash
# Set up the environment (conda + uv)
./bin/setup_environment.sh

# Activate the environment
conda activate metagenome-benchmark
```

### 2. Basic Test Run

```bash
# Run a basic benchmark test
./bin/run_benchmark.sh --help

# Start with a minimal test
./bin/run_benchmark.sh --config configs/benchmark.config
```

## Understanding the Framework

### Pipeline Support

The framework supports three types of pipelines:

1. **nf-core/mag variants**:
   - `standard`: Default configuration
   - `megahit_only`: MEGAHIT assembly only
   - `spades_only`: SPAdes assembly only
   - `ensemble_binning`: All tools with ensemble binning

2. **Custom pipelines**:
   - Add your own pipeline implementations
   - See `pipelines/custom/` for examples

3. **External pipelines**:
   - MetaWRAP, ATLAS, and other tools
   - Wrapped for standardized comparison

### Configuration

Main configuration files:

- `configs/benchmark.config`: Global benchmark settings
- `configs/pipeline_registry.yml`: Pipeline definitions
- `configs/datasets/`: Dataset-specific configurations

### Execution Profiles

- `standard`: Local execution
- `slurm`: SLURM cluster execution
- `singularity`: Containerized execution

## Next Steps

1. **Download datasets**: See [Dataset Setup](dataset_setup.md)
2. **Add custom pipelines**: See [Custom Pipelines](custom_pipelines.md)
3. **Configure evaluation**: See [Evaluation Setup](evaluation_setup.md)
4. **View results**: See [Results Analysis](results_analysis.md)

## Troubleshooting

### Common Issues

**Environment activation fails**:
```bash
# Make sure conda is in PATH
conda --version
# Re-run setup
./bin/setup_environment.sh
```

**Nextflow not found**:
```bash
# Activate environment first
conda activate metagenome-benchmark
nextflow -version
```

**Permission denied**:
```bash
# Make scripts executable
chmod +x bin/*.sh
```

For more help, check the [FAQ](../faq.md) or open an issue on GitHub.