# Metagenome Pipeline Benchmarking Framework

A comprehensive benchmarking framework for evaluating and comparing metagenome analysis pipelines with a focus on accuracy, robustness, and resource efficiency.

## Overview

This framework enables systematic comparison of different metagenomic analysis pipelines including:
- **nf-core/mag** with various parameter configurations
- **Custom pipelines** and tool combinations
- **External pipelines** like MetaWRAP, ATLAS, etc.

## Quick Start

```bash
# 1. Set up environment
./bin/setup_environment.sh

# 2. Download benchmark datasets
./bin/download_datasets.sh

# 3. Run benchmark comparison
./bin/run_benchmark.sh --config configs/benchmark.config

# 4. View results
open results/reports/benchmark_report.html
```

## Key Features

### 🔍 Multi-Pipeline Support
- nf-core/mag variants and optimizations
- Custom pipeline integration
- External tool wrappers

### 📊 Comprehensive Evaluation
- **Accuracy**: CAMI-2 ground truth comparison
- **Robustness**: Real-world data (MetaSUB) testing
- **Efficiency**: Resource usage tracking

### 📈 Automated Reporting
- Interactive HTML reports
- Comparative analysis plots
- Best practices recommendations

## Architecture

```
metagenome-pipeline-benchmark/
├── pipelines/           # Pipeline definitions
├── workflows/           # Benchmark orchestration
├── src/                # Evaluation and comparison code
├── configs/            # Configuration files
└── results/            # Generated reports and analysis
```

## Documentation

- [Installation Guide](docs/tutorials/installation.md)
- [Adding Custom Pipelines](docs/tutorials/custom_pipelines.md)
- [API Reference](docs/api/)
- [Best Practices Guide](docs/best_practices.md)

## Citation

If you use this benchmarking framework in your research, please cite:

```
[Citation information will be added after publication]
```

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Contributing

We welcome contributions! Please see our [Contributing Guidelines](CONTRIBUTING.md) for details.